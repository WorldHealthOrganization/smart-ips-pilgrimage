//! TEST ONLY: a self-signed DSC around a public key a host generated, so a
//! demo can issue and verify with its own key pair. This module encodes
//! DER; the host signs the TBSCertificate with the private key it holds
//! (WebCrypto in a browser), so no private key ever enters the library. A
//! certificate made here is not a GDHCN DSC: it is signed by nobody but
//! itself and its subject is the test participant XX.

use crate::types::CoseAlgorithm;

fn tlv(tag: u8, content: &[u8]) -> Vec<u8> {
    let mut out = vec![tag];
    let n = content.len();
    if n < 0x80 {
        out.push(n as u8);
    } else if n < 0x100 {
        out.extend_from_slice(&[0x81, n as u8]);
    } else {
        out.extend_from_slice(&[0x82, (n >> 8) as u8, n as u8]);
    }
    out.extend_from_slice(content);
    out
}

fn seq(parts: &[&[u8]]) -> Vec<u8> {
    tlv(0x30, &parts.concat())
}

fn oid(dotted_der: &[u8]) -> Vec<u8> {
    tlv(0x06, dotted_der)
}

// ecdsa-with-SHA256, 1.2.840.10045.4.3.2
const OID_ECDSA_SHA256: &[u8] = &[0x2a, 0x86, 0x48, 0xce, 0x3d, 0x04, 0x03, 0x02];
// id-RSASSA-PSS, 1.2.840.113549.1.1.10
const OID_RSASSA_PSS: &[u8] = &[0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x0a];
// RSASSA-PSS-params: SHA-256, MGF1 with SHA-256, salt 32 (RFC 4055)
const PSS_SHA256_PARAMS: &[u8] = &[
    0x30, 0x34, 0xa0, 0x0f, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0xa1, 0x1c, 0x30, 0x1a, 0x06, 0x09,
    0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x08, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, 0xa2,
    0x03, 0x02, 0x01, 0x20,
];
const OID_COUNTRY: &[u8] = &[0x55, 0x04, 0x06];
const OID_COMMON_NAME: &[u8] = &[0x55, 0x04, 0x03];
const OID_EKU: &[u8] = &[0x55, 0x1d, 0x25];

/// HCERT A.2 extended key usages by name: test, vaccinations, recovery.
fn eku_oid(name: &str) -> Option<Vec<u8>> {
    let last = match name {
        "test" => 1,
        "vaccinations" => 2,
        "recovery" => 3,
        _ => return None,
    };
    // 1.3.6.1.4.1.1847.2021.1.<n>
    Some(vec![0x2b, 0x06, 0x01, 0x04, 0x01, 0x8e, 0x37, 0x8f, 0x65, 0x01, last])
}

fn algorithm_identifier(alg: CoseAlgorithm) -> Vec<u8> {
    match alg {
        CoseAlgorithm::Es256 => seq(&[&oid(OID_ECDSA_SHA256)]),
        CoseAlgorithm::Ps256 => seq(&[&oid(OID_RSASSA_PSS), PSS_SHA256_PARAMS]),
    }
}

/// Days since 1970-01-01 to (year, month, day), proleptic Gregorian.
fn civil(days: i64) -> (i64, u32, u32) {
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (yoe + era * 400 + i64::from(m <= 2), m, d)
}

/// UTCTime before 2050, GeneralizedTime from then on (RFC 5280 4.1.2.5).
fn time(unix: i64) -> Vec<u8> {
    let (y, mo, d) = civil(unix.div_euclid(86_400));
    let s = unix.rem_euclid(86_400);
    let (h, mi, se) = (s / 3600, s % 3600 / 60, s % 60);
    if (1950..2050).contains(&y) {
        tlv(0x17, format!("{:02}{mo:02}{d:02}{h:02}{mi:02}{se:02}Z", y % 100).as_bytes())
    } else {
        tlv(0x18, format!("{y:04}{mo:02}{d:02}{h:02}{mi:02}{se:02}Z").as_bytes())
    }
}

