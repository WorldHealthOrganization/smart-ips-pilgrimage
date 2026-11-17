//! Skill `vhl-share`: issue a Verifiable Health Link (journey J4.0). The
//! same cases as the Kotlin VhlShareTest.

mod common;
use common::*;
use hcert::cbor::{self, Item};
use hcert::payload::Payload;
use hcert::types::*;
use hcert::{codec, cose, verifier, vhl};

fn key5(cose_bytes: &[u8]) -> Item {
    let s = cose::parse_sign1(cose_bytes, &DEFAULT_LIMITS).unwrap();
    let claims = cbor::decode(&s.payload, &DEFAULT_LIMITS).unwrap();
    claims.get_int(-260).unwrap().get_int(5).unwrap().clone()
}

fn payload() -> vhl::VhlPayload {
    vhl::VhlPayload { exp: Some(TESTKIT_NOW + 86_400), ..ihe_vhl() }
}

#[test]
fn stt_vhl_001_the_ihe_iti_yy3_example_payload_is_valid_and_each_rule_is_enforced() {
    assert!(vhl::validate(&ihe_vhl(), None).is_empty());
    let codes = |p: vhl::VhlPayload| vhl::validate(&p, None).into_iter().map(|i| i.code).collect::<Vec<_>>();
    // the ITI-YY4 example key: 44 characters, 33 bytes (OI-22)
    assert_eq!(codes(vhl::VhlPayload { key: "dGhpcyBpcyBhIHNlY3JldCBrZXkgdXNlZCBmb3IgZW5j".into(), ..ihe_vhl() }), vec!["bad-key"]);
    assert_eq!(codes(vhl::VhlPayload { flag: Some("PL".into()), ..ihe_vhl() }), vec!["bad-flag"]);
    assert_eq!(codes(vhl::VhlPayload { flag: Some("LU".into()), ..ihe_vhl() }), vec!["unsupported-flag-U"]);
    assert_eq!(codes(vhl::VhlPayload { label: Some("x".repeat(81)), ..ihe_vhl() }), vec!["label-too-long"]);
    assert_eq!(codes(vhl::VhlPayload { url: "http://vhl-sharer.example.org/List?_id=1".into(), ..ihe_vhl() }), vec!["not-https"]);
}

#[test]
fn stt_vhl_002_the_payload_is_a_cbor_map_at_hcert_key_5_and_verifies() {
    let issued = issue_payload(Payload::Vhl(payload()));
    assert!(matches!(key5(&issued.cose), Item::Map(_)));
    let v = verifier::verify(&issued.hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap();
    assert_eq!(only(&v).subclaim, 5);
    assert_eq!(only(&v).payload, Payload::Vhl(payload()));
}

#[test]
fn stt_vhl_002_stt_vhl_003_a_vhlink_string_at_key_5_still_verifies_and_the_map_is_smaller() {
    let text = cbor::encode(&Item::Text(vhl::to_vhlink(&payload()))).unwrap();
    let issued = issue_payload(Payload::Raw { subclaim: 5, cbor: text });
    assert!(matches!(key5(&issued.cose), Item::Text(_)));
    let v = verifier::verify(&issued.hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap();
    assert_eq!(only(&v).payload, Payload::Vhl(payload()));
    let as_map = issue_payload(Payload::Vhl(payload())).hc1.len();
    let as_text = codec::to_hc1(&issued.cose).len();
    // The claim is about the encoding: the map is under 80% of the string's
    // bytes. After DEFLATE the ratio depends on the implementation (the
    // Kotlin suite's JDK zlib gives under 0.8, miniz_oxide 0.81), so the HC1
    // string is only required to be shorter.
    let map_cose = issue_payload(Payload::Vhl(payload())).cose.len();
    assert!((map_cose as f64) < issued.cose.len() as f64 * 0.8, "COSE map {map_cose} vs text {} bytes", issued.cose.len());
    assert!(as_map < as_text, "map {as_map} vs text {as_text} characters");
}

#[test]
fn stt_vhl_003_vhlink_round_trips_and_reads_the_ihe_example_link() {
    let link = vhl::to_vhlink(&ihe_vhl());
    assert!(link.starts_with("vhlink:/eyJ1cmwiOi"));
    assert_eq!(vhl::from_vhlink(&link).unwrap(), ihe_vhl());
    let upstream = "vhlink:/eyJ1cmwiOiJodHRwczovL3ZobC1zaGFyZXIuZXhhbXBsZS5vcmcvTGlzdC9fc2VhcmNoP19pZD1hYmMxMjNkZWY0NTYmY29kZT1mb2xkZXImc3RhdHVzPWN1cnJlbnQmcGF0aWVudC5pZGVudGlmaWVyPXVybjpvaWQ6Mi4xNi44NDAuMS4xMTM4ODMuMi40LjYuM3xQQVNTUE9SVDEyMyZfaW5jbHVkZT1MaXN0Oml0ZW0iLCJrZXkiOiI4NkY4TFk1TGxXQWExLU9TX0ZnclRuWU5xRkhKUDJleTVSU0tMSkJOOWprIiwiZXhwIjoxNzM1Njg5NjAwLCJmbGFnIjoiTFAiLCJsYWJlbCI6IlBhdGllbnQgSGVhbHRoIFN1bW1hcnkiLCJ2IjoxLCJleHRlbnNpb25zIjp7ImZoaXJCYXNlVXJsIjoiaHR0cHM6Ly92aGwtc2hhcmVyLmV4YW1wbGUub3JnIn19";
    // its "extensions" is not the payload's "extension"
    assert_eq!(vhl::from_vhlink(upstream).unwrap(), vhl::VhlPayload { fhir_base_url: None, ..ihe_vhl() });
    assert!(matches!(vhl::from_vhlink("shlink:/abc"), Err(vhl::VhlError::NotAVhlink(_))));
}

#[test]
fn stt_vhl_004_a_new_key_is_32_random_bytes_base64url_without_padding() {
    let a = vhl::new_key().unwrap();
    assert_eq!(a.len(), 43);
    assert_eq!(cose::base64_decode(&a).unwrap().len(), 32);
    assert_ne!(a, vhl::new_key().unwrap());
}

#[test]
fn stt_vhl_007_a_document_is_encrypted_as_compact_jwe_dir_a256gcm() {
    let key = vhl::new_key().unwrap();
    let jwe = vhl::encrypt(b"hello", "text/plain", &key).unwrap();
    let parts: Vec<&str> = jwe.split('.').collect();
    assert_eq!(parts.len(), 5);
    assert_eq!(parts[1], "", "dir: no encrypted key");
    assert_eq!(String::from_utf8(cose::base64_decode(parts[0]).unwrap()).unwrap(), r#"{"alg":"dir","enc":"A256GCM","cty":"text/plain"}"#);
    assert_eq!(vhl::decrypt(&jwe, &key).unwrap().content, b"hello");
}
