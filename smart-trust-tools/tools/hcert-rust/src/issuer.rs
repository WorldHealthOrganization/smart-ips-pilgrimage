//! Two-phase issuance, QR Code Generation steps 3 to 8. `prepare` returns
//! the bytes to sign; any key holder signs them (an HSM, WebCrypto in a
//! browser); `finish` checks the signature and assembles the HC1 string
//! (STT-ISS-004, STT-COS-006, STT-CWT-001 to STT-CWT-005, STT-SEL-003).

use crate::cbor::{self, Item};
use crate::codec;
use crate::cose;
use crate::payload::{self, Payload, PayloadKind, Registry};
use crate::types::*;
use crate::verifier::{CLAIM_EXP, CLAIM_HCERT, CLAIM_IAT, CLAIM_ISS};

#[derive(Clone, Debug, PartialEq)]
pub struct IssueRequest {
    /// One or more payloads, each under its own subclaim (STT-SEL-004).
    pub payloads: Vec<Payload>,
    pub iss: Option<String>,
    pub iat: NumericDate,
    pub exp: NumericDate,
    pub alg: CoseAlgorithm,
    /// The DSC whose key will sign; the kid is derived from it (STT-KID-001).
    pub dsc_der: Vec<u8>,
    pub allow_development_subclaims: bool,
}

