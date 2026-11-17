//! The WebAssembly component: the `hcert` world of the WIT contract in
//! api/wit, implemented by the library (STT-GEN-005). wit-bindgen generates
//! the bindings from the WIT at build time; everything here converts between
//! them and the library's own types and calls the library. Randomness comes
//! from the host's wasi:random/random import.

wit_bindgen::generate!({
    path: "../../api/wit",
    world: "hcert",
    // The one foreign interface: generate its import bindings here.
    with: { "wasi:random/random@0.2.6": generate },
});

use std::cell::RefCell;

use exports::who::smart_trust as w;
use w::codec::CodecError as WCodecError;
use w::cose::{Base64Alphabet, CoseError as WCoseError, Sign1 as WSign1};
use w::dvc::{DvcMin as WDvc, DvcMinVaccineDetails as WVx};
use w::issuer::{IssueError as WIssueError, IssueRequest as WIssueRequest, IssuedHcert as WIssued, PendingSignature as WPending};
use w::payloads::{Payload as WPayload, RawPayload as WRaw};
use w::subclaims::{PayloadKind as WKind, RegistryBorrow};
use w::trust::{TrustError as WTrustError, TrustStoreBorrow, TrustedDsc as WDsc};
use w::types::{
    CoseAlgorithm as WAlg, DecodeLimits as WLimits, Diagnostic as WDiag, FailureReason as WReason, Severity as WSeverity, Step as WStep, Subclaim as WSubclaim,
    ValidationIssue as WIssue,
};
use w::verifier::{
    HcertEntry as WEntry, UnverifiedEntry as WUnverifiedEntry, UnverifiedHcert as WUnverified, VerificationFailure as WFailure, VerificationResult as WResult, VerifiedHcert as WVerified,
    VerifierOptions as WOptions,
};
use w::vhl::{
    Decrypted as WDecrypted, ManifestDocument as WDoc, ManifestRequest as WManifestRequest, SignatureBase as WSigBase, SignatureRequest as WSigRequest, VhlError as WVhlError,
    VhlPayload as WVhl,
};

use crate::payload::{DvcMin, Payload, PayloadKind, Subclaim, VaccineDetails};
use crate::types::*;
use crate::vhl::{VhlError, VhlPayload};

struct Component;
export!(Component);

fn host_entropy(buf: &mut [u8]) -> Result<(), getrandom::Error> {
    let bytes = wasi::random::random::get_random_bytes(buf.len() as u64);
    if bytes.len() != buf.len() {
        return Err(getrandom::Error::UNSUPPORTED);
    }
    buf.copy_from_slice(&bytes);
    Ok(())
}
getrandom::register_custom_getrandom!(host_entropy);

// ---- conversions --------------------------------------------------------

