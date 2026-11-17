---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s005-4-step-3-build-the-cwt-claim-set
section_title: "4. Step 3 — Build the CWT claim set"
file: "input/pagecontent/qr_code_generation.md"
lines: 86-100
source_sha256: 03253100cd38b5c6
granularity: heading
---
#### 4. Step 3 — Build the CWT claim set

Place the payload under its subclaim, inside the `hcert` claim, inside a
[CWT claim set](StructureDefinition-CWTPayload.html) — see that model for the
claim keys and types, and
[section 3.2](hcert_spec.html#32-cwt-claims) of the specification for their
normative definitions.

`exp` deserves attention because it is the only revocation mechanism this
specification offers: certificates cannot be reliably revoked once issued, so
the validity period must be chosen to bound the damage from a compromised key,
balanced against the holder's ability to come back for a reissue. It must not
exceed the DSC's own validity period, and `iat` must not predate it. See
[section 6.1](hcert_spec.html#61-hcert-signature-validity-time).