fn name(country: &str, common_name: &str) -> Vec<u8> {
    let rdn = |o: &[u8], tag: u8, v: &str| tlv(0x31, &seq(&[&oid(o), &tlv(tag, v.as_bytes())]));
    seq(&[&rdn(OID_COUNTRY, 0x13, country), &rdn(OID_COMMON_NAME, 0x0c, common_name)])
}

/// What the test DSC says about itself.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TestDscRequest {
    /// DER SubjectPublicKeyInfo of the key that will sign (WebCrypto's `spki` export).
    pub spki_der: Vec<u8>,
    pub alg: CoseAlgorithm,
    /// Two upper-case letters; XX is the test participant.
    pub country: String,
    pub common_name: String,
    pub not_before: i64,
    pub not_after: i64,
    pub serial: u64,
    /// HCERT A.2 EKUs by name (test, vaccinations, recovery); empty means none.
    pub extended_key_usages: Vec<String>,
}

/// The DER TBSCertificate to sign with the key the SPKI names.
pub fn tbs_certificate(req: &TestDscRequest) -> Result<Vec<u8>, String> {
    if !(req.country.len() == 2 && req.country.bytes().all(|c| c.is_ascii_uppercase())) {
        return Err("country must be two upper-case letters".into());
    }
    if req.not_after <= req.not_before {
        return Err("notAfter must be after notBefore".into());
    }
    let mut serial = req.serial.max(1).to_be_bytes().to_vec();
    while serial.len() > 1 && serial[0] == 0 && serial[1] & 0x80 == 0 {
        serial.remove(0);
    }
    if serial[0] & 0x80 != 0 {
        serial.insert(0, 0);
    }
    let subject = name(&req.country, &req.common_name);
    let mut parts: Vec<Vec<u8>> = vec![
        tlv(0xa0, &tlv(0x02, &[2])), // version v3
        tlv(0x02, &serial),
        algorithm_identifier(req.alg),
        subject.clone(), // issuer: self-signed
        seq(&[&time(req.not_before), &time(req.not_after)]),
        subject,
        req.spki_der.clone(),
    ];
    if !req.extended_key_usages.is_empty() {
        let mut usages = Vec::new();
        for n in &req.extended_key_usages {
            usages.extend(oid(&eku_oid(n).ok_or_else(|| format!("unknown extended key usage {n}"))?));
        }
        let eku = seq(&[&oid(OID_EKU), &tlv(0x04, &tlv(0x30, &usages))]);
        parts.push(tlv(0xa3, &seq(&[&eku])));
    }
    let refs: Vec<&[u8]> = parts.iter().map(Vec::as_slice).collect();
    Ok(seq(&refs))
}

/// The certificate: the TBS, the algorithm and the host's signature over
/// the TBS (ES256: 64-byte r||s or DER; PS256: the RSASSA-PSS signature).
pub fn certificate(tbs: &[u8], alg: CoseAlgorithm, signature: &[u8]) -> Result<Vec<u8>, String> {
    let sig = match alg {
        CoseAlgorithm::Es256 if signature.len() == 64 => ecdsa_raw_to_der(signature),
        _ => signature.to_vec(),
    };
    let mut bits = vec![0u8];
    bits.extend_from_slice(&sig);
    let cert = seq(&[tbs, &algorithm_identifier(alg), &tlv(0x03, &bits)]);
    crate::x509::certificate(&cert)?;
    if !crate::x509::verify(alg, &cert, tbs, &match alg {
        CoseAlgorithm::Es256 => crate::cose::ecdsa_der_to_raw(&sig).map_err(|e| e.to_string())?.to_vec(),
        CoseAlgorithm::Ps256 => sig.clone(),
    }) {
        return Err("the signature does not verify with the certificate's own key".into());
    }
    Ok(cert)
}

/// 64-byte r||s to ECDSA-Sig-Value DER.
pub fn ecdsa_raw_to_der(raw: &[u8]) -> Vec<u8> {
    let int = |b: &[u8]| {
        let start = b.iter().position(|&x| x != 0).unwrap_or(b.len() - 1);
        let mut v = b[start..].to_vec();
        if v[0] & 0x80 != 0 {
            v.insert(0, 0);
        }
        tlv(0x02, &v)
    };
    seq(&[&int(&raw[..32]), &int(&raw[32..64])])
}
