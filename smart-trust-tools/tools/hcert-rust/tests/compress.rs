//! Skill `hcert-compress`: each test named after the requirements it verifies.

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
fn stt_zip_001_stt_zip_002_zlib_round_trips_and_inflation_is_bounded() {
    let data = vec![7u8; 10_000];
    let z = codec::zlib_compress(&data, 9);
    assert!(z.len() < 100);
    assert_eq!(codec::zlib_inflate(&z, 10_000).unwrap(), data);
    assert!(matches!(codec::zlib_inflate(&z, 9_999), Err(CodecError::LimitExceeded(_))));
    let mut trailing = z.clone();
    trailing.push(0);
    assert!(matches!(codec::zlib_inflate(&trailing, 10_000), Err(CodecError::InflateFailed(_))));
    assert!(matches!(codec::zlib_inflate(&z[..z.len() - 3], 10_000), Err(CodecError::InflateFailed(_))));
}
