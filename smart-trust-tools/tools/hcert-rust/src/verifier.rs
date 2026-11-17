//! QR Code Generation section 11, in the STT-VER-001 order. Every failure is
//! a value naming its step and reason; nothing about an unverified
//! certificate is returned (STT-VER-001 to STT-VER-008, STT-KID-002,
//! STT-SEL-004, STT-CWT-006).

use crate::cbor::{self, Item};
use crate::codec;
use crate::cose::{self, Sign1};
use crate::payload::{self, Payload, PayloadKind, Registry};
use crate::trust::{TrustStore, TrustedDsc};
use crate::types::*;

pub const CLAIM_ISS: i64 = 1;
pub const CLAIM_EXP: i64 = 4;
pub const CLAIM_IAT: i64 = 6;
pub const CLAIM_HCERT: i64 = -260;

/// EKU OIDs (HCERT A.2).
const EKU_TEST: &str = "1.3.6.1.4.1.1847.2021.1.1";
const EKU_VACCINATION: &str = "1.3.6.1.4.1.1847.2021.1.2";
const EKU_RECOVERY: &str = "1.3.6.1.4.1.1847.2021.1.3";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct VerifierOptions {
    pub limits: DecodeLimits,
    pub clock_skew_seconds: i64,
    /// Refuse an hcert claim with more entries than this: a deployment's
    /// strict profile. None accepts any number (STT-SEL-004).
    pub max_payloads: Option<u32>,
}

impl Default for VerifierOptions {
    fn default() -> Self {
        VerifierOptions { limits: DEFAULT_LIMITS, clock_skew_seconds: 300, max_payloads: None }
    }
}

/// One entry of the hcert claim (STT-SEL-004).
#[derive(Clone, Debug, PartialEq)]
pub struct HcertEntry {
    pub subclaim: i64,
    /// Raw CBOR for a subclaim the registry does not know.
    pub payload: Payload,
    /// False when the DSC's EKU does not permit this entry's certificate
    /// type; the entry is kept, marked, with a diagnostic (STT-VER-004).
    pub key_usage_authorised: bool,
}