fn limits(l: WLimits) -> DecodeLimits {
    DecodeLimits {
        max_input_chars: l.max_input_chars as usize,
        max_inflated_bytes: l.max_inflated_bytes as usize,
        max_depth: l.max_depth as usize,
        max_items: l.max_items as usize,
        max_string_bytes: l.max_string_bytes as usize,
    }
}
fn alg_out(a: CoseAlgorithm) -> WAlg {
    match a {
        CoseAlgorithm::Es256 => WAlg::Es256,
        CoseAlgorithm::Ps256 => WAlg::Ps256,
    }
}
fn alg_in(a: WAlg) -> CoseAlgorithm {
    match a {
        WAlg::Es256 => CoseAlgorithm::Es256,
        WAlg::Ps256 => CoseAlgorithm::Ps256,
    }
}
fn s32(v: i64) -> i32 {
    v.clamp(i32::MIN as i64, i32::MAX as i64) as i32
}
fn severity(s: Severity) -> WSeverity {
    match s {
        Severity::Blocking => WSeverity::Blocking,
        Severity::Warning => WSeverity::Warning,
        Severity::Information => WSeverity::Information,
    }
}
fn issue(i: ValidationIssue) -> WIssue {
    WIssue { path: i.path, code: i.code, message: i.message, severity: severity(i.severity) }
}
fn issues(v: Vec<ValidationIssue>) -> Vec<WIssue> {
    v.into_iter().map(issue).collect()
}
fn step(s: Step) -> WStep {
    match s {
        Step::Prefix => WStep::Prefix,
        Step::Base45 => WStep::Base45,
        Step::Inflate => WStep::Inflate,
        Step::Cose => WStep::Cose,
        Step::Header => WStep::Header,
        Step::TrustLookup => WStep::TrustLookup,
        Step::Signature => WStep::Signature,
        Step::KeyUsage => WStep::KeyUsage,
        Step::Cwt => WStep::Cwt,
        Step::Time => WStep::Time,
        Step::Hcert => WStep::Hcert,
        Step::Payload => WStep::Payload,
    }
}
fn reason(r: FailureReason) -> WReason {
    match r {
        FailureReason::BadPrefix => WReason::BadPrefix,
        FailureReason::UnsupportedContextVersion => WReason::UnsupportedContextVersion,
        FailureReason::Base45Invalid => WReason::Base45Invalid,
        FailureReason::InflateFailed => WReason::InflateFailed,
        FailureReason::LimitExceeded => WReason::LimitExceeded,
        FailureReason::CoseMalformed => WReason::CoseMalformed,
        FailureReason::HeaderInvalid => WReason::HeaderInvalid,
        FailureReason::UnsupportedAlgorithm => WReason::UnsupportedAlgorithm,
        FailureReason::KidNotFound => WReason::KidNotFound,
        FailureReason::SignatureInvalid => WReason::SignatureInvalid,
        FailureReason::KeyUsageMismatch => WReason::KeyUsageMismatch,
        FailureReason::Expired => WReason::Expired,
        FailureReason::NotYetValid => WReason::NotYetValid,
        FailureReason::HcertMissing => WReason::HcertMissing,
        FailureReason::MultipleSubclaims => WReason::MultipleSubclaims,
        FailureReason::PayloadInvalid => WReason::PayloadInvalid,
    }
}
fn diag(d: Diagnostic) -> WDiag {
    WDiag { step: step(d.step), severity: severity(d.severity), message: d.message }
}
fn codec_error(e: CodecError) -> WCodecError {
    match e {
        CodecError::Base45Invalid(m) => WCodecError::Base45Invalid(m),
        CodecError::InflateFailed(m) => WCodecError::InflateFailed(m),
        CodecError::LimitExceeded(m) => WCodecError::LimitExceeded(m),
        CodecError::CborMalformed(m) => WCodecError::CborMalformed(m),
        CodecError::BadPrefix => WCodecError::BadPrefix,
        CodecError::UnsupportedContextVersion(v) => WCodecError::UnsupportedContextVersion(v),
    }
}
fn cose_error(e: CoseError) -> WCoseError {
    match e {
        CoseError::Malformed(m) => WCoseError::Malformed(m),
        CoseError::HeaderInvalid(m) => WCoseError::HeaderInvalid(m),
        CoseError::UnsupportedAlgorithm(a) => WCoseError::UnsupportedAlgorithm(s32(a)),
        CoseError::BadSignatureFormat(m) => WCoseError::BadSignatureFormat(m),
        CoseError::SignatureInvalid => WCoseError::SignatureInvalid,
        CoseError::BadCertificate(m) => WCoseError::BadCertificate(m),
    }
}
fn trust_error(e: TrustError) -> WTrustError {
    match e {
        TrustError::Parse(m) => WTrustError::Parse(m),
        TrustError::UnknownTrustDomain(d) => WTrustError::UnknownTrustDomain(d),
        TrustError::ProofInvalid(m) => WTrustError::ProofInvalid(m),
    }
}
fn issue_error(e: IssueError) -> WIssueError {
    match e {
        IssueError::PayloadInvalid(v) => WIssueError::PayloadInvalid(issues(v)),
        IssueError::NoPayload => WIssueError::NoPayload,
        IssueError::DuplicateSubclaim(s) => WIssueError::DuplicateSubclaim(s32(s)),
        IssueError::DevelopmentSubclaimNotAllowed(s) => WIssueError::DevelopmentSubclaimNotAllowed(s32(s)),
        IssueError::UnknownSubclaim(s) => WIssueError::UnknownSubclaim(s32(s)),
        IssueError::ValidityOutsideDsc => WIssueError::ValidityOutsideDsc,
        IssueError::BadCertificate(m) => WIssueError::BadCertificate(m),
        IssueError::BadSignatureFormat(m) => WIssueError::BadSignatureFormat(m),
    }
}
fn vhl_error(e: VhlError) -> WVhlError {
    match e {
        VhlError::Invalid(v) => WVhlError::Invalid(issues(v)),
        VhlError::NotAVhlink(m) => WVhlError::NotAVhlink(m),
        VhlError::Manifest(m) => WVhlError::Manifest(m),
        VhlError::DecryptFailed(m) => WVhlError::DecryptFailed(m),
        VhlError::Unsupported(m) => WVhlError::Unsupported(m),
    }
}
fn subclaim_out(s: &Subclaim) -> WSubclaim {
    WSubclaim { key: s32(s.key), title: s.name.clone(), logical_model: s.profile.clone() }
}
fn kind_in(k: WKind) -> PayloadKind {
    match k {
        WKind::DvcMin => PayloadKind::DvcMin,
        WKind::Vhl => PayloadKind::Vhl,
    }
}
fn dvc_in(p: WDvc) -> DvcMin {
    DvcMin {
        n: p.n,
        dob: p.dob,
        s: p.s,
        nt: p.nt,
        id: p.id,
        dt: p.dt,
        gn: p.gn,
        vx: VaccineDetails { vp: p.vx.vp, dv: p.vx.dv, cn: p.vx.cn, is: p.vx.is, bo: p.vx.bo },
        v: p.v,
        extensions: p.extensions,
    }
}
fn dvc_out(p: DvcMin) -> WDvc {
    WDvc {
        n: p.n,
        dob: p.dob,
        s: p.s,
        nt: p.nt,
        id: p.id,
        dt: p.dt,
        gn: p.gn,
        vx: WVx { vp: p.vx.vp, dv: p.vx.dv, cn: p.vx.cn, is: p.vx.is, bo: p.vx.bo },
        v: p.v,
        extensions: p.extensions,
    }
}
fn vhl_in(p: WVhl) -> VhlPayload {
    VhlPayload { url: p.url, key: p.key, exp: p.exp, flag: p.flag, label: p.label, v: p.v, fhir_base_url: p.fhir_base_url }
}
fn vhl_out(p: VhlPayload) -> WVhl {
    WVhl { url: p.url, key: p.key, exp: p.exp, flag: p.flag, label: p.label, v: p.v, fhir_base_url: p.fhir_base_url }
}
fn payload_in(p: WPayload) -> Payload {
    match p {
        WPayload::DvcMin(d) => Payload::DvcMin(dvc_in(d)),
        WPayload::Vhl(v) => Payload::Vhl(vhl_in(v)),
        WPayload::Raw(r) => Payload::Raw { subclaim: r.subclaim as i64, cbor: r.cbor },
    }
}
fn payload_out(p: Payload) -> WPayload {
    match p {
        Payload::DvcMin(d) => WPayload::DvcMin(dvc_out(d)),
        Payload::Vhl(v) => WPayload::Vhl(vhl_out(v)),
        Payload::Raw { subclaim, cbor } => WPayload::Raw(WRaw { subclaim: s32(subclaim), cbor }),
    }
}
fn dsc_out(d: crate::trust::TrustedDsc) -> WDsc {
    WDsc {
        der: d.der,
        kid: d.kid.to_vec(),
        country: d.country,
        not_before: d.not_before,
        not_after: d.not_after,
        extended_key_usages: d.extended_key_usages,
        domain: d.trust_domain,
        participant: d.participant,
    }
}
fn kid_in(k: &[u8]) -> Option<Kid> {
    k.try_into().ok()
}
fn failure_out(f: crate::verifier::VerificationFailure) -> WFailure {
    WFailure { step: step(f.step), reason: reason(f.reason), detail: f.detail, diagnostics: Vec::new() }
}
fn options_in(o: WOptions) -> crate::verifier::VerifierOptions {
    crate::verifier::VerifierOptions { limits: limits(o.limits), clock_skew_seconds: o.clock_skew_seconds as i64, max_payloads: o.max_payloads }
}
fn result_out(r: Result<crate::verifier::VerifiedHcert, crate::verifier::VerificationFailure>) -> WResult {
    match r {
        Ok(v) => WResult::Verified(WVerified {
            iss: v.iss,
            iat: v.iat,
            exp: v.exp,
            entries: v.entries.into_iter().map(|e| WEntry { subclaim: s32(e.subclaim), payload: payload_out(e.payload), key_usage_authorised: e.key_usage_authorised }).collect(),
            dsc: dsc_out(v.dsc),
            other_claims: v.other_claims,
            diagnostics: v.diagnostics.into_iter().map(diag).collect(),
        }),
        Err(f) => WResult::Failed(failure_out(f)),
    }
}

