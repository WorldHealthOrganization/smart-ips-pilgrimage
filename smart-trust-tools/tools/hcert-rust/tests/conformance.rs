//! Skill `hcert-conformance-testing`: the shared vectors, the same files the
//! Kotlin suite and the Node smoke test load (STT-TST-001, 002, 004, 005).

mod common;
use common::*;
use hcert::codec;
use hcert::cose;
use hcert::payload::Payload;
use hcert::trust::TrustStore;
use hcert::types::*;
use hcert::verifier::{self, VerifierOptions};

#[test]
fn stt_tst_001_stt_kid_001_the_vectors_kid_is_the_dscs() {
    let kid = cose::base64_decode("WHM+BYqqZiE=").unwrap();
    let store = pr129_store();
    let c = store.candidates(&kid.clone().try_into().unwrap());
    assert_eq!(c.len(), 1);
    assert_eq!(to_hex(&c[0].kid), "58733e058aaa6621");
}

#[test]
fn stt_tst_001_stt_pay_001_both_pr129_certificates_verify_and_decode_as_published() {
    let store = pr129_store();
    let vector = json(PR129);
    for name in ["hepb1", "bcg"] {
        let v = verifier::verify(&pr129_hc1(name), &store, &reg(), NOW, &options()).unwrap_or_else(|f| panic!("{name}: {f:?}"));
        assert_eq!(v.iss.as_deref(), Some("XX"));
        assert_eq!(only(&v).subclaim, -6);
        let Payload::DvcMin(p) = &only(&v).payload else { panic!("{name}: not a DVCMin") };
        let expected = vector.get("certificates").unwrap().get(name).unwrap().get("payload").unwrap();
        assert_eq!(Some(p.n.as_str()), expected.get("n").and_then(|j| j.as_str()));
        assert_eq!(Some(p.nt.as_str()), expected.get("nt").and_then(|j| j.as_str()));
        assert_eq!(Some(p.vx.vp.as_str()), expected.get("vx").unwrap().get("vp").and_then(|j| j.as_str()));
        assert_eq!(Some(p.vx.bo.as_str()), expected.get("vx").unwrap().get("bo").and_then(|j| j.as_str()));
        assert!(v.diagnostics.is_empty(), "{:?}", v.diagnostics);
    }
}

#[test]
fn stt_tst_002_stt_cbr_001_deterministic_re_encoding_reproduces_the_issued_cwt_byte_for_byte() {
    let cose_bytes = codec::from_hc1(&pr129_hc1("hepb1"), &DEFAULT_LIMITS).unwrap();
    let s = cose::parse_sign1(&cose_bytes, &DEFAULT_LIMITS).unwrap();
    assert_eq!(codec::cbor_deterministic(&s.payload, &DEFAULT_LIMITS).unwrap(), s.payload);
    assert_eq!(s.payload.len(), 210);
    assert_eq!(cose_bytes.len(), 295);
    // and the HC1 string round-trips through the QR layers
    assert_eq!(codec::from_hc1(&codec::to_hc1(&cose_bytes), &DEFAULT_LIMITS).unwrap(), cose_bytes);
}

