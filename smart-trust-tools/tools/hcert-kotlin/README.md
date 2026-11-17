# Kotlin libraries

`hcert-api/` holds the **API**: Kotlin Multiplatform declarations generated
from the contract in [`../../api/wit/`](../../api/wit/) by
[`../wit2kotlin/wit2kotlin.py`](../wit2kotlin/wit2kotlin.py). It contains
interfaces and types only, no behaviour [STT-GEN-014]. The contract is written
in WIT so that the Rust WebAssembly component and this library cannot drift
apart, but the Kotlin API does not name WIT: a caller sees Kotlin types only.

| Contract | Kotlin |
|---|---|
| exported interface (e.g. `codec`, `verifier`) | `interface Codec`, `interface Verifier`, implemented by the library |
| resource (e.g. `trust-store`) | `interface TrustStore : AutoCloseable`, created by `newTrustStore()` on its interface |
| record / enum / variant | `data class` / `enum class` / `sealed interface` |
| `result<T, E>` | `HcertResult<T, E>` (`Ok` / `Err`) |
| world (e.g. `hcert-verifier`) | nothing: a world says what a WebAssembly component exports, which only the Rust build needs |

Targets: JVM (Java 11+, also used on Android) and Node.js (Kotlin/JS IR, with
TypeScript declarations). An `androidTarget()` is added with the first
Android-specific module.

```sh
python3 tools/wit2kotlin/wit2kotlin.py          # regenerate after editing api/wit
python3 tools/wit2kotlin/wit2kotlin.py --check  # CI: fail if stale
gradle -p tools/hcert-kotlin build               # compile JVM + JS
```

Do not edit files under `hcert-api/src/commonMain`. Implementations go in
separate modules (e.g. `hcert-core`) that depend on `:hcert-api` and
implement its interfaces.

## hcert-core

`hcert-core/` implements every interface of `:hcert-api` (object `Hcert` is
the entry point: `Hcert.codec`, `Hcert.verifier`, `Hcert.issuer`, …) with the Kotlin standard library and the platform
only: the JDK (`java.security`, `java.util.zip`) on JVM and Android, and
`node:crypto`, `node:zlib` and `node:buffer` on Node. No third-party
runtime dependency. Base45, deterministic CBOR, ASN.1 signature conversion,
the small JSON reader for DID documents and the canonical N-Quads and RFC 8785
JCS that verifying a trust list DID document's proof needs (`DidProof.kt`,
STT-TRU-006) are written here.

```sh
gradle -p tools/hcert-kotlin :hcert-core:jvmTest                           # JVM tests, incl. the PR 129 vector
gradle -p tools/hcert-kotlin :hcert-core:compileProductionLibraryKotlinJs  # Node build (ES modules)
node tools/hcert-kotlin/hcert-core/node-smoke.mjs                          # the PR 129 vector on Node
```

The tests are one file per skill (`SignCoseTest.kt` for `hcert-sign-cose`, and
so on), and each test is named after the requirements it verifies
(`` `STT-COS-002 … both ES256 and PS256 sign and verify` ``). The skill names its
file in `tested-by:`, so the requirement graph shows which test verifies which
requirement, and `check:req-nodes` fails on a test naming a requirement that
does not exist.

The tests sign with the throw-away keys in [`../../vectors/testkit/`](../../vectors/testkit/).
Kotlin/JS uses the machine's Node.js; its npm packages (the mocha runner) come only from
`kotlin-js-store/yarn.lock`, and Gradle artifacts only as listed in
`gradle/verification-metadata.xml`.

## Release packaging

Both modules are packaged for Maven Central as `io.github.litlfred:hcert-api`
and `io.github.litlfred:hcert-core`, at the version in [`../../VERSION`](../../VERSION),
with Gradle's built-in `maven-publish` only. `gradle -p tools/hcert-kotlin
publishDryRun` publishes them into `build/maven-dry-run/` (no remote) and lists
the artefacts; nothing is published from here or from CI.
[`../../docs/RELEASING.md`](../../docs/RELEASING.md) is the runbook.
