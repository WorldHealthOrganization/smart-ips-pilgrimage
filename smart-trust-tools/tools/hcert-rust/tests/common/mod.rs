//! Shared test support: the repository's vectors and the test PKI.
#![allow(dead_code)]

use hcert::cose;
use hcert::payload::{DvcMin, Registry, VaccineDetails};
use hcert::trust::{pem_blocks, TrustStore};
use hcert::types::CoseAlgorithm;
use hcert::verifier::VerifierOptions;
use std::path::PathBuf;

pub fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../..")
}

pub fn read(path: &str) -> String {
    std::fs::read_to_string(repo_root().join(path)).unwrap_or_else(|e| panic!("{path}: {e}"))
}

pub fn json(path: &str) -> hcert::json::Json {
    hcert::json::parse(&read(path)).unwrap()
}

/// 2026-10-20T00:00:00Z, inside the PR 129 certificates' validity.
pub const NOW: i64 = 1_792_454_400;

pub fn options() -> VerifierOptions {
    VerifierOptions::default()
}

pub fn reg() -> Registry {
    Registry::default()
}

pub const PR129: &str = "vectors/smart-trust-pr129/dvc-qr-example-XXA.json";
pub const PR129_DSC: &str = "vectors/smart-trust-pr129/dvc-qr-example-XXA-dsc.pem";

pub fn pr129_store() -> TrustStore {
    let mut s = TrustStore::new();
    s.add_pem(&read(PR129_DSC)).unwrap();
    s
}

/// The merged guide's example (WHO af75be2): GDHCN DEV participant XXR. Its DSC
/// is on the DEV trust list, not in this repository, so it decodes but is not verified here.
pub const XXR: &str = "vectors/smart-trust-af75be2/dvc-qr-example-XXR.json";
/// XXR's DSC DID document, from the GDHCN DEV trust list (SOURCE.yaml says when).
pub const XXR_DSC_DID: &str = "vectors/smart-trust-af75be2/XXR-DSC-did.json";

pub fn pr129_hc1(name: &str) -> String {
    json(PR129).get("certificates").unwrap().get(name).unwrap().get("hc1").unwrap().as_str().unwrap().to_owned()
}

pub fn es_der() -> Vec<u8> {
    pem_blocks(&read("vectors/testkit/es256-dsc.pem"), "CERTIFICATE").unwrap().remove(0)
}

pub fn ps_der() -> Vec<u8> {
    pem_blocks(&read("vectors/testkit/ps256-dsc-test-eku.pem"), "CERTIFICATE").unwrap().remove(0)
}

/// An hour after the testkit DSCs' notBefore (2026-10-20T18:16:32Z).
pub const TESTKIT_NOW: i64 = 1_792_520_192 + 3600;

/// Deterministic, and only for signing in tests: never use it for anything else.
pub struct TestRng(pub u64);
impl rand_core::RngCore for TestRng {
    fn next_u32(&mut self) -> u32 {
        self.next_u64() as u32
    }
    fn next_u64(&mut self) -> u64 {
        self.0 ^= self.0 << 13;
        self.0 ^= self.0 >> 7;
        self.0 ^= self.0 << 17;
        self.0
    }
    fn fill_bytes(&mut self, dest: &mut [u8]) {
        for b in dest {
            *b = self.next_u64() as u8;
        }
    }
    fn try_fill_bytes(&mut self, dest: &mut [u8]) -> Result<(), rand_core::Error> {
        self.fill_bytes(dest);
        Ok(())
    }
}
impl rand_core::CryptoRng for TestRng {}

/// Signs `data` with the testkit key for `alg`, as a host would: ES256 as r||s.
pub fn sign(alg: CoseAlgorithm, data: &[u8]) -> Vec<u8> {
    match alg {
        CoseAlgorithm::Es256 => {
            use p256::ecdsa::signature::Signer;
            use p256::pkcs8::DecodePrivateKey;
            let der = pem_blocks(&read("vectors/testkit/es256-key.pem"), "PRIVATE KEY").unwrap().remove(0);
            let key = p256::ecdsa::SigningKey::from_pkcs8_der(&der).unwrap();
            let sig: p256::ecdsa::Signature = key.sign(data);
            sig.to_bytes().to_vec()
        }
        CoseAlgorithm::Ps256 => {
            use rsa::pkcs8::DecodePrivateKey;
            use rsa::signature::{RandomizedSigner, SignatureEncoding};
            let der = pem_blocks(&read("vectors/testkit/ps256-key.pem"), "PRIVATE KEY").unwrap().remove(0);
            let key = rsa::RsaPrivateKey::from_pkcs8_der(&der).unwrap();
            let signer = rsa::pss::BlindedSigningKey::<sha2::Sha256>::new(key);
            signer.sign_with_rng(&mut TestRng(0x9e37_79b9_7f4a_7c15), data).to_vec()
        }
    }
}

