//! Skills `hcert-build-cwt`, `hcert-sign-cose`: each test named after the requirements it verifies.

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
fn stt_cwt_001_stt_cos_002_stt_cos_003_prepare_builds_the_claims_and_a_protected_alg_and_kid() {
    let p = issuer::prepare(&request(CoseAlgorithm::Es256), &reg()).unwrap();
    let ph = cbor::decode(&p.protected, &DEFAULT_LIMITS).unwrap();
    assert_eq!(ph.get_int(1), Some(&Item::Int(-7)));
    assert_eq!(ph.get_int(4), Some(&Item::Bytes(kid_of(&es_der()).to_vec())));
    let claims = cbor::decode(&p.payload, &DEFAULT_LIMITS).unwrap();
    assert_eq!(claims.get_int(1), Some(&Item::Text("XX".into())));
    assert_eq!(claims.get_int(6), Some(&Item::Int(TESTKIT_NOW)));
    assert!(claims.get_int(-260).unwrap().get_int(-6).is_some());
    assert_eq!(p.to_be_signed, cose::sig_structure(&p.protected, &p.payload));
}

#[test]
fn stt_cwt_004_validity_outside_the_dsc_is_refused() {
    let mut r = request(CoseAlgorithm::Es256);
    r.exp = r.iat + 86_400 * 365 * 20;
    assert_eq!(issuer::prepare(&r, &reg()), Err(IssueError::ValidityOutsideDsc));
}

#[test]
fn stt_iss_004_stt_cos_005_two_phase_issuance_with_es256_and_ps256_verifies() {
    for (alg, der) in [(CoseAlgorithm::Es256, es_der()), (CoseAlgorithm::Ps256, ps_der())] {
        // The PS256 testkit DSC's EKU is test certificates only (STT-VER-004),
        // so under PS256 the payload is a test certificate (subclaim 4).
        let payload = match alg {
            CoseAlgorithm::Es256 => Payload::DvcMin(newborn()),
            CoseAlgorithm::Ps256 => Payload::Raw { subclaim: 4, cbor: cbor::encode(&Item::Map(vec![(Item::Text("t".into()), Item::Text("x".into()))])).unwrap() },
        };
        let mut r = request(alg);
        r.payloads = vec![payload.clone()];
        let p = issuer::prepare(&r, &reg()).unwrap();
        let issued = issuer::finish(&p, &sign(alg, &p.to_be_signed)).unwrap();
        assert!(issued.hc1.starts_with("HC1:"));
        let v = verifier::verify(&issued.hc1, &store_with(&der), &reg(), TESTKIT_NOW, &options()).unwrap_or_else(|f| panic!("{alg:?}: {f:?}"));
        assert_eq!(only(&v).payload, payload, "{alg:?}");
    }
    // A DVC under the PS256 DSC is refused, by key usage.
    let f = verifier::verify(&issue(CoseAlgorithm::Ps256).hc1, &store_with(&ps_der()), &reg(), TESTKIT_NOW, &options()).unwrap_err();
    assert_eq!((f.step, f.reason), (Step::KeyUsage, FailureReason::KeyUsageMismatch));
}

#[test]
fn stt_cos_006_finish_refuses_a_signature_from_another_key() {
    use p256::ecdsa::signature::Signer;
    let p = issuer::prepare(&request(CoseAlgorithm::Es256), &reg()).unwrap();
    // A well-formed signature over the right bytes, by a key that is not the DSC's.
    let other = p256::ecdsa::SigningKey::from_slice(&[7u8; 32]).unwrap();
    let other_sig: p256::ecdsa::Signature = other.sign(&p.to_be_signed);
    assert!(matches!(issuer::finish(&p, &other_sig.to_bytes()), Err(IssueError::BadSignatureFormat(_))));
    // and the DSC key's signature with one bit flipped
    let mut sig = sign(CoseAlgorithm::Es256, &p.to_be_signed);
    sig[10] ^= 1;
    assert!(matches!(issuer::finish(&p, &sig), Err(IssueError::BadSignatureFormat(_))));
    // DER, as JCA gives it, is accepted
    let der = testdsc::ecdsa_raw_to_der(&sign(CoseAlgorithm::Es256, &p.to_be_signed));
    assert!(issuer::finish(&p, &der).is_ok());
}

