//! What the library reads from a DSC: validity, country, extended key
//! usages and the public key, through RustCrypto's x509-cert (STT-SEC-002).

use crate::types::CoseAlgorithm;
use p256::ecdsa::signature::Verifier;
use x509_cert::der::{Decode, Encode};
use x509_cert::Certificate;

pub(crate) struct CertificateInfo {
    pub not_before: i64,
    pub not_after: i64,
    pub country: Option<String>,
    pub extended_key_usages: Vec<String>,
}

const OID_COUNTRY: &str = "2.5.4.6";
const OID_EKU: &str = "2.5.29.37";

pub(crate) fn certificate(der: &[u8]) -> Result<CertificateInfo, String> {
    let c = Certificate::from_der(der).map_err(|e| format!("not an X.509 certificate: {e}"))?;
    let tbs = &c.tbs_certificate;
    let secs = |t: &x509_cert::time::Time| t.to_unix_duration().as_secs() as i64;
    let mut country = None;
    for rdn in tbs.subject.0.iter() {
        for atv in rdn.0.iter() {
            if atv.oid.to_string() == OID_COUNTRY {
                country = std::str::from_utf8(atv.value.value()).ok().map(str::to_owned);
            }
        }
    }
    let mut ekus = Vec::new();
    for ext in tbs.extensions.iter().flatten() {
        if ext.extn_id.to_string() == OID_EKU {
            let list = x509_cert::ext::pkix::ExtendedKeyUsage::from_der(ext.extn_value.as_bytes())
                .map_err(|e| format!("bad extended key usage: {e}"))?;
            ekus.extend(list.0.iter().map(|o| o.to_string()));
        }
    }
    Ok(CertificateInfo {
        not_before: secs(&tbs.validity.not_before),
        not_after: secs(&tbs.validity.not_after),
        country,
        extended_key_usages: ekus,
    })
}

/// The DER SubjectPublicKeyInfo of the DSC.
pub(crate) fn spki(der: &[u8]) -> Result<Vec<u8>, String> {
    let c = Certificate::from_der(der).map_err(|e| format!("not an X.509 certificate: {e}"))?;
    c.tbs_certificate.subject_public_key_info.to_der().map_err(|e| e.to_string())
}

/// Verifies `signature` over `data` with the DSC's key: ES256 takes the
/// 64-byte r||s; PS256 is RSASSA-PSS with SHA-256, MGF1-SHA-256 and a
/// 32-byte salt (RFC 8230).
pub(crate) fn verify(alg: CoseAlgorithm, dsc_der: &[u8], data: &[u8], signature: &[u8]) -> bool {
    let Ok(spki) = spki(dsc_der) else { return false };
    match alg {
        CoseAlgorithm::Es256 => {
            use p256::pkcs8::DecodePublicKey;
            let (Ok(key), Ok(sig)) = (p256::ecdsa::VerifyingKey::from_public_key_der(&spki), p256::ecdsa::Signature::from_slice(signature)) else {
                return false;
            };
            key.verify(data, &sig).is_ok()
        }
        CoseAlgorithm::Ps256 => {
            use rsa::pkcs8::DecodePublicKey;
            let Ok(key) = rsa::RsaPublicKey::from_public_key_der(&spki) else { return false };
            let Ok(sig) = rsa::pss::Signature::try_from(signature) else { return false };
            rsa::pss::VerifyingKey::<sha2::Sha256>::new(key).verify(data, &sig).is_ok()
        }
    }
}

pub(crate) fn sha256(data: &[u8]) -> [u8; 32] {
    use sha2::Digest;
    sha2::Sha256::digest(data).into()
}
