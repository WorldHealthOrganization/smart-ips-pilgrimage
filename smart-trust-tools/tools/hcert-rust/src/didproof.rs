//! GDHCN trust list DID document proofs (STT-TRU-006): the JsonWebSignature2020
//! profile of WorldHealthOrganization/tng-key-distribution (ld-signatures-java
//! 1.11.0, URDNA2015 by titanium).
//!
//! Not a JSON-LD processor. The documents the key distribution service emits
//! have one fixed shape, and under the pinned contexts (did/v1, jws-2020/v1,
//! the tng-context of the environment, and security v3 for the proof options)
//! that shape maps to RDF with no blank node in the document and exactly one in
//! the proof options, so URDNA2015 reduces to: serialise each quad as N-Quads,
//! drop duplicates, sort by code point. Anything outside the shape — another
//! key, value type, context, IRI form — is refused (fail closed), so that no
//! term a JSON-LD processor would drop from the signed bytes can reach the
//! trust store unsigned.
//!
//! The JWS is detached with `b64:false`: the signing input is
//! `ASCII(header) || "." || SHA-256(options) || SHA-256(document)`, and the
//! signature may be DER (what the service emits) or the 64-byte r||s of
//! RFC 7518 section 3.4.

use crate::json::{self, Json};
use crate::types::TrustError;
use p256::ecdsa::signature::Verifier;
use sha2::{Digest, Sha256};

const SEC: &str = "https://w3id.org/security#";
const RDF_TYPE: &str = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type";
const RDF_JSON: &str = "http://www.w3.org/1999/02/22-rdf-syntax-ns#JSON";
const XSD_DATETIME: &str = "http://www.w3.org/2001/XMLSchema#dateTime";
const DC_CREATED: &str = "http://purl.org/dc/terms/created";

const DID_V1: &str = "https://www.w3.org/ns/did/v1";
const JWS_2020: &str = "https://w3id.org/security/suites/jws-2020/v1";
/// The tng-context URLs the service emits, with the suffix their value set
/// IRIs carry (tng-key-distribution's bundled v1.jsonld, v1-uat.jsonld,
/// v1-dev.jsonld).
const TNG_CONTEXTS: [(&str, &str); 3] = [
    ("https://smart.who.int/trust/tng-context/v1.jsonld", ""),
    ("https://smart.who.int/trust/tng-context/v1-UAT.jsonld", "-UAT"),
    ("https://smart.who.int/trust/tng-context/v1-DEV.jsonld", "-DEV"),
];
/// tng-context terms: each a property whose IRI is the value set's, with a
/// scoped `@base` of that IRI plus "#" against which `code` (an `@id`) resolves.
const VALUE_SETS: [(&str, &str); 3] = [("domain", "Domains"), ("participant", "Participants"), ("keyusage", "KeyUsage")];

fn bad(m: impl Into<String>) -> TrustError {
    TrustError::ProofInvalid(m.into())
}

/// Verify `document`'s proof against `signer`, the did:web document of the
/// proof's verificationMethod (the host fetched it). Any failure, including a
/// document outside the profile, is [`TrustError::ProofInvalid`].
pub fn verify_did_proof(document: &str, signer: &str) -> Result<(), TrustError> {
    let doc = parse_object(document, "document")?;
    let signer = parse_object(signer, "signer document")?;
    let proof = doc.get("proof").ok_or_else(|| bad("the document has no proof"))?;
    let jws = str_of(proof.get("jws"), "proof.jws")?;
    let (header, signature) = jws_parts(jws)?;
    let doc_hash = Sha256::digest(document_nquads(&doc, true)?.as_bytes());
    let opts_hash = Sha256::digest(proof_options_nquads(proof)?.as_bytes());
    let mut input = Vec::with_capacity(header.len() + 65);
    input.extend_from_slice(header.as_bytes());
    input.push(b'.');
    input.extend_from_slice(&opts_hash);
    input.extend_from_slice(&doc_hash);
    let key = signer_key(&signer, str_of(proof.get("verificationMethod"), "proof.verificationMethod")?)?;
    if signature_candidates(&signature).iter().any(|s| key.verify(&input, s).is_ok()) {
        Ok(())
    } else {
        Err(bad("the proof's signature does not verify"))
    }
}

/// The canonical N-Quads of `document` without its proof, as signed.
#[doc(hidden)]
pub fn canonical_document(document: &str) -> Result<String, TrustError> {
    document_nquads(&parse_object(document, "document")?, false)
}

