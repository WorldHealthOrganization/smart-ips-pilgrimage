//! Skill `hcert-verify`: each test named after the requirements it verifies.

mod common;
#[allow(unused_imports)]
use common::*;
#[allow(unused_imports)]
use hcert::cbor::{self, Item};
#[allow(unused_imports)]
use hcert::{codec, cose, issuer, payload, testdsc, verifier};
#[allow(unused_imports)]
use hcert::payload::Payload;
#[allow(unused_imports)]
use hcert::testdsc::TestDscRequest;
#[allow(unused_imports)]
use hcert::trust::TrustStore;
#[allow(unused_imports)]
use hcert::types::*;

#[test]
fn stt_ver_003_headers_are_checked_before_any_signature() {
    let s = |ph: Item, uh: Item| cbor::encode(&Item::Array(vec![Item::Bytes(cbor::encode(&ph).unwrap()), uh, Item::Bytes(vec![0xa0]), Item::Bytes(vec![0; 64])])).unwrap();
    let alg_in_unprotected = s(Item::Map(vec![(Item::Int(1), Item::Int(-7))]), Item::Map(vec![(Item::Int(1), Item::Int(-7))]));
    let no_kid = s(Item::Map(vec![(Item::Int(1), Item::Int(-7))]), Item::Map(vec![]));
    let short_kid = s(Item::Map(vec![(Item::Int(1), Item::Int(-7)), (Item::Int(4), Item::Bytes(vec![1, 2]))]), Item::Map(vec![]));
    for bytes in [alg_in_unprotected, no_kid, short_kid] {
        let f = verifier::verify_cose(&bytes, &TrustStore::new(), &reg(), NOW, &options()).unwrap_err();
        assert_eq!((f.step, f.reason), (Step::Header, FailureReason::HeaderInvalid), "{}", f.detail);
    }
}

