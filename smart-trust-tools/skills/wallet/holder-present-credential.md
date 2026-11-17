---
name: holder-present-credential
description: >
  The holder shows the one health credential a receiver asks for, as a QR:
  an HCERT (HC1:) on paper or in a wallet app, or a health link: the HCERT
  carrying a Verifiable Health Link, or a SMART Health Link (shlink:/). Input is what the holder holds and what is asked
  for; output is the QR shown. Performed by a person; the library has no
  holder-side operation.
input: schemas/skills/holder-present-credential/input.schema.json
output: schemas/skills/holder-present-credential/output.schema.json
---

# Present a health credential

**Performed by a person**: the holder (IHE ITI VHL
[VHL Holder](https://profiles.ihe.net/ITI/VHL/volume-1.html), smart-trust
Holder), often a parent presenting a child's records. Role `vhl-holder`.

## Input and output

The contract is [`input.schema.json`](../../schemas/skills/holder-present-credential/input.schema.json)
and [`output.schema.json`](../../schemas/skills/holder-present-credential/output.schema.json).

- **In:** the `credentials` held, each with the `member` it is about, its
  `kind` (`hcert`, `vhl` or `shl`), its `medium` (`paper` or `wallet`) and
  its `qr` text (`HC1:…` for an HCERT or VHL, `shlink:/…` for a SMART Health
  Link); and the `request`: which member, and which kind.
- **Out:** the credential `shown`, and when it is a health link whose
  manifest needs a passcode (VHL, or an SHL with the `P` flag), that the
  holder must now say it (`passcodeToSay`).

## Preconditions

The credential was issued to the holder (an HCERT by the issuing system,
`hcert-prefix-context`; a VHL by the sharer, `vhl-share`; an SHL by its
sharer, per the [SMART Health Link](https://hl7.org/fhir/uv/smart-health-cards-and-links/links-specification.html) specification).

## What the holder does

1. Pick the credential asked for, and only it: one member, one QR.
2. Show the QR whole and steady (paper flat, screen bright); the receiver
   scans it ([`receiver-scan-credential`](receiver-scan-credential.md)).
3. For a passcode-protected health link, say the passcode to the health worker; it
   is never printed beside the QR.

## Success criteria

- The receiver reads exactly the `qr` of the credential asked for.
- Nothing about any other member is shown.
