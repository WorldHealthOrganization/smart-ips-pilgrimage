# hcert-rust dependencies

Every crate the library builds with, from `Cargo.lock`, checked by
`python3 tools/hcert-rust/dep_audit.py`. Each is a release at least 14 days
older than the cutoff (2026-10-08; the audit ran on 2026-10-22), pinned in
`Cargo.lock` with its checksum. CI builds with `--locked`, so nothing is
resolved at build time.

## Why these

- **Cryptography: RustCrypto `p256`, `rsa`, `sha2`.** STT-SEC-002 names these
  crates and forbids the library's own primitives. `x509-cert` (also RustCrypto)
  reads DSCs. Together they bring most of the tree below: `der`, `spki`,
  `pkcs1`, `pkcs8`, `elliptic-curve`, `crypto-bigint`, `num-bigint-dig` and
  their helpers.
- **DEFLATE: `miniz_oxide`.** Pure Rust, with `adler2` as its only dependency.
- **NFC: `unicode-normalization`.** STT-CBR-002 requires NFC normalisation
  of CBOR text. The Kotlin library takes it from the platform.
- **`getrandom` with `custom` on wasm32.** `rsa` and `p256` reach `rand_core`.
  Verification draws no randomness, and signing is the host's, so the
  WebAssembly build registers an entropy source that always fails. It does not
  import JavaScript (the `js` feature, through wasm-bindgen).
- **Live demos only: `qrcode` 0.14.1 (feature `qr`).** This renders the HC1
  string as an SVG QR symbol on the demo page. It sits behind a feature the
  library proper never enables, because the library leaves rendering to the
  host. The owner allowed one vetted, pinned QR encoder for the demos on
  2026-10-21. Why this one:
  - it is the most-used QR encoder on crates.io (23 million downloads);
  - it is MIT or Apache-2.0;
  - it is pure Rust, with no build script;
  - without default features it has no dependencies.

  A test checks it: the PR 129 string encodes as the version 16, level Q
  symbol the page states, which is only possible in Alphanumeric mode.
- **VHL: RustCrypto `aes-gcm` 0.10.3.** It does the JWE dir / A256GCM encryption
  of VHL documents (STT-VHL-007). Version 0.10 matches the `sha2` 0.10
  generation already in the tree; 0.11 would bring a second cipher stack.
  It adds `aead`, `aes`, `cipher`, `ctr`, `ghash`, `polyval`, `universal-hash`,
  `inout` and `opaque-debug`, all RustCrypto, none with a build script.
- **The WebAssembly component: `wit-bindgen` 0.62.0 (feature `component`).**
  Its `generate!` macro writes the Rust bindings for api/wit at build time,
  from the Bytecode Alliance's `wit-parser`, `wit-component`, `wasm-encoder`,
  `wasm-metadata` and `wasmparser`. The macro also uses `serde`,
  `serde_json`, `indexmap` and `syn` 3.
  - Only the component build compiles any of these, and they run only at
    compile time. Native builds and the demo module never see them.
  - **Prebuilt objects.** The `wit-bindgen` crate ships two tiny static
    libraries in `src/rt/`, compiled by its CI from the C files beside them:
    - `libwit_bindgen_cabi_realloc.a`
      (`056965a5ed15886088fab589b590227435d2fae945c2b9abcde35950421dd3fb`) is a
      weak `cabi_realloc` that forwards to the crate's Rust allocator;
    - `libwit_bindgen_cabi_wasip3.a`
      (`ca0e79cb4102bc4ae99c26d660d1c1b0b5c44a7afc5e34fa7d1d5840d8e8303b`) holds
      a task-context pointer.

    Its build script copies them into `OUT_DIR` and links them; they were read
    as source at this version. Of them, only `cabi_realloc` reaches the
    component's exports.
- **jco 1.35.0 (npm, already pinned in `toolchain/node`).** It turns the core
  module into a component (`jco new`) and transpiles it to an ES module
  (`jco transpile`). The component's one import, `wasi:random/random`, maps to
  `js/component/wasi-random.js`, a few lines over `crypto.getRandomValues`, so
  the transpiled module needs no npm package at run time.
- **CI only: the `llvm-tools` toolchain component.** `coverage.sh` measures
  coverage with rustc's own `-C instrument-coverage` and the `llvm-profdata` and
  `llvm-cov` that ship as a component of the pinned 1.97.0 toolchain
  (`rust-toolchain.toml`), which rustup installs and checks against the
  release's channel manifest. It replaces `cargo-llvm-cov`, a crates.io binary
  that would otherwise be one more dependency to vet.
- **Tests only: `rand_core`.** It is already in the tree; the tests use it for
  a deterministic RNG to sign PS256 with.

Base45, CBOR, COSE, JSON, the trust store and the test DSC builder are
written here and add no crates.

## Build scripts and macros, reviewed

Cargo runs a crate's `build.rs`, and the compiler runs a procedural macro, at
build time. Each one was read at the version pinned here:

| Crate | What its build-time code does |
|---|---|
| `generic-array` 0.14.9 | Sets a cfg flag from the compiler version. 19 lines; no commands. |
| `libc` 0.2.190 | Runs `rustc --version`, and `freebsd-version` or `emcc` on those targets only. Sets cfg flags. |
| `libm` 0.2.16 | Reads one environment variable (`ENSURE_NO_PANIC`) and sets cfg flags. |
| `num-bigint-dig` 0.8.6 | Three lines: sets one cfg flag. |
| `num-traits` 0.2.19 | `autocfg` probes of the compiler. |
| `proc-macro2` 1.0.107, `quote` 1.0.47 | Run `rustc --version` and compile a probe into `OUT_DIR`. They are needed by `der_derive` and `zeroize_derive`. |
| `zerocopy` 0.8.61 | Runs `rustc --version` and sets cfg flags. |
| `anyhow` 1.0.104 | Runs `rustc --version` and compiles a probe into `OUT_DIR`. |
| `serde` 1.0.229, `serde_core` 1.0.229 | Run `rustc --version` and write a version-stamped `private.rs` into `OUT_DIR`. |
| `prettyplease` 0.3.0 | Checks its own version and `links` key; no commands. |
| `wit-bindgen` 0.62.0 | On wasm32 only, copies the two prebuilt objects above from its own `src/rt/` into `OUT_DIR` and links them. |
| `wit-bindgen-rust`, `wit-bindgen-rust-macro` 0.62.0 | Set an environment variable to `OUT_DIR`; nothing else. |
| `serde_derive` | A procedural macro, used by the component feature's tools. |
| `der_derive`, `zeroize_derive`, `zerocopy-derive` | Procedural macros from RustCrypto and Google that derive DER, zeroize and zerocopy impls. |

None of them reaches the network or writes outside `OUT_DIR`.

## The pinned set

The Feature column says which builds compile a crate. `all` means every build, `component` only the WebAssembly component, and `demo` only the live-demo module.