/// The canonical N-Quads of `document`'s proof options, as signed.
#[doc(hidden)]
pub fn canonical_proof_options(document: &str) -> Result<String, TrustError> {
    let doc = parse_object(document, "document")?;
    proof_options_nquads(doc.get("proof").ok_or_else(|| bad("the document has no proof"))?)
}

fn parse_object(text: &str, what: &str) -> Result<Json, TrustError> {
    let j = json::parse(text).map_err(|e| bad(format!("{what}: {e}")))?;
    if !matches!(j, Json::Obj(_)) {
        return Err(bad(format!("{what} is not a JSON object")));
    }
    no_duplicates(&j, what)?;
    Ok(j)
}

/// Refuses a duplicate member name in any object, at any depth: JSON-LD
/// processors and JSON readers disagree on which one wins.
fn no_duplicates(j: &Json, what: &str) -> Result<(), TrustError> {
    match j {
        Json::Obj(m) => {
            for (i, (k, v)) in m.iter().enumerate() {
                if m[..i].iter().any(|(e, _)| e == k) {
                    return Err(bad(format!("{what} has a duplicate key: {k}")));
                }
                no_duplicates(v, what)?;
            }
            Ok(())
        }
        Json::Arr(a) => a.iter().try_for_each(|v| no_duplicates(v, what)),
        _ => Ok(()),
    }
}

/// The members of an object, after checking it has no duplicate, every key
/// in `allowed` and every key of `required`.
fn members<'a>(j: &'a Json, what: &str, allowed: &[&str], required: &[&str]) -> Result<&'a [(String, Json)], TrustError> {
    let Json::Obj(m) = j else { return Err(bad(format!("{what} is not an object"))) };
    for (i, (k, _)) in m.iter().enumerate() {
        if !allowed.contains(&k.as_str()) {
            return Err(bad(format!("{what} has a key the profile does not model: {k}")));
        }
        if m[..i].iter().any(|(e, _)| e == k) {
            return Err(bad(format!("{what} has a duplicate key: {k}")));
        }
    }
    if let Some(r) = required.iter().find(|r| !m.iter().any(|(k, _)| k == *r)) {
        return Err(bad(format!("{what} has no {r}")));
    }
    Ok(m)
}

fn str_of<'a>(j: Option<&'a Json>, what: &str) -> Result<&'a str, TrustError> {
    j.and_then(Json::as_str).ok_or_else(|| bad(format!("{what} is not a string")))
}

/// Printable ASCII without whitespace or the characters an N-Quads IRI
/// would need escaped.
fn iri_chars_ok(s: &str) -> bool {
    s.bytes().all(|b| (0x21..0x7f).contains(&b) && !b"<>\"{}|^`\\".contains(&b))
}

/// A DID URL (the only IRIs a trust list's own terms hold) as an N-Quads
/// term, so that its JSON-LD expansion is the string itself.
fn iri(s: &str, what: &str) -> Result<String, TrustError> {
    if !s.starts_with("did:") || s.len() < 5 || !iri_chars_ok(s) {
        return Err(bad(format!("{what} is not an absolute IRI the profile accepts: {s}")));
    }
    Ok(format!("<{s}>"))
}

/// An N-Quads string literal. Control characters are refused, not escaped.
fn literal(s: &str, what: &str) -> Result<String, TrustError> {
    Ok(nq_literal(plain(s, what)?))
}

/// Refuses U+0000-U+001F and U+007F (Rust strings hold no lone surrogate,
/// and the JSON reader refuses an unpaired one).
fn plain<'a>(s: &'a str, what: &str) -> Result<&'a str, TrustError> {
    if s.chars().any(|c| c < ' ' || c == '\u{7f}') {
        return Err(bad(format!("{what} holds a control character")));
    }
    Ok(s)
}

