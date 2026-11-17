//! QR Code Generation steps 4, 6, 7 and 8: deterministic CBOR, ZLIB,
//! Base45 and the HC1 context identifier (STT-GEN-002).

use crate::cbor;
use crate::types::{CodecError, DecodeLimits};
use miniz_oxide::inflate::stream::{inflate, InflateState};
use miniz_oxide::{DataFormat, MZError, MZFlush, MZStatus};

pub fn base45_encode(data: &[u8]) -> String {
    crate::base45::encode(data)
}

pub fn base45_decode(text: &str) -> Result<Vec<u8>, CodecError> {
    crate::base45::decode(text).map_err(CodecError::Base45Invalid)
}

/// ZLIB (RFC 1950) at `level` 0 to 9; 9 is what HCERT issuers use (STT-ZIP-001).
pub fn zlib_compress(data: &[u8], level: u8) -> Vec<u8> {
    miniz_oxide::deflate::compress_to_vec_zlib(data, level.min(9))
}

/// Inflates one ZLIB stream, refusing more than `max_out` bytes of output
/// and any bytes after the stream (STT-ZIP-002).
pub fn zlib_inflate(data: &[u8], max_out: usize) -> Result<Vec<u8>, CodecError> {
    inflate_with(data, max_out, DataFormat::Zlib)
}

/// Raw DEFLATE (RFC 1951), as JWE "zip": "DEF" uses.
pub fn inflate_raw(data: &[u8], max_out: usize) -> Result<Vec<u8>, CodecError> {
    inflate_with(data, max_out, DataFormat::Raw)
}

fn inflate_with(data: &[u8], max_out: usize, format: DataFormat) -> Result<Vec<u8>, CodecError> {
    let mut state = InflateState::new_boxed(format);
    let mut out = Vec::new();
    let mut buf = [0u8; 4096];
    let mut input = data;
    loop {
        let r = inflate(&mut state, input, &mut buf, MZFlush::None);
        input = &input[r.bytes_consumed..];
        if out.len() + r.bytes_written > max_out {
            return Err(CodecError::LimitExceeded(format!("inflated data exceeds {max_out} bytes")));
        }
        out.extend_from_slice(&buf[..r.bytes_written]);
        match r.status {
            Ok(MZStatus::StreamEnd) => {
                if !input.is_empty() {
                    return Err(CodecError::InflateFailed(format!("{} byte(s) after the ZLIB stream", input.len())));
                }
                return Ok(out);
            }
            Ok(_) => {
                if r.bytes_consumed == 0 && r.bytes_written == 0 {
                    return Err(CodecError::InflateFailed("truncated ZLIB stream".into()));
                }
            }
            Err(MZError::Buf) if input.is_empty() => return Err(CodecError::InflateFailed("truncated ZLIB stream".into())),
            Err(MZError::Data) => return Err(CodecError::InflateFailed("the ZLIB stream is corrupt".into())),
            Err(MZError::Param) => return Err(CodecError::InflateFailed("not a ZLIB stream: the header is wrong".into())),
            Err(e) => return Err(CodecError::InflateFailed(format!("invalid ZLIB data ({e:?})"))),
        }
    }
}

/// Splits `HC<v>:<rest>` into the version and the rest (STT-HC1-001).
pub fn detect_context(text: &str) -> Result<(String, &str), CodecError> {
    let b = text.as_bytes();
    if b.len() >= 4 && &b[..2] == b"HC" && (b[2].is_ascii_digit() && b[2] != b'0' || b[2].is_ascii_uppercase()) && b[3] == b':' {
        Ok(((b[2] as char).to_string(), &text[4..]))
    } else {
        Err(CodecError::BadPrefix)
    }
}

/// COSE bytes to the HC1 string: deflate, Base45, prefix (steps 6 to 8).
pub fn to_hc1(cose: &[u8]) -> String {
    format!("HC1:{}", base45_encode(&zlib_compress(cose, 9)))
}

/// The HC1 string back to COSE bytes, within `limits` (STT-HC1-001).
pub fn from_hc1(text: &str, limits: &DecodeLimits) -> Result<Vec<u8>, CodecError> {
    if text.len() > limits.max_input_chars {
        return Err(CodecError::LimitExceeded(format!("input of {} characters exceeds {}", text.len(), limits.max_input_chars)));
    }
    let (version, rest) = detect_context(text)?;
    if version != "1" {
        return Err(CodecError::UnsupportedContextVersion(format!("HC{version}")));
    }
    zlib_inflate(&base45_decode(rest)?, limits.max_inflated_bytes)
}

/// Decodes `bytes` and re-encodes them deterministically (STT-CBR-001).
pub fn cbor_deterministic(bytes: &[u8], limits: &DecodeLimits) -> Result<Vec<u8>, CodecError> {
    let item = cbor::decode(bytes, limits).map_err(cbor_error)?;
    cbor::encode(&item).map_err(cbor_error)
}

pub(crate) fn cbor_error(e: cbor::CborError) -> CodecError {
    if e.limit {
        CodecError::LimitExceeded(e.message)
    } else {
        CodecError::CborMalformed(e.message)
    }
}
