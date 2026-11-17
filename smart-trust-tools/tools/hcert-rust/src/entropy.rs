//! Secure random bytes: the operating system natively; in the WebAssembly
//! component, the host's wasi:random/random import; in the import-free
//! module, none (an error).

pub fn random_bytes(n: usize) -> Result<Vec<u8>, String> {
    let mut b = vec![0u8; n];
    getrandom::getrandom(&mut b).map_err(|e| format!("no secure random source: {e}"))?;
    Ok(b)
}
