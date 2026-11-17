---
name: hcert-build-cwt
description: >
  Step 3: wrap the payload in a CWT claim set (iss, iat, exp, hcert -260) inside the DSC's validity.
satisfies:
  - "req:stt-cbr-004#statement"
  - "req:stt-cwt-001#statement"
  - "req:stt-cwt-002#statement"
  - "req:stt-cwt-003#statement"
  - "req:stt-cwt-004#statement"
  - "req:stt-cwt-005#statement"
  - "req:stt-cwt-006#statement"
  - "req:stt-gen-001#statement"
  - "req:stt-sel-004#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/BuildCwtTest.kt
  - tools/hcert-rust/tests/build_cwt_sign_cose.rs
---

# Step 3

Step 3: wrap the payload in a CWT claim set (iss, iat, exp, hcert -260) inside the DSC's validity.

## Library operations

In the WIT contract (`api/wit/`):

- `issuer.issue-request`
- `issuer.prepare`
- `verifier.verify`
- `verifier.verified-hcert`

## Requirements

This skill satisfies 9 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.