#[test]
fn stt_iss_003_a_test_dsc_around_a_host_key_issues_and_verifies() {
    use p256::pkcs8::EncodePublicKey;
    use p256::ecdsa::signature::Signer;
    let key = p256::ecdsa::SigningKey::from_slice(&[7u8; 32]).unwrap();
    let spki = p256::PublicKey::from(key.verifying_key()).to_public_key_der().unwrap().as_bytes().to_vec();
    let tbs = testdsc::tbs_certificate(&TestDscRequest {
        spki_der: spki,
        alg: CoseAlgorithm::Es256,
        country: "XX".into(),
        common_name: "TEST ONLY demo DSC".into(),
        not_before: NOW - 60,
        not_after: NOW + 86_400 * 365,
        serial: 42,
        extended_key_usages: vec!["vaccinations".into()],
    })
    .unwrap();
    let tbs_sig: p256::ecdsa::Signature = key.sign(&tbs);
    let der = testdsc::certificate(&tbs, CoseAlgorithm::Es256, &tbs_sig.to_bytes()).unwrap();
    let mut req = request(CoseAlgorithm::Es256);
    req.dsc_der = der.clone();
    req.iat = NOW;
    req.exp = NOW + 86_400;
    let p = issuer::prepare(&req, &reg()).unwrap();
    let sig: p256::ecdsa::Signature = key.sign(&p.to_be_signed);
    let issued = issuer::finish(&p, &sig.to_bytes()).unwrap();
    let v = verifier::verify(&issued.hc1, &store_with(&der), &reg(), NOW, &options()).unwrap();
    assert_eq!(v.dsc.country.as_deref(), Some("XX"));
    assert_eq!(v.dsc.extended_key_usages, vec!["1.3.6.1.4.1.1847.2021.1.2".to_string()]);
}

/// A claim set as the issuer builds it, with `extra` claims added and exp
/// left out when `exp` is None: for claim sets the issuer would refuse.
fn claims_with(exp: Option<i64>, extra: Vec<(Item, Item)>) -> Item {
    let mut c = vec![(Item::Int(1), Item::Text("XX".into()))];
    if let Some(exp) = exp {
        c.push((Item::Int(4), Item::Int(exp)));
    }
    c.push((Item::Int(6), Item::Int(TESTKIT_NOW)));
    c.push((Item::Int(-260), Item::Map(vec![(Item::Int(-6), payload::to_item(&newborn()).unwrap())])));
    c.extend(extra);
    Item::Map(c)
}

