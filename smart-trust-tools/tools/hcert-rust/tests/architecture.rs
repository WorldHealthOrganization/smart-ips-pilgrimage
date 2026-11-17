//! Architecture rules read from the library's own sources, as the Kotlin
//! suite's ArchitectureTest does: each test named after the requirements it verifies.

mod common;
use common::*;
use std::path::PathBuf;

fn sources() -> Vec<(String, String)> {
    let dir = repo_root().join("tools/hcert-rust/src");
    let mut files: Vec<PathBuf> = std::fs::read_dir(&dir).unwrap().map(|e| e.unwrap().path()).filter(|p| p.extension().is_some_and(|x| x == "rs")).collect();
    files.sort();
    assert!(files.len() > 10, "{dir:?}");
    files.into_iter().map(|p| (p.file_name().unwrap().to_string_lossy().into_owned(), std::fs::read_to_string(&p).unwrap())).collect()
}

/// Lines of the library's sources that contain any needle, outside comments.
fn offending(needles: &[&str]) -> Vec<String> {
    let mut found = Vec::new();
    for (name, text) in sources() {
        for (i, line) in text.lines().enumerate() {
            let code = line.split("//").next().unwrap();
            if needles.iter().any(|n| code.contains(n)) {
                found.push(format!("{name}:{}: {}", i + 1, line.trim()));
            }
        }
    }
    found
}

#[test]
fn stt_gen_012_stt_vhl_010_stt_ver_009_the_core_does_no_network_file_clock_or_asynchronous_io() {
    let found = offending(&["std::net", "std::fs", "std::io::", "std::env", "std::process", "SystemTime", "Instant::", "async fn", ".await", "tokio", "reqwest", "hyper"]);
    assert_eq!(found, Vec::<String>::new());
}

#[test]
fn stt_sec_001_the_core_writes_nothing_to_a_log_or_console() {
    let found = offending(&["println!", "eprintln!", "print!(", "eprint!(", "dbg!", "log::", "tracing::", "console_log", "web_sys::console"]);
    assert_eq!(found, Vec::<String>::new());
}

#[test]
fn stt_sec_002_cryptography_comes_from_rustcrypto_with_no_primitive_of_our_own() {
    // The runtime dependencies are the vetted RustCrypto crates and a few
    // non-cryptographic ones; any new one has to be added here on purpose.
    let manifest = read("tools/hcert-rust/Cargo.toml");
    let deps = manifest.split("[dependencies]").nth(1).unwrap().split("\n[").next().unwrap();
    let names: Vec<&str> = deps.lines().filter_map(|l| l.split_once(" = ").map(|(n, _)| n.trim())).filter(|n| !n.starts_with('#')).collect();
    let crypto = ["p256", "rsa", "sha2", "aes-gcm"];
    let other = ["x509-cert", "getrandom", "miniz_oxide", "unicode-normalization", "qrcode", "wit-bindgen"];
    for n in &names {
        assert!(crypto.contains(n) || other.contains(n), "unexpected runtime dependency {n}");
    }
    for c in crypto {
        assert!(names.contains(&c), "{c} is not a dependency");
    }
    // No hand-written primitive: no SHA-256 round constant, no AES S-box, no
    // GCM, modular or curve arithmetic in the sources. (x509::sha256 is a
    // one-line call into sha2.)
    let found = offending(&["0x428a2f98", "0x63, 0x7c, 0x77", "fn aes", "fn gcm", "fn ghash", "fn mod_pow", "fn modpow", "fn point_add", "fn scalar_mul", "struct BigUint"]);
    assert_eq!(found, Vec::<String>::new());
}

#[test]
fn stt_iss_003_no_private_key_and_no_test_key_is_in_the_librarys_sources() {
    let found = offending(&["PRIVATE KEY", "vectors/testkit", "include_bytes!", "include_str!"]);
    assert_eq!(found, Vec::<String>::new());
}

#[test]
fn stt_gen_010_the_component_exports_the_wit_contract() {
    let component = read("tools/hcert-rust/src/component.rs");
    assert!(component.contains("path: \"../../api/wit\""), "the component's bindings are not generated from api/wit");
    assert!(component.contains("world: \"hcert\""));
    assert!(read("api/wit/worlds.wit").contains("world hcert"));
}
