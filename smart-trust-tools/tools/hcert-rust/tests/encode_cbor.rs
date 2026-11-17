//! Skill `hcert-encode-cbor`: each test named after the requirements it verifies.

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
fn stt_cbr_001_maps_are_encoded_in_deterministic_key_order() {
    let m = Item::Map(vec![(Item::Text("b".into()), Item::Int(2)), (Item::Int(-1), Item::Int(1)), (Item::Int(10), Item::Int(3))]);
    let Item::Map(rev) = &m else { unreachable!() };
    let r = Item::Map(rev.iter().rev().cloned().collect());
    assert_eq!(cbor::encode(&m).unwrap(), cbor::encode(&r).unwrap());
    assert_eq!(to_hex(&cbor::encode(&m).unwrap()), "a30a032001616202");
}

#[test]
fn stt_cbr_001_rfc_8949_appendix_a_numbers_re_encode_in_their_shortest_form() {
    for v in ["1b000000e8d4a51000", "3b7fffffffffffffff", "f90000", "f98000", "f93c00", "fb3ff199999999999a", "f93e00", "f97bff", "fa47c35000", "fa7f7fffff",
        "fb7e37e43c8800759c", "f90001", "f90400", "fbc010666666666666", "f97c00", "f97e00", "f9fc00", "f4", "f5", "f6", "f7", "f0", "f8ff", "c11a514b67b0"]
    {
        assert_eq!(deterministic(v), v);
    }
    assert_eq!(deterministic("fa3f800000"), "f93c00");
    assert_eq!(deterministic("fb3ff0000000000000"), "f93c00");
    assert_eq!(deterministic("fb40f86a0000000000"), "fa47c35000");
    assert_eq!(deterministic("fa7f800000"), "f97c00");
    assert_eq!(deterministic("fb7ff8000000000000"), "f97e00");
    assert_eq!(deterministic("190064"), "1864");
}

#[test]
fn stt_cbr_001_indefinite_lengths_re_encode_as_definite() {
    assert_eq!(deterministic("5f42010243030405ff"), "450102030405");
    assert_eq!(deterministic("7f657374726561646d696e67ff"), "6973747265616d696e67");
    assert_eq!(deterministic("9fff"), "80");
    assert_eq!(deterministic("9f018202039f0405ffff"), "8301820203820405");
    assert_eq!(deterministic("bf61610161629f0203ffff"), "a26161016162820203");
    assert_eq!(deterministic("bf6346756ef563416d7421ff"), "a263416d74216346756ef5");
}

#[test]
fn stt_cbr_002_text_is_nfc_normalised_on_encode() {
    let decomposed = "Hoa\u{300}";
    let enc = cbor::encode(&Item::Text(decomposed.into())).unwrap();
    assert_eq!(cbor::decode(&enc, &DEFAULT_LIMITS).unwrap(), Item::Text("Ho\u{e0}".into()));
}

#[test]
fn stt_cbr_003_malformed_or_oversized_input_is_refused_with_a_typed_error() {
    for bad in ["5f42010243", "5f4201026103ff", "5f5f4101ffff", "9f01", "bf6161", "ff", "1c", "5a00000005", "3bffffffffffffffff"] {
        assert!(codec::cbor_deterministic(&from_hex(bad).unwrap(), &DEFAULT_LIMITS).is_err(), "{bad}");
    }
    let deep = [vec![0x81u8; 40], vec![0]].concat();
    assert!(matches!(codec::cbor_deterministic(&deep, &DEFAULT_LIMITS), Err(CodecError::LimitExceeded(_))));
    let long = [vec![0x59, 0x50, 0x00], vec![0u8; 0x5000]].concat();
    assert!(matches!(codec::cbor_deterministic(&long, &DEFAULT_LIMITS), Err(CodecError::LimitExceeded(_))));
}
