---
name: vhl-receive
description: >
  Use a VHL: verify it, build the ITI-YY5 manifest request with its HTTP Message Signature, read the manifest Bundle and decrypt each document (journey J4.1). A plain SMART Health Link is received by the same steps, without the HCERT verification.
satisfies:
  - "req:stt-vhl-002#statement"
  - "req:stt-vhl-005#statement"
  - "req:stt-vhl-006#statement"
  - "req:stt-vhl-007#statement"
  - "req:stt-vhl-008#statement"
  - "req:stt-vhl-009#statement"
  - "req:stt-vhl-010#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlReceiveTest.kt
  - tools/hcert-rust/tests/vhl_receive.rs
---

# Use a VHL

Use a VHL: verify it, build the ITI-YY5 manifest request with its HTTP Message Signature, read the manifest Bundle and decrypt each document (journey J4.1).

## Library operations

In the WIT contract (`api/wit/`):

- `vhl.vhl-payload`
- `payloads.raw-payload`
- `vhl.build-manifest-request`
- `vhl.parse-manifest`
- `vhl.decrypt`
- `vhl.build-signature-base`

## Requirements

This skill satisfies 7 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.

## A SMART Health Link is the same receipt, with another carrier

A plain [SMART Health Link](https://hl7.org/fhir/uv/smart-health-cards-and-links/links-specification.html) (`shlink:/`, from
`receiver-scan-credential`) is followed by the same steps: the manifest
request with the passcode when its `P` flag is set, the manifest, and each
document decrypted. It carries no HCERT, so there is no signature to verify
(`hcert-verify` is skipped) and the receiver cannot tell who issued the link.
A "Verifiable SHL" (smart-ips-pilgrimage's term) is a VHL, verified as above.