pub fn newborn() -> DvcMin {
    DvcMin {
        n: "Test CHILD".into(),
        dob: "2026-09-28".into(),
        s: "female".into(),
        nt: "LAO".into(),
        gn: Some("Test MOTHER".into()),
        vx: VaccineDetails { vp: "XM9V38".into(), dv: "2026-09-28".into(), cn: None, is: Some("org-test".into()), bo: "HEPB-TEST".into() },
        v: "1.0.0".into(),
        extensions: vec![("zz".into(), hcert::cbor::encode(&hcert::cbor::Item::Text("kept".into())).unwrap())],
        ..Default::default()
    }
}

pub fn kid_of(der: &[u8]) -> [u8; 8] {
    cose::kid_from_dsc(der)
}

pub fn deterministic(hex: &str) -> String {
    hcert::types::to_hex(&hcert::codec::cbor_deterministic(&hcert::types::from_hex(hex).unwrap(), &hcert::types::DEFAULT_LIMITS).unwrap())
}

pub fn request(alg: CoseAlgorithm) -> hcert::issuer::IssueRequest {
    hcert::issuer::IssueRequest {
        payloads: vec![hcert::payload::Payload::DvcMin(newborn())],
        iss: Some("XX".into()),
        iat: TESTKIT_NOW,
        exp: TESTKIT_NOW + 86_400 * 365,
        alg,
        dsc_der: if alg == CoseAlgorithm::Es256 { es_der() } else { ps_der() },
        allow_development_subclaims: true,
    }
}

pub fn issue(alg: CoseAlgorithm) -> hcert::issuer::IssuedHcert {
    let p = hcert::issuer::prepare(&request(alg), &reg()).unwrap();
    hcert::issuer::finish(&p, &sign(alg, &p.to_be_signed)).unwrap()
}

/// A COSE_Sign1 over `claims`, signed by the ES256 testkit key: for claim
/// sets the issuer would refuse to build.
pub fn signed_claims(claims: &hcert::cbor::Item) -> Vec<u8> {
    let payload_bytes = hcert::cbor::encode(claims).unwrap();
    let ph = hcert::issuer::protected_header(CoseAlgorithm::Es256, &kid_of(&es_der()));
    let sig = sign(CoseAlgorithm::Es256, &cose::sig_structure(&ph, &payload_bytes));
    cose::assemble_sign1(&ph, &payload_bytes, &sig)
}

/// The IHE example link, live at TESTKIT_NOW (its own exp is in 2025).
pub fn live_vhl() -> hcert::vhl::VhlPayload {
    hcert::vhl::VhlPayload { exp: Some(TESTKIT_NOW + 86_400), ..ihe_vhl() }
}

/// The one entry of a single-payload certificate.
pub fn only(v: &hcert::verifier::VerifiedHcert) -> &hcert::verifier::HcertEntry {
    assert_eq!(v.entries.len(), 1, "{:?}", v.entries);
    &v.entries[0]
}

pub fn store_with(der: &[u8]) -> TrustStore {
    let mut s = TrustStore::new();
    s.add_der(der).unwrap();
    s
}

/// The IHE ITI-YY3 example payload.
pub fn ihe_vhl() -> hcert::vhl::VhlPayload {
    hcert::vhl::VhlPayload {
        url: "https://vhl-sharer.example.org/List/_search?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item".into(),
        key: "86F8LY5LlWAa1-OS_FgrTnYNqFHJP2ey5RSKLJBN9jk".into(),
        exp: Some(1_735_689_600),
        flag: Some("LP".into()),
        label: Some("Patient Health Summary".into()),
        v: Some(1),
        fhir_base_url: Some("https://vhl-sharer.example.org".into()),
    }
}

/// Issues `payload` with the ES256 testkit key, valid at TESTKIT_NOW.
pub fn issue_payload(payload: hcert::payload::Payload) -> hcert::issuer::IssuedHcert {
    issue_payloads(vec![payload])
}

/// Issues several payloads in one certificate, with the ES256 testkit key.
pub fn issue_payloads(payloads: Vec<hcert::payload::Payload>) -> hcert::issuer::IssuedHcert {
    let mut r = request(CoseAlgorithm::Es256);
    r.payloads = payloads;
    let p = hcert::issuer::prepare(&r, &reg()).unwrap();
    hcert::issuer::finish(&p, &sign(CoseAlgorithm::Es256, &p.to_be_signed)).unwrap()
}
