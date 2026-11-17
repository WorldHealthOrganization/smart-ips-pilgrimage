//! DSCs the host has loaded. No I/O. Lookup returns every DSC with the kid;
//! kids are computed from the DER, never taken from a list's labels
//! (STT-TRU-001, STT-TRU-002, STT-TRU-005, STT-KID-002, STT-SEL-006).

use crate::cose::{base64_decode, kid_from_dsc};
use crate::json::{self, Json};
use crate::types::{Kid, TrustError};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TrustedDsc {
    pub der: Vec<u8>,
    pub kid: Kid,
    pub country: Option<String>,
    pub not_before: i64,
    pub not_after: i64,
    pub extended_key_usages: Vec<String>,
    pub trust_domain: Option<String>,
    pub participant: Option<String>,
}

#[derive(Clone, Debug, Default)]
pub struct TrustStore {
    dscs: Vec<TrustedDsc>,
    /// From the GDHCN Trust Domain code system; None until loaded.
    domains: Option<Vec<String>>,
}

impl TrustStore {
    pub fn new() -> Self {
        Self::default()
    }

    fn add(&mut self, der: Vec<u8>, domain: Option<String>, participant: Option<String>) -> Result<u32, TrustError> {
        if self.dscs.iter().any(|d| d.der == der) {
            return Ok(0);
        }
        let info = crate::x509::certificate(&der).map_err(TrustError::Parse)?;
        self.dscs.push(TrustedDsc {
            kid: kid_from_dsc(&der),
            der,
            country: info.country,
            not_before: info.not_before,
            not_after: info.not_after,
            extended_key_usages: info.extended_key_usages,
            trust_domain: domain,
            participant,
        });
        Ok(1)
    }

    pub fn add_der(&mut self, der: &[u8]) -> Result<u32, TrustError> {
        self.add(der.to_vec(), None, None)
    }

    /// Every CERTIFICATE block; returns how many were new.
    pub fn add_pem(&mut self, pem: &str) -> Result<u32, TrustError> {
        let blocks = pem_blocks(pem, "CERTIFICATE").map_err(|_| TrustError::Parse("bad base64 in a PEM block".into()))?;
        if blocks.is_empty() {
            return Err(TrustError::Parse("no CERTIFICATE block".into()));
        }
        let mut n = 0;
        for b in blocks {
            n += self.add(b, None, None)?;
        }
        Ok(n)
    }

    /// The codes of a FHIR CodeSystem, as the GDHCN Trust Domain code
    /// systems publish them; nested concepts count too. Loading again
    /// replaces the set.
    pub fn load_trust_domains(&mut self, codesystem_json: &str) -> Result<u32, TrustError> {
        let doc = json::parse(codesystem_json).map_err(TrustError::Parse)?;
        if !matches!(doc, Json::Obj(_)) {
            return Err(TrustError::Parse("CodeSystem is not a JSON object".into()));
        }
        if doc.get("resourceType").and_then(Json::as_str) != Some("CodeSystem") {
            return Err(TrustError::Parse("not a FHIR CodeSystem".into()));
        }
        fn walk(concepts: Option<&Json>, out: &mut Vec<String>) {
            for c in concepts.and_then(Json::as_arr).unwrap_or_default() {
                if let Some(code) = c.get("code").and_then(Json::as_str) {
                    if !out.iter().any(|x| x == code) {
                        out.push(code.into());
                    }
                }
                walk(c.get("concept"), out);
            }
        }
        let mut codes = Vec::new();
        walk(doc.get("concept"), &mut codes);
        if codes.is_empty() {
            return Err(TrustError::Parse("CodeSystem has no concepts".into()));
        }
        let n = codes.len() as u32;
        self.domains = Some(codes);
        Ok(n)
    }

    pub fn trust_domains(&self) -> Vec<String> {
        let mut d = self.domains.clone().unwrap_or_default();
        d.sort();
        d
    }