// ---- resources ----------------------------------------------------------

pub struct Registry(RefCell<crate::payload::Registry>);
pub struct TrustStore(RefCell<crate::trust::TrustStore>);
pub struct Pending(crate::issuer::PendingSignature);

impl w::subclaims::GuestRegistry for Registry {
    fn new() -> Self {
        Registry(RefCell::new(crate::payload::Registry::default()))
    }
    fn lookup(&self, key: i32) -> Option<WSubclaim> {
        self.0.borrow().lookup(key as i64).map(subclaim_out)
    }
    fn register(&self, s: WSubclaim) {
        self.0.borrow_mut().register(Subclaim { key: s.key as i64, name: s.title, profile: s.logical_model });
    }
    fn all(&self) -> Vec<WSubclaim> {
        self.0.borrow().all().iter().map(subclaim_out).collect()
    }
    fn subclaim_for(&self, kind: WKind) -> Option<i32> {
        Some(s32(self.0.borrow().subclaim_for(kind_in(kind))))
    }
    fn set_subclaim_for(&self, kind: WKind, key: i32) {
        self.0.borrow_mut().set_subclaim_for(kind_in(kind), key as i64);
    }
}

impl w::trust::GuestTrustStore for TrustStore {
    fn new() -> Self {
        TrustStore(RefCell::new(crate::trust::TrustStore::new()))
    }
    fn add_pem(&self, pem: String) -> Result<u32, WTrustError> {
        self.0.borrow_mut().add_pem(&pem).map_err(trust_error)
    }
    fn add_der(&self, der: Vec<u8>) -> Result<u32, WTrustError> {
        self.0.borrow_mut().add_der(&der).map_err(trust_error)
    }
    fn add_did_document(&self, json: String) -> Result<u32, WTrustError> {
        self.0.borrow_mut().add_did_document(&json).map_err(trust_error)
    }
    fn add_verified_did_document(&self, json: String, signer: String) -> Result<u32, WTrustError> {
        self.0.borrow_mut().add_verified_did_document(&json, &signer).map_err(trust_error)
    }
    fn load_trust_domains(&self, codesystem_json: String) -> Result<u32, WTrustError> {
        self.0.borrow_mut().load_trust_domains(&codesystem_json).map_err(trust_error)
    }
    fn trust_domains(&self) -> Vec<String> {
        self.0.borrow().trust_domains()
    }
    fn candidates(&self, k: Vec<u8>) -> Vec<WDsc> {
        match kid_in(&k) {
            Some(kid) => self.0.borrow().candidates(&kid).into_iter().cloned().map(dsc_out).collect(),
            None => Vec::new(),
        }
    }
    fn size(&self) -> u32 {
        self.0.borrow().len() as u32
    }
    fn clear(&self) {
        self.0.borrow_mut().clear();
    }
}

