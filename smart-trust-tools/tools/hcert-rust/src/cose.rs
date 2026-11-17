//! QR Code Generation step 5: COSE_Sign1 (RFC 9052) and the kid
//! (STT-COS-001 to STT-COS-005, STT-KID-001, STT-KID-003, STT-VER-003).

use crate::cbor::{self, Item};
use crate::types::{CoseAlgorithm, CoseError, DecodeLimits, Kid};

pub const COSE_SIGN1_TAG: u64 = 18;

/// A parsed COSE_Sign1. `alg` and `kid` are read from the headers.
#[derive(Clone, Debug, PartialEq)]
pub struct Sign1 {
    pub protected: Vec<u8>,
    pub payload: Vec<u8>,
    pub signature: Vec<u8>,
    pub alg: CoseAlgorithm,
    pub kid: Option<Kid>,
    pub kid_in_protected: bool,
    pub tagged: bool,
}

/// The first 8 bytes of SHA-256 over the DSC's DER (STT-KID-001).
pub fn kid_from_dsc(dsc_der: &[u8]) -> Kid {
    let h = crate::x509::sha256(dsc_der);
    let mut k = [0u8; 8];
    k.copy_from_slice(&h[..8]);
    k
}

pub fn parse_sign1(bytes: &[u8], limits: &DecodeLimits) -> Result<Sign1, CoseError> {
    let item = cbor::decode(bytes, limits).map_err(|e| CoseError::Malformed(e.message))?;
    let (tagged, inner) = match item {
        Item::Tag(COSE_SIGN1_TAG, i) => (true, *i),
        Item::Tag(t, _) => return Err(CoseError::Malformed(format!("tag {t} is not COSE_Sign1 (18)"))),
        other => (false, other),
    };
    let Item::Array(arr) = inner else { return Err(CoseError::Malformed("COSE_Sign1 is not an array".into())) };
    if arr.len() != 4 {
        return Err(CoseError::Malformed(format!("COSE_Sign1 has {} elements, not 4", arr.len())));
    }
    let bytes_at = |i: usize, what: &str| arr[i].as_bytes().map(<[u8]>::to_vec).ok_or_else(|| CoseError::Malformed(format!("{what} is not a byte string")));
    let protected = bytes_at(0, "protected header")?;
    let Item::Map(unprotected) = &arr[1] else { return Err(CoseError::Malformed("unprotected header is not a map".into())) };
    let payload = bytes_at(2, "payload")?;
    let signature = bytes_at(3, "signature")?;

    let ph = if protected.is_empty() {
        Vec::new()
    } else {
        match cbor::decode(&protected, limits) {
            Ok(Item::Map(m)) => m,
            Ok(_) => return Err(CoseError::HeaderInvalid("protected header is not a map".into())),
            Err(e) => return Err(CoseError::HeaderInvalid(e.message)),
        }
    };
    for h in [&ph, unprotected] {
        for (i, (k, _)) in h.iter().enumerate() {
            if h[..i].iter().any(|(k2, _)| k2 == k) {
                return Err(CoseError::HeaderInvalid("duplicate header label".into()));
            }
        }
    }
    let find = |h: &[(Item, Item)], label: i64| h.iter().find(|(k, _)| *k == Item::Int(label)).map(|(_, v)| v.clone());
    if find(unprotected, 1).is_some() {
        return Err(CoseError::HeaderInvalid("alg must be in the protected header".into()));
    }
    let alg_label = match find(&ph, 1) {
        None => return Err(CoseError::HeaderInvalid("no alg in the protected header".into())),
        Some(Item::Int(l)) => l,
        Some(_) => return Err(CoseError::HeaderInvalid("alg is not an integer".into())),
    };
    let alg = CoseAlgorithm::from_label(alg_label).ok_or(CoseError::UnsupportedAlgorithm(alg_label))?;
    let kid_of = |h: &[(Item, Item)]| -> Result<Option<Kid>, CoseError> {
        match find(h, 4) {
            None => Ok(None),
            Some(Item::Bytes(b)) => b.as_slice().try_into().map(Some).map_err(|_| CoseError::HeaderInvalid(format!("kid is {} bytes, not 8", b.len()))),
            Some(_) => Err(CoseError::HeaderInvalid("kid is not a byte string".into())),
        }
    };
    let pk = kid_of(&ph)?;
    let uk = kid_of(unprotected)?;
    Ok(Sign1 { protected, payload, signature, alg, kid: pk.or(uk), kid_in_protected: pk.is_some(), tagged })
}

/// The bytes a COSE_Sign1 signature covers: the Sig_structure
/// `["Signature1", protected, h'', payload]` (STT-COS-004).
pub fn sig_structure(protected: &[u8], payload: &[u8]) -> Vec<u8> {
    cbor::encode(&Item::Array(vec![
        Item::Text("Signature1".into()),
        Item::Bytes(protected.to_vec()),
        Item::Bytes(Vec::new()),
        Item::Bytes(payload.to_vec()),
    ]))
    .expect("an array has no map keys")
}

