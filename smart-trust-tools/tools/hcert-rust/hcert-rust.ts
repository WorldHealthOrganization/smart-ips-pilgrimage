import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "hcert-rust",
    title: "HCERT library (Rust, native and WebAssembly)",
    description:
      "The Rust implementation of the HCERT pipeline: Base45, ZLIB, deterministic CBOR, COSE_Sign1 ES256/PS256 (RustCrypto p256, rsa, sha2), CWT, the DVCMin payload, the trust store (PEM, DER, GDHCN DID trustlist v2, trust domains), the section 11 verifier, two-phase issuance and Verifiable Health Links (payload, vhlink:/, the ITI-YY5 manifest, JWE dir/A256GCM with aes-gcm, the RFC 9421 signature base). It builds natively; as the WebAssembly component of the `hcert` world in api/wit (feature component, wit-bindgen; build-component.sh componentises and transpiles it with the pinned jco into an ES module for browsers and Node, whose only import, wasi:random, maps to crypto.getRandomValues); and as an import-free module with a JSON call surface for the live demos (js/hcert.mjs, with a TEST ONLY builder of self-signed DSCs). Every crate is pinned in Cargo.lock (DEPENDENCIES.md).",
    install: { none: true },
    invoke: { shell: "cargo test --locked --manifest-path tools/hcert-rust/Cargo.toml" },
    io: {
      inputs: [
        { name: "target", schema: t("Slug"), required: false, arg: { flag: "--target" }, description: "wasm32-unknown-unknown for the WebAssembly module (with `cargo build --release`), else the host." },
      ],
      outputs: [
        { name: "library", schema: t("RepoPath"), description: "tools/hcert-rust/target/<target>/release/: the rlib, and hcert.wasm for wasm32." },
      ],
    },
    satisfies: ["hcert-select-payload", "hcert-assemble-payload", "hcert-build-cwt", "hcert-encode-cbor", "hcert-sign-cose", "hcert-compress", "hcert-encode-base45", "hcert-prefix-context", "hcert-verify", "hcert-trust-list", "hcert-conformance-testing"],
    selection: {
      when: "A Rust program or a web page issues or verifies an HCERT, or a demo shows the QR Code Generation steps live; or the second implementation is checked against the first on the shared vectors.",
      limits: "No coverage-guided fuzzing in CI (cargo-fuzz needs nightly); the seeded fuzzer runs instead. The codec does not yet build without std. Not yet published to crates.io or npm (STT-NFR-002); the crate (cargo package) and the npm component package (tools/release-packaging) are ready, for an agent to publish by docs/RELEASING.md.",
      cost: "Seconds once the crates are cached; the first build downloads the crates Cargo.lock pins (72 for the library, 29 more for the component).",
    },
    requires: { runtime: ["cargo", "node"], network: true },
    remedies: [
      { host: "index.crates.io", none: "Every crate is pinned with its checksum in Cargo.lock; a vendored copy (cargo vendor) serves the same bytes offline." },
    ],
  }),
);
