# API contract (API-first)

The library API is defined here **before** any implementation, in
[WIT](https://component-model.bytecodealliance.org/design/wit.html), the
interface definition language of the WebAssembly Component Model. The WIT is
the reviewable contract. The Kotlin and Rust libraries implement it, and the
requirements in [`../skills/requirements/`](../skills/requirements/) say what each function
must do. Every WIT item is tagged `[STT-…]` with the requirement it
implements.

- Source of truth: [`wit/`](wit/)
- Generated TypeScript view for review: [`generated/ts/`](generated/ts/)
  (`tools/gen-api-types/gen_api_types.sh`)
- Wire format: [`cddl/hcert.cddl`](cddl/hcert.cddl) (RFC 8610)

## Three layers, three open standards

| Layer | Describes | Format | Where |
|---|---|---|---|
| Library API | Functions, objects, errors | WIT | [`wit/`](wit/) |
| Wire format | CBOR bytes: COSE_Sign1, CWT claims, `hcert` map | CDDL, IETF RFC 8610 | [`cddl/hcert.cddl`](cddl/hcert.cddl) plus generated payload rules |
| Payload model | DVCMin and others as data | JSON-LD context + SHACL, W3C, derived from the FHIR logical models | [`../models/`](../models/) |

All type references are to openly available standards: IETF, W3C, HL7 FHIR,
ITU-T. There are no paywalled ISO references [STT-GEN-013]. ISO/IEC 18004 (QR)
is cited only because the HCERT Specification mandates it.

## Why WIT, and not something else

There is no OpenAPI equivalent that generates the API of two separate native
libraries (one Kotlin, one Rust). The candidates:

| IDL | Fit | Why / why not |
|---|---|---|
| **WIT** (Component Model) | **chosen** | Not tied to REST. Has records, variants, enums, `result`, `option`, and *resources* (objects with methods). Imports and exports model host-provided pieces like the signer. It is the native contract for the Rust→WASM target, and `jco` turns it into TypeScript for Node and browsers. Kotlin has no generator, so `tools/wit2kotlin` generates the Kotlin API by fixed mapping rules (below); the Kotlin API itself names no WIT. |
| Smithy | close second | Protocol-agnostic and has the best review tooling (smithy-diff detects breaking changes), but its Kotlin and Rust generators produce network clients, not in-process libraries. |
| UniFFI (Mozilla) | different architecture | Generates Kotlin/Swift/Python bindings *from a single Rust implementation*. Only a fit if we drop the native Kotlin library and make Kotlin a binding over Rust. Worth keeping in mind for iOS later. |
| TypeSpec | weak | Core is protocol-agnostic, but its generators are HTTP/OpenAPI oriented. |
| Protobuf services | weak | RPC-shaped, no resources, no host imports. |

WIT also has limits, which shaped the design:

- **No recursive types**, so arbitrary CBOR crosses as encoded bytes
  (`cbor-bytes`). Typed payloads (DVCMin, VHL) cross as records.
- **Calls are synchronous** in WASI 0.2, so the core does no I/O and makes no
  async callbacks (see the design rules below and OI-15). Verify stays
  synchronous on every target: the Kotlin/JS target is Node only, using
  Node's synchronous `crypto` and `zlib`, and browsers use the Rust
  component, which verifies with in-WASM RustCrypto (owner's decision,
  2026-10-24, OI-37 option C).
- `s64` maps to `bigint` in JavaScript, so it is used only for timestamps.
  Subclaim numbers are `s32`.

## How it is organised

Package `who:smart-trust@0.1.0` (placeholder namespace, OI-14).

```
                        ┌────────────── worlds ──────────────┐
                        │ hcert-codec   hcert-verifier       │
                        │ hcert-issuer  hcert (= both)       │
                        └────────────────────────────────────┘
 pipeline     issuer ─ prepare / finish
 (pipeline.wit) verifier ─ verify / verify-cose / read-unverified
                    │                 │
 domain       subclaims   dvc   payloads   trust (trust-store resource)
 (payload.wit, trust.wit)
                    │
 encoding     codec (CBOR, ZLIB, Base45, HC1)   cose (Sign1, kid, sigs)
 (codec.wit, cose.wit)
                    │
 base         types (shared records, enums, failure taxonomy)
```

| File | Interface | Pipeline step | Purpose |
|---|---|---|---|
| `types.wit` | `types` | all | Shared records/enums; closed `failure-reason` taxonomy |
| `codec.wit` | `codec` | 4, 6, 7, 8 | Deterministic CBOR, ZLIB, Base45, `HC1:` |
| `cose.wit` | `cose` | 5 | COSE_Sign1 parse/verify, Sig_structure, kid, DER↔r‖s |
| `payload.wit` | `subclaims` | 1 | Subclaim registry (resource) |
| `payload.wit` | `dvc` | 2 | DVCMin records, validation, CBOR |
| `payload.wit` | `payloads` | 2 | `payload` variant: dvc-min, vhl, raw |
| `vhl.wit` | `vhl` | J4 | Verifiable Health Links (IHE ITI VHL): payload, `vhlink:/`, ITI-YY5 request and manifest, JWE dir / A256GCM, HTTP Message Signatures |
| `trust.wit` | `trust` | trust | `trust-store` resource filled by the host: PEM, DER, DID trustlist v2 documents |
| `pipeline.wit` | `issuer` | 3–8 | Two-phase `prepare`/`finish` signing |
| `pipeline.wit` | `verifier` | verify | `verify` returns `verified` or `failed(step, reason)` |
| `worlds.wit` | — | — | What each deployable bundle exports |

Step 9, the QR symbol, is not in the contract: the HC1 string uses only QR
Alphanumeric characters, and integrators render it with their platform's QR
encoder at error correction Q. [STT-QR-001]

### Design rules

1. **The core is synchronous and does no I/O.** No network, no file system, no
   ambient clock. The host fetches trust lists and loads them into a
   `trust-store`; the current time is a `now` argument. [STT-GEN-012]
2. **Signing is two-phase.** `issuer.prepare` returns the bytes to sign;
   the caller signs them anywhere (HSM, KMS, Android Keystore, WebCrypto,
   which is async) and passes the signature to `issuer.finish`. Nothing is
   imported from the host. [STT-ISS-004]
3. **Payload content is only reachable after verification.** `verify` returns
   a `verification-result` variant; only its `verified` case carries the
   payload. `read-unverified` is the one explicitly named way to look at an
   unverified certificate, and its result is a different type. [STT-VER-002,
   STT-VER-011]
4. **Expected failures are values, not exceptions.** Invalid certificates
   give `failed(step, reason)`. Note that `jco` maps WIT `result<_, E>` to a
   thrown `ComponentError` in JS; `verify` deliberately returns a variant,
   not a `result`, so it never throws for a bad certificate. [STT-VER-008]

## Targets and how each implements the contract

| Language | Target | How it gets the WIT API |
|---|---|---|
| Rust | native crate (crates.io) | Idiomatic Rust API, plus a `wit-bindgen` guest layer that exports the worlds |
| Rust | **wasm32 component** | `cargo component build` → `.wasm` implementing `hcert-*` worlds |
| Rust | Node / browser (npm) | `jco transpile` of the component → ES module + the `.d.ts` in `generated/ts/` |
| Kotlin | **JVM** (Maven Central) | API generated by the mapping rules below; behaviour in `hcert-core` |
| Kotlin | **Android** (AAR) | Same KMP code as JVM, with Android Keystore signer and crypto backend |
| Kotlin | **Node** (npm, Kotlin/JS IR) | `@JsExport` façade whose generated `.d.ts` must match `generated/ts/` |

### WIT → Kotlin mapping rules

| WIT | Kotlin |
|---|---|
| `record` | `data class` (kebab-case → camelCase) |
| `variant` | `sealed interface` with one `data class` / `object` per case |
| `enum` | `enum class` (cases in UPPER_SNAKE) |
| `resource` | `interface … : AutoCloseable` |
| `option<T>` | `T?` |
| `result<T, E>` | `HcertResult<T, E>` (`Ok` / `Err`), so no exceptions for expected failures; on Kotlin/JS, throw like jco does |
| `list<u8>` | `ByteArray` (JVM) / `Uint8Array` (JS) |
| `s32` / `s64` / `u32` | `Int` / `Long` / `Int` (JS: `number` / `bigint` / `number`) |
| interface | `object` (functions) or package |
| imported interface | Kotlin `interface` the caller implements (`Signer`, `TerminologyValidator`) |
| `world` | nothing: a world bundles a WebAssembly component's exports and imports, which only the Rust build needs. Kotlin's entry point is `object Hcert` |

No Kotlin name or KDoc mentions WIT; each generated file carries one provenance comment naming the `.wit` it came from.

### Checking conformance to the contract

- **One JS test suite, two implementations.** The Kotlin/JS npm package and
  the jco-transpiled Rust component expose the same TypeScript surface. A
  single TypeScript conformance suite, built on the shared vectors, runs
  against both. The suite is type-checked against `generated/ts/`.
  [STT-GEN-011, STT-TST-007]
- **API dumps.** Kotlin: binary-compatibility-validator `.api` files
  (JVM + klib). Rust: `cargo public-api`. Both are committed and diffed in
  CI, so a change to an implementation's API shows up in review.

## Reviewing a change

1. Edit `wit/*.wit`.
2. Run `tools/gen-api-types/gen_api_types.sh`. It validates the WIT and regenerates
   `generated/ts/`.
3. Review the WIT diff, and the TypeScript diff for how the change looks to a
   JS caller.
4. Bump the package version for breaking changes.
