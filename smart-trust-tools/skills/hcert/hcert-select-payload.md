---
name: hcert-select-payload
description: >
  Step 1: choose the logical model and hcert subclaim for a use case, from the registry the IG defines.
satisfies:
  - "req:stt-gen-001#statement"
  - "req:stt-sel-001#statement"
  - "req:stt-sel-002#statement"
  - "req:stt-sel-003#statement"
  - "req:stt-sel-004#statement"
  - "req:stt-sel-006#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SelectPayloadTest.kt
  - tools/hcert-rust/tests/payload.rs
---

# Step 1

Step 1: choose the logical model and hcert subclaim for a use case, from the registry the IG defines.

## Library operations

In the WIT contract (`api/wit/`):

- `issuer.prepare`
- `verifier.verify`
- `types.subclaim`
- `subclaims.registry`
- `verifier.verified-hcert`

## Requirements

This skill satisfies 6 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.
