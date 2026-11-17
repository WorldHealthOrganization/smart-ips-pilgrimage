//! Types shared by every module, as api/wit/types.wit names them.

use std::fmt;

/// The first 8 bytes of the SHA-256 of the DSC's DER (STT-KID-001).
pub type Kid = [u8; 8];

/// Seconds since the Unix epoch (RFC 8392 NumericDate).
pub type NumericDate = i64;

/// The signature algorithms HCERT allows (STT-COS-002).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CoseAlgorithm {
    Es256,
    Ps256,
}

impl CoseAlgorithm {
    /// The COSE algorithm label (RFC 9053).
    pub fn label(self) -> i64 {
        match self {
            CoseAlgorithm::Es256 => -7,
            CoseAlgorithm::Ps256 => -37,
        }
    }

    pub fn from_label(label: i64) -> Option<Self> {
        match label {
            -7 => Some(CoseAlgorithm::Es256),
            -37 => Some(CoseAlgorithm::Ps256),
            _ => None,
        }
    }
}

/// Bounds for untrusted input (STT-CBR-003, STT-ZIP-002).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct DecodeLimits {
    pub max_input_chars: usize,
    pub max_inflated_bytes: usize,
    pub max_depth: usize,
    pub max_items: usize,
    pub max_string_bytes: usize,
}

/// An HC1 string in a version 40 QR symbol is at most 4296 characters.
pub const DEFAULT_LIMITS: DecodeLimits = DecodeLimits {
    max_input_chars: 8192,
    max_inflated_bytes: 65536,
    max_depth: 16,
    max_items: 4096,
    max_string_bytes: 16384,
};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Severity {
    Blocking,
    Warning,
    Information,
}

/// A problem with a payload, at a path inside it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ValidationIssue {
    pub path: String,
    pub code: String,
    pub message: String,
    pub severity: Severity,
}

/// Where in QR Code Generation section 11 a check is made (STT-VER-008).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Step {
    Prefix,
    Base45,
    Inflate,
    Cose,
    Header,
    TrustLookup,
    Signature,
    KeyUsage,
    Cwt,
    Time,
    Hcert,
    Payload,
}

/// Why verification stopped (STT-VER-008).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FailureReason {
    BadPrefix,
    UnsupportedContextVersion,
    Base45Invalid,
    InflateFailed,
    LimitExceeded,
    CoseMalformed,
    HeaderInvalid,
    UnsupportedAlgorithm,
    KidNotFound,
    SignatureInvalid,
    KeyUsageMismatch,
    Expired,
    NotYetValid,
    HcertMissing,
    MultipleSubclaims,
    PayloadInvalid,
}

/// The upper-case name both libraries and the shared vectors use.
pub trait WireName {
    fn wire_name(&self) -> &'static str;
}

impl WireName for Step {
    fn wire_name(&self) -> &'static str {
        match self {
            Step::Prefix => "PREFIX",
            Step::Base45 => "BASE45",
            Step::Inflate => "INFLATE",
            Step::Cose => "COSE",
            Step::Header => "HEADER",
            Step::TrustLookup => "TRUST_LOOKUP",
            Step::Signature => "SIGNATURE",
            Step::KeyUsage => "KEY_USAGE",
            Step::Cwt => "CWT",
            Step::Time => "TIME",
            Step::Hcert => "HCERT",
            Step::Payload => "PAYLOAD",
        }
    }
}

impl WireName for FailureReason {
    fn wire_name(&self) -> &'static str {
        match self {
            FailureReason::BadPrefix => "BAD_PREFIX",
            FailureReason::UnsupportedContextVersion => "UNSUPPORTED_CONTEXT_VERSION",
            FailureReason::Base45Invalid => "BASE45_INVALID",
            FailureReason::InflateFailed => "INFLATE_FAILED",
            FailureReason::LimitExceeded => "LIMIT_EXCEEDED",
            FailureReason::CoseMalformed => "COSE_MALFORMED",
            FailureReason::HeaderInvalid => "HEADER_INVALID",
            FailureReason::UnsupportedAlgorithm => "UNSUPPORTED_ALGORITHM",
            FailureReason::KidNotFound => "KID_NOT_FOUND",
            FailureReason::SignatureInvalid => "SIGNATURE_INVALID",
            FailureReason::KeyUsageMismatch => "KEY_USAGE_MISMATCH",
            FailureReason::Expired => "EXPIRED",
            FailureReason::NotYetValid => "NOT_YET_VALID",
            FailureReason::HcertMissing => "HCERT_MISSING",
            FailureReason::MultipleSubclaims => "MULTIPLE_SUBCLAIMS",
            FailureReason::PayloadInvalid => "PAYLOAD_INVALID",
        }
    }
}