    /// GDHCN DID trustlist v2: each verificationMethod with publicKeyJwk.x5c
    /// contributes its first certificate. Domain and participant come from
    /// the `trustlist:<domain>:<participant>:<usage>` DID path; "-" is the
    /// wildcard. Once trust domains are loaded, a document naming another
    /// domain is refused whole.
    pub fn add_did_document(&mut self, text: &str) -> Result<u32, TrustError> {
        let doc = json::parse(text).map_err(TrustError::Parse)?;
        if !matches!(doc, Json::Obj(_)) {
            return Err(TrustError::Parse("DID document is not a JSON object".into()));
        }
        let methods = doc.get("verificationMethod").and_then(Json::as_arr).ok_or_else(|| TrustError::Parse("no verificationMethod array".into()))?;
        let doc_id = doc.get("id").and_then(Json::as_str);
        fn id<'a>(m: &'a Json, doc_id: Option<&'a str>) -> Option<&'a str> {
            m.get("id").and_then(Json::as_str).or(doc_id)
        }
        let id_of = |m| id(m, doc_id);
        if let Some(known) = &self.domains {
            for m in methods {
                if let (Some(d), _) = path_of(id_of(m)) {
                    if !known.contains(&d) {
                        return Err(TrustError::UnknownTrustDomain(d));
                    }
                }
            }
        }
        let mut n = 0;
        for m in methods {
            let Some(x5c) = m.get("publicKeyJwk").and_then(|j| j.get("x5c")).and_then(Json::as_arr) else { continue };
            let first = x5c.first().and_then(Json::as_str).ok_or_else(|| TrustError::Parse("x5c entry is not a string".into()))?;
            let der = base64_decode(first).map_err(|_| TrustError::Parse("x5c entry is not base64".into()))?;
            let (domain, participant) = path_of(id_of(m));
            n += self.add(der, domain, participant)?;
        }
        Ok(n)
    }

    /// [`Self::add_did_document`], but only once the document's proof
    /// verifies against `signer`, the did:web document of the proof's
    /// verificationMethod; on any failure nothing is added (STT-TRU-006).
    pub fn add_verified_did_document(&mut self, text: &str, signer: &str) -> Result<u32, TrustError> {
        crate::didproof::verify_did_proof(text, signer)?;
        let mut next = self.clone();
        let n = next.add_did_document(text)?;
        *self = next;
        Ok(n)
    }

    pub fn candidates(&self, kid: &Kid) -> Vec<&TrustedDsc> {
        self.dscs.iter().filter(|d| &d.kid == kid).collect()
    }

    pub fn len(&self) -> usize {
        self.dscs.len()
    }

    pub fn is_empty(&self) -> bool {
        self.dscs.is_empty()
    }

    pub fn clear(&mut self) {
        self.dscs.clear();
    }
}

fn path_of(did: Option<&str>) -> (Option<String>, Option<String>) {
    let Some(did) = did else { return (None, None) };
    let parts: Vec<&str> = did.split('#').next().unwrap_or_default().split(':').collect();
    let Some(at) = parts.iter().position(|p| *p == "trustlist") else { return (None, None) };
    let level = |i: usize| parts.get(at + i).filter(|p| **p != "-" && !p.is_empty()).map(|p| p.to_string());
    (level(1), level(2))
}

/// The blocks of one PEM type, decoded.
pub fn pem_blocks(pem: &str, kind: &str) -> Result<Vec<Vec<u8>>, String> {
    let begin = format!("-----BEGIN {kind}-----");
    let end = format!("-----END {kind}-----");
    let mut out = Vec::new();
    let mut rest = pem;
    while let Some(b) = rest.find(&begin) {
        let after = &rest[b + begin.len()..];
        let e = after.find(&end).ok_or("unterminated PEM block")?;
        let body: String = after[..e].chars().filter(|c| !c.is_whitespace()).collect();
        out.push(base64_decode(&body)?);
        rest = &after[e + end.len()..];
    }
    Ok(out)
}