fn nq_literal(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for c in s.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

/// URDNA2015's output for a graph with no blank node to relabel: lines
/// sorted by code point. A code point above U+FFFF is refused, so that the
/// order is the same whether an implementation compares code points or
/// UTF-16 code units (no WHO document has one).
fn canonical(mut lines: Vec<String>) -> Result<String, TrustError> {
    if lines.iter().any(|l| l.chars().any(|c| c > '\u{ffff}')) {
        return Err(bad("the canonical form holds a character above U+FFFF"));
    }
    lines.sort();
    lines.dedup();
    Ok(lines.concat())
}

fn quad(s: &str, p: &str, o: &str) -> String {
    format!("{s} {p} {o} .\n")
}

fn document_nquads(doc: &Json, with_proof: bool) -> Result<String, TrustError> {
    let top: &[&str] = &["@context", "id", "controller", "verificationMethod", "proof"];
    let required: &[&str] = if with_proof { top } else { &top[..4] };
    members(doc, "the document", top, required)?;
    let ctx = doc.get("@context").and_then(Json::as_arr).unwrap_or_default();
    let ctx: Vec<&str> = ctx.iter().filter_map(Json::as_str).collect();
    let env = match ctx[..] {
        [DID_V1, JWS_2020, tng] if doc.get("@context").and_then(Json::as_arr).map(<[Json]>::len) == Some(3) => {
            TNG_CONTEXTS.iter().find(|(u, _)| *u == tng).map(|(_, e)| *e)
        }
        _ => None,
    }
    .ok_or_else(|| bad("the document's @context is not did/v1, jws-2020/v1 and a tng-context"))?;

    let subject = iri(str_of(doc.get("id"), "id")?, "id")?;
    let sec = |t: &str| format!("<{SEC}{t}>");
    let mut q = vec![quad(&subject, &sec("controller"), &iri(str_of(doc.get("controller"), "controller")?, "controller")?)];
    let methods = doc.get("verificationMethod").and_then(Json::as_arr).ok_or_else(|| bad("verificationMethod is not an array"))?;
    for m in methods {
        // The reference variant lists DIDs; each is an IRI (did/v1: @type @id).
        if let Json::Str(r) = m {
            q.push(quad(&subject, &sec("verificationMethod"), &iri(r, "a verificationMethod reference")?));
            continue;
        }
        let what = "a verificationMethod";
        members(m, what, &["id", "type", "controller", "publicKeyJwk", "domain", "participant", "keyusage"], &["id", "type", "controller", "publicKeyJwk"])?;
        let id = iri(str_of(m.get("id"), "verificationMethod.id")?, "verificationMethod.id")?;
        if str_of(m.get("type"), "verificationMethod.type")? != "JsonWebKey2020" {
            return Err(bad("a verificationMethod is not a JsonWebKey2020"));
        }
        q.push(quad(&subject, &sec("verificationMethod"), &id));
        q.push(quad(&id, &format!("<{RDF_TYPE}>"), &sec("JsonWebKey2020")));
        q.push(quad(&id, &sec("controller"), &iri(str_of(m.get("controller"), "verificationMethod.controller")?, "verificationMethod.controller")?));
        q.push(quad(&id, &sec("publicKeyJwk"), &format!("{}^^<{RDF_JSON}>", nq_literal(&jwk_jcs(m.get("publicKeyJwk"))?))));
        for (term, set) in VALUE_SETS {
            let Some(v) = m.get(term) else { continue };
            members(v, term, &["code"], &["code"])?;
            let code = str_of(v.get("code"), term)?;
            let frag = code.strip_prefix('#').filter(|f| !f.is_empty() && !f.contains('#') && iri_chars_ok(f));
            let frag = frag.ok_or_else(|| bad(format!("{term}.code is not a fragment reference: {code}")))?;
            let vs = format!("https://smart.who.int/trust/ValueSet-{set}{env}.jsonld");
            q.push(quad(&id, &format!("<{vs}>"), &format!("<{vs}#{frag}>")));
        }
    }
    canonical(q)
}

/// RFC 8785 of a JWK whose members are strings or arrays of strings (all a
/// trust list's JWKs hold); anything else is refused rather than canonicalised.
fn jwk_jcs(jwk: Option<&Json>) -> Result<String, TrustError> {
    let jwk = jwk.ok_or_else(|| bad("a verificationMethod has no publicKeyJwk"))?;
    let Json::Obj(m) = jwk else { return Err(bad("publicKeyJwk is not an object")) };
    let names: Vec<&str> = m.iter().map(|(k, _)| k.as_str()).collect();
    members(jwk, "publicKeyJwk", &names, &[])?;
    let mut sorted: Vec<&(String, Json)> = m.iter().collect();
    sorted.sort_by(|a, b| a.0.encode_utf16().cmp(b.0.encode_utf16()));
    let mut out = String::from("{");
    for (i, (k, v)) in sorted.into_iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        out.push_str(&jcs_string(k));
        out.push(':');
        match v {
            Json::Str(s) => out.push_str(&jcs_string(plain(s, "publicKeyJwk")?)),
            Json::Arr(a) => {
                let not_str = || bad(format!("publicKeyJwk.{k} holds a value that is not a string"));
                let items = a.iter().map(|x| Ok(jcs_string(plain(x.as_str().ok_or_else(not_str)?, "publicKeyJwk")?))).collect::<Result<Vec<_>, TrustError>>()?;
                out.push('[');
                out.push_str(&items.join(","));
                out.push(']');
            }
            _ => return Err(bad(format!("publicKeyJwk.{k} is neither a string nor an array of strings"))),
        }
    }
    out.push('}');
    Ok(out)
}

