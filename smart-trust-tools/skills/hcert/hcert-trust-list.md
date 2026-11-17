---
name: hcert-trust-list
description: >
  Hold the trusted DSCs the host obtained (PEM, DER, GDHCN DID trustlist v2) and find every candidate for a kid.
satisfies:
  - "req:stt-kid-001#statement"
  - "req:stt-kid-002#statement"
  - "req:stt-kid-003#statement"
  - "req:stt-sel-006#statement"
  - "req:stt-tru-001#statement"
  - "req:stt-tru-002#statement"
  - "req:stt-tru-005#statement"
  - "req:stt-tru-006#statement"
  - "req:stt-ver-006#statement"
  - "req:stt-ver-009#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt
  - tools/hcert-rust/tests/trust_list.rs
---

# hcert-trust-list

Hold the trusted DSCs the host obtained (PEM, DER, GDHCN DID trustlist v2) and find every candidate for a kid.

## Library operations

In the WIT contract (`api/wit/`):

- `cose.kid-from-dsc`
- `trust.trust-store`
- `verifier.verify`

## Requirements

This skill satisfies 9 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.