impl w::issuer::GuestPendingSignature for Pending {
    fn to_be_signed(&self) -> Vec<u8> {
        self.0.to_be_signed.clone()
    }
    fn algorithm(&self) -> WAlg {
        alg_out(self.0.alg)
    }
    fn kid(&self) -> Vec<u8> {
        self.0.kid.to_vec()
    }
}

// ---- interfaces ---------------------------------------------------------


impl w::codec::Guest for Component {
    fn base45_encode(data: Vec<u8>) -> String {
        crate::codec::base45_encode(&data)
    }
    fn base45_decode(text: String) -> Result<Vec<u8>, WCodecError> {
        crate::codec::base45_decode(&text).map_err(codec_error)
    }
    fn zlib_compress(data: Vec<u8>, level: u8) -> Vec<u8> {
        crate::codec::zlib_compress(&data, level)
    }
    fn zlib_inflate(data: Vec<u8>, max_out: u32) -> Result<Vec<u8>, WCodecError> {
        crate::codec::zlib_inflate(&data, max_out as usize).map_err(codec_error)
    }
    fn detect_context(text: String) -> Result<(String, String), WCodecError> {
        crate::codec::detect_context(&text).map(|(v, rest)| (v, rest.to_string())).map_err(codec_error)
    }
    fn to_hc1(cose: Vec<u8>) -> String {
        crate::codec::to_hc1(&cose)
    }
    fn from_hc1(text: String, l: WLimits) -> Result<Vec<u8>, WCodecError> {
        crate::codec::from_hc1(&text, &limits(l)).map_err(codec_error)
    }
    fn cbor_deterministic(cbor: Vec<u8>, l: WLimits) -> Result<Vec<u8>, WCodecError> {
        crate::codec::cbor_deterministic(&cbor, &limits(l)).map_err(codec_error)
    }
}

