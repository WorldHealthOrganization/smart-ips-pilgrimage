//! The C ABI the browser loads: memory in, JSON out, no imports. A caller
//! allocates with `hcert_alloc`, writes a UTF-8 JSON request, calls
//! `hcert_call`, reads the result at the packed (pointer << 32 | length)
//! and frees both with `hcert_free`.

#[no_mangle]
pub extern "C" fn hcert_alloc(len: usize) -> *mut u8 {
    let mut v = Vec::<u8>::with_capacity(len.max(1));
    let p = v.as_mut_ptr();
    std::mem::forget(v);
    p
}

/// # Safety
/// `ptr` and `len` must come from `hcert_alloc` or `hcert_call`.
#[no_mangle]
pub unsafe extern "C" fn hcert_free(ptr: *mut u8, len: usize) {
    drop(Vec::from_raw_parts(ptr, 0, len.max(1)));
}

/// # Safety
/// `ptr` must point at `len` bytes the caller wrote.
#[no_mangle]
pub unsafe extern "C" fn hcert_call(ptr: *const u8, len: usize) -> u64 {
    let request = std::str::from_utf8(std::slice::from_raw_parts(ptr, len)).unwrap_or("");
    let out = crate::api::call(request).into_bytes().into_boxed_slice();
    let n = out.len();
    let p = Box::into_raw(out) as *mut u8;
    ((p as u64) << 32) | n as u64
}
