//! CBOR (RFC 8949): a bounded decoder and the core deterministic encoder.

use crate::types::DecodeLimits;
use unicode_normalization::UnicodeNormalization;

/// A decoded data item. Integers are held as i64; a value outside that
/// range is refused rather than silently truncated.
#[derive(Clone, Debug, PartialEq)]
pub enum Item {
    Int(i64),
    Bytes(Vec<u8>),
    Text(String),
    Array(Vec<Item>),
    /// Entries in wire order; [`Item::get`] looks a key up.
    Map(Vec<(Item, Item)>),
    Tag(u64, Box<Item>),
    Bool(bool),
    Null,
    Undefined,
    Simple(u8),
    Float(f64),
}

impl Item {
    pub fn get(&self, key: &Item) -> Option<&Item> {
        match self {
            Item::Map(e) => e.iter().find(|(k, _)| k == key).map(|(_, v)| v),
            _ => None,
        }
    }
    pub fn get_int(&self, key: i64) -> Option<&Item> {
        self.get(&Item::Int(key))
    }
    pub fn get_text(&self, key: &str) -> Option<&Item> {
        self.get(&Item::Text(key.into()))
    }
    pub fn as_text(&self) -> Option<&str> {
        match self {
            Item::Text(t) => Some(t),
            _ => None,
        }
    }
    pub fn as_bytes(&self) -> Option<&[u8]> {
        match self {
            Item::Bytes(b) => Some(b),
            _ => None,
        }
    }
    pub fn as_int(&self) -> Option<i64> {
        match self {
            Item::Int(i) => Some(*i),
            _ => None,
        }
    }
    pub fn entries(&self) -> Option<&[(Item, Item)]> {
        match self {
            Item::Map(e) => Some(e),
            _ => None,
        }
    }
}

/// A decode error; `limit` is true when a [`DecodeLimits`] bound was hit.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CborError {
    pub message: String,
    pub limit: bool,
}

fn err<T>(message: impl Into<String>) -> Result<T, CborError> {
    Err(CborError { message: message.into(), limit: false })
}

fn limit<T>(message: impl Into<String>) -> Result<T, CborError> {
    Err(CborError { message: message.into(), limit: true })
}

/// Every length is checked against the remaining input and the limits
/// before anything is allocated (STT-CBR-003).
pub fn decode(data: &[u8], limits: &DecodeLimits) -> Result<Item, CborError> {
    let mut d = Decoder { data, pos: 0, items: 0, limits };
    let item = d.read(0)?;
    if d.pos != data.len() {
        return err(format!("{} trailing byte(s) after the data item", data.len() - d.pos));
    }
    Ok(item)
}

struct Decoder<'a> {
    data: &'a [u8],
    pos: usize,
    items: usize,
    limits: &'a DecodeLimits,
}