| Crate | Version | Released | Feature | Build-time code |
|---|---|---|---|---|
| `adler2` | 2.0.1 | 2025-06-09 | all | — |
| `aead` | 0.5.2 | 2023-04-02 | all | — |
| `aes` | 0.8.4 | 2024-02-13 | all | — |
| `aes-gcm` | 0.10.3 | 2023-09-21 | all | — |
| `anyhow` | 1.0.104 | 2026-07-18 | component | build.rs |
| `autocfg` | 1.5.1 | 2026-05-22 | all | — |
| `base16ct` | 0.2.0 | 2023-02-26 | all | — |
| `base64ct` | 1.8.3 | 2026-01-12 | all | — |
| `bitflags` | 2.13.2 | 2026-09-10 | component | — |
| `block-buffer` | 0.10.4 | 2023-03-09 | all | — |
| `cfg-if` | 1.0.5 | 2026-09-16 | all | — |
| `cipher` | 0.4.4 | 2023-03-09 | all | — |
| `const-oid` | 0.9.6 | 2023-12-15 | all | — |
| `cpufeatures` | 0.2.17 | 2025-01-25 | all | — |
| `crypto-bigint` | 0.5.5 | 2023-11-18 | all | — |
| `crypto-common` | 0.1.6 | 2022-07-16 | all | — |
| `ctr` | 0.9.2 | 2022-09-30 | all | — |
| `der` | 0.7.10 | 2025-04-18 | all | — |
| `der_derive` | 0.7.3 | 2024-07-09 | all | proc-macro |
| `digest` | 0.10.7 | 2023-05-19 | all | — |
| `ecdsa` | 0.16.9 | 2023-11-16 | all | — |
| `elliptic-curve` | 0.13.8 | 2023-11-19 | all | — |
| `equivalent` | 1.0.2 | 2025-02-14 | component | — |
| `ff` | 0.13.1 | 2025-03-09 | all | — |
| `flagset` | 0.4.7 | 2025-04-04 | all | — |
| `foldhash` | 0.2.0 | 2025-08-23 | component | — |
| `generic-array` | 0.14.9 | 2025-10-13 | all | build.rs |
| `getrandom` | 0.2.17 | 2026-01-11 | all | — |
| `ghash` | 0.5.1 | 2024-03-03 | all | — |
| `group` | 0.13.0 | 2022-12-06 | all | — |
| `hashbrown` | 0.17.1 | 2026-05-09 | component | — |
| `heck` | 0.5.0 | 2024-03-12 | component | — |
| `hmac` | 0.12.1 | 2022-02-17 | all | — |
| `id-arena` | 2.3.0 | 2026-01-14 | component | — |
| `indexmap` | 2.14.2 | 2026-09-05 | component | — |
| `inout` | 0.1.4 | 2025-02-21 | all | — |
| `itoa` | 1.0.18 | 2026-03-20 | component | — |
| `lazy_static` | 1.5.1 | 2026-10-01 | all | — |
| `leb128fmt` | 0.1.0 | 2023-10-02 | component | — |
| `libc` | 0.2.190 | 2026-10-02 | all | build.rs |
| `libm` | 0.2.16 | 2026-01-24 | all | build.rs |
| `log` | 0.4.34 | 2026-08-22 | component | — |
| `memchr` | 2.8.3 | 2026-07-08 | component | — |
| `miniz_oxide` | 0.8.9 | 2025-06-09 | all | — |
| `num-bigint-dig` | 0.8.6 | 2025-11-12 | all | build.rs |
| `num-integer` | 0.1.47 | 2026-08-12 | all | — |
| `num-iter` | 0.1.46 | 2026-07-07 | all | — |
| `num-traits` | 0.2.19 | 2024-05-03 | all | build.rs |
| `opaque-debug` | 0.3.1 | 2024-03-01 | all | — |
| `p256` | 0.13.2 | 2023-04-15 | all | — |
| `pkcs1` | 0.7.5 | 2023-04-24 | all | — |
| `pkcs8` | 0.10.2 | 2023-04-05 | all | — |
| `polyval` | 0.6.2 | 2024-03-03 | all | — |
| `ppv-lite86` | 0.2.21 | 2025-03-09 | all | — |
| `prettyplease` | 0.3.0 | 2026-07-18 | component | build.rs |
| `primeorder` | 0.13.6 | 2023-11-16 | all | — |
| `proc-macro2` | 1.0.107 | 2026-07-19 | all | build.rs |
| `qrcode` | 0.14.1 | 2024-07-05 | demo (`qr`) | — |
| `quote` | 1.0.47 | 2026-07-19 | all | build.rs |
| `rand` | 0.8.8 | 2026-08-25 | all | — |
| `rand_chacha` | 0.3.1 | 2021-06-09 | all | — |
| `rand_core` | 0.6.4 | 2022-09-15 | all | — |
| `rfc6979` | 0.4.0 | 2023-02-28 | all | — |
| `rsa` | 0.9.10 | 2026-01-06 | all | — |
| `ryu` | 1.0.23 | 2026-02-08 | component | — |
| `sec1` | 0.7.3 | 2023-07-16 | all | — |
| `semver` | 1.0.28 | 2026-04-04 | component | — |
| `serde` | 1.0.229 | 2026-07-18 | component | build.rs |
| `serde_core` | 1.0.229 | 2026-07-18 | component | build.rs |
| `serde_derive` | 1.0.229 | 2026-07-18 | component | proc-macro |
| `serde_json` | 1.0.145 | 2025-09-14 | component | build.rs |
| `sha2` | 0.10.9 | 2025-04-30 | all | — |
| `signature` | 2.2.0 | 2023-11-12 | all | — |
| `smallvec` | 1.16.2 | 2026-09-25 | all | — |
| `spin` | 0.9.9 | 2026-07-13 | all | — |
| `spki` | 0.7.3 | 2023-11-28 | all | — |
| `subtle` | 2.6.1 | 2024-06-24 | all | — |
| `syn` | 2.0.119 | 2026-07-15 | all | — |
| `syn` | 3.0.6 | 2026-09-16 | component | — |
| `tinyvec` | 1.13.3 | 2026-09-13 | all | — |
| `tls_codec` | 0.4.2 | 2025-02-10 | all | — |
| `tls_codec_derive` | 0.4.2 | 2025-02-10 | all | proc-macro |
| `typenum` | 1.20.1 | 2026-05-29 | all | — |
| `unicode-ident` | 1.0.26 | 2026-09-17 | all | — |
| `unicode-normalization` | 0.1.25 | 2025-10-30 | all | — |
| `universal-hash` | 0.5.1 | 2023-05-19 | all | — |
| `version_check` | 0.9.5 | 2024-07-25 | all | — |
| `wasi` | 0.11.1+wasi-snapshot-preview1 | 2025-06-10 | all | — |
| `wasm-encoder` | 0.259.0 | 2026-09-10 | component | — |
| `wasm-metadata` | 0.259.0 | 2026-09-10 | component | — |
| `wasmparser` | 0.259.0 | 2026-09-10 | component | — |
| `wit-bindgen` | 0.62.0 | 2026-09-10 | component | build.rs |
| `wit-bindgen-core` | 0.62.0 | 2026-09-10 | component | — |
| `wit-bindgen-rust` | 0.62.0 | 2026-09-10 | component | build.rs |
| `wit-bindgen-rust-macro` | 0.62.0 | 2026-09-10 | component | build.rs proc-macro |
| `wit-component` | 0.259.0 | 2026-09-10 | component | — |
| `wit-parser` | 0.259.0 | 2026-09-10 | component | — |
| `x509-cert` | 0.2.5 | 2023-12-24 | all | — |
| `zerocopy` | 0.8.61 | 2026-10-07 | all | build.rs |
| `zerocopy-derive` | 0.8.61 | 2026-10-07 | all | proc-macro |
| `zeroize` | 1.9.1 | 2026-10-06 | all | — |
| `zeroize_derive` | 1.5.0 | 2026-06-12 | all | proc-macro |