/// The tagged COSE_Sign1 with an empty unprotected header.
pub fn assemble_sign1(protected: &[u8], payload: &[u8], signature: &[u8]) -> Vec<u8> {
    cbor::encode(&Item::Tag(
        COSE_SIGN1_TAG,
        Box::new(Item::Array(vec![Item::Bytes(protected.to_vec()), Item::Map(Vec::new()), Item::Bytes(payload.to_vec()), Item::Bytes(signature.to_vec())])),
    ))
    .expect("an empty map has no duplicate keys")
}

pub fn verify_sign1(s: &Sign1, dsc_der: &[u8]) -> Result<(), CoseError> {
    if s.alg == CoseAlgorithm::Es256 && s.signature.len() != 64 {
        return Err(CoseError::BadSignatureFormat(format!("ES256 signature is {} bytes, not 64", s.signature.len())));
    }
    crate::x509::certificate(dsc_der).map_err(CoseError::BadCertificate)?;
    if crate::x509::verify(s.alg, dsc_der, &sig_structure(&s.protected, &s.payload), &s.signature) {
        Ok(())
    } else {
        Err(CoseError::SignatureInvalid)
    }
}

/// ECDSA-Sig-Value (RFC 3279) DER to the 64-byte r||s COSE uses (STT-COS-005).
pub fn ecdsa_der_to_raw(der: &[u8]) -> Result<[u8; 64], CoseError> {
    let bad = |m: &str| CoseError::BadSignatureFormat(m.into());
    let mut p = 0usize;
    let mut byte = || -> Result<u8, CoseError> {
        let b = *der.get(p).ok_or_else(|| bad("truncated DER"))?;
        p += 1;
        Ok(b)
    };
    if byte()? != 0x30 {
        return Err(bad("not a DER SEQUENCE"));
    }
    let seq_len = byte()? as usize;
    if seq_len >= 0x80 || seq_len != der.len() - 2 {
        return Err(bad("SEQUENCE length does not match"));
    }
    let mut out = [0u8; 64];
    let mut p = 2usize;
    for k in 0..2 {
        if der.get(p) != Some(&0x02) {
            return Err(bad("expected INTEGER"));
        }
        let l = *der.get(p + 1).ok_or_else(|| bad("truncated DER"))? as usize;
        p += 2;
        if l == 0 || l >= 0x80 || p + l > der.len() {
            return Err(bad("bad INTEGER length"));
        }
        let v = &der[p..p + l];
        p += l;
        if v[0] & 0x80 != 0 {
            return Err(bad("negative INTEGER"));
        }
        let start = v.iter().position(|&b| b != 0).unwrap_or(v.len());
        let v = &v[start..];
        if v.len() > 32 {
            return Err(bad("INTEGER wider than 32 bytes"));
        }
        out[k * 32 + 32 - v.len()..k * 32 + 32].copy_from_slice(v);
    }
    if p != der.len() {
        return Err(bad("trailing bytes after the signature"));
    }
    Ok(out)
}

/// Standard (RFC 4648 section 4) or URL-safe (section 5) base64, padded.
pub fn base64_encode(data: &[u8], url_safe: bool) -> String {
    let a: &[u8; 64] = if url_safe { b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_" } else { b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/" };
    let mut out = String::new();
    for c in data.chunks(3) {
        let n = (c[0] as u32) << 16 | (*c.get(1).unwrap_or(&0) as u32) << 8 | *c.get(2).unwrap_or(&0) as u32;
        for i in 0..4 {
            if i <= c.len() {
                out.push(a[(n >> (18 - 6 * i) & 63) as usize] as char);
            } else {
                out.push('=');
            }
        }
    }
    out
}

/// Either alphabet, padded or not; whitespace is not allowed.
pub fn base64_decode(text: &str) -> Result<Vec<u8>, String> {
    let t = text.trim_end_matches('=');
    let mut out = Vec::with_capacity(t.len() * 3 / 4);
    let mut acc = 0u32;
    let mut bits = 0;
    for c in t.bytes() {
        let v = match c {
            b'A'..=b'Z' => c - b'A',
            b'a'..=b'z' => c - b'a' + 26,
            b'0'..=b'9' => c - b'0' + 52,
            b'+' | b'-' => 62,
            b'/' | b'_' => 63,
            _ => return Err("not base64".into()),
        } as u32;
        acc = acc << 6 | v;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push((acc >> bits) as u8);
        }
    }
    if t.len() % 4 == 1 {
        return Err("not base64".into());
    }
    Ok(out)
}