/// RFC 8785 section 3.2.2.2.
fn jcs_string(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\u{8}' => out.push_str("\\b"),
            '\u{c}' => out.push_str("\\f"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if c < ' ' => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

/// The proof without jws, under security v3: one blank node, `_:c14n0`.
fn proof_options_nquads(proof: &Json) -> Result<String, TrustError> {
    let allowed = ["type", "created", "nonce", "proofPurpose", "verificationMethod", "domain", "challenge", "jws"];
    members(proof, "the proof", &allowed, &["type", "created", "proofPurpose", "verificationMethod", "jws"])?;
    if str_of(proof.get("type"), "proof.type")? != "JsonWebSignature2020" {
        return Err(bad("the proof is not a JsonWebSignature2020"));
    }
    if str_of(proof.get("proofPurpose"), "proof.proofPurpose")? != "assertionMethod" {
        return Err(bad("the proof's purpose is not assertionMethod"));
    }
    let b = "_:c14n0";
    let sec = |t: &str| format!("<{SEC}{t}>");
    // The dateTime literal keeps its lexical form: URDNA2015 does not normalise it.
    let created = literal(str_of(proof.get("created"), "proof.created")?, "proof.created")?;
    let mut q = vec![
        quad(b, &format!("<{RDF_TYPE}>"), &sec("JsonWebSignature2020")),
        quad(b, &format!("<{DC_CREATED}>"), &format!("{created}^^<{XSD_DATETIME}>")),
        quad(b, &sec("proofPurpose"), &sec("assertionMethod")),
        quad(b, &sec("verificationMethod"), &iri(str_of(proof.get("verificationMethod"), "proof.verificationMethod")?, "proof.verificationMethod")?),
    ];
    for term in ["nonce", "domain", "challenge"] {
        if let Some(v) = proof.get(term) {
            q.push(quad(b, &sec(term), &literal(str_of(Some(v), term)?, term)?));
        }
    }
    canonical(q)
}

/// Unpadded base64url (RFC 4648 section 5) with zero trailing bits: one
/// encoding per byte string.
fn base64url(s: &str, what: &str) -> Result<Vec<u8>, TrustError> {
    let err = || bad(format!("{what} is not unpadded base64url"));
    let mut out = Vec::with_capacity(s.len() * 3 / 4);
    let (mut acc, mut bits) = (0u32, 0u32);
    for c in s.bytes() {
        let v = match c {
            b'A'..=b'Z' => c - b'A',
            b'a'..=b'z' => c - b'a' + 26,
            b'0'..=b'9' => c - b'0' + 52,
            b'-' => 62,
            b'_' => 63,
            _ => return Err(err()),
        } as u32;
        acc = (acc << 6 | v) & 0xffff;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push((acc >> bits) as u8);
        }
    }
    if s.len() % 4 == 1 || acc & ((1 << bits) - 1) != 0 {
        return Err(err());
    }
    Ok(out)
}

/// The detached JWS's header (as received) and decoded signature, after
/// checking the header is exactly `{"b64":false,"crit":["b64"],"alg":"ES256"}`.
fn jws_parts(jws: &str) -> Result<(&str, Vec<u8>), TrustError> {
    let parts: Vec<&str> = jws.split('.').collect();
    let [header, "", signature] = parts[..] else { return Err(bad("proof.jws is not a detached JWS")) };
    let h = String::from_utf8(base64url(header, "the JWS header")?).map_err(|_| bad("the JWS header is not UTF-8"))?;
    let h = json::parse(&h).map_err(|e| bad(format!("the JWS header: {e}")))?;
    no_duplicates(&h, "the JWS header")?;
    // The only protected header ld-signatures' JsonWebSignature2020 signer writes.
    members(&h, "the JWS header", &["b64", "crit", "alg"], &["b64", "crit", "alg"])?;
    let crit_ok = h.get("crit").and_then(Json::as_arr).is_some_and(|a| a.len() == 1 && a[0].as_str() == Some("b64"));
    if h.get("b64") != Some(&Json::Bool(false)) || !crit_ok || h.get("alg").and_then(Json::as_str) != Some("ES256") {
        return Err(bad("the JWS header is not {\"b64\":false,\"crit\":[\"b64\"],\"alg\":\"ES256\"}"));
    }
    Ok((header, base64url(signature, "the JWS signature")?))
}

/// The ways to read the signature: strict DER, and 64-byte r||s.
fn signature_candidates(sig: &[u8]) -> Vec<p256::ecdsa::Signature> {
    let mut out = Vec::new();
    if sig.first() == Some(&0x30) {
        out.extend(p256::ecdsa::Signature::from_der(sig));
    }
    if sig.len() == 64 {
        out.extend(p256::ecdsa::Signature::from_slice(sig));
    }
    out
}

/// The P-256 key of the signer's verificationMethod whose id is exactly the
/// proof's; the signer document must be that DID's (its id is the
/// verificationMethod's DID, and the method's controller is it).
fn signer_key(signer: &Json, vm: &str) -> Result<p256::ecdsa::VerifyingKey, TrustError> {
    let signer_id = str_of(signer.get("id"), "the signer's id")?;
    if vm.split('#').next() != Some(signer_id) {
        return Err(bad(format!("the signer document is {signer_id}, not the DID of {vm}")));
    }
    let methods = signer.get("verificationMethod").and_then(Json::as_arr).ok_or_else(|| bad("the signer has no verificationMethod array"))?;
    let mut found = methods.iter().filter(|m| m.get("id").and_then(Json::as_str) == Some(vm));
    let (Some(m), None) = (found.next(), found.next()) else { return Err(bad(format!("the signer has not exactly one verificationMethod {vm}"))) };
    if m.get("type").and_then(Json::as_str) != Some("JsonWebKey2020") {
        return Err(bad("the signer's verificationMethod is not a JsonWebKey2020"));
    }
    if m.get("controller").is_some_and(|c| c.as_str() != Some(signer_id)) {
        return Err(bad("the signer's verificationMethod has another controller"));
    }
    let jwk = m.get("publicKeyJwk").ok_or_else(|| bad("the signer's verificationMethod has no publicKeyJwk"))?;
    if jwk.get("kty").and_then(Json::as_str) != Some("EC") || jwk.get("crv").and_then(Json::as_str) != Some("P-256") {
        return Err(bad("the signer's key is not an EC P-256 JWK"));
    }
    if jwk.get("alg").is_some_and(|a| a.as_str() != Some("ES256")) {
        return Err(bad("the signer's key is not for ES256"));
    }
    let mut sec1 = vec![4u8];
    for c in ["x", "y"] {
        let v = base64url(str_of(jwk.get(c), c)?, c)?;
        // Java's BigInteger.toByteArray() leaves a sign byte on half the coordinates.
        let v = match v.len() {
            32 => &v[..],
            33 if v[0] == 0 => &v[1..],
            _ => return Err(bad(format!("the signer's {c} is not 32 bytes"))),
        };
        sec1.extend_from_slice(v);
    }
    p256::ecdsa::VerifyingKey::from_sec1_bytes(&sec1).map_err(|_| bad("the signer's key is not a P-256 point"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn base64url_is_strict() {
        assert_eq!(base64url("AQ", "t").unwrap(), [1]);
        assert!(base64url("AR", "t").is_err(), "non-zero trailing bits");
        assert!(base64url("AQ==", "t").is_err(), "padding");
        assert!(base64url("A", "t").is_err());
        assert!(base64url("+/", "t").is_err());
    }

    #[test]
    fn jcs_sorts_by_utf16_and_escapes() {
        let j = json::parse(r#"{"\ud83d\ude00":"a","\uff61":"b","x":["\"\\"]}"#).unwrap();
        // U+FF61 sorts before U+1F600 by code point, after it by UTF-16 code unit (D83D).
        assert_eq!(jwk_jcs(Some(&j)).unwrap(), "{\"x\":[\"\\\"\\\\\"],\"\u{1f600}\":\"a\",\"\u{ff61}\":\"b\"}");
        assert!(jwk_jcs(Some(&json::parse(r#"{"x":"\u007f"}"#).unwrap())).is_err());
        assert!(jwk_jcs(Some(&json::parse(r#"{"x":["\n"]}"#).unwrap())).is_err());
        assert!(jwk_jcs(Some(&json::parse(r#"{"n":1}"#).unwrap())).is_err());
        assert!(jwk_jcs(Some(&json::parse(r#"{"a":[{}]}"#).unwrap())).is_err());
        assert!(jwk_jcs(Some(&json::parse(r#"{"a":"1","a":"2"}"#).unwrap())).is_err());
        assert!(jwk_jcs(Some(&json::parse(r#"[]"#).unwrap())).is_err());
        assert!(jwk_jcs(None).is_err());
        assert_eq!(nq_literal("a\\\"\n\r"), "\"a\\\\\\\"\\n\\r\"");
        assert_eq!(jcs_string("\u{8}\u{c}\t\r"), "\"\\b\\f\\t\\r\"");
    }
}
