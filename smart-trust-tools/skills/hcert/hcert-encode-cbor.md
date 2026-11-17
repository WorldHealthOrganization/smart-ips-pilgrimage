---
name: hcert-encode-cbor
description: >
  Step 4: serialise as RFC 8949 deterministic CBOR, and decode untrusted CBOR within limits.
satisfies:
  - "req:stt-cbr-001#statement"
  - "req:stt-cbr-002#statement"
  - "req:stt-cbr-003#statement"
  - "req:stt-cbr-004#statement"
  - "req:stt-gen-001#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/EncodeCborTest.kt
  - tools/hcert-rust/tests/encode_cbor.rs
---

# Step 4

Step 4: serialise as RFC 8949 deterministic CBOR, and decode untrusted CBOR within limits.

## Library operations

In the WIT contract (`api/wit/`):

- `codec.cbor-deterministic`
- `types.decode-limits`
- `issuer.prepare`
- `verifier.verify`

## Requirements

This skill satisfies 5 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.
