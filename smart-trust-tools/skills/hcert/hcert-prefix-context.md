---
name: hcert-prefix-context
description: >
  Steps 8 and 9: the HC1: context identifier, giving a QR-ready string the application renders with its own QR encoder.
satisfies:
  - "req:stt-gen-001#statement"
  - "req:stt-hc1-001#statement"
  - "req:stt-qr-001#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/PrefixContextTest.kt
  - tools/hcert-rust/tests/prefix_context.rs
---

# hcert-prefix-context

Steps 8 and 9: the HC1: context identifier, giving a QR-ready string the application renders with its own QR encoder.

## Library operations

In the WIT contract (`api/wit/`):

- `issuer.prepare`
- `verifier.verify`
- `codec.detect-context`

## Requirements

This skill satisfies 3 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.