impl Decoder<'_> {
    fn byte(&mut self) -> Result<u8, CborError> {
        let b = *self.data.get(self.pos).ok_or_else(|| CborError { message: "unexpected end of input".into(), limit: false })?;
        self.pos += 1;
        Ok(b)
    }

    fn argument(&mut self, info: u8) -> Result<u64, CborError> {
        let n = match info {
            0..=23 => return Ok(info as u64),
            24 => 1,
            25 => 2,
            26 => 4,
            27 => 8,
            _ => return err(format!("reserved additional information {info}")),
        };
        let mut v = 0u64;
        for _ in 0..n {
            v = v << 8 | self.byte()? as u64;
        }
        Ok(v)
    }

    fn int_argument(&mut self, info: u8) -> Result<i64, CborError> {
        let v = self.argument(info)?;
        if v > i64::MAX as u64 {
            return err("integer argument exceeds 2^63-1");
        }
        Ok(v as i64)
    }

    fn length(&self, n: u64, per_unit: u64) -> Result<usize, CborError> {
        let remaining = (self.data.len() - self.pos) as u64;
        if n.checked_mul(per_unit).is_none_or(|t| t > remaining) {
            return err(format!("length {n} exceeds the remaining input"));
        }
        Ok(n as usize)
    }

    fn bytes_of(&mut self, n: usize) -> Result<Vec<u8>, CborError> {
        if n > self.limits.max_string_bytes {
            return limit(format!("string of {n} bytes exceeds {}", self.limits.max_string_bytes));
        }
        let out = self.data[self.pos..self.pos + n].to_vec();
        self.pos += n;
        Ok(out)
    }

    fn chunks(&mut self, major: u8) -> Result<Vec<u8>, CborError> {
        let mut out = Vec::new();
        loop {
            match self.data.get(self.pos) {
                None => return err("unterminated indefinite-length string"),
                Some(0xff) => {
                    self.pos += 1;
                    return Ok(out);
                }
                Some(_) => {}
            }
            let ib = self.byte()?;
            if ib >> 5 != major || ib & 0x1f == 31 {
                return err("bad chunk in an indefinite-length string");
            }
            let n = self.argument(ib & 0x1f)?;
            let n = self.length(n, 1)?;
            let chunk = self.bytes_of(n)?;
            out.extend_from_slice(&chunk);
            if out.len() > self.limits.max_string_bytes {
                return limit(format!("string exceeds {} bytes", self.limits.max_string_bytes));
            }
        }
    }

    fn peek_break(&mut self) -> Result<bool, CborError> {
        match self.data.get(self.pos) {
            None => err("unterminated indefinite-length item"),
            Some(0xff) => {
                self.pos += 1;
                Ok(true)
            }
            Some(_) => Ok(false),
        }
    }

    fn string(&mut self, major: u8, info: u8) -> Result<Vec<u8>, CborError> {
        if info == 31 {
            self.chunks(major)
        } else {
            let n = self.argument(info)?;
            let n = self.length(n, 1)?;
            self.bytes_of(n)
        }
    }

    fn read(&mut self, depth: usize) -> Result<Item, CborError> {
        if depth > self.limits.max_depth {
            return limit(format!("nesting deeper than {}", self.limits.max_depth));
        }
        self.items += 1;
        if self.items > self.limits.max_items {
            return limit(format!("more than {} data items", self.limits.max_items));
        }
        let ib = self.byte()?;
        let (major, info) = (ib >> 5, ib & 0x1f);
        Ok(match major {
            0 => Item::Int(self.int_argument(info)?),
            1 => Item::Int(-1 - self.int_argument(info)?),
            2 => Item::Bytes(self.string(2, info)?),
            3 => match String::from_utf8(self.string(3, info)?) {
                Ok(s) => Item::Text(s),
                Err(_) => return err("text string is not valid UTF-8"),
            },
            4 => {
                let mut list = Vec::new();
                if info == 31 {
                    while !self.peek_break()? {
                        list.push(self.read(depth + 1)?);
                    }
                } else {
                    let n = self.argument(info)?;
                    let n = self.length(n, 1)?;
                    for _ in 0..n {
                        list.push(self.read(depth + 1)?);
                    }
                }
                Item::Array(list)
            }
            5 => {
                let mut list = Vec::new();
                if info == 31 {
                    while !self.peek_break()? {
                        let k = self.read(depth + 1)?;
                        list.push((k, self.read(depth + 1)?));
                    }
                } else {
                    let n = self.argument(info)?;
                    let n = self.length(n, 2)?;
                    for _ in 0..n {
                        let k = self.read(depth + 1)?;
                        list.push((k, self.read(depth + 1)?));
                    }
                }
                Item::Map(list)
            }
            6 => {
                let tag = self.argument(info)?;
                Item::Tag(tag, Box::new(self.read(depth + 1)?))
            }
            _ => match info {
                20 => Item::Bool(false),
                21 => Item::Bool(true),
                22 => Item::Null,
                23 => Item::Undefined,
                24 => {
                    let v = self.byte()?;
                    if v < 32 {
                        return err("non-canonical simple value");
                    }
                    Item::Simple(v)
                }
                25 => Item::Float(half_to_f64(self.argument(25)? as u16)),
                26 => Item::Float(f32::from_bits(self.argument(26)? as u32) as f64),
                27 => Item::Float(f64::from_bits(self.argument(27)?)),
                31 => return err("unexpected break"),
                0..=19 => Item::Simple(info),
                _ => return err(format!("reserved simple value {info}")),
            },
        })
    }
}

/// RFC 8949 section 4.2.1 core deterministic encoding: shortest arguments,
/// definite lengths, map keys sorted by their encoded bytes, floats in the
/// shortest form that keeps the value. Text is NFC-normalised
/// (STT-CBR-001, STT-CBR-002). Fails only on a duplicate map key.
pub fn encode(item: &Item) -> Result<Vec<u8>, CborError> {
    let mut out = Vec::new();
    write(&mut out, item)?;
    Ok(out)
}

fn head(out: &mut Vec<u8>, major: u8, n: u64) {
    let m = major << 5;
    if n < 24 {
        out.push(m | n as u8);
    } else if n < 0x100 {
        out.extend_from_slice(&[m | 24, n as u8]);
    } else if n < 0x10000 {
        out.push(m | 25);
        out.extend_from_slice(&(n as u16).to_be_bytes());
    } else if n < 0x1_0000_0000 {
        out.push(m | 26);
        out.extend_from_slice(&(n as u32).to_be_bytes());
    } else {
        out.push(m | 27);
        out.extend_from_slice(&n.to_be_bytes());
    }
}