/// What `prepare` returns: the protected header, the CWT and the bytes to sign.
#[derive(Clone, Debug, PartialEq)]
pub struct PendingSignature {
    pub protected: Vec<u8>,
    pub payload: Vec<u8>,
    pub alg: CoseAlgorithm,
    pub kid: Kid,
    pub dsc_der: Vec<u8>,
    /// The CBOR Sig_structure (STT-COS-004).
    pub to_be_signed: Vec<u8>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct IssuedHcert {
    pub hc1: String,
    pub cose: Vec<u8>,
}

fn invalid(path: &str, code: &str, message: &str) -> IssueError {
    IssueError::PayloadInvalid(vec![ValidationIssue { path: path.into(), code: code.into(), message: message.into(), severity: Severity::Blocking }])
}

/// The CWT claim set: iss, exp, iat and hcert {subclaim: body, ...}
/// (STT-CWT-001, STT-SEL-004). The encoder orders the hcert keys.
pub fn build_cwt(iss: Option<&str>, iat: NumericDate, exp: NumericDate, entries: Vec<(i64, Item)>) -> Result<Vec<u8>, IssueError> {
    let mut claims = Vec::new();
    if let Some(iss) = iss {
        claims.push((Item::Int(CLAIM_ISS), Item::Text(iss.into())));
    }
    claims.push((Item::Int(CLAIM_EXP), Item::Int(exp)));
    claims.push((Item::Int(CLAIM_IAT), Item::Int(iat)));
    claims.push((Item::Int(CLAIM_HCERT), Item::Map(entries.into_iter().map(|(sc, body)| (Item::Int(sc), body)).collect())));
    cbor::encode(&Item::Map(claims)).map_err(|e| invalid("", "cbor", &e.message))
}

/// The protected header {1: alg, 4: kid} (STT-COS-002, STT-COS-003).
pub fn protected_header(alg: CoseAlgorithm, kid: &Kid) -> Vec<u8> {
    cbor::encode(&Item::Map(vec![(Item::Int(1), Item::Int(alg.label())), (Item::Int(4), Item::Bytes(kid.to_vec()))])).expect("distinct keys")
}

/// One payload's subclaim and CBOR body, after its own checks.
fn entry(p: &Payload, req: &IssueRequest, reg: &Registry) -> Result<(i64, Item), IssueError> {
    let (subclaim, body) = match p {
        Payload::DvcMin(p) => {
            let issues: Vec<_> = payload::validate(p).into_iter().filter(|i| i.severity == Severity::Blocking).collect();
            if !issues.is_empty() {
                return Err(IssueError::PayloadInvalid(issues));
            }
            (reg.subclaim_for(PayloadKind::DvcMin), payload::to_item(p).map_err(|m| invalid("extensions", "invalid-extension", &m))?)
        }
        Payload::Vhl(p) => {
            let issues: Vec<_> = crate::vhl::validate(p, None).into_iter().filter(|i| i.severity == Severity::Blocking).collect();
            if !issues.is_empty() {
                return Err(IssueError::PayloadInvalid(issues));
            }
            // A CBOR map, not a vhlink:/ string (STT-VHL-002).
            (reg.subclaim_for(PayloadKind::Vhl), crate::vhl::to_item(p))
        }
        Payload::Raw { subclaim, cbor: bytes } => (*subclaim, cbor::decode(bytes, &DEFAULT_LIMITS).map_err(|e| invalid("", "cbor", &e.message))?),
    };
    if reg.lookup(subclaim).is_none() {
        return Err(IssueError::UnknownSubclaim(subclaim));
    }
    if subclaim < 0 && !req.allow_development_subclaims {
        return Err(IssueError::DevelopmentSubclaimNotAllowed(subclaim));
    }
    Ok((subclaim, body))
}

pub fn prepare(req: &IssueRequest, reg: &Registry) -> Result<PendingSignature, IssueError> {
    if req.payloads.is_empty() {
        return Err(IssueError::NoPayload);
    }
    // Duplicates first, then each payload's own checks in request order, as
    // the Kotlin library does (STT-GEN-006).
    let mut seen = Vec::with_capacity(req.payloads.len());
    for p in &req.payloads {
        let sc = match p {
            Payload::DvcMin(_) => reg.subclaim_for(PayloadKind::DvcMin),
            Payload::Vhl(_) => reg.subclaim_for(PayloadKind::Vhl),
            Payload::Raw { subclaim, .. } => *subclaim,
        };
        if seen.contains(&sc) {
            return Err(IssueError::DuplicateSubclaim(sc));
        }
        seen.push(sc);
    }
    let entries = req.payloads.iter().map(|p| entry(p, req, reg)).collect::<Result<Vec<_>, _>>()?;
    if let Some(iss) = &req.iss {
        if !(iss.len() == 2 && iss.bytes().all(|c| c.is_ascii_uppercase())) {
            return Err(invalid("iss", "not-alpha2", "iss must be two upper-case letters"));
        }
    }
    if req.exp <= req.iat {
        return Err(invalid("exp", "exp-not-after-iat", "exp must be after iat"));
    }
    let dsc = crate::x509::certificate(&req.dsc_der).map_err(IssueError::BadCertificate)?;
    // STT-CWT-004
    if req.iat < dsc.not_before || req.exp > dsc.not_after {
        return Err(IssueError::ValidityOutsideDsc);
    }
    let kid = cose::kid_from_dsc(&req.dsc_der);
    let payload = build_cwt(req.iss.as_deref(), req.iat, req.exp, entries)?;
    let protected = protected_header(req.alg, &kid);
    let to_be_signed = cose::sig_structure(&protected, &payload);
    Ok(PendingSignature { protected, payload, alg: req.alg, kid, dsc_der: req.dsc_der.clone(), to_be_signed })
}

/// Accepts an ES256 signature as 64-byte r||s or DER (WebCrypto gives the
/// former, JCA the latter); a signature from the wrong key is refused here.
pub fn finish(p: &PendingSignature, signature: &[u8]) -> Result<IssuedHcert, IssueError> {
    let sig = match p.alg {
        CoseAlgorithm::Es256 if signature.len() == 64 => signature.to_vec(),
        CoseAlgorithm::Es256 => cose::ecdsa_der_to_raw(signature)
            .map_err(|e| IssueError::BadSignatureFormat(format!("ES256 signature is neither 64-byte r||s nor DER: {e}")))?
            .to_vec(),
        CoseAlgorithm::Ps256 => signature.to_vec(),
    };
    if !crate::x509::verify(p.alg, &p.dsc_der, &p.to_be_signed, &sig) {
        return Err(IssueError::BadSignatureFormat("the signature does not verify with the DSC's public key".into()));
    }
    let cose_bytes = cose::assemble_sign1(&p.protected, &p.payload, &sig);
    Ok(IssuedHcert { hc1: codec::to_hc1(&cose_bytes), cose: cose_bytes })
}
