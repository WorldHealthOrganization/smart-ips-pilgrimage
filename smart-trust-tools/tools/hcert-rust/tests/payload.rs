//! Skills `hcert-assemble-payload`, `hcert-select-payload`: each test named after the requirements it verifies.

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
fn stt_sel_004_stt_iss_004_a_certificate_with_a_dvc_and_a_vhl_verifies_with_both_entries() {
    let issued = issue_payloads(vec![Payload::DvcMin(newborn()), Payload::Vhl(live_vhl())]);
    let v = verifier::verify(&issued.hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap();
    // Wire order: the deterministic encoder sorts 5 (0x05) before -6 (0x25).
    assert_eq!(v.entries.iter().map(|e| (e.subclaim, e.key_usage_authorised)).collect::<Vec<_>>(), [(5, true), (-6, true)]);
    assert_eq!(v.entries[0].payload, Payload::Vhl(live_vhl()));
    assert_eq!(v.entries[1].payload, Payload::DvcMin(newborn()));
    let u = verifier::read_unverified(&issued.hc1, &reg(), &DEFAULT_LIMITS).unwrap();
    assert_eq!(u.entries.iter().map(|e| (e.subclaim, e.payload.is_some())).collect::<Vec<_>>(), [(5, true), (-6, true)]);
}

#[test]
fn stt_sel_004_max_payloads_refuses_more_entries_than_the_profile_allows() {
    let issued = issue_payloads(vec![Payload::DvcMin(newborn()), Payload::Vhl(live_vhl())]);
    let opts = |m| verifier::VerifierOptions { max_payloads: Some(m), ..options() };
    let f = verifier::verify(&issued.hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW, &opts(1)).unwrap_err();
    assert_eq!((f.step, f.reason), (Step::Hcert, FailureReason::MultipleSubclaims));
    assert_eq!(verifier::verify(&issued.hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW, &opts(2)).unwrap().entries.len(), 2);
}

#[test]
fn stt_sel_004_an_invalid_entry_is_left_out_and_reported() {
    let mut bad = newborn();
    bad.nt = "LA".into();
    let claims = Item::Map(vec![
        (Item::Int(4), Item::Int(TESTKIT_NOW + 1000)),
        (Item::Int(6), Item::Int(TESTKIT_NOW)),
        (Item::Int(-260), Item::Map(vec![(Item::Int(5), hcert::vhl::to_item(&live_vhl())), (Item::Int(-6), payload::to_item(&bad).unwrap())])),
    ]);
    let cose_bytes = signed_claims(&claims);
    let v = verifier::verify_cose(&cose_bytes, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap();
    assert_eq!(only(&v).subclaim, 5);
    assert!(v.diagnostics.iter().any(|d| d.step == Step::Payload && d.message.starts_with("subclaim -6:")), "{:?}", v.diagnostics);
    // With no valid entry left, the entry's own failure stands, as for one payload.
    let alone = Item::Map(vec![
        (Item::Int(4), Item::Int(TESTKIT_NOW + 1000)),
        (Item::Int(6), Item::Int(TESTKIT_NOW)),
        (Item::Int(-260), Item::Map(vec![(Item::Int(-6), payload::to_item(&bad).unwrap())])),
    ]);
    let f = verifier::verify_cose(&signed_claims(&alone), &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap_err();
    assert_eq!((f.step, f.reason), (Step::Payload, FailureReason::PayloadInvalid));
}

#[test]
fn stt_sel_004_issuance_refuses_no_payload_and_a_duplicate_subclaim() {
    let mut r = request(CoseAlgorithm::Es256);
    r.payloads = vec![];
    assert_eq!(issuer::prepare(&r, &reg()), Err(IssueError::NoPayload));
    r.payloads = vec![Payload::DvcMin(newborn()), Payload::DvcMin(newborn())];
    assert_eq!(issuer::prepare(&r, &reg()), Err(IssueError::DuplicateSubclaim(-6)));
}

#[test]
fn stt_pay_001_stt_pay_008_a_dvcmin_round_trips_and_keeps_unknown_elements() {
    let p = newborn();
    let bytes = payload::to_cbor(&p).unwrap();
    assert_eq!(payload::from_cbor(&bytes, &DEFAULT_LIMITS).unwrap(), p);
}

#[test]
fn stt_pay_002_stt_pay_003_the_logical_model_rules_are_checked() {
    let mut p = newborn();
    p.nt = "LA".into();
    p.dob = "2026-13-01".into();
    p.vx.is = None;
    let codes: Vec<_> = payload::validate(&p).into_iter().map(|i| i.code).collect();
    assert!(codes.contains(&"not-alpha3".to_string()));
    assert!(codes.contains(&"invalid-date".to_string()));
    assert!(codes.contains(&"must-have-issuer-or-clinician-name".to_string()));
    assert!(payload::validate(&newborn()).is_empty());
}

#[test]
fn stt_sel_001_stt_sel_003_the_subclaims_are_the_guides_and_development_ones_need_opting_in() {
    let keys: Vec<i64> = reg().all().iter().map(|s| s.key).collect();
    assert_eq!(keys, vec![1, 3, 4, 5, -6, -7]);
    let mut r = request(CoseAlgorithm::Es256);
    r.allow_development_subclaims = false;
    assert_eq!(issuer::prepare(&r, &reg()), Err(IssueError::DevelopmentSubclaimNotAllowed(-6)));
}

#[test]
fn stt_pay_004_stt_pay_007_an_invalid_payload_is_refused_naming_each_rule() {
    let mut bad = newborn();
    bad.nt = "LA".into();
    bad.vx.is = None;
    bad.vx.cn = None;
    let mut r = request(CoseAlgorithm::Es256);
    r.payloads = vec![Payload::DvcMin(bad)];
    let Err(IssueError::PayloadInvalid(issues)) = issuer::prepare(&r, &reg()) else { panic!("not refused") };
    let mut codes: Vec<_> = issues.iter().map(|i| i.code.as_str()).collect();
    codes.sort();
    codes.dedup();
    assert_eq!(codes, ["must-have-issuer-or-clinician-name", "not-alpha3"]);
    // User-assigned alpha-3 codes, such as XXA for testing, are accepted.
    let mut xxa = newborn();
    xxa.nt = "XXA".into();
    assert!(payload::validate(&xxa).is_empty());
}

#[test]
fn stt_sel_002_a_host_registers_its_own_subclaim_and_issues_under_it() {
    let mut r = reg();
    assert!(r.lookup(42).is_none());
    let body = cbor::encode(&Item::Map(vec![(Item::Text("k".into()), Item::Text("v".into()))])).unwrap();
    let mut req = request(CoseAlgorithm::Es256);
    req.payloads = vec![Payload::Raw { subclaim: 42, cbor: body.clone() }];
    assert_eq!(issuer::prepare(&req, &r).err(), Some(IssueError::UnknownSubclaim(42)));
    r.register(payload::Subclaim { key: 42, name: "Local payload".into(), profile: None });
    let p = issuer::prepare(&req, &r).unwrap();
    let issued = issuer::finish(&p, &sign(CoseAlgorithm::Es256, &p.to_be_signed)).unwrap();
    let v = verifier::verify(&issued.hc1, &store_with(&es_der()), &r, TESTKIT_NOW, &options()).unwrap();
    assert_eq!(only(&v).payload, Payload::Raw { subclaim: 42, cbor: body });
    // A default can be overridden too: the same key, a new name.
    r.register(payload::Subclaim { key: -7, name: "Local medication list".into(), profile: None });
    assert_eq!(r.lookup(-7).unwrap().name, "Local medication list");
    assert_eq!(r.all().iter().filter(|s| s.key == -7).count(), 1);
}

#[test]
fn stt_sel_003_dvc_moves_to_an_assigned_subclaim_without_an_api_change() {
    // WHO assigns DVC a production number (6 here): registry configuration only.
    let mut assigned = reg();
    assigned.register(payload::Subclaim { key: 6, name: "DVCMin".into(), profile: Some("http://smart.who.int/trust-phw/StructureDefinition/DVCMin".into()) });
    assigned.set_subclaim_for(payload::PayloadKind::DvcMin, 6);
    for alg in [CoseAlgorithm::Es256, CoseAlgorithm::Ps256] {
        let mut r = request(alg);
        // A production number needs no development opt-in.
        r.allow_development_subclaims = false;
        let p = issuer::prepare(&r, &assigned).unwrap();
        let issued = issuer::finish(&p, &sign(alg, &p.to_be_signed)).unwrap();
        let der = if alg == CoseAlgorithm::Es256 { es_der() } else { ps_der() };
        match (alg, verifier::verify(&issued.hc1, &store_with(&der), &assigned, TESTKIT_NOW, &options())) {
            (CoseAlgorithm::Es256, Ok(v)) => assert_eq!((only(&v).subclaim, &only(&v).payload), (6, &Payload::DvcMin(newborn()))),
            // The key-usage check follows the number too: the PS256 DSC's EKU is
            // test certificates only, so a DVC under 6 is refused, as under -6.
            (CoseAlgorithm::Ps256, Err(f)) => assert_eq!((f.step, f.reason), (Step::KeyUsage, FailureReason::KeyUsageMismatch)),
            (a, r) => panic!("{a:?}: {r:?}"),
        }
    }
}

#[test]
fn stt_pay_005_a_newborns_dvcmin_has_no_identity_document_and_names_a_guardian() {
    let p = newborn();
    assert_eq!((p.id.as_deref(), p.dt.as_deref(), p.gn.as_deref()), (None, None, Some("Test MOTHER")));
    assert!(payload::validate(&p).iter().all(|i| i.severity != Severity::Blocking));
    let v = verifier::verify(&issue(CoseAlgorithm::Es256).hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap();
    let Payload::DvcMin(got) = &only(&v).payload else { panic!("not a DVC") };
    assert_eq!((got.id.as_deref(), got.dt.as_deref(), got.gn.as_deref()), (None, None, Some("Test MOTHER")));
}

#[test]
fn stt_pay_009_stt_gen_003_another_payload_passes_through_the_core_untouched() {
    // Each under a DSC whose key usage allows its certificate type: the PS256
    // testkit DSC signs test certificates only, the ES256 one vaccinations.
    let entry = |k: &str| cbor::encode(&Item::Map(vec![(Item::Text(k.into()), Item::Text("x".into()))])).unwrap();
    for (subclaim, k, alg, der) in [(4, "t", CoseAlgorithm::Ps256, ps_der()), (1, "v", CoseAlgorithm::Es256, es_der()), (3, "v", CoseAlgorithm::Es256, es_der()), (-7, "m", CoseAlgorithm::Es256, es_der())] {
        let body = entry(k);
        let mut r = request(alg);
        r.payloads = vec![Payload::Raw { subclaim, cbor: body.clone() }];
        let p = issuer::prepare(&r, &reg()).unwrap();
        let issued = issuer::finish(&p, &sign(alg, &p.to_be_signed)).unwrap();
        let v = verifier::verify(&issued.hc1, &store_with(&der), &reg(), TESTKIT_NOW, &options()).unwrap_or_else(|f| panic!("{subclaim}: {f:?}"));
        assert_eq!(only(&v).payload, Payload::Raw { subclaim, cbor: body }, "{subclaim}");
    }
}