#[test]
fn stt_ver_007_stt_sel_004_an_unknown_second_entry_is_kept_raw_unless_the_profile_allows_one() {
    let claims = Item::Map(vec![
        (Item::Int(4), Item::Int(TESTKIT_NOW + 1000)),
        (Item::Int(6), Item::Int(TESTKIT_NOW)),
        (Item::Int(-260), Item::Map(vec![(Item::Int(-6), payload::to_item(&newborn()).unwrap()), (Item::Int(-7), Item::Map(vec![]))])),
    ]);
    let cose_bytes = signed_claims(&claims);
    let v = verifier::verify_cose(&cose_bytes, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap();
    assert_eq!(v.entries.iter().map(|e| e.subclaim).collect::<Vec<_>>(), [-6, -7]);
    assert_eq!(v.entries[0].payload, Payload::DvcMin(newborn()));
    assert!(matches!(&v.entries[1].payload, Payload::Raw { subclaim: -7, .. }));
    assert!(v.diagnostics.iter().any(|d| d.step == Step::KeyUsage && d.message.contains("subclaim -7")), "{:?}", v.diagnostics);
    // A deployment's strict profile still refuses it.
    let strict = verifier::VerifierOptions { max_payloads: Some(1), ..options() };
    let f = verifier::verify_cose(&cose_bytes, &store_with(&es_der()), &reg(), TESTKIT_NOW, &strict).unwrap_err();
    assert_eq!((f.step, f.reason), (Step::Hcert, FailureReason::MultipleSubclaims));
}

#[test]
fn stt_ver_004_stt_sel_004_key_usage_is_checked_per_entry() {
    // The PS256 testkit DSC's EKU is test certificates only.
    let mut r = request(CoseAlgorithm::Ps256);
    r.payloads = vec![Payload::DvcMin(newborn()), Payload::Vhl(live_vhl())];
    let p = issuer::prepare(&r, &reg()).unwrap();
    let issued = issuer::finish(&p, &sign(CoseAlgorithm::Ps256, &p.to_be_signed)).unwrap();
    let v = verifier::verify(&issued.hc1, &store_with(&ps_der()), &reg(), TESTKIT_NOW, &options()).unwrap();
    let marks: Vec<_> = v.entries.iter().map(|e| (e.subclaim, e.key_usage_authorised)).collect();
    assert_eq!(marks, [(5, true), (-6, false)]);
    assert!(v.diagnostics.iter().any(|d| d.step == Step::KeyUsage && d.message.contains("subclaim -6")), "{:?}", v.diagnostics);
    // A DVC alone still stops at key usage.
    let alone = issue(CoseAlgorithm::Ps256);
    let f = verifier::verify(&alone.hc1, &store_with(&ps_der()), &reg(), TESTKIT_NOW, &options()).unwrap_err();
    assert_eq!((f.step, f.reason), (Step::KeyUsage, FailureReason::KeyUsageMismatch));
}

#[test]
fn stt_ver_011_read_unverified_says_so() {
    let u = verifier::read_unverified(&pr129_hc1("bcg"), &reg(), &DEFAULT_LIMITS).unwrap();
    assert!(u.diagnostics[0].message.starts_with("NOT VERIFIED"));
    assert_eq!(u.entries.iter().map(|e| e.subclaim).collect::<Vec<_>>(), [-6]);
    assert_eq!(u.iss.as_deref(), Some("XX"));
}

#[test]
fn stt_ver_001_stt_ver_002_a_tampered_payload_fails_at_the_signature_before_any_payload_is_read() {
    // A payload that would also fail its model check: the signature step comes first.
    let mut bad = newborn();
    bad.nt = "LA".into();
    let claims = Item::Map(vec![
        (Item::Int(4), Item::Int(TESTKIT_NOW + 1000)),
        (Item::Int(6), Item::Int(TESTKIT_NOW)),
        (Item::Int(-260), Item::Map(vec![(Item::Int(-6), payload::to_item(&bad).unwrap())])),
    ]);
    let s = cose::parse_sign1(&signed_claims(&claims), &DEFAULT_LIMITS).unwrap();
    let mut tampered_payload = s.payload.clone();
    *tampered_payload.last_mut().unwrap() ^= 1;
    let tampered = cose::assemble_sign1(&s.protected, &tampered_payload, &s.signature);
    let f = verifier::verify_cose(&tampered, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap_err();
    assert_eq!((f.step, f.reason), (Step::Signature, FailureReason::SignatureInvalid));
    // The trust lookup comes before the signature, and time before the payload.
    let f = verifier::verify_cose(&tampered, &TrustStore::new(), &reg(), TESTKIT_NOW, &options()).unwrap_err();
    assert_eq!((f.step, f.reason), (Step::TrustLookup, FailureReason::KidNotFound));
    let f = verifier::verify_cose(&signed_claims(&claims), &store_with(&es_der()), &reg(), TESTKIT_NOW + 100_000, &options()).unwrap_err();
    assert_eq!((f.step, f.reason), (Step::Time, FailureReason::Expired));
    let f = verifier::verify_cose(&signed_claims(&claims), &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap_err();
    assert_eq!((f.step, f.reason), (Step::Payload, FailureReason::PayloadInvalid));
}

#[test]
fn stt_ver_008_every_failure_is_a_value_naming_its_step_and_reason() {
    let cases = [
        ("NCFOXN", FailureReason::BadPrefix),
        ("HC2:NCFOXN", FailureReason::UnsupportedContextVersion),
        ("HC1:abc", FailureReason::Base45Invalid),
    ];
    for (hc1, reason) in cases {
        let f = verifier::verify(hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap_err();
        assert_eq!(f.reason, reason, "{hc1}");
        assert!(!f.detail.is_empty(), "{hc1}");
    }
    let long = format!("HC1:{}", "0".repeat(9000));
    let f = verifier::verify(&long, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap_err();
    assert_eq!(f.reason, FailureReason::LimitExceeded);
}

#[test]
fn stt_gen_001_stt_gen_009_issue_and_verify_with_es256_and_ps256_and_the_cose_bytes_travel_alone() {
    // ES256 signs a DVC; the PS256 testkit DSC may sign test certificates only (subclaim 4).
    let dvc = issue(CoseAlgorithm::Es256);
    assert_eq!(only(&verifier::verify(&dvc.hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap()).payload, Payload::DvcMin(newborn()));
    let mut r = request(CoseAlgorithm::Ps256);
    r.payloads = vec![Payload::Raw { subclaim: 4, cbor: cbor::encode(&Item::Map(vec![(Item::Text("t".into()), Item::Text("x".into()))])).unwrap() }];
    let p = issuer::prepare(&r, &reg()).unwrap();
    let test = issuer::finish(&p, &sign(CoseAlgorithm::Ps256, &p.to_be_signed)).unwrap();
    assert!(verifier::verify(&test.hc1, &store_with(&ps_der()), &reg(), TESTKIT_NOW, &options()).is_ok());
    // The same certificates as COSE bytes, for NFC, Bluetooth or app-to-app.
    assert_eq!(codec::from_hc1(&dvc.hc1, &DEFAULT_LIMITS).unwrap(), dvc.cose);
    assert!(verifier::verify_cose(&dvc.cose, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).is_ok());
    assert!(verifier::verify_cose(&test.cose, &store_with(&ps_der()), &reg(), TESTKIT_NOW, &options()).is_ok());
}

#[test]
fn stt_ver_002_stt_sec_001_a_failure_carries_no_payload_and_names_none_of_it() {
    let issued = issue(CoseAlgorithm::Es256);
    let f = verifier::verify(&issued.hc1, &TrustStore::new(), &reg(), TESTKIT_NOW, &options()).unwrap_err();
    // A failure is step, reason and detail: no claims, no payload.
    let verifier::VerificationFailure { step, reason, detail } = f;
    assert_eq!((step, reason), (Step::TrustLookup, FailureReason::KidNotFound));
    for secret in ["Test CHILD", "Test MOTHER", "XM9V38", &issued.hc1[4..24]] {
        assert!(!detail.contains(secret), "{secret}: {detail}");
    }
    // Reading without verifying is its own, named call, and says so.
    let u = verifier::read_unverified(&issued.hc1, &reg(), &DEFAULT_LIMITS).unwrap();
    assert!(u.diagnostics[0].message.starts_with("NOT VERIFIED"));
}

#[test]
fn stt_ver_005_time_is_the_clock_the_caller_passes_with_the_skew_it_allows() {
    let mut r = request(CoseAlgorithm::Es256);
    r.exp = TESTKIT_NOW + 86_400;
    let p = issuer::prepare(&r, &reg()).unwrap();
    let hc1 = issuer::finish(&p, &sign(CoseAlgorithm::Es256, &p.to_be_signed)).unwrap().hc1;
    let at = |now| verifier::verify(&hc1, &store_with(&es_der()), &reg(), now, &options());
    let skew = options().clock_skew_seconds;
    assert!(at(r.exp + skew - 1).is_ok());
    assert_eq!(at(r.exp + skew + 1).unwrap_err().reason, FailureReason::Expired);
    assert!(at(TESTKIT_NOW - skew + 1).is_ok());
    assert_eq!(at(TESTKIT_NOW - skew - 1).unwrap_err().reason, FailureReason::NotYetValid);
    let strict = verifier::VerifierOptions { clock_skew_seconds: 0, ..options() };
    assert_eq!(verifier::verify(&hc1, &store_with(&es_der()), &reg(), r.exp + 1, &strict).unwrap_err().reason, FailureReason::Expired);
}

#[test]
fn stt_ver_006_stt_kid_002_trust_list_presence_is_the_validity_check() {
    let issued = issue(CoseAlgorithm::Es256);
    // A kid nobody trusts fails the trust lookup; no CRL or OCSP is asked.
    let f = verifier::verify(&issued.hc1, &TrustStore::new(), &reg(), TESTKIT_NOW, &options()).unwrap_err();
    assert_eq!((f.step, f.reason), (Step::TrustLookup, FailureReason::KidNotFound));
    // A trusted DSC outside its X.509 validity is reported, not refused.
    let late = verifier::VerifierOptions { clock_skew_seconds: 86_400 * 365 * 20, ..options() };
    let v = verifier::verify(&issued.hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW + 86_400 * 365 * 11, &late).unwrap();
    assert!(v.diagnostics.iter().any(|d| d.step == Step::TrustLookup && d.message.contains("X.509 validity")), "{:?}", v.diagnostics);
}
