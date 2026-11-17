---
name: hcert-conformance-testing
description: >
  Test an implementation against the shared vectors: the PR 129 DVC example, negative vectors, cross-implementation checks and schema checks.
satisfies:
  - "req:stt-tst-001#statement"
  - "req:stt-tst-002#statement"
  - "req:stt-tst-003#statement"
  - "req:stt-tst-004#statement"
  - "req:stt-tst-005#statement"
  - "req:stt-tst-006#statement"
  - "req:stt-tst-007#statement"
  - "req:stt-tst-008#statement"
  - "req:stt-tst-009#statement"
  - "req:stt-tst-010#statement"
  - "req:stt-tst-011#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ConformanceVectorsTest.kt
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/FuzzTest.kt
  - tools/hcert-kotlin/hcert-core/node-smoke.mjs
  - tools/check-models/check_models.py
  - tools/hcert-rust/tests/conformance.rs
  - tools/hcert-rust/tests/fuzz.rs
  - tools/hcert-rust/tests/api.rs
  - tools/hcert-rust/js/smoke.mjs
  - tools/conformance-ts/suite.ts
  - tools/conformance-ts/cross.ts
  - tools/hcert-kotlin/hcert-core/build.gradle.kts
  - tools/hcert-rust/coverage.sh
---

# hcert-conformance-testing

Test an implementation against the shared vectors: the PR 129 DVC example, negative vectors, cross-implementation checks and schema checks.

## Requirements

This skill satisfies 8 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.