#[test]
fn stt_tst_011_stt_tst_002_the_merged_guides_xxr_certificates_decode_as_published() {
    let vector = json(XXR);
    let num = |c: &hcert::json::Json, k: &str| c.get(k).unwrap().as_f64().unwrap() as usize;
    for name in ["hepb1", "bcg"] {
        let c = vector.get("certificates").unwrap().get(name).unwrap();
        let hc1 = c.get("hc1").unwrap().as_str().unwrap();
        let u = verifier::read_unverified(hc1, &reg(), &DEFAULT_LIMITS).unwrap_or_else(|f| panic!("{name}: {f:?}"));
        assert_eq!(to_hex(u.kid.as_ref().unwrap()), "916ffa567c0f44a2");
        assert_eq!(u.iss.as_deref(), Some("XR"));
        assert_eq!((u.iat, u.exp), (Some(1_792_657_800), Some(1_824_193_800)));
        assert_eq!(u.entries.len(), 1);
        assert_eq!(u.entries[0].subclaim, -6);
        let Some(Payload::DvcMin(p)) = &u.entries[0].payload else { panic!("{name}: not a DVCMin") };
        let expected = c.get("payload").unwrap();
        let vx = expected.get("vx").unwrap();
        assert_eq!(Some(p.n.as_str()), expected.get("n").and_then(|j| j.as_str()));
        assert_eq!(Some(p.dob.as_str()), expected.get("dob").and_then(|j| j.as_str()));
        assert_eq!(Some(p.vx.vp.as_str()), vx.get("vp").and_then(|j| j.as_str()));
        assert_eq!(p.vx.is.as_deref(), vx.get("is").and_then(|j| j.as_str()));
        assert_eq!(Some(p.vx.bo.as_str()), vx.get("bo").and_then(|j| j.as_str()));
        // 12.5 Size at each stage, exactly: these are the published strings.
        let cose_bytes = codec::from_hc1(hc1, &DEFAULT_LIMITS).unwrap();
        let s = cose::parse_sign1(&cose_bytes, &DEFAULT_LIMITS).unwrap();
        assert_eq!(codec::cbor_deterministic(&s.payload, &DEFAULT_LIMITS).unwrap(), s.payload);
        assert_eq!(s.payload.len(), num(c, "cwt_cbor_bytes"));
        assert_eq!(cose_bytes.len(), num(c, "cose_sign1_bytes"));
        assert_eq!(codec::base45_decode(&hc1[4..]).unwrap().len(), num(c, "deflated_bytes"));
        assert_eq!(hc1.len(), num(c, "hc1_chars"));
        // Without the DEV trust list's DSC, verification stops at the trust lookup.
        let f = verifier::verify(hc1, &pr129_store(), &reg(), NOW, &options()).unwrap_err();
        assert_eq!((f.step, f.reason), (Step::TrustLookup, FailureReason::KidNotFound), "{name}");
    }
    // The hepatitis B figures 12.5 prints.
    let h = vector.get("certificates").unwrap().get("hepb1").unwrap();
    assert_eq!([num(h, "cwt_cbor_bytes"), num(h, "cose_sign1_bytes"), num(h, "deflated_bytes"), num(h, "hc1_chars")], [222, 307, 293, 444]);
}

#[test]
fn stt_tst_011_the_merged_guides_xxr_certificates_verify_against_the_dev_trust_lists_dsc() {
    let mut store = TrustStore::new();
    assert_eq!(store.add_did_document(&read(XXR_DSC_DID)).unwrap(), 1);
    let vector = json(XXR);
    for name in ["hepb1", "bcg"] {
        let c = vector.get("certificates").unwrap().get(name).unwrap();
        let iat = c.get("iat").unwrap().as_f64().unwrap() as i64;
        let v = verifier::verify(c.get("hc1").unwrap().as_str().unwrap(), &store, &reg(), iat + 3600, &options()).unwrap_or_else(|f| panic!("{name}: {f:?}"));
        assert_eq!(v.iss.as_deref(), Some("XR"));
        assert_eq!(v.dsc.country.as_deref(), Some("XR"));
        assert_eq!(to_hex(&v.dsc.kid), "916ffa567c0f44a2");
        let e = only(&v);
        assert!(e.key_usage_authorised);
        let Payload::DvcMin(p) = &e.payload else { panic!("{name}: not a DVCMin") };
        assert_eq!(Some(p.vx.vp.as_str()), c.get("payload").unwrap().get("vx").unwrap().get("vp").and_then(|j| j.as_str()));
        assert!(v.diagnostics.is_empty(), "{name}: {:?}", v.diagnostics);
    }
}

#[test]
fn stt_tst_004_stt_tst_005_the_shared_negative_vectors_fail_at_the_named_step_with_the_named_reason() {
    let doc = json("vectors/negative/negative-vectors.json");
    let defaults = doc.get("defaults").unwrap();
    let cases = doc.get("cases").unwrap().as_arr().unwrap();
    assert!(cases.len() >= 15);
    let skew = defaults.get("clockSkewSeconds").unwrap().as_f64().unwrap() as i64;
    let options = VerifierOptions { clock_skew_seconds: skew, ..VerifierOptions::default() };
    for c in cases {
        let id = c.get("id").unwrap().as_str().unwrap();
        let mut store = TrustStore::new();
        for p in c.get("trust").or(defaults.get("trust")).unwrap().as_arr().unwrap() {
            store.add_pem(&read(p.as_str().unwrap())).unwrap();
        }
        let now = c.get("now").or(defaults.get("now")).unwrap().as_f64().unwrap() as i64;
        let r = match c.get("coseHex").and_then(|j| j.as_str()) {
            Some(hex) => verifier::verify_cose(&from_hex(hex).unwrap(), &store, &reg(), now, &options),
            None => verifier::verify(c.get("hc1").unwrap().as_str().unwrap(), &store, &reg(), now, &options),
        };
        let f = r.err().unwrap_or_else(|| panic!("{id}: verified"));
        let expect = c.get("expect").unwrap();
        assert_eq!(
            (f.step.wire_name(), f.reason.wire_name()),
            (expect.get("step").unwrap().as_str().unwrap(), expect.get("reason").unwrap().as_str().unwrap()),
            "{id}: {}",
            f.detail
        );
    }
}
