//! RFC 9285 Base45. Decoding is strict (STT-B45-001, STT-B45-002).

pub const ALPHABET: &[u8; 45] = b"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";

pub fn encode(data: &[u8]) -> String {
    let mut out = String::with_capacity(data.len().div_ceil(2) * 3);
    for chunk in data.chunks(2) {
        let (mut n, digits) = match chunk {
            [a, b] => ((*a as u32) << 8 | *b as u32, 3),
            [a] => (*a as u32, 2),
            _ => unreachable!(),
        };
        for _ in 0..digits {
            out.push(ALPHABET[(n % 45) as usize] as char);
            n /= 45;
        }
    }
    out
}

fn value(c: u8) -> Option<u32> {
    ALPHABET.iter().position(|&a| a == c).map(|p| p as u32)
}

/// Fails on a character outside the alphabet, a dangling character or an overflow.
pub fn decode(text: &str) -> Result<Vec<u8>, String> {
    let bytes = text.as_bytes();
    if bytes.len() % 3 == 1 {
        return Err("dangling character at the end".into());
    }
    let mut out = Vec::with_capacity(bytes.len() / 3 * 2 + 1);
    for (ci, chunk) in bytes.chunks(3).enumerate() {
        let mut n = 0u32;
        let mut mul = 1u32;
        for (j, &c) in chunk.iter().enumerate() {
            let v = value(c).ok_or_else(|| format!("character at {} is not Base45", ci * 3 + j))?;
            n += v * mul;
            mul *= 45;
        }
        if chunk.len() == 3 {
            if n > 0xffff {
                return Err(format!("triple at {} overflows 16 bits", ci * 3));
            }
            out.push((n >> 8) as u8);
            out.push(n as u8);
        } else {
            if n > 0xff {
                return Err(format!("pair at {} overflows 8 bits", ci * 3));
            }
            out.push(n as u8);
        }
    }
    Ok(out)
}