/// Something worth telling the caller that did not stop verification.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Diagnostic {
    pub step: Step,
    pub severity: Severity,
    pub message: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CodecError {
    Base45Invalid(String),
    InflateFailed(String),
    LimitExceeded(String),
    CborMalformed(String),
    BadPrefix,
    UnsupportedContextVersion(String),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CoseError {
    Malformed(String),
    HeaderInvalid(String),
    UnsupportedAlgorithm(i64),
    BadSignatureFormat(String),
    SignatureInvalid,
    BadCertificate(String),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TrustError {
    Parse(String),
    UnknownTrustDomain(String),
    /// A DID document's proof does not verify, or the document is not one
    /// the proof profile models (STT-TRU-006).
    ProofInvalid(String),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum IssueError {
    PayloadInvalid(Vec<ValidationIssue>),
    /// The request carries no payload (STT-SEL-004).
    NoPayload,
    /// Two payloads map to the same subclaim (STT-SEL-004).
    DuplicateSubclaim(i64),
    DevelopmentSubclaimNotAllowed(i64),
    UnknownSubclaim(i64),
    ValidityOutsideDsc,
    BadCertificate(String),
    BadSignatureFormat(String),
}

impl fmt::Display for CodecError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CodecError::Base45Invalid(m) | CodecError::InflateFailed(m) | CodecError::LimitExceeded(m) | CodecError::CborMalformed(m) => f.write_str(m),
            CodecError::BadPrefix => f.write_str("no HC[1-9A-Z]: context identifier"),
            CodecError::UnsupportedContextVersion(v) => write!(f, "unsupported context identifier {v}"),
        }
    }
}

impl fmt::Display for CoseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CoseError::Malformed(m) | CoseError::HeaderInvalid(m) | CoseError::BadSignatureFormat(m) | CoseError::BadCertificate(m) => f.write_str(m),
            CoseError::UnsupportedAlgorithm(a) => write!(f, "unsupported alg {a}"),
            CoseError::SignatureInvalid => f.write_str("the signature does not verify"),
        }
    }
}

impl fmt::Display for TrustError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            TrustError::Parse(m) => f.write_str(m),
            TrustError::ProofInvalid(m) => write!(f, "DID document proof invalid: {m}"),
            TrustError::UnknownTrustDomain(d) => write!(f, "trust domain {d} is not in the loaded code system"),
        }
    }
}

impl fmt::Display for IssueError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            IssueError::PayloadInvalid(v) => write!(f, "payload invalid: {}", v.iter().map(|i| format!("{}: {}", i.path, i.message)).collect::<Vec<_>>().join("; ")),
            IssueError::NoPayload => f.write_str("the request carries no payload"),
            IssueError::DuplicateSubclaim(s) => write!(f, "two payloads have subclaim {s}"),
            IssueError::DevelopmentSubclaimNotAllowed(s) => write!(f, "subclaim {s} is in the development range and the issuer did not opt in"),
            IssueError::UnknownSubclaim(s) => write!(f, "subclaim {s} is not in the registry"),
            IssueError::ValidityOutsideDsc => f.write_str("iat and exp must fall inside the DSC's validity"),
            IssueError::BadCertificate(m) | IssueError::BadSignatureFormat(m) => f.write_str(m),
        }
    }
}

impl std::error::Error for CodecError {}
impl std::error::Error for CoseError {}
impl std::error::Error for TrustError {}
impl std::error::Error for IssueError {}

/// Lower-case hex, for messages and the JavaScript surface.
pub fn to_hex(b: &[u8]) -> String {
    b.iter().map(|x| format!("{x:02x}")).collect()
}

/// Inverse of [`to_hex`]; None on an odd length or a non-hex digit.
pub fn from_hex(s: &str) -> Option<Vec<u8>> {
    if s.len() % 2 != 0 {
        return None;
    }
    (0..s.len()).step_by(2).map(|i| u8::from_str_radix(s.get(i..i + 2)?, 16).ok()).collect()
}
