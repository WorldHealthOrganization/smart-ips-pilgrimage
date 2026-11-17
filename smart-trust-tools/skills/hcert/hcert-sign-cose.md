---
name: hcert-sign-cose
description: >
  Step 5: sign as COSE_Sign1 (ES256 or PS256) in two phases, the private key staying with its holder.
satisfies:
  - "req:stt-cbr-004#statement"
  - "req:stt-cos-001#statement"
  - "req:stt-cos-002#statement"
  - "req:stt-cos-003#statement"
  - "req:stt-cos-004#statement"
  - "req:stt-cos-005#statement"
  - "req:stt-cos-006#statement"
  - "req:stt-cwt-004#statement"
  - "req:stt-gen-001#statement"
  - "req:stt-gen-009#statement"
  - "req:stt-iss-004#statement"
  - "req:stt-kid-001#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SignCoseTest.kt
  - tools/hcert-rust/tests/build_cwt_sign_cose.rs
---

# Step 5

Step 5: sign as COSE_Sign1 (ES256 or PS256) in two phases, the private key staying with its holder.

## Library operations

In the WIT contract (`api/wit/`):

- `cose.sign1`
- `types.cose-algorithm`
- `cose.kid-from-dsc`
- `cose.ecdsa-der-to-raw`
- `issuer.pending-signature`
- `issuer.prepare`
- `verifier.verify`

## Requirements

This skill satisfies 12 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.
