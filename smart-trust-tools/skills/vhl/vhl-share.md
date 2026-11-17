---
name: vhl-share
description: >
  Issue a VHL: a key, documents encrypted as JWE dir / A256GCM, and the payload as a CBOR map at HCERT key 5 (journey J4.0). A plain SMART Health Link is issued by the same steps with its own carrier.
satisfies:
  - "req:stt-vhl-001#statement"
  - "req:stt-vhl-002#statement"
  - "req:stt-vhl-003#statement"
  - "req:stt-vhl-004#statement"
  - "req:stt-vhl-007#statement"
  - "req:stt-vhl-010#statement"
tested-by:
  - tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlShareTest.kt
  - tools/hcert-rust/tests/vhl_share.rs
---

# Issue a VHL

Issue a VHL: a key, documents encrypted as JWE dir / A256GCM, and the payload as a CBOR map at HCERT key 5 (journey J4.0).

## Library operations

In the WIT contract (`api/wit/`):

- `vhl.vhl-payload`
- `payloads.raw-payload`
- `vhl.to-vhlink`
- `vhl.new-key`
- `vhl.decrypt`
- `vhl.build-manifest-request`

## Requirements

This skill satisfies 6 requirement(s), listed in `satisfies` above; each is a `req:` node in `skills/requirements/`.

## A SMART Health Link is the same issue, with another carrier

A VHL is a [SMART Health Link](https://hl7.org/fhir/uv/smart-health-cards-and-links/links-specification.html) payload carried, signed, in an HCERT
(what smart-ips-pilgrimage calls a "Verifiable SHL"). A plain SHL is issued
by the same steps (the key, each document encrypted, the manifest, the
passcode flag `P` and `exp` from the holder's consent,
`holder-consent-to-share`) with the payload as `shlink:/` and base64url JSON
instead of HCERT key 5, so it is not signed and the hcert steps are skipped.
This skill covers both; the requirements above are the VHL's.