/// One entry of an unverified hcert claim.
#[derive(Clone, Debug, PartialEq)]
pub struct UnverifiedEntry {
    pub subclaim: i64,
    pub payload: Option<Payload>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct VerifiedHcert {
    pub iss: Option<String>,
    pub iat: NumericDate,
    pub exp: NumericDate,
    /// The valid entries, in wire order. An entry whose payload fails its
    /// model check is left out with a diagnostic (STT-SEL-004).
    pub entries: Vec<HcertEntry>,
    pub dsc: TrustedDsc,
    /// Claims this version does not know, as encoded (key, value) (STT-CWT-006).
    pub other_claims: Vec<(Vec<u8>, Vec<u8>)>,
    pub diagnostics: Vec<Diagnostic>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct VerificationFailure {
    pub step: Step,
    pub reason: FailureReason,
    pub detail: String,
}

/// What a decoder may show without verifying anything (STT-VER-011). The
/// first diagnostic always says it is not verified.
#[derive(Clone, Debug, PartialEq)]
pub struct UnverifiedHcert {
    pub kid: Option<Kid>,
    pub iss: Option<String>,
    pub iat: Option<NumericDate>,
    pub exp: Option<NumericDate>,
    /// Every entry of the hcert claim, in wire order.
    pub entries: Vec<UnverifiedEntry>,
    pub diagnostics: Vec<Diagnostic>,
}

fn fail<T>(step: Step, reason: FailureReason, detail: impl Into<String>) -> Result<T, VerificationFailure> {
    Err(VerificationFailure { step, reason, detail: detail.into() })
}

/// Prefix, Base45 and inflate: HC1 text to COSE bytes.
pub fn front(hc1: &str, limits: &DecodeLimits) -> Result<Vec<u8>, VerificationFailure> {
    if hc1.len() > limits.max_input_chars {
        return fail(Step::Prefix, FailureReason::LimitExceeded, format!("input exceeds {} characters", limits.max_input_chars));
    }
    let (version, rest) = match codec::detect_context(hc1) {
        Ok(c) => c,
        Err(_) => return fail(Step::Prefix, FailureReason::BadPrefix, "no HC[1-9A-Z]: context identifier"),
    };
    if version != "1" {
        return fail(Step::Prefix, FailureReason::UnsupportedContextVersion, format!("context identifier HC{version}"));
    }
    let deflated = match codec::base45_decode(rest) {
        Ok(d) => d,
        Err(CodecError::Base45Invalid(m)) => return fail(Step::Base45, FailureReason::Base45Invalid, m),
        Err(e) => return fail(Step::Base45, FailureReason::Base45Invalid, e.to_string()),
    };
    match codec::zlib_inflate(&deflated, limits.max_inflated_bytes) {
        Ok(c) => Ok(c),
        Err(CodecError::LimitExceeded(m)) => fail(Step::Inflate, FailureReason::LimitExceeded, m),
        Err(e) => fail(Step::Inflate, FailureReason::InflateFailed, e.to_string()),
    }
}

pub fn verify(hc1: &str, store: &TrustStore, reg: &Registry, now: NumericDate, options: &VerifierOptions) -> Result<VerifiedHcert, VerificationFailure> {
    run(&front(hc1, &options.limits)?, store, reg, now, options)
}

/// For raw COSE_Sign1 bytes, without the QR layers (STT-GEN-009).
pub fn verify_cose(cose: &[u8], store: &TrustStore, reg: &Registry, now: NumericDate, options: &VerifierOptions) -> Result<VerifiedHcert, VerificationFailure> {
    run(cose, store, reg, now, options)
}

fn parse(cose_bytes: &[u8], limits: &DecodeLimits) -> Result<Sign1, VerificationFailure> {
    cose::parse_sign1(cose_bytes, limits).or_else(|e| match e {
        CoseError::HeaderInvalid(m) => fail(Step::Header, FailureReason::HeaderInvalid, m),
        CoseError::UnsupportedAlgorithm(a) => fail(Step::Header, FailureReason::UnsupportedAlgorithm, format!("alg {a}")),
        CoseError::Malformed(m) => {
            let limit = m.contains("exceeds") || m.contains("more than") || m.contains("deeper");
            fail(Step::Cose, if limit { FailureReason::LimitExceeded } else { FailureReason::CoseMalformed }, m)
        }
        other => fail(Step::Cose, FailureReason::CoseMalformed, other.to_string()),
    })
}

fn decode_claims(payload_bytes: &[u8], limits: &DecodeLimits) -> Result<Item, VerificationFailure> {
    match cbor::decode(payload_bytes, limits) {
        Ok(m @ Item::Map(_)) => Ok(m),
        Ok(_) => fail(Step::Cwt, FailureReason::CoseMalformed, "CWT claim set is not a map"),
        Err(e) => fail(Step::Cwt, if e.limit { FailureReason::LimitExceeded } else { FailureReason::CoseMalformed }, e.message),
    }
}

fn payload_of(subclaim: i64, body: &Item, reg: &Registry) -> Result<Payload, VerificationFailure> {
    if subclaim == reg.subclaim_for(PayloadKind::Vhl) {
        // A CBOR map, or the vhlink:/ string IHE ITI-YY3 describes (STT-VHL-002).
        let p = crate::vhl::from_item(body).or_else(|e| fail(Step::Payload, FailureReason::PayloadInvalid, format!("VHL payload: {e}")))?;
        if let Some(i) = crate::vhl::validate(&p, None).into_iter().find(|i| i.severity == Severity::Blocking) {
            return fail(Step::Payload, FailureReason::PayloadInvalid, format!("{}: {}", i.path, i.message));
        }
        Ok(Payload::Vhl(p))
    } else if subclaim == reg.subclaim_for(PayloadKind::DvcMin) {
        let dvc = payload::from_item(body).or_else(|issues| {
            fail(Step::Payload, FailureReason::PayloadInvalid, issues.iter().map(|i| format!("{}: {}", i.path, i.message)).collect::<Vec<_>>().join("; "))
        })?;
        if let Some(i) = payload::validate(&dvc).into_iter().find(|i| i.severity == Severity::Blocking) {
            return fail(Step::Payload, FailureReason::PayloadInvalid, format!("{}: {}", i.path, i.message));
        }
        Ok(Payload::DvcMin(dvc))
    } else {
        let cbor = cbor::encode(body).or_else(|e| fail(Step::Payload, FailureReason::PayloadInvalid, e.message))?;
        Ok(Payload::Raw { subclaim, cbor })
    }
}

/// The EKU a certificate type needs. DVC (under whichever subclaim the
/// registry gives it, STT-SEL-003) and DDCC VS (3) are vaccinations, DDCC TR
/// (4) a test; a DCC (1) says which by carrying a v, t or r entry (STT-VER-004).
fn eku_for(subclaim: i64, body: &Item, reg: &Registry) -> Option<&'static str> {
    if subclaim == reg.subclaim_for(PayloadKind::DvcMin) {
        return Some(EKU_VACCINATION);
    }
    match subclaim {
        3 => Some(EKU_VACCINATION),
        4 => Some(EKU_TEST),
        1 => {
            let found: Vec<_> = [("v", EKU_VACCINATION), ("t", EKU_TEST), ("r", EKU_RECOVERY)].into_iter().filter(|(k, _)| body.get_text(k).is_some()).map(|(_, e)| e).collect();
            (found.len() == 1).then(|| found[0])
        }
        _ => None,
    }
}

fn run(cose_bytes: &[u8], store: &TrustStore, reg: &Registry, now: NumericDate, options: &VerifierOptions) -> Result<VerifiedHcert, VerificationFailure> {
    let limits = &options.limits;
    let mut diagnostics = Vec::new();
    let warn = |d: &mut Vec<Diagnostic>, step, m: &str| d.push(Diagnostic { step, severity: Severity::Warning, message: m.into() });

    // COSE parse and header validation (STT-VER-003)
    let s = parse(cose_bytes, limits)?;
    if !s.tagged {
        warn(&mut diagnostics, Step::Cose, "COSE_Sign1 is not tagged 18");
    }
    let Some(kid) = s.kid else { return fail(Step::Header, FailureReason::HeaderInvalid, "no kid") };
    if !s.kid_in_protected {
        warn(&mut diagnostics, Step::Header, "kid is in the unprotected header");
    }

    // Trust lookup, then every candidate until one verifies (STT-KID-002)
    let candidates = store.candidates(&kid);
    if candidates.is_empty() {
        return fail(Step::TrustLookup, FailureReason::KidNotFound, format!("no trusted DSC has kid {}", to_hex(&kid)));
    }
    let Some(dsc) = candidates.into_iter().find(|d| cose::verify_sign1(&s, &d.der).is_ok()) else {
        return fail(Step::Signature, FailureReason::SignatureInvalid, format!("no DSC with kid {} verifies the signature", to_hex(&kid)));
    };
    if now < dsc.not_before || now > dsc.not_after {
        warn(&mut diagnostics, Step::TrustLookup, "the DSC is outside its X.509 validity period");
    }

    // CWT, decoded only now that the signature has verified.
    let claims = decode_claims(&s.payload, limits)?;
    let entries: &[(Item, Item)] = claims.get_int(CLAIM_HCERT).and_then(Item::entries).unwrap_or_default();

    // EKU against each entry's certificate type (STT-VER-004). Only when no
    // entry is authorised does it stop verification; otherwise the others
    // are marked.
    let dsc_ekus: Vec<&String> = dsc.extended_key_usages.iter().filter(|e| [EKU_TEST, EKU_VACCINATION, EKU_RECOVERY].contains(&e.as_str())).collect();
    let authorised: Vec<bool> = entries
        .iter()
        .map(|(k, body)| {
            let Some(sc) = k.as_int() else { return true };
            if dsc_ekus.is_empty() {
                return true;
            }
            match eku_for(sc, body, reg) {
                None => {
                    warn(&mut diagnostics, Step::KeyUsage, &format!("no certificate type is known for subclaim {sc}"));
                    true
                }
                Some(needed) => dsc_ekus.iter().any(|e| e.as_str() == needed),
            }
        })
        .collect();
    if !authorised.is_empty() && !authorised.contains(&true) {
        return fail(Step::KeyUsage, FailureReason::KeyUsageMismatch, "the DSC's extended key usage does not allow this certificate type");
    }

    // CWT claims and time (STT-CWT-002, STT-CWT-003, STT-VER-005)
    let int = |key: i64, name: &str| -> Result<Option<i64>, VerificationFailure> {
        match claims.get_int(key) {
            None => Ok(None),
            Some(Item::Int(v)) => Ok(Some(*v)),
            Some(_) => fail(Step::Cwt, FailureReason::CoseMalformed, format!("{name} is not an integer NumericDate")),
        }
    };
    let Some(exp) = int(CLAIM_EXP, "exp")? else { return fail(Step::Cwt, FailureReason::CoseMalformed, "exp is missing") };
    let Some(iat) = int(CLAIM_IAT, "iat")? else { return fail(Step::Cwt, FailureReason::CoseMalformed, "iat is missing") };
    let iss = match claims.get_int(CLAIM_ISS) {
        None => None,
        Some(Item::Text(t)) => Some(t.clone()),
        Some(_) => return fail(Step::Cwt, FailureReason::CoseMalformed, "iss is not a text string"),
    };
    let skew = options.clock_skew_seconds;
    if now - skew > exp {
        return fail(Step::Time, FailureReason::Expired, "exp has passed");
    }
    if iat > now + skew {
        return fail(Step::Time, FailureReason::NotYetValid, "iat is in the future");
    }

    // Subclaim dispatch (STT-SEL-004, STT-VER-007): every entry, each on its own.
    if entries.is_empty() {
        return fail(Step::Hcert, FailureReason::HcertMissing, "no hcert (-260) entry");
    }
    if options.max_payloads.is_some_and(|m| entries.len() > m as usize) {
        return fail(Step::Hcert, FailureReason::MultipleSubclaims, format!("hcert has {} entries", entries.len()));
    }
    let mut keyed = Vec::with_capacity(entries.len());
    for (k, body) in entries {
        let Some(subclaim) = k.as_int() else { return fail(Step::Hcert, FailureReason::HcertMissing, "hcert key is not an integer") };
        keyed.push((subclaim, body));
    }
    let mut valid = Vec::new();
    let mut first_failure = None;
    for ((subclaim, body), key_usage_authorised) in keyed.into_iter().zip(authorised) {
        if reg.lookup(subclaim).is_none() {
            warn(&mut diagnostics, Step::Hcert, &format!("subclaim {subclaim} is not in the registry"));
        }
        let checked = payload_of(subclaim, body, reg).and_then(|payload| match &payload {
            // The link's own exp, besides the HCERT's (STT-VHL-009).
            Payload::Vhl(v) if v.exp.is_some_and(|e| now - skew > e) => fail(Step::Time, FailureReason::Expired, "the VHL payload's exp has passed"),
            _ => Ok(payload),
        });
        match checked {
            Ok(payload) => {
                if !key_usage_authorised {
                    warn(&mut diagnostics, Step::KeyUsage, &format!("the DSC's extended key usage does not allow subclaim {subclaim}'s certificate type"));
                }
                valid.push(HcertEntry { subclaim, payload, key_usage_authorised });
            }
            Err(f) => {
                warn(&mut diagnostics, f.step, &format!("subclaim {subclaim}: {}", f.detail));
                first_failure.get_or_insert(f);
            }
        }
    }
    // With no entry left, the first entry's own failure stands, as it does for one payload.
    if valid.is_empty() {
        return Err(first_failure.expect("an entry failed"));
    }

    // Claims this version does not know are kept (STT-CWT-006).
    let known = [CLAIM_ISS, CLAIM_EXP, CLAIM_IAT, CLAIM_HCERT];
    let other_claims = claims
        .entries()
        .unwrap_or_default()
        .iter()
        .filter(|(k, _)| !k.as_int().is_some_and(|i| known.contains(&i)))
        .filter_map(|(k, v)| Some((cbor::encode(k).ok()?, cbor::encode(v).ok()?)))
        .collect();

    Ok(VerifiedHcert { iss, iat, exp, entries: valid, dsc: dsc.clone(), other_claims, diagnostics })
}

/// Decodes without checking anything; the first diagnostic says so (STT-VER-011).
pub fn read_unverified(hc1: &str, reg: &Registry, limits: &DecodeLimits) -> Result<UnverifiedHcert, VerificationFailure> {
    let cose_bytes = front(hc1, limits)?;
    let mut diagnostics = vec![Diagnostic { step: Step::Signature, severity: Severity::Warning, message: "NOT VERIFIED: no trust lookup and no signature check were made".into() }];
    let s = parse(&cose_bytes, limits)?;
    let claims = decode_claims(&s.payload, limits)?;
    let iss = claims.get_int(CLAIM_ISS).and_then(Item::as_text).map(str::to_owned);
    let iat = claims.get_int(CLAIM_IAT).and_then(Item::as_int);
    let exp = claims.get_int(CLAIM_EXP).and_then(Item::as_int);
    let entries = claims.get_int(CLAIM_HCERT).and_then(Item::entries).unwrap_or_default();
    if entries.is_empty() {
        diagnostics.push(Diagnostic { step: Step::Hcert, severity: Severity::Warning, message: "no hcert entry".into() });
    }
    let entries = entries
        .iter()
        .filter_map(|(k, body)| {
            let subclaim = k.as_int()?;
            let payload = match payload_of(subclaim, body, reg) {
                Ok(p) => Some(p),
                Err(f) => {
                    diagnostics.push(Diagnostic { step: f.step, severity: Severity::Warning, message: format!("subclaim {subclaim}: {}", f.detail) });
                    None
                }
            };
            Some(UnverifiedEntry { subclaim, payload })
        })
        .collect();
    Ok(UnverifiedHcert { kid: s.kid, iss, iat, exp, entries, diagnostics })
}