impl w::cose::Guest for Component {
    fn kid_from_dsc(dsc_der: Vec<u8>) -> Vec<u8> {
        crate::cose::kid_from_dsc(&dsc_der).to_vec()
    }
    fn kid_to_base64(k: Vec<u8>, alphabet: Base64Alphabet) -> String {
        crate::cose::base64_encode(&k, alphabet == Base64Alphabet::UrlSafe)
    }
    fn kid_from_base64(text: String) -> Result<Vec<u8>, WCoseError> {
        crate::cose::base64_decode(&text).map_err(|_| WCoseError::Malformed("kid is not base64".into()))
    }
    fn parse_sign1(bytes: Vec<u8>, l: WLimits) -> Result<WSign1, WCoseError> {
        let s = crate::cose::parse_sign1(&bytes, &limits(l)).map_err(cose_error)?;
        Ok(WSign1 {
            protected: s.protected,
            payload: s.payload,
            signature: s.signature,
            alg: Some(alg_out(s.alg)),
            kid: s.kid.map(|k| k.to_vec()),
            kid_in_protected: s.kid_in_protected,
            tagged: s.tagged,
        })
    }
    fn sig_structure(protected: Vec<u8>, payload: Vec<u8>) -> Vec<u8> {
        crate::cose::sig_structure(&protected, &payload)
    }
    fn verify_sign1(s: WSign1, dsc_der: Vec<u8>) -> Result<(), WCoseError> {
        let alg = s.alg.ok_or_else(|| WCoseError::HeaderInvalid("no alg".into()))?;
        let kid = match s.kid {
            None => None,
            Some(k) => Some(kid_in(&k).ok_or_else(|| WCoseError::HeaderInvalid(format!("kid is {} bytes, not 8", k.len())))?),
        };
        let sign1 = crate::cose::Sign1 { protected: s.protected, payload: s.payload, signature: s.signature, alg: alg_in(alg), kid, kid_in_protected: s.kid_in_protected, tagged: s.tagged };
        crate::cose::verify_sign1(&sign1, &dsc_der).map_err(cose_error)
    }
    fn ecdsa_der_to_raw(der: Vec<u8>) -> Result<Vec<u8>, WCoseError> {
        crate::cose::ecdsa_der_to_raw(&der).map(|r| r.to_vec()).map_err(cose_error)
    }
    fn ecdsa_raw_to_der(raw: Vec<u8>) -> Result<Vec<u8>, WCoseError> {
        if raw.len() != 64 {
            return Err(WCoseError::BadSignatureFormat(format!("ES256 signature must be 64 bytes, got {}", raw.len())));
        }
        Ok(crate::testdsc::ecdsa_raw_to_der(&raw))
    }
}

impl w::subclaims::Guest for Component {
    type Registry = Registry;
}

impl w::dvc::Guest for Component {
    fn validate(p: WDvc) -> Vec<WIssue> {
        issues(crate::payload::validate(&dvc_in(p)))
    }
    fn to_cbor(p: WDvc) -> Vec<u8> {
        // A collision between an extension and an element is refused at
        // issuance; here it gives the elements without the extensions.
        let d = dvc_in(p);
        crate::payload::to_cbor(&d).unwrap_or_else(|_| crate::payload::to_cbor(&DvcMin { extensions: Vec::new(), ..d }).unwrap_or_default())
    }
    fn from_cbor(cbor: Vec<u8>, l: WLimits) -> Result<WDvc, Vec<WIssue>> {
        crate::payload::from_cbor(&cbor, &limits(l)).map(dvc_out).map_err(issues)
    }
}


