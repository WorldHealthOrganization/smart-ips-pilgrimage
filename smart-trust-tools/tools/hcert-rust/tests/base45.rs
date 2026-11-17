//! Skill `hcert-encode-base45`: each test named after the requirements it verifies.

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
fn stt_b45_001_rfc_9285_examples_encode_and_decode() {
    for (plain, enc) in [("AB", "BB8"), ("Hello!!", "%69 VD92EX0"), ("base-45", "UJCLQE7W581"), ("ietf!", "QED8WEX0")] {
        assert_eq!(codec::base45_encode(plain.as_bytes()), enc);
        assert_eq!(codec::base45_decode(enc).unwrap(), plain.as_bytes());
    }
}

#[test]
fn stt_b45_002_decoding_is_strict() {
    for bad in ["GGW", "A", "abc", "::::"] {
        assert!(matches!(codec::base45_decode(bad), Err(CodecError::Base45Invalid(_))), "{bad}");
    }
}