#[test]
fn stt_cos_001_the_issued_cose_sign1_is_tagged_18_and_an_untagged_one_also_verifies() {
    let issued = issue(CoseAlgorithm::Es256);
    let Item::Tag(18, inner) = cbor::decode(&issued.cose, &DEFAULT_LIMITS).unwrap() else { panic!("not tagged 18") };
    let Item::Array(items) = *inner else { panic!("not an array") };
    assert_eq!(items.len(), 4);
    assert!(matches!((&items[0], &items[1], &items[2], &items[3]), (Item::Bytes(_), Item::Map(_), Item::Bytes(_), Item::Bytes(_))));
    let s = cose::parse_sign1(&issued.cose, &DEFAULT_LIMITS).unwrap();
    assert!(s.tagged && s.kid_in_protected);
    // The same four items, untagged: accepted, with a diagnostic.
    let untagged = cbor::encode(&Item::Array(items)).unwrap();
    let v = verifier::verify_cose(&untagged, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap();
    assert_eq!(only(&v).payload, Payload::DvcMin(newborn()));
    assert!(v.diagnostics.iter().any(|d| d.step == Step::Cose && d.message.contains("not tagged 18")), "{:?}", v.diagnostics);
}

#[test]
fn stt_cos_004_the_signature1_structure_uses_the_protected_bytes_as_received() {
    let p = issuer::prepare(&request(CoseAlgorithm::Es256), &reg()).unwrap();
    let expected = cbor::encode(&Item::Array(vec![Item::Text("Signature1".into()), Item::Bytes(p.protected.clone()), Item::Bytes(vec![]), Item::Bytes(p.payload.clone())])).unwrap();
    assert_eq!(p.to_be_signed, expected);
    assert_eq!(cose::sig_structure(&p.protected, &p.payload), expected);
    // A protected header that is not in deterministic order ({4: kid, 1: alg},
    // hand-encoded) verifies when signed as sent; re-encoding it would break it.
    let kid = kid_of(&es_der());
    let mut ph = vec![0xa2, 0x04, 0x48];
    ph.extend_from_slice(&kid);
    ph.extend_from_slice(&[0x01, 0x26]);
    assert_ne!(ph, issuer::protected_header(CoseAlgorithm::Es256, &kid));
    let sig = sign(CoseAlgorithm::Es256, &cose::sig_structure(&ph, &p.payload));
    let bytes = cose::assemble_sign1(&ph, &p.payload, &sig);
    assert_eq!(only(&verifier::verify_cose(&bytes, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap()).payload, Payload::DvcMin(newborn()));
}

#[test]
fn stt_cwt_002_iat_and_exp_are_integer_numeric_dates() {
    let p = issuer::prepare(&request(CoseAlgorithm::Es256), &reg()).unwrap();
    let claims = cbor::decode(&p.payload, &DEFAULT_LIMITS).unwrap();
    let keys: Vec<i64> = claims.entries().unwrap().iter().map(|(k, _)| k.as_int().unwrap()).collect();
    assert_eq!(keys, [1, 4, 6, -260]);
    assert_eq!(claims.get_int(4), Some(&Item::Int(TESTKIT_NOW + 86_400 * 365)));
    assert_eq!(claims.get_int(6), Some(&Item::Int(TESTKIT_NOW)));
}

#[test]
fn stt_cwt_003_an_hcert_without_exp_is_refused_on_issue_and_on_verify() {
    let mut r = request(CoseAlgorithm::Es256);
    r.exp = r.iat;
    assert!(matches!(issuer::prepare(&r, &reg()), Err(IssueError::PayloadInvalid(i)) if i[0].code == "exp-not-after-iat"));
    let f = verifier::verify_cose(&signed_claims(&claims_with(None, vec![])), &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap_err();
    assert_eq!((f.step, f.reason), (Step::Cwt, FailureReason::CoseMalformed));
}

#[test]
fn stt_cwt_005_iss_is_optional_and_two_upper_case_letters_when_present() {
    let mut r = request(CoseAlgorithm::Es256);
    for bad in ["Xx", "XXX", "x"] {
        r.iss = Some(bad.into());
        assert!(matches!(issuer::prepare(&r, &reg()), Err(IssueError::PayloadInvalid(i)) if i[0].code == "not-alpha2"), "{bad}");
    }
    r.iss = None;
    let p = issuer::prepare(&r, &reg()).unwrap();
    assert_eq!(cbor::decode(&p.payload, &DEFAULT_LIMITS).unwrap().get_int(1), None);
    let issued = issuer::finish(&p, &sign(CoseAlgorithm::Es256, &p.to_be_signed)).unwrap();
    assert_eq!(verifier::verify(&issued.hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap().iss, None);
    assert_eq!(verifier::verify(&issue(CoseAlgorithm::Es256).hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap().iss.as_deref(), Some("XX"));
}

#[test]
fn stt_cwt_006_claims_this_version_does_not_know_are_kept() {
    let extra = (Item::Int(-70000), Item::Text("future".into()));
    let cose_bytes = signed_claims(&claims_with(Some(TESTKIT_NOW + 1000), vec![extra.clone()]));
    let v = verifier::verify_cose(&cose_bytes, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap();
    assert_eq!(v.other_claims.len(), 1);
    let (k, value) = &v.other_claims[0];
    assert_eq!((cbor::decode(k, &DEFAULT_LIMITS).unwrap(), cbor::decode(value, &DEFAULT_LIMITS).unwrap()), extra);
}
