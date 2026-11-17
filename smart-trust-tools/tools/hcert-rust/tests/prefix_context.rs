//! Skill `hcert-prefix-context`: each test named after the requirements it verifies.

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
fn stt_hc1_001_the_context_identifier_is_read_and_checked() {
    assert_eq!(codec::detect_context("HC1:ABC").unwrap(), ("1".to_string(), "ABC"));
    assert_eq!(codec::detect_context("HCZ:").unwrap().0, "Z");
    assert_eq!(codec::detect_context("HC0:"), Err(CodecError::BadPrefix));
    assert_eq!(codec::detect_context("hc1:"), Err(CodecError::BadPrefix));
    assert!(matches!(codec::from_hc1("HC2:00", &DEFAULT_LIMITS), Err(CodecError::UnsupportedContextVersion(_))));
}
