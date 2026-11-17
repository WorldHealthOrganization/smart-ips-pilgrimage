# Changelog

The HCERT libraries of this repository and every artefact built from them —
the Kotlin library on Maven Central (`io.github.litlfred:hcert-api`,
`io.github.litlfred:hcert-core`) and npm (`@litlfred/hcert-kotlin-js`), the
Rust library on crates.io (`litlfred-hcert`, library `hcert`) and its WebAssembly component on npm
(`@litlfred/hcert-component`) — share one version, the one in
[`VERSION`](VERSION). It follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)
(STT-NFR-001): a change to the wire format or to a subclaim default is a major
or a minor version change, and its entry cites the smart-trust
[change log](https://github.com/WorldHealthOrganization/smart-trust/blob/main/input/pagecontent/changes.md)
entry it implements. [`docs/RELEASING.md`](docs/RELEASING.md) says how a
release is cut.

## [0.1.0] — unreleased

The first version of both libraries. It implements HCERT Specification 1.1.1
and the smart-trust implementation guide at 1.7.5 (STT-GEN-007).

### Implements, from the smart-trust change log

- **v1.7.5 — "QR Code Generation page added, with step-by-step HCERT encoding,
  signing and decoding instructions, worked through with a DVC payload."**
  The whole pipeline of that page, step by step: select the payload type,
  assemble the DVCMin payload, build the CWT claim set, encode it as
  deterministic CBOR, sign it as COSE_Sign1 (ES256, PS256), compress it with
  ZLIB, encode it in Base45 and prefix the `HC1:` context identifier; and the
  section 11 verifier, which names the failing step and reason. The page's
  worked examples, the XXA vector and the GDHCN DEV participant XXR's
  newborn birth-dose certificate, verify end to end in both libraries.
- **v1.7.5 — "CWT Payload logical model updated to allow more than one health
  certificate under the hcert claim, per HCERT Specification 3.2.7."** The
  `hcert` (-260) claim is `1..*`: the issuer emits one entry per payload and
  refuses none (NoPayload) or two under one subclaim (DuplicateSubclaim); the
  verifier returns every valid entry with its subclaim, in wire order
  (STT-SEL-004). This is a wire-format behaviour, so it is recorded here.

### Added

- The API contract in WIT (`api/wit`), from which the Kotlin declarations
  (`hcert-api`) and the TypeScript reference types are generated.
- `hcert-core` (Kotlin Multiplatform: JVM 11+, used as-is on Android, and
  Node through Kotlin/JS IR): codec, COSE, DVCMin, the trust store (PEM, DER,
  GDHCN DID trust list v2, trust domains), verification, two-phase issuance
  (the host signs), and Verifiable Health Links (the payload, `vhlink:/`, the
  ITI-YY5 manifest request, JWE dir/A256GCM). No third-party runtime
  dependency.
- `hcert` (Rust, native and wasm32): the same operations, with RustCrypto,
  and the WebAssembly component of the `hcert` world, transpiled with jco to
  an ES module for browsers and Node.
- Verification of the GDHCN DID trust list proofs (STT-TRU-006):
  `verify-did-proof` and `trust-store.add-verified-did-document` check a
  document's JsonWebSignature2020 proof against the signer's DID document,
  under one fail-closed profile shared by both libraries; `proof-invalid`
  names the rule a refused document breaks. The WebAssembly build's JSON
  `verify` takes the signer as `trustDidSigner` beside `trustDid`, and the
  live demo trusts XXR's DSC only once its proof verifies against the WHO
  signing DID.
- One TypeScript conformance suite run on both JavaScript packages, and the
  two libraries verifying each other's certificates (STT-TST-003,
  STT-TST-007).

[0.1.0]: https://github.com/litlfred/smart-trust-tools/commits/main
