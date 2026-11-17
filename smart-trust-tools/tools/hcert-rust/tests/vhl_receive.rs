//! Skill `vhl-receive`: use a Verifiable Health Link (journey J4.1). The
//! same cases as the Kotlin VhlReceiveTest, against the same fixtures.

mod common;
use common::*;
use hcert::payload::Payload;
use hcert::types::*;
use hcert::vhl::{self, SignatureRequest, VhlError, VhlPayload};
use hcert::{cose, verifier};

#[test]
fn stt_vhl_005_the_iti_yy5_request_is_the_exact_body_of_the_ihe_example() {
    let r = vhl::build_manifest_request(&ihe_vhl(), "Dr. Smith Hospital", Some("user-pin"), Some(10000)).unwrap();
    assert_eq!(r.url, "https://vhl-sharer.example.org/List/_search");
    assert_eq!(r.content_type, "application/x-www-form-urlencoded");
    assert_eq!(
        r.body,
        "_id=abc123def456&code=folder&status=current&patient.identifier=urn%3Aoid%3A2.16.840.1.113883.2.4.6.3%7CPASSPORT123&_include=List%3Aitem&recipient=Dr.+Smith+Hospital&passcode=user-pin&embeddedLengthMax=10000"
    );
}

#[test]
fn stt_vhl_005_a_list_url_is_searched_and_the_passcode_follows_the_p_flag() {
    let list = VhlPayload { url: "https://vhl-sharer.example.org/List?_id=abc&code=folder&status=current&patient.identifier=s%7Cv".into(), flag: None, ..ihe_vhl() };
    assert_eq!(vhl::build_manifest_request(&list, "Clinic B", None, None).unwrap().url, "https://vhl-sharer.example.org/List/_search");
    assert!(matches!(vhl::build_manifest_request(&ihe_vhl(), "Clinic B", None, None), Err(VhlError::Manifest(_))), "P without passcode");
    assert!(matches!(vhl::build_manifest_request(&list, "Clinic B", Some("1234"), None), Err(VhlError::Manifest(_))), "passcode without P");
    let no_id = VhlPayload { url: "https://vhl-sharer.example.org/List?code=folder&status=current&patient.identifier=s%7Cv".into(), ..list };
    assert!(matches!(vhl::build_manifest_request(&no_id, "Clinic B", None, None), Err(VhlError::Manifest(_))));
}

#[test]
fn stt_vhl_006_the_ihe_case_b_manifest_bundle_reads_as_documents() {
    let docs = vhl::parse_manifest(&read("vectors/ihe-vhl/iti-yy5-manifest-case-b.json")).unwrap();
    assert_eq!(docs.len(), 4);
    assert_eq!(docs[0].url.as_deref(), Some("https://vhl-sharer.example.org/Binary/doc001-content"));
    assert_eq!(docs[0].content_type.as_deref(), Some("application/pdf"));
    // the example abbreviates doc002..doc004 to bare ids: handed back as references
    let refs: Vec<_> = docs[1..].iter().map(|d| d.reference.clone().unwrap()).collect();
    assert_eq!(refs, vec!["DocumentReference/doc002", "DocumentReference/doc003", "DocumentReference/doc004"]);
}

