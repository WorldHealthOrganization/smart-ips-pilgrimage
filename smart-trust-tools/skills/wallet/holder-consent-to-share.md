---
name: holder-consent-to-share
description: >
  The holder decides what a health link (a Verifiable Health Link or a SMART
  Health Link) shares: which members'
  records, protected by which passcode, until when. That choice is the
  holder's consent, and the sharer issues nothing beyond it. Input is the
  records the sharer offers; output is the share request. Performed by a
  person.
input: schemas/skills/holder-consent-to-share/input.schema.json
output: schemas/skills/holder-consent-to-share/output.schema.json
---

# Consent to share a health link

**Performed by a person**: the holder (IHE ITI VHL
[VHL Holder](https://profiles.ihe.net/ITI/VHL/volume-1.html)). Role
`vhl-holder`. The sharer that acts on the answer is `vhl-share` for a VHL;
for a [SMART Health Link](https://hl7.org/fhir/uv/smart-health-cards-and-links/links-specification.html) it is the SHL sharer, which sets the link's `P` flag and
`exp` from the same answer. Which kind of link is the sharer's, not the
holder's, choice.

## Input and output

The contract is [`input.schema.json`](../../schemas/skills/holder-consent-to-share/input.schema.json)
and [`output.schema.json`](../../schemas/skills/holder-consent-to-share/output.schema.json).

- **In:** the `offer`: the `members` whose records the sharer holds and may
  share, with the documents each has (an IPS, vaccination certificates), and
  the longest `maxExpiry` the sharer allows.
- **Out:** the `share` request: the members (and documents) chosen, the
  `passcode` the holder sets, and the `expiry`.

## What the holder does

1. Choose who is shared: one member, several, or none. Nothing is chosen by
   default.
2. Set a passcode the holder can say aloud, and an expiry no later than the
   trip or visit needs.
3. Confirm. Declining at any step shares nothing.

## Success criteria

- The share request names only what the holder chose; the sharer issues
  nothing else (`vhl-share` encrypts exactly those documents).
- The passcode is handed to the sharer once, to protect the manifest, and
  is not printed on the QR.
- With nothing chosen, no link is issued.
