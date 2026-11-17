---
name: hcert-assemble-payload
description: >
  Step 2: build and validate the payload against its logical model (DVCMin, or a VHL payload), keeping unknown elements.
satisfies:
  - "req:stt-gen-001#statement"
  - "req:stt-pay-001#statement"
  - "req:stt-pay-002#statement"
  - "req:stt-pay-003#statement"
  - "req:stt-pay-004#statement"
  - "req:stt-pay-005#statement"
  - "req:stt-pay-007#statement"
  - "req:stt-pay-008#statement"
  - "req:stt-pay-009#statement"
  - "req:stt-pay-010#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/AssemblePayloadTest.kt
  - tools/hcert-rust/tests/payload.rs
---

# Step 2

Step 2: build and validate the payload against its logical model (DVCMin, or a VHL payload), keeping unknown elements.

## Library operations

In the WIT contract (`api/wit/`):

- `issuer.prepare`
- `verifier.verify`
- `dvc.dvc-min`
- `dvc.to-cbor`
- `dvc.dvc-min-vaccine-details`
- `payloads.raw-payload`

## Requirements

This skill satisfies 10 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.