#[test]
fn stt_vhl_006_a_case_a_manifest_without_includes_hands_back_references() {
    let bundle = r#"{"resourceType":"Bundle","type":"searchset","entry":[{"resource":{"resourceType":"List","entry":[{"item":{"reference":"DocumentReference/d1"}}]},"search":{"mode":"match"}}]}"#;
    let d = vhl::parse_manifest(bundle).unwrap();
    assert_eq!(d.len(), 1);
    assert_eq!(d[0].reference.as_deref(), Some("DocumentReference/d1"));
    assert!(d[0].url.is_none());
    assert!(matches!(vhl::parse_manifest(r#"{"resourceType":"Bundle","type":"document"}"#), Err(VhlError::Manifest(_))));
}

#[test]
fn stt_vhl_007_decrypts_what_node_crypto_encrypted_with_and_without_zip_def() {
    let f = json("vectors/ihe-vhl/jwe-dir-a256gcm.json");
    let s = |k: &str| f.get(k).unwrap().as_str().unwrap().to_owned();
    for k in ["jwe", "jweZipDef"] {
        let d = vhl::decrypt(&s(k), &s("key")).unwrap_or_else(|e| panic!("{k}: {e}"));
        assert_eq!(String::from_utf8(d.content).unwrap(), s("plaintext"), "{k}");
        assert_eq!(d.content_type.as_deref(), Some("application/fhir+json"));
    }
}

#[test]
fn stt_vhl_007_a_wrong_key_a_changed_byte_and_another_enc_are_refused() {
    let key = vhl::new_key().unwrap();
    let jwe = vhl::encrypt(b"hello", "text/plain", &key).unwrap();
    assert!(matches!(vhl::decrypt(&jwe, &vhl::new_key().unwrap()), Err(VhlError::DecryptFailed(_))));
    let mut parts: Vec<String> = jwe.split('.').map(str::to_owned).collect();
    let mut ct = cose::base64_decode(&parts[3]).unwrap();
    ct[0] ^= 1;
    parts[3] = cose::base64_encode(&ct, true).trim_end_matches('=').to_owned();
    assert!(matches!(vhl::decrypt(&parts.join("."), &key), Err(VhlError::DecryptFailed(_))));
    let a128 = format!("{}..{}", cose::base64_encode(br#"{"alg":"dir","enc":"A128GCM"}"#, true).trim_end_matches('='), jwe.split_once("..").unwrap().1);
    assert!(matches!(vhl::decrypt(&a128, &key), Err(VhlError::Unsupported(_))));
}

fn request() -> SignatureRequest {
    SignatureRequest {
        method: "POST".into(),
        authority: "vhl-sharer.example.org".into(),
        path: "/List/_search".into(),
        content_type: Some("application/x-www-form-urlencoded".into()),
        body: Some(br#"{"hello": "world"}"#.to_vec()),
        keyid: "receiver-key-123".into(),
        alg: "ecdsa-p256-sha256".into(),
        created: 1_735_689_600,
    }
}

/// RFC 9530 appendix B.1's sha-256 of {"hello": "world"} (OI-26).
#[test]
fn stt_vhl_008_the_content_digest_is_rfc_9530() {
    assert_eq!(vhl::build_signature_base(&request()).content_digest.as_deref(), Some("sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:"));
}

#[test]
fn stt_vhl_008_the_rfc_9421_signature_base_has_the_ihe_shape() {
    let b = vhl::build_signature_base(&request());
    let params = r#"("@method" "@path" "@authority" "content-type" "content-digest");created=1735689600;keyid="receiver-key-123";alg="ecdsa-p256-sha256""#;
    assert_eq!(b.signature_input, format!("sig1={params}"));
    let expected = [
        "\"@method\": POST".to_string(),
        "\"@path\": /List/_search".into(),
        "\"@authority\": vhl-sharer.example.org".into(),
        "\"content-type\": application/x-www-form-urlencoded".into(),
        "\"content-digest\": sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:".into(),
        format!("\"@signature-params\": {params}"),
    ]
    .join("\n");
    assert_eq!(String::from_utf8(b.base).unwrap(), expected);
}

#[test]
fn stt_vhl_008_a_der_signature_becomes_the_raw_header_value_and_verifies() {
    use p256::ecdsa::signature::{Signer, Verifier};
    let b = vhl::build_signature_base(&request());
    let key = p256::ecdsa::SigningKey::from_slice(&[9u8; 32]).unwrap();
    let sig: p256::ecdsa::Signature = key.sign(&b.base);
    let header = vhl::signature_header(sig.to_der().as_bytes(), "ecdsa-p256-sha256").unwrap();
    let raw = cose::base64_decode(header.strip_prefix("sig1=:").unwrap().strip_suffix(':').unwrap()).unwrap();
    assert_eq!(raw.len(), 64);
    assert!(key.verifying_key().verify(&b.base, &p256::ecdsa::Signature::from_slice(&raw).unwrap()).is_ok());
}

#[test]
fn stt_vhl_009_an_expired_link_fails_verification_by_its_own_exp() {
    assert_eq!(vhl::validate(&ihe_vhl(), Some(1_735_689_601)).into_iter().map(|i| i.code).collect::<Vec<_>>(), vec!["expired"]);
    let issued = issue_payload(Payload::Vhl(VhlPayload { exp: Some(TESTKIT_NOW - 1000), ..ihe_vhl() }));
    let f = verifier::verify(&issued.hc1, &store_with(&es_der()), &reg(), TESTKIT_NOW, &options()).unwrap_err();
    assert_eq!(f.reason, FailureReason::Expired);
}
