---
name: hcert-compress
description: >
  Step 6: ZLIB/DEFLATE after signing, and bounded inflation.
satisfies:
  - "req:stt-gen-001#statement"
  - "req:stt-zip-001#statement"
  - "req:stt-zip-002#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/CompressTest.kt
  - tools/hcert-rust/tests/compress.rs
---

# Step 6

Step 6: ZLIB/DEFLATE after signing, and bounded inflation.

## Library operations

In the WIT contract (`api/wit/`):

- `issuer.prepare`
- `verifier.verify`
- `codec.zlib-inflate`
- `types.decode-limits`

## Requirements

This skill satisfies 3 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.
