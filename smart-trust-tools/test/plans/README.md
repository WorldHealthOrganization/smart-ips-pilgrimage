# Test plan: SMART Trust HCERT and VHL libraries

This is the readable form of the two test plans in this directory. The plans
themselves are `test-plan/v1` nodes of the knowledge graph (cat-harness
`schemas/test-plan.ts`, shaped after FHIR R5 TestPlan):

- [`hcert-library-conformance.test-plan.json`](hcert-library-conformance.test-plan.json)
  is the plan any implementation runs: the Kotlin library today, the Rust
  library when it exists. It is written by the `test-plan` Tool from the
  skills and the requirements' success criteria, and CI fails if it is stale.
- [`who-itb-agreement.test-plan.json`](who-itb-agreement.test-plan.json)
  compares a library with the WHO Interoperability Test Bed (WHO-ITB) on its
  three HCERT tracks. It runs after the first plan.

`bun run check:req-nodes` checks both: each assertion id must name a success
criterion, each data path must exist, and each predecessor must name a plan.

## What "done" means: the success criteria

Every requirement statement now carries success criteria
(`statements[].successCriteria`, from the bootstrap `RequirementSchema`). Each
criterion is one sentence a reviewer can answer yes or no, with a
verification method. A criterion's address is
`req:<id>#<statement>/<key>`, and that address is the assertion id in a test
plan. A verdict on an assertion is therefore a verdict on a criterion.

| Verification | Criteria | Requirements | Judged by |
|---|---|---|---|
| test | 92 | 87 | the suites in CI, through the test plans |
| inspection | 6 | 6 | reading the artefact at release: API shape, wire format, standards, versioning, publication |
| review | 3 | 3 | a person's recorded judgement at release: spec precedence, API parity, the coverage floor never lowered |

For a requirement verified by test, the criterion is that a test named after
it (`STT-XXX-nnn …`) passes in each implementation's suite. The Kotlin
suite's test names are listed in the criterion text.

**Where things stand (Kotlin, JVM):**

- 80 named tests pass.
- 88 of the 95 requirements are verified by a test named after them, the
  Rust library's tests included.
- Kotlin line coverage is 91.3% and branch coverage 71.1% (JaCoCo, hcert-core
  commonMain and jvmMain).
- Rust line coverage is 85.7% and region coverage 81.8% (`coverage.sh`, the
  library's sources under `cargo test`).

The unverified requirements are STT-TST-009, and the six verified by
inspection or review (bean OI-32, closed 2026-10-24).

## Which test verifies which assertion

Each implementation is a system under test in [`../systems/`](../systems/README.md)
(`system/v1`). Its `bindings` map every assertion of this plan to the tests
that verify it, per surface and target. They are generated from the tags in
the tests themselves, the requirement ids each test's name starts with. Its
`uncovered` list names each required assertion that a declared target leaves
unverified. The counts above are therefore computed per system and target,
not by hand.

## Each case in Gherkin

Each case of both plans has a `feature`, its Gherkin file in
[`../features/`](../features/): `test/features/<case>.feature`. The feature is
the specification and the tests are the binding. Each Scenario is one test,
written from what that test sets up and asserts, and names it in a tag in
the shared grammar `@test:<file>::<scope>::<name>`: the scope is the Rust
`mod` or Kotlin class the test is in, and each run of whitespace is written
`_`, since a tag ends at whitespace. The TypeScript conformance suites run
their own `run("title", …)`, and say so in a `@test-runner run` comment; a
looped case is titled `id[${key}]` and tagged as written.
The WHO-ITB cases have one Scenario per GITB test case, tagged
`@itb:<suite>/<testcase>` and written from the suite at the commit
`references/who-itb` cites; its test data is cited, not copied. No CI job
runs them yet (bean OI-33).

cat-harness-tools' `check:test-gherkin` (CI runs it, with `--itb` at the
WHO-ITB commit) fails when a test has no Scenario, a tag names no test, or an
`@itb:` tag names no GITB test case. `make_test_plan.py --check` fails when a
case's feature is missing or a feature file is no case's.

## Test levels

