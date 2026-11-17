---
name: hcert-library-architecture
description: >
  The rules every implementation follows: Kotlin first, Rust second, one contract, a synchronous core with no I/O, open standards, no payload in logs.
satisfies:
  - "req:stt-gen-002#statement"
  - "req:stt-gen-003#statement"
  - "req:stt-gen-004#statement"
  - "req:stt-gen-005#statement"
  - "req:stt-gen-006#statement"
  - "req:stt-gen-007#statement"
  - "req:stt-gen-008#statement"
  - "req:stt-gen-011#statement"
  - "req:stt-gen-012#statement"
  - "req:stt-gen-013#statement"
  - "req:stt-iss-003#statement"
  - "req:stt-nfr-001#statement"
  - "req:stt-nfr-002#statement"
  - "req:stt-sec-001#statement"
  - "req:stt-sec-002#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ArchitectureTest.kt
  - tools/hcert-kotlin/hcert-core/node-smoke.mjs
  - tools/hcert-rust/js/component/component-test.mjs
---

# hcert-library-architecture

The rules every implementation follows: Kotlin first, Rust second, one contract, a synchronous core with no I/O, open standards, no payload in logs.

## Library operations

In the WIT contract (`api/wit/`):

- `codec.cbor-deterministic`
- `cose.sign1`
- `codec.zlib-inflate`
- `codec.base45-decode`
- `codec.detect-context`
- `dvc.to-cbor`
- `subclaims.registry`
- `trust.trust-store`
- `verifier.verify`

## Requirements

This skill satisfies 15 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.
