//! The JSON surface the WebAssembly demo calls, run natively: every step in
//! order, then verify (STT-GEN-002, STT-GEN-005).

mod common;
use common::*;
use hcert::api::call;
use hcert::json::{parse, Json};
use hcert::types::CoseAlgorithm;

fn ok(req: &str) -> Json {
    let r = parse(&call(req)).unwrap();
    assert_eq!(r.get("ok"), Some(&Json::Bool(true)), "{req} -> {r:?}");
    r
}
fn st<'a>(j: &'a Json, k: &str) -> &'a str {
    j.get(k).and_then(Json::as_str).unwrap_or_else(|| panic!("{k} missing in {j:?}"))
}

const DVC: &str = r#"{"n":"Test CHILD","dob":"2026-09-28","s":"female","nt":"LAO","gn":"Test MOTHER","vx":{"vp":"XM9V38","dv":"2026-09-28","is":"org-test","bo":"HEPB-TEST"},"v":"1.0.0"}"#;

#[test]
fn stt_gen_002_every_step_is_its_own_call_and_they_compose_to_a_verifiable_hc1() {
    let assembled = ok(&format!(r#"{{"op":"assemblePayload","dvc":{DVC}}}"#));
    assert_eq!(assembled.get("issues").unwrap().as_arr().unwrap().len(), 0);
    let cwt = ok(&format!(r#"{{"op":"buildCwt","payload":"{}","iss":"XX","iat":{TESTKIT_NOW},"exp":{},"subclaim":-6}}"#, st(&assembled, "cbor"), TESTKIT_NOW + 86400));
    assert!(st(&cwt, "diagnostic").contains("-260: {"));
    let det = ok(&format!(r#"{{"op":"cborDeterministic","cbor":"{}"}}"#, st(&cwt, "cwt")));
    assert_eq!(st(&det, "cbor"), st(&cwt, "cwt"));

    let dsc = hcert::types::to_hex(&es_der());
    let prep = ok(&format!(r#"{{"op":"prepare","dvc":{DVC},"iss":"XX","iat":{TESTKIT_NOW},"exp":{},"alg":"ES256","dsc":"{dsc}"}}"#, TESTKIT_NOW + 86400));
    assert_eq!(st(&prep, "cwt"), st(&cwt, "cwt"), "prepare builds the same CWT as the separate steps");
    let sig = sign(CoseAlgorithm::Es256, &hcert::types::from_hex(st(&prep, "toBeSigned")).unwrap());
    let fin = ok(&format!(
        r#"{{"op":"finish","protected":"{}","cwt":"{}","alg":"ES256","dsc":"{dsc}","signature":"{}"}}"#,
        st(&prep, "protected"),
        st(&prep, "cwt"),
        hcert::types::to_hex(&sig)
    ));
    // steps 6 to 8 by hand give the same string
    let z = ok(&format!(r#"{{"op":"compress","data":"{}"}}"#, st(&fin, "cose")));
    let b45 = ok(&format!(r#"{{"op":"base45Encode","data":"{}"}}"#, st(&z, "data")));
    let hc1 = ok(&format!(r#"{{"op":"prefix","text":"{}"}}"#, st(&b45, "text")));
    assert_eq!(st(&hc1, "hc1"), st(&fin, "hc1"));

    let layers = ok(&format!(r#"{{"op":"decodeLayers","hc1":"{}"}}"#, st(&fin, "hc1")));
    assert_eq!(st(&layers, "cose"), st(&fin, "cose"));
    let pem = read("vectors/testkit/es256-dsc.pem").replace('\n', "\\n");
    let v = ok(&format!(r#"{{"op":"verify","hc1":"{}","trustPem":"{pem}","now":{TESTKIT_NOW}}}"#, st(&fin, "hc1")));
    assert_eq!(st(&v, "status"), "verified");
    let entries = v.get("entries").unwrap().as_arr().unwrap();
    assert_eq!(entries.len(), 1);
    assert_eq!(entries[0].get("subclaim").unwrap().as_f64(), Some(-6.0));
    assert_eq!(entries[0].get("keyUsageAuthorised"), Some(&hcert::json::Json::Bool(true)));
    assert_eq!(st(entries[0].get("payload").unwrap(), "n"), "Test CHILD");
    let late = ok(&format!(r#"{{"op":"verify","hc1":"{}","trustPem":"{pem}","now":{}}}"#, st(&fin, "hc1"), TESTKIT_NOW + 86400 * 2));
    assert_eq!((st(&late, "step"), st(&late, "reason")), ("TIME", "EXPIRED"));
}

#[test]
fn stt_tst_011_stt_tru_001_the_xxr_certificates_verify_through_the_json_surface_against_a_did_document() {
    let did = read(XXR_DSC_DID).replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n");
    let vector = json(XXR);
    let c = vector.get("certificates").unwrap().get("hepb1").unwrap();
    let iat = c.get("iat").unwrap().as_f64().unwrap() as i64;
    let v = ok(&format!(r#"{{"op":"verify","hc1":"{}","trustDid":"{did}","now":{}}}"#, c.get("hc1").unwrap().as_str().unwrap(), iat + 3600));
    assert_eq!(st(&v, "status"), "verified");
    assert_eq!(st(&v, "iss"), "XR");
    assert_eq!(st(&v, "kid"), "916ffa567c0f44a2");
}

/// A file as a JSON string literal's contents.
fn esc(path: &str) -> String {
    read(path).replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n")
}

#[test]
fn stt_tru_006_verify_trusts_a_did_document_only_once_its_proof_verifies_against_the_signer() {
    let signer = esc("vectors/gdhcn-dev-trustlist/WHO-signing-did.json");
    let vector = json(XXR);
    let c = vector.get("certificates").unwrap().get("hepb1").unwrap();
    let hc1 = c.get("hc1").unwrap().as_str().unwrap();
    let now = c.get("iat").unwrap().as_f64().unwrap() as i64 + 3600;
    for f in [XXR_DSC_DID, "vectors/gdhcn-dev-trustlist/XXR-DSC-did-2026-10-23.json"] {
        let v = ok(&format!(r#"{{"op":"verify","hc1":"{hc1}","trustDid":"{}","trustDidSigner":"{signer}","now":{now}}}"#, esc(f)));
        assert_eq!((st(&v, "status"), st(&v, "kid")), ("verified", "916ffa567c0f44a2"), "{f}");
        assert_eq!(v.get("trustDidProofVerified"), Some(&Json::Bool(true)));
    }
    let unchecked = ok(&format!(r#"{{"op":"verify","hc1":"{hc1}","trustDid":"{}","now":{now}}}"#, esc(XXR_DSC_DID)));
    assert_eq!(unchecked.get("trustDidProofVerified"), Some(&Json::Bool(false)));

    // One added member changes the canonical document: the proof fails, the call fails, nothing is verified.
    let tampered = esc(XXR_DSC_DID).replacen("\\\"kty\\\"", "\\\"ext\\\":\\\"1\\\",\\\"kty\\\"", 1);
    assert_ne!(tampered, esc(XXR_DSC_DID));
    let bad = parse(&call(&format!(r#"{{"op":"verify","hc1":"{hc1}","trustDid":"{tampered}","trustDidSigner":"{signer}","now":{now}}}"#))).unwrap();
    assert_eq!(bad.get("ok"), Some(&Json::Bool(false)));
    assert!(st(&bad, "error").starts_with("DID document proof invalid"), "{bad:?}");
    assert!(bad.get("status").is_none());
    // The wrong signer: XXR's own trust-list document is not WHO's signing DID.
    let wrong = parse(&call(&format!(r#"{{"op":"verify","hc1":"{hc1}","trustDid":"{}","trustDidSigner":"{}","now":{now}}}"#, esc(XXR_DSC_DID), esc("vectors/gdhcn-dev-trustlist/XXR-did.json")))).unwrap();
    assert_eq!(wrong.get("ok"), Some(&Json::Bool(false)), "{wrong:?}");
    let alone = parse(&call(&format!(r#"{{"op":"verify","hc1":"{hc1}","trustDidSigner":"{signer}","now":{now}}}"#))).unwrap();
    assert_eq!(st(&alone, "error"), "trustDidSigner needs trustDid");
}

#[test]
fn stt_tst_001_the_pr129_vector_verifies_through_the_json_surface() {
    let pem = read(PR129_DSC).replace('\n', "\\n");
    let v = ok(&format!(r#"{{"op":"verify","hc1":"{}","trustPem":"{pem}","now":{NOW}}}"#, pr129_hc1("bcg")));
    assert_eq!(st(&v, "status"), "verified");
    assert_eq!(st(&v, "kid"), "58733e058aaa6621");
    let bad = parse(&call(r#"{"op":"verify","hc1":"HC1:abc","now":0}"#)).unwrap();
    assert_eq!(st(&bad, "reason"), "BASE45_INVALID");
    let err = parse(&call(r#"{"op":"nope"}"#)).unwrap();
    assert_eq!(err.get("ok"), Some(&Json::Bool(false)));
}

#[cfg(feature = "qr")]
#[test]
fn stt_qr_001_the_pr129_hc1_string_renders_as_the_version_16_q_symbol_the_page_states() {
    let r = ok(&format!(r#"{{"op":"qrSvg","text":"{}"}}"#, pr129_hc1("hepb1")));
    assert_eq!(r.get("version").and_then(Json::as_f64), Some(16.0));
    assert_eq!(r.get("modules").and_then(Json::as_f64), Some(81.0));
    assert!(st(&r, "svg").starts_with("<?xml") || st(&r, "svg").starts_with("<svg"));
}