| Level | What it shows | Kotlin | Rust (to build) | Data | Requirements |
|---|---|---|---|---|---|
| Skill tests | each pipeline step meets its requirements, including the error paths | `jvmTest`, one class per skill, each test named after the requirements it verifies | `cargo test`, the same names | the testkit PKI (`vectors/testkit`) | the step requirements (PRE, B45, CMP, CBR, COS, CWT, PAY, SEL, TRU, VER, VHL, …) |
| Conformance vectors | the published WHO certificates decode and verify as published, byte for byte | `ConformanceVectorsTest`; `node-smoke.mjs` on Node | the same files | `vectors/smart-trust-af75be2` (the merged guide's XXR pair: decoded and sized, not verified, since its DSC is on the DEV trust list only); `vectors/smart-trust-pr129` (the PR branch's XXA pair with its DSC: verified end to end) | STT-TST-001, 002, 011 |
| Negative vectors | a bad input stops at the named step with the named reason | the same file, on the JVM and on Node | the same file | `vectors/negative` (the `negative-vectors` Tool) | STT-TST-004, 005, VER-008 |
| Fuzzing | no input crashes, hangs or exceeds `DecodeLimits` | `FuzzTest`, a seeded mutation fuzzer over 6 entry points | `cargo-fuzz`, coverage-guided, same 6 targets | generated: seeds from PR 129, a fixed seed per target | STT-TST-006 |
| Coverage floor | new code does not arrive untested | `:hcert-core:jvmTestCoverageCheck`: fails below 90% line, 70% branch | `tools/hcert-rust/coverage.sh`: fails below 85% line, 80% region (stable rustc measures no branches) | — | STT-TST-010 |
| Targets | the same behaviour on every platform | JVM and Node (Kotlin/JS) run in CI; **Android is not yet run** | native and wasm32 (jco) | the shared vectors | STT-GEN-004, 005, 011 |
| Cross-implementation | each library verifies the other's certificates, from byte-identical bytes to sign | `tools/conformance-ts/cross.mjs` loads both packages | the same | issued at test time, ES256 and PS256, DVC and VHL | STT-TST-003, GEN-006 |
| One TypeScript suite | both npm packages behave the same through `api/generated/ts` | `tools/conformance-ts` on the Kotlin/JS package (`WitJs.kt`) | the same suite on the jco component | the shared vectors | STT-TST-007 |
| Schema checks | the payloads match the CDDL and SHACL models | `check-models` | — | PR 129 | STT-TST-008 |
| WHO-ITB agreement | the library agrees with the test bed WHO uses for GDHCN participants | plan `who-itb-agreement` | the same plan | WHO-ITB track data (bean OI-33) | STT-TST-009 |

A case passes when every required assertion has a passing named test,
run in CI on every target. The exit rule is the cat-harness default
(`processes/sdlc/decisions/test-certification.dmn`). A run is certified only
if it completed, its data hashed, every case has a verdict, the untainted
checker agrees, and no required assertion failed. A case that could not run
is **undetermined**, never passed.

## The WHO Interoperability Test Bed