fn write(out: &mut Vec<u8>, item: &Item) -> Result<(), CborError> {
    match item {
        Item::Int(v) if *v >= 0 => head(out, 0, *v as u64),
        Item::Int(v) => head(out, 1, (-1 - *v) as u64),
        Item::Bytes(b) => {
            head(out, 2, b.len() as u64);
            out.extend_from_slice(b);
        }
        Item::Text(t) => {
            let nfc: String = t.nfc().collect();
            head(out, 3, nfc.len() as u64);
            out.extend_from_slice(nfc.as_bytes());
        }
        Item::Array(items) => {
            head(out, 4, items.len() as u64);
            for i in items {
                write(out, i)?;
            }
        }
        Item::Map(entries) => {
            let mut encoded = Vec::with_capacity(entries.len());
            for (k, v) in entries {
                encoded.push((encode(k)?, v));
            }
            encoded.sort_by(|a, b| a.0.cmp(&b.0));
            if encoded.windows(2).any(|w| w[0].0 == w[1].0) {
                return err("duplicate map key");
            }
            head(out, 5, encoded.len() as u64);
            for (k, v) in encoded {
                out.extend_from_slice(&k);
                write(out, v)?;
            }
        }
        Item::Tag(t, i) => {
            head(out, 6, *t);
            write(out, i)?;
        }
        Item::Bool(b) => out.push(if *b { 0xf5 } else { 0xf4 }),
        Item::Null => out.push(0xf6),
        Item::Undefined => out.push(0xf7),
        Item::Simple(v) if *v < 24 => out.push(0xe0 | v),
        Item::Simple(v) => out.extend_from_slice(&[0xf8, *v]),
        Item::Float(d) => write_float(out, *d),
    }
    Ok(())
}

fn write_float(out: &mut Vec<u8>, d: f64) {
    let f = d as f32;
    let fits_f32 = f as f64 == d || d.is_nan();
    if let Some(h) = fits_f32.then(|| f64_to_half(d)).flatten() {
        out.push(0xf9);
        out.extend_from_slice(&h.to_be_bytes());
    } else if f as f64 == d {
        out.push(0xfa);
        out.extend_from_slice(&f.to_bits().to_be_bytes());
    } else {
        out.push(0xfb);
        out.extend_from_slice(&d.to_bits().to_be_bytes());
    }
}

fn half_to_f64(h: u16) -> f64 {
    let exp = (h >> 10) & 0x1f;
    let mant = (h & 0x3ff) as f64;
    let v = match exp {
        0 => mant * 2f64.powi(-24),
        31 if mant == 0.0 => f64::INFINITY,
        31 => f64::NAN,
        _ => (mant + 1024.0) * 2f64.powi(exp as i32 - 25),
    };
    if h & 0x8000 != 0 {
        -v
    } else {
        v
    }
}

/// The binary16 bits for `d` when it is exactly representable.
fn f64_to_half(d: f64) -> Option<u16> {
    if d.is_nan() {
        return Some(0x7e00);
    }
    let sign: u16 = if d.is_sign_negative() { 0x8000 } else { 0 };
    let a = d.abs();
    if a == 0.0 {
        return Some(sign);
    }
    if a.is_infinite() {
        return Some(sign | 0x7c00);
    }
    for exp in 1..=30i32 {
        let mant = a / 2f64.powi(exp - 25) - 1024.0;
        if (0.0..1024.0).contains(&mant) && mant == mant.floor() {
            return Some(sign | (exp as u16) << 10 | mant as u16);
        }
    }
    let sub = a / 2f64.powi(-24);
    if sub < 1024.0 && sub == sub.floor() {
        return Some(sign | sub as u16);
    }
    None
}

/// RFC 8949 section 8 diagnostic notation, for showing a data item to a
/// person. Long byte strings are shortened; this is not an encoding.
pub fn diagnostic(item: &Item) -> String {
    let mut out = String::new();
    diag(&mut out, item, 0);
    out
}

fn diag(out: &mut String, item: &Item, indent: usize) {
    let pad = |n: usize| "  ".repeat(n);
    match item {
        Item::Int(i) => out.push_str(&i.to_string()),
        Item::Bytes(b) if b.len() > 48 => out.push_str(&format!("h'{}…' ({} bytes)", crate::types::to_hex(&b[..24]), b.len())),
        Item::Bytes(b) => out.push_str(&format!("h'{}'", crate::types::to_hex(b))),
        Item::Text(t) => out.push_str(&crate::json::quote(t)),
        Item::Array(a) if a.is_empty() => out.push_str("[]"),
        Item::Array(a) => {
            out.push_str("[\n");
            for (i, x) in a.iter().enumerate() {
                out.push_str(&pad(indent + 1));
                diag(out, x, indent + 1);
                out.push_str(if i + 1 < a.len() { ",\n" } else { "\n" });
            }
            out.push_str(&pad(indent));
            out.push(']');
        }
        Item::Map(m) if m.is_empty() => out.push_str("{}"),
        Item::Map(m) => {
            out.push_str("{\n");
            for (i, (k, v)) in m.iter().enumerate() {
                out.push_str(&pad(indent + 1));
                diag(out, k, indent + 1);
                out.push_str(": ");
                diag(out, v, indent + 1);
                out.push_str(if i + 1 < m.len() { ",\n" } else { "\n" });
            }
            out.push_str(&pad(indent));
            out.push('}');
        }
        Item::Tag(t, i) => {
            out.push_str(&format!("{t}("));
            diag(out, i, indent);
            out.push(')');
        }
        Item::Bool(b) => out.push_str(if *b { "true" } else { "false" }),
        Item::Null => out.push_str("null"),
        Item::Undefined => out.push_str("undefined"),
        Item::Simple(v) => out.push_str(&format!("simple({v})")),
        Item::Float(f) => out.push_str(&format!("{f:?}")),
    }
}
