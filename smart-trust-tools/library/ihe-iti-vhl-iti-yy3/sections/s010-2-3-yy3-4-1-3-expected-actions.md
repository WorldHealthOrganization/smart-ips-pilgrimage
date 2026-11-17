---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s010-2-3-yy3-4-1-3-expected-actions
section_title: "2:3.YY3.4.1.3 Expected Actions"
file: "input/pagecontent/ITI-YY3.md"
lines: 121-268
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
##### 2:3.YY3.4.1.3 Expected Actions
{{ reqGenerateVHLResponseDescription.valueMarkdown }}

{% include requirements-list-statements.liquid req=reqGenerateVHLResponse site=site  %}

Based on the requested `format`, the {{ linkvhls }} generates the VHL as either a QR code (HCERT/CWT-encoded per the [WHO SMART Trust HCERT specification](https://smart.who.int/trust/hcert_spec.html), with the VHL payload embedded at claim key 5) or a Verifiable Credential (JSON-LD per the [W3C VC Data Model v2](https://www.w3.org/TR/vc-data-model-2.0/), with the VHL payload under `credentialSubject`). Both carriers share the same VHL payload construction.

The generation process is as follows:

<a name="vhl-payload-construction"></a>

**VHL Payload Construction**

The VHL payload SHALL be constructed in alignment with the [SMART Health Links specification](https://hl7.org/fhir/uv/smart-health-cards-and-links/links-specification.html). The VHL Sharer SHALL:

1. Generate a unique folder ID with 256-bit entropy to serve as the List resource identifier

2. Generate a 32-byte (256-bit) random encryption key, base64url-encode it (resulting in 43 characters) - this is the 'key' parameter. The {{ linkvhlr }} uses this key to decrypt document binaries retrieved via [ITI-68](https://profiles.ihe.net/ITI/MHD/ITI-68.html); see [ITI-YY5 Document Encryption](ITI-YY5.html#23yy5425-document-encryption).

3. Construct the manifest URL as a query on the base List resource:
   - **If VHL Sharer supports the Include DocumentReference Option:**
     ```
     [base]/List?_id=[folder-id]&code=folder&status=current&patient.identifier=[sourceIdentifier-system|value]&_include=List:item
     ```
   - **If VHL Sharer does NOT support the Include DocumentReference Option:**
     ```
     [base]/List?_id=[folder-id]&code=folder&status=current&patient.identifier=[sourceIdentifier-system|value]
     ```
   
 Note: This profile requires the manifest URL to include `_id`, `code`, `status`, and `patient.identifier` (chained search on the `patient` reference parameter, in `system|value` form). [IHE MHD ITI-66 Find Document Lists](https://profiles.ihe.net/ITI/MHD/ITI-66.html) already requires the Document Consumer to include `code`, `status`, and `patient`/`patient.identifier`, and requires the Document Responder to support `_id` — this profile additionally requires `_id` to be present in every VHL manifest URL, since the folder ID is the primary authorization mechanism for the VHL (see [ITI-YY5 Section 2:3.YY5.4.1.2 FHIR Search Parameters](ITI-YY5.html#23yy5412-message-semantics) where `_id` is marked `[1..1]`). `_include=List:item` is added only when the {{ linkvhls }} supports the Include DocumentReference Option.

4. Create the VHL payload (using the SHL payload format) as a JSON object with:
   - `url`: the manifest URL from step 3
   - `key`: the base64url-encoded encryption key from step 2 (43 characters). Used by the {{ linkvhlr }} as the symmetric key for JWE `dir`/`A256GCM` decryption of document binaries; see [ITI-YY5 Document Encryption](ITI-YY5.html#23yy5425-document-encryption).
   - `exp`: (optional) expiration time in Epoch seconds, as a hint to help the VHL Receiver determine if this QR is stale
   - `flag`: (optional) flags string (e.g., 'P' for passcode, 'L' for long-term, 'U' for direct file access)
   - `label`: (optional) description string (max 80 characters)
   - `v`: version number (defaults to 1)
   - `extension`: (conditional) object containing implementation-defined extensions. Required when the {{ linkvhls }} supports the OAuth with SSRAA Option, in which case it SHALL include:
     - `fhirBaseUrl`: the FHIR base URL of the {{ linkvhls }} (e.g., `https://vhl-sharer.example.org`). This enables the {{ linkvhlr }} to perform UDAP Discovery (per Section 2 of the HL7 Security for Scalable Registration, Authentication, and Authorization IG) and Dynamic Client Registration (per Section 3) with the {{ linkvhls }} before making an authenticated manifest request via ITI-YY5.

5. The JSON Payload is then:
    - Minified
    - Base64urlencoded
    - Prefixed with vhlink:/

**Example VHL Construction:**

```json
// Step 4: VHL Payload JSON (SHL payload format, with OAuth with SSRAA extension)
{
  "url": "https://vhl-sharer.example.org/List/_search?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item",
  "key": "86F8LY5LlWAa1-OS_FgrTnYNqFHJP2ey5RSKLJBN9jk",
  "exp": 1735689600,
  "flag": "LP",
  "label": "Patient Health Summary",
  "v": 1,
  "extension": {
    "fhirBaseUrl": "https://vhl-sharer.example.org"
  }
}
```

```text
// Step 5: Minify, Base64url-encode, and prefix with vhlink:/

// Step 5a – Minified JSON:
{"url":"https://vhl-sharer.example.org/List/_search?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item","key":"86F8LY5LlWAa1-OS_FgrTnYNqFHJP2ey5RSKLJBN9jk","exp":1735689600,"flag":"LP","label":"Patient Health Summary","v":1,"extension":{"fhirBaseUrl":"https://vhl-sharer.example.org"}}

// Step 5b – Base64url-encoded:
eyJ1cmwiOiJodHRwczovL3ZobC1zaGFyZXIuZXhhbXBsZS5vcmcvTGlzdC9fc2VhcmNoP19pZD1hYmMxMjNkZWY0NTYmY29kZT1mb2xkZXImc3RhdHVzPWN1cnJlbnQmcGF0aWVudC5pZGVudGlmaWVyPXVybjpvaWQ6Mi4xNi44NDAuMS4xMTM4ODMuMi40LjYuM3xQQVNTUE9SVDEyMyZfaW5jbHVkZT1MaXN0Oml0ZW0iLCJrZXkiOiI4NkY4TFk1TGxXQWExLU9TX0ZnclRuWU5xRkhKUDJleTVSU0tMSkJOOWprIiwiZXhwIjoxNzM1Njg5NjAwLCJmbGFnIjoiTFAiLCJsYWJlbCI6IlBhdGllbnQgSGVhbHRoIFN1bW1hcnkiLCJ2IjoxLCJleHRlbnNpb25zIjp7ImZoaXJCYXNlVXJsIjoiaHR0cHM6Ly92aGwtc2hhcmVyLmV4YW1wbGUub3JnIn19

// Step 5c – Final VHL link (prefixed with vhlink:/):
vhlink:/eyJ1cmwiOiJodHRwczovL3ZobC1zaGFyZXIuZXhhbXBsZS5vcmcvTGlzdC9fc2VhcmNoP19pZD1hYmMxMjNkZWY0NTYmY29kZT1mb2xkZXImc3RhdHVzPWN1cnJlbnQmcGF0aWVudC5pZGVudGlmaWVyPXVybjpvaWQ6Mi4xNi44NDAuMS4xMTM4ODMuMi40LjYuM3xQQVNTUE9SVDEyMyZfaW5jbHVkZT1MaXN0Oml0ZW0iLCJrZXkiOiI4NkY4TFk1TGxXQWExLU9TX0ZnclRuWU5xRkhKUDJleTVSU0tMSkJOOWprIiwiZXhwIjoxNzM1Njg5NjAwLCJmbGFnIjoiTFAiLCJsYWJlbCI6IlBhdGllbnQgSGVhbHRoIFN1bW1hcnkiLCJ2IjoxLCJleHRlbnNpb25zIjp7ImZoaXJCYXNlVXJsIjoiaHR0cHM6Ly92aGwtc2hhcmVyLmV4YW1wbGUub3JnIn19

// NOTE: extension.fhirBaseUrl is only present when the VHL Sharer supports the OAuth with SSRAA Option
// The VHL link (step 5c) will be embedded in the HCERT structure (see QR Code Generation below)
```

**QR Code Generation (HCERT/CWT Encoding) — `format=qrcode`**

After constructing the VHL payload (steps 1–4 above), the {{ linkvhls }} SHALL encode it within an [HCERT](https://smart.who.int/trust/StructureDefinition-HCert.html) structure per the WHO SMART Trust specification with the VHL payload at HCERT claim 5, then generate the QR code per the [HCERT Specification](https://smart.who.int/trust/hcert_spec.html).

**Example HCERT/CWT Structure:**

```json
// CWT Claims
{
  "1": "US",                    // iss: issuer country code
  "4": 1735689600,              // exp: expiration timestamp
  "6": 1704067200,              // iat: issued at timestamp
  "-260": {                     // hcert: health certificate claim
    "5": "vhlink:/eyJ1cmwiOiJodHRwczovL3ZobC1zaGFyZXIuZXhhbXBsZS5vcmcvTGlzdC9fc2VhcmNoP19pZD1hYmMxMjNkZWY0NTYmY29kZT1mb2xkZXImc3RhdHVzPWN1cnJlbnQmcGF0aWVudC5pZGVudGlmaWVyPXVybjpvaWQ6Mi4xNi44NDAuMS4xMTM4ODMuMi40LjYuM3xQQVNTUE9SVDEyMyZfaW5jbHVkZT1MaXN0Oml0ZW0iLCJrZXkiOiI4NkY4TFk1TGxXQWExLU9TX0ZnclRuWU5xRkhKUDJleTVSU0tMSkJOOWprIiwiZXhwIjoxNzM1Njg5NjAwLCJmbGFnIjoiTFAiLCJsYWJlbCI6IlBhdGllbnQgSGVhbHRoIFN1bW1hcnkiLCJ2IjoxLCJleHRlbnNpb25zIjp7ImZoaXJCYXNlVXJsIjoiaHR0cHM6Ly92aGwtc2hhcmVyLmV4YW1wbGUub3JnIn19"
  }
}

// After signing, compressing, and Base45 encoding:
HC1:NCF3R0KLBBA...V8N8W.CE8WY
```

**VC Envelope Generation (Option — `format=vc`)**

When `format=vc` is requested and the {{ linkvhls }} supports the [VC Enveloped VHL Option](#vc-enveloped-vhl-carrier-option--formatvc), the {{ linkvhls }} SHALL construct a JSON-LD document per the [W3C VC Data Model v2](https://www.w3.org/TR/vc-data-model-2.0/) with an embedded `proof` of type `DataIntegrityProof` per the [W3C VC Data Integrity 1.0](https://www.w3.org/TR/vc-di-ecdsa/) specification (cryptosuite selected per the central [Cryptographic Algorithm Selection](volume-1.html#1xx53-cryptographic-algorithm-selection)). The `issuer` SHALL identify the {{ linkvhls }} using a key from the same trust network used for HCERT/CWT signatures — no new trust framework is introduced. The `credentialSubject` SHALL carry the VHL payload from step 4 (`url`, `key`, `flag`, `label`, `exp`, `v`, `extension`). The VC is delivered to the {{ linkvhlh }} and subsequently transmitted to the {{ linkvhlr }} per [ITI-YY4 Provide VHL](ITI-YY4.html).

**Example VC carrying the VHL payload:**

```json
{
  "@context": ["https://www.w3.org/ns/credentials/v2"],
  "type": ["VerifiableCredential", "VHLEnvelopeCredential"],
  "issuer": "did:web:vhl-sharer.example.org",
  "issuanceDate": "2024-01-01T00:00:00Z",
  "expirationDate": "2025-01-01T00:00:00Z",
  "credentialSubject": {
    "url": "https://vhl-sharer.example.org/List?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item",
    "key": "86F8LY5LlWAa1-OS_FgrTnYNqFHJP2ey5RSKLJBN9jk",
    "exp": 1735689600,
    "flag": "LP",
    "label": "Patient Health Summary",
    "v": 1,
    "extension": {
      "fhirBaseUrl": "https://vhl-sharer.example.org"
    }
  },
  "proof": {
    "type": "DataIntegrityProof",
    "cryptosuite": "ecdsa-2019",
    "created": "2024-01-01T00:00:00Z",
    "verificationMethod": "did:web:vhl-sharer.example.org#sharer-key-1",
    "proofPurpose": "assertionMethod",
    "proofValue": "z3FD9sJ8kL2m9pQ7rT4vW5xY6zAb3cD4eF5gH6iJ7kL8mN9oP0qR1sT2uV3wX4yZ"
  }
}
```

**Handling Notes**

The following handling rules apply within the steps above:

**sourceIdentifier Validation** — The {{ linkvhls }} SHALL parse `sourceIdentifier` as a FHIR `Identifier` in `system|value` form, resolve it to a known Patient, authorize the caller, and echo the exact `system|value` into the manifest URL as `patient.identifier` (never substituting `Patient.id`). In patient-constrained contexts (e.g., SMART `launch/patient` scope), mismatches with the patient-in-context SHALL be rejected with `403`. Other failures return `OperationOutcome` with `400` / `404` / `403` as appropriate.

<a name="purpose-of-use-handling"></a>

**Purpose of Use Handling (if provided)** — The {{ linkvhls }} SHALL validate each `purposeOfUse` value against [PurposeOfUse](http://terminology.hl7.org/ValueSet/v3-PurposeOfUse) (extensible binding) and persist the value(s) against the folder ID for downstream enforcement at [ITI-YY5](ITI-YY5.html). When grouped with an IHE PCF [Consent Creator](https://profiles.ihe.net/ITI/PCF/) or [Consent Recipient](https://profiles.ihe.net/ITI/PCF/), the persisted value(s) SHALL populate `Consent.provision.purpose`. `purposeOfUse` value(s) SHALL NOT be embedded in the QR code, VC, or VHL payload — they are share metadata held by the {{ linkvhls }}, not content consumed by the {{ linkvhlr }}.

**Passcode Handling (if provided)** — The {{ linkvhls }} SHALL hash the passcode with a strong one-way function (e.g., bcrypt, Argon2, PBKDF2), store the hash against the folder ID for ITI-YY5 validation, and set the `P` flag in the VHL payload. The plaintext passcode SHALL NOT appear in the VHL URL, QR code, or VC, and SHALL NOT be stored by the {{ linkvhls }}; the {{ linkvhlh }} retains it for out-of-band sharing with the {{ linkvhlr }}.