[WHO-ITB](https://github.com/WorldHealthOrganization/WHO-ITB/tree/883291d51e206719c1417cf95393a5cd8b20dc4b)
is a pre-configured GITB instance for the GDHCN trust network
(`references/who-itb`). It has three HCERT tracks, and each starts from an
uploaded QR image.

| Track | ITB test case | After the HCERT is verified |
|---|---|---|
| 1. HCERT VHL | `tc-vhl-001`: QR to a verified LAC IPS bundle | extract the SHL reference, authorize with the PIN, fetch the FHIR content through the manifest, validate against `LACBundleIPS` |
| 2. HCERT ICVP | `tc-icvp-001`: QR to ICVP-IPS conformance | transform the claim with `ICVPClaimtoIPS`, validate |
| 3. HCERT PH4H | `tc-ph4h-qr-001`: QR to a MeOW bundle | transform with `MedicationOverviewMinToMedicationOverviewBundle`, validate, check with FHIRPath |

How each ITB step maps to the library:

| ITB step (gdhcn-helper) | Library | Criterion |
|---|---|---|
| Decode QR image (`/decode/image`) | out of scope: the library takes the text (STT-QR-005) | — |
| Decode HC1 (`/decode/hcert`) | `HcertCodec.fromHc1`, `HcertCose.parseSign1`, `HcertVerifier.readUnverified` | `req:stt-tst-009#statement/decode` |
| Verify COSE signature (`/verify/signature`, GDHCN DEV trust list) | `HcertTrustStore.addDidDocument`, `HcertVerifier.verify` | `…/verify` |
| Extract SHL reference, authorize, fetch via manifest (`/extract/reference`, `/shlink/authorize`, `/shlink/fetch-fhir`) | `HcertVhl` (link, ITI-YY5 manifest request, JWE decryption) | `…/vhl-link` |
| StructureMap transform, Matchbox validation, FHIRPath | out of scope: the library hands over the claim | `…/icvp-claim`, `…/meow-claim` |

Two things differ from the ITB:

- The ITB verifies only ES256. The library also verifies PS256.
- The ITB fetches the trust list itself. The library's trust store does no
  I/O, so the host supplies the DID documents (STT-TRU-001).

**What blocks running it in CI (bean OI-33):**

- WHO-ITB has no licence file, so its track images cannot be copied here.
- The images must be read to HC1 text once, and no QR reader is pinned.
- The track data is signed by GDHCN DEV participants, whose trust list host
  is not reachable from the build environment.

Until these are resolved, a tester runs the ITB (`docker compose up`) beside
the library and records a test report against the plan.

## The Rust library

The Rust suite runs the same plan, with these additions:

1. It loads the same files in `vectors/` (STT-TST-005) and names its tests
   after the same requirements, so the plan's assertions apply unchanged.
2. `cargo test` runs on native targets. The wasm32 component is transpiled
   with jco and runs `node-smoke.mjs`'s checks in Node (STT-GEN-005).
3. `cargo-fuzz` gets one target per entry point the Kotlin fuzzer covers.
   CI runs it for a fixed time, and the corpus is kept between runs.
4. `coverage.sh` measures coverage with rustc's own `-C instrument-coverage`
   and the toolchain's `llvm-tools`, and fails below a floor recorded beside
   the Kotlin one (STT-TST-010): 85% of lines and 80% of regions, just under
   the first measurement (85.7%, 81.8%).
5. Certificates issued by each library are verified by the other
   (`cross.mjs`, STT-TST-003).
6. One TypeScript suite runs against both npm packages (STT-TST-007).

## Gaps and next steps

- **Android:** STT-GEN-004 names Android as a target, but no test runs on an
  Android runtime yet. The JVM tests cover the common code, not the platform
  crypto Android provides.
- **WHO-ITB data:** bean OI-33.
- **Rust:** `tools/hcert-rust` exists, and steps 1 and 2 above run in CI:
  - 34 native tests load the same vectors, and agree with Kotlin on every
    negative vector's step and reason;
  - the WebAssembly module runs on Node with WebCrypto keys.

  Still to do: the seeded fuzzer runs in CI, but coverage-guided
  `cargo-fuzz` needs nightly and doesn't. The coverage floor runs in CI. Each library verifies the other's
  certificates (STT-TST-003). The TypeScript suite (STT-TST-007) runs the same 45
  checks on both packages. The WIT component
  of the `hcert` world is built, transpiled with jco, and driven through
  every interface in CI (STT-GEN-005). The live demos use a plain module
  with a JSON call surface instead.
- **Release review:** the inspection and review criteria (STT-GEN-007, 008,
  013, NFR-001, 002, QR-005, and TST-010's `never-lowered`) need a
  release-review record. There is none until a first release.
- **Coverage:** branch coverage is the weaker number. The lowest files are
  `Asn1.kt` (55%), `Payloads.kt` (60%), `Json.kt` (64%), `Vhl.kt` (65%),
  `Pipeline.kt` (67%) and `CodecCose.kt` (68%). In Rust the lowest line
  coverage is in `types.rs` (60%, mostly `Display`), `api.rs` (76%, the
  demos' JSON surface, exercised in wasm by `smoke.mjs` but not measured),
  `json.rs` (80%), `issuer.rs` (80%) and `verifier.rs` (82%). Raise each
  floor as tests reach them.

## Running it

```sh
# Kotlin: tests, coverage report and floor (report in hcert-core/build/reports/jacoco/)
gradle -p tools/hcert-kotlin --no-daemon --init-script gradle/central-mirror.init.gradle \
  :hcert-core:jvmTest :hcert-core:jvmTestCoverageCheck :hcert-core:compileProductionLibraryKotlinJs
node tools/hcert-kotlin/hcert-core/node-smoke.mjs
# Rust: coverage against its floor, with the per-file table
tools/hcert-rust/coverage.sh --report
# One TypeScript suite on both packages (type check, then each implementation)
toolchain/node/node_modules/.bin/tsc -p tools/conformance-ts/tsconfig.json
node tools/conformance-ts/run.mjs kotlin tools/hcert-kotlin/hcert-core/build/compileSync/js/main/productionLibrary/kotlin
node tools/conformance-ts/run.mjs rust <dir written by tools/hcert-rust/build-component.sh>
node tools/conformance-ts/cross.mjs <that dir> tools/hcert-kotlin/hcert-core/build/compileSync/js/main/productionLibrary/kotlin
# A longer fuzz run
STT_FUZZ_ITERATIONS=60000 gradle -p tools/hcert-kotlin --no-daemon --init-script gradle/central-mirror.init.gradle \
  :hcert-core:jvmTest --tests '*FuzzTest*' --rerun
# The plans resolve, and the library plan is current
bun run check:req-nodes
python3 tools/test-plan/make_test_plan.py --check
# Every test has a Gherkin Scenario (test/features/); --itb <WHO-ITB checkout> resolves the @itb: tags
bun cat-harness-tools/scripts/check-test-gherkin.ts --root . --itb ../WHO-ITB
# Each system under test's bindings are current with its tests' tags (test/systems/)
python3 tools/test-systems/make_test_systems.py --check
```
