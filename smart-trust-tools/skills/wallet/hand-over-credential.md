---
name: hand-over-credential
description: >
  The health worker at the issuing side hands the holder the credentials the
  issuing system made: printed (one QR per certificate) or into the holder's
  wallet, and says what each is. Input is what was issued and the medium;
  output is what the holder now holds. Performed by a person; the issuing
  system's own steps are the hcert package's.
input: schemas/skills/hand-over-credential/input.schema.json
output: schemas/skills/hand-over-credential/output.schema.json
---

# Hand over a health credential

**Performed by a person**: the health worker of the issuing participant
(a vaccinator who prints the DVCs, a clerk at the portal desk). Role
`issuing-health-worker`. What is handed over was made by the issuing
system (`hcert-prefix-context`, or `vhl-share` for a link).

## Input and output

The contract is [`input.schema.json`](../../schemas/skills/hand-over-credential/input.schema.json)
and [`output.schema.json`](../../schemas/skills/hand-over-credential/output.schema.json).

- **In:** the `issued` credentials, each with its `member`, `kind` (`hcert`,
  `vhl` or `shl`) and `qr` text, and the `medium` (`paper` or `wallet`).
- **Out:** the `handedOver` credentials, as the holder will hold them
  ([`holder-present-credential`](holder-present-credential.md)'s input).

## What the health worker does

1. Print one QR per certificate, whole and legible, or send each to the
   holder's wallet.
2. Say what each one is and whom it is about; the holder keeps them.

## Success criteria

- Every issued credential is handed over, unchanged, labelled by member.
- Nothing is handed to anyone but the holder.
