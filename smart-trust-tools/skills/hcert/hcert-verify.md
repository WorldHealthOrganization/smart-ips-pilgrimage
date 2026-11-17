---
name: hcert-verify
description: >
  Verify an HC1 string or raw COSE: the steps upwards, trust lookup by kid, signature, key usage, time and payload; or read it explicitly unverified for triage.
satisfies:
  - "req:stt-b45-002#statement"
  - "req:stt-cbr-002#statement"
  - "req:stt-cbr-003#statement"
  - "req:stt-cos-002#statement"
  - "req:stt-cos-003#statement"
  - "req:stt-cos-004#statement"
  - "req:stt-cos-005#statement"
  - "req:stt-cwt-006#statement"
  - "req:stt-gen-001#statement"
  - "req:stt-gen-009#statement"
  - "req:stt-hc1-001#statement"
  - "req:stt-kid-002#statement"
  - "req:stt-pay-008#statement"
  - "req:stt-qr-005#statement"
  - "req:stt-sel-004#statement"
  - "req:stt-ver-001#statement"
  - "req:stt-ver-002#statement"
  - "req:stt-ver-003#statement"
  - "req:stt-ver-004#statement"
  - "req:stt-ver-005#statement"
  - "req:stt-ver-006#statement"
  - "req:stt-ver-007#statement"
  - "req:stt-ver-008#statement"
  - "req:stt-ver-009#statement"
  - "req:stt-ver-011#statement"
  - "req:stt-zip-002#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VerifyTest.kt
  - tools/hcert-rust/tests/verify.rs
---

# hcert-verify

Verify an HC1 string or raw COSE: the steps upwards, trust lookup by kid, signature, key usage, time and payload; or read it explicitly unverified for triage.

## Library operations

In the WIT contract (`api/wit/`):

- `codec.cbor-deterministic`
- `types.decode-limits`
- `types.cose-algorithm`
- `cose.sign1`
- `cose.kid-from-dsc`
- `cose.ecdsa-der-to-raw`
- `issuer.issue-request`
- `issuer.prepare`
- `verifier.verify`
- `codec.detect-context`
- `trust.trust-store`
- `verifier.verified-hcert`
- `verifier.verification-result`
- `subclaims.registry`
- `verifier.read-unverified`
- `codec.zlib-inflate`

## Requirements

This skill satisfies 26 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.