impl w::vhl::Guest for Component {
    fn validate(p: WVhl, now: Option<i64>) -> Vec<WIssue> {
        issues(crate::vhl::validate(&vhl_in(p), now))
    }
    fn to_vhlink(p: WVhl) -> String {
        crate::vhl::to_vhlink(&vhl_in(p))
    }
    fn from_vhlink(text: String) -> Result<WVhl, WVhlError> {
        crate::vhl::from_vhlink(&text).map(vhl_out).map_err(vhl_error)
    }
    fn new_key() -> String {
        crate::vhl::new_key().expect("the host supplies wasi:random")
    }
    fn build_manifest_request(p: WVhl, recipient: String, passcode: Option<String>, embedded_length_max: Option<u32>) -> Result<WManifestRequest, WVhlError> {
        crate::vhl::build_manifest_request(&vhl_in(p), &recipient, passcode.as_deref(), embedded_length_max)
            .map(|r| WManifestRequest { url: r.url, content_type: r.content_type, body: r.body })
            .map_err(vhl_error)
    }
    fn parse_manifest(bundle_json: String) -> Result<Vec<WDoc>, WVhlError> {
        crate::vhl::parse_manifest(&bundle_json)
            .map(|d| d.into_iter().map(|d| WDoc { url: d.url, reference: d.reference, content_type: d.content_type, title: d.title }).collect())
            .map_err(vhl_error)
    }
    fn encrypt(content: Vec<u8>, content_type: String, key: String) -> Result<String, WVhlError> {
        crate::vhl::encrypt(&content, &content_type, &key).map_err(vhl_error)
    }
    fn decrypt(jwe: String, key: String) -> Result<WDecrypted, WVhlError> {
        crate::vhl::decrypt(&jwe, &key).map(|d| WDecrypted { content_type: d.content_type, content: d.content }).map_err(vhl_error)
    }
    fn build_signature_base(r: WSigRequest) -> WSigBase {
        let b = crate::vhl::build_signature_base(&crate::vhl::SignatureRequest {
            method: r.method,
            authority: r.authority,
            path: r.path,
            content_type: r.content_type,
            body: r.body,
            keyid: r.keyid,
            alg: r.alg,
            created: r.created,
        });
        WSigBase { content_digest: b.content_digest, signature_input: b.signature_input, base: b.base }
    }
    fn signature_header(signature: Vec<u8>, alg: String) -> Result<String, WVhlError> {
        crate::vhl::signature_header(&signature, &alg).map_err(vhl_error)
    }
}

impl w::trust::Guest for Component {
    type TrustStore = TrustStore;
    fn verify_did_proof(document: String, signer: String) -> Result<(), WTrustError> {
        crate::didproof::verify_did_proof(&document, &signer).map_err(trust_error)
    }
}

impl w::verifier::Guest for Component {
    fn verify(hc1: String, store: TrustStoreBorrow<'_>, reg: RegistryBorrow<'_>, now: i64, options: WOptions) -> WResult {
        let store = store.get::<TrustStore>().0.borrow();
        let reg = reg.get::<Registry>().0.borrow();
        result_out(crate::verifier::verify(&hc1, &store, &reg, now, &options_in(options)))
    }
    fn verify_cose(cose: Vec<u8>, store: TrustStoreBorrow<'_>, reg: RegistryBorrow<'_>, now: i64, options: WOptions) -> WResult {
        let store = store.get::<TrustStore>().0.borrow();
        let reg = reg.get::<Registry>().0.borrow();
        result_out(crate::verifier::verify_cose(&cose, &store, &reg, now, &options_in(options)))
    }
    fn read_unverified(hc1: String, reg: RegistryBorrow<'_>, l: WLimits) -> Result<WUnverified, WFailure> {
        let reg = reg.get::<Registry>().0.borrow();
        crate::verifier::read_unverified(&hc1, &reg, &limits(l))
            .map(|u| WUnverified {
                kid: u.kid.map(|k| k.to_vec()),
                iss: u.iss,
                iat: u.iat,
                exp: u.exp,
                entries: u.entries.into_iter().map(|e| WUnverifiedEntry { subclaim: s32(e.subclaim), payload: e.payload.map(payload_out) }).collect(),
                diagnostics: u.diagnostics.into_iter().map(diag).collect(),
            })
            .map_err(failure_out)
    }
}

impl w::issuer::Guest for Component {
    type PendingSignature = Pending;

    fn prepare(req: WIssueRequest, reg: RegistryBorrow<'_>) -> Result<WPending, WIssueError> {
        let reg = reg.get::<Registry>().0.borrow();
        let r = crate::issuer::IssueRequest {
            payloads: req.payloads.into_iter().map(payload_in).collect(),
            iss: req.iss,
            iat: req.validity.iat,
            exp: req.validity.exp,
            alg: alg_in(req.alg),
            dsc_der: req.dsc_der,
            allow_development_subclaims: req.allow_development_subclaims,
        };
        crate::issuer::prepare(&r, &reg).map(|p| WPending::new(Pending(p))).map_err(issue_error)
    }
    fn finish(pending: WPending, signature: Vec<u8>) -> Result<WIssued, WIssueError> {
        let p = pending.get::<Pending>();
        crate::issuer::finish(&p.0, &signature).map(|i| WIssued { hc1: i.hc1, cose: i.cose }).map_err(issue_error)
    }
}
