---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s013-2-3-yy3-4-2-2-message-semantics
section_title: "2:3.YY3.4.2.2  Message Semantics"
file: "input/pagecontent/ITI-YY3.md"
lines: 275-305
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
##### 2:3.YY3.4.2.2  Message Semantics

See [ITI TF-2: Appendix Z.6](https://profiles.ihe.net/ITI/TF/Volume2/ch-Z.html#z.6-populating-the-expected-response-format) for more details on response format handling.

The response message is a FHIR operation response (<http://hl7.org/fhir/operations.html#response>).

On Failure, the response message is an HTTP status code of 4xx or 5xx
indicates an error, and an OperationOutcome Resource shall be returned
with details.

**Success Response:**

The response SHALL include exactly one of the following output parameters, selected by the `format` input:

| Parameter | Type | Cardinality | Description |
|-----------|------|-------------|-------------|
| qrcode | Binary | [0..1] | QR code image containing HCERT-encoded VHL. Populated when `format=qrcode` or when format is absent, as the default format. |
| verifiableCredential | Binary | [0..1] | A Verifiable Credential (`application/vc+ld+json`) carrying the VHL. Populated when `format=vc` and the VHL Sharer supports the [VC Enveloped VHL Carrier Option](#vc-enveloped-vhl-carrier-option--formatvc). |
{: .grid}

**QR Code Output:**
- SHALL be encoded as HCERT with `HC1:` prefix
- SHALL contain the VHL payload embedded in HCERT claim structure (claim key -260, key 5)
- SHALL be suitable for camera scanning
- SHALL be in PNG or SVG format

**Verifiable Credential Output (VC Enveloped VHL Option only):**
- SHALL be a JSON-LD document per W3C VC Data Model v2 with `Content-Type: application/vc+ld+json`
- SHALL carry the VHL payload under `credentialSubject` (same fields otherwise embedded at HCERT claim key 5)
- SHALL be signed by the VHL Sharer using a `DataIntegrityProof` with its trust-network key (cryptosuite selected per [Cryptographic Algorithm Selection](volume-1.html#1xx53-cryptographic-algorithm-selection))
