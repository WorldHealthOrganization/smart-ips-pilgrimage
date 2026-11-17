---
doc_id: ihe-iti-vhl-iti-yy4
doc_title: "IHE VHL ITI-YY4 Provide VHL"
section_id: s010-2-3-yy4-4-1-4-expected-actions-vhl-receiver
section_title: "2:3.YY4.4.1.4 Expected Actions - VHL Receiver"
file: "input/pagecontent/ITI-YY4.md"
lines: 103-288
source_sha256: a01169d66ede4502
granularity: heading
---
##### 2:3.YY4.4.1.4 Expected Actions - VHL Receiver

{{ provideVHLRespDescription.valueMarkdown }}

The VHL Receiver SHALL decode the received VHL using the appropriate path below. Upon receiving a VHL via QR code, the VHL Receiver SHALL perform the following 9-step decoding process. When the VHL is received as a Verifiable Credential (VC Enveloped VHL Option), see the VC Decoding section further below.

1. **Scan QR Code**:
   - Use QR code scanner (camera, dedicated scanner, or software library)
   - Capture QR code image displayed on screen or printed on paper
   - Decode the QR code per ISO/IEC 18004:2015 in Alphanumeric mode
   - Provide visual feedback to user during scanning process

2. **Verify Context Identifier**:
   - Extract the complete string from the QR code
   - Verify the string begins with `HC1:` prefix (HCERT context identifier)
   - If prefix is missing or incorrect, reject and inform user
   - Remove the `HC1:` prefix from the string

3. **Base45 Decode**:
   - Decode the remaining string using Base45 decoding algorithm
   - Result is a compressed byte array
   - Handle any Base45 decoding errors appropriately

4. **Decompress ZLIB/DEFLATE**:
   - Decompress the byte array using ZLIB (RFC 1950) with DEFLATE (RFC 1951)
   - Result is a CBOR-encoded CWT structure
   - Handle decompression errors (corrupted data, invalid format)

5. **Parse CBOR Web Token (CWT)**:
   - Parse the decompressed bytes as CBOR per RFC 8392
   - Extract the CWT structure containing protected header and claims
   - Protected header contains:
     - `alg` (algorithm): selected per [Cryptographic Algorithm Selection](volume-1.html#1xx53-cryptographic-algorithm-selection)
     - `kid` (key identifier): 8-byte truncated SHA-256 of DSC
   - Handle CBOR parsing errors

6. **Verify Digital Signature**:
   - Extract `kid` from CWT protected header
   - Retrieve corresponding Document Signing Certificate (DSC) from trust list
   - Verify the COSE signature (RFC 8152) using DSC public key
   - Confirm signature is valid and CWT has not been tampered with
   - Reject if signature invalid or DSC not trusted

7. **Extract and Validate CWT Claims**:
   - Extract CWT claims:
     - `iss` (issuer, claim key 1): ISO 3166-1 alpha-2 country code (optional)
     - `iat` (issued at, claim key 6): timestamp in NumericDate format
     - `exp` (expiration, claim key 4): timestamp in NumericDate format
     - `hcert` (health certificate, claim key -260): HCERT payload object
   - Validate `exp` - reject if current time > expiration
   - Validate `iat` is not in the future

8. **Extract VHL Payload from HCERT**:
   - Within the `hcert` claim (claim key -260), locate claim key 5
   - Claim key 5 contains the VHL payload (conforming to the SHL payload format) with:
     - `url`: manifest URL (required) - includes all mandatory FHIR search parameters
     - `key`: base64url-encoded decryption key, 43 characters (required). The {{ linkvhlr }} caches this key for the VHL session and uses it as the symmetric key for JWE `dir`/`A256GCM` decryption of document binaries retrieved via [ITI-68](https://profiles.ihe.net/ITI/MHD/ITI-68.html); see [ITI-YY5 Document Encryption](ITI-YY5.html#23yy5425-document-encryption).
     - `flag`: flags such as "L" for long-term, "P" for passcode (optional)
     - `label`: human-readable description (optional)
     - `exp`: expiration timestamp in seconds since epoch (optional)
     - `v`: version number (optional)
   - Validate VHL payload structure conforms to the SHL payload format (per the SMART Health Links specification)

9. **Validate VHL Payload**:
   - Verify `url` field is present and is a valid HTTPS URL
   - Verify `key` field is present and is 43 characters (base64url-encoded 32 bytes)
   - Check the payload's `exp` (if present) - reject if current time > expiration
   - Note `flag` value:
     - "L" indicates long-term use
     - "P" indicates passcode required (obtain from VHL Holder)
     - "LP" indicates both long-term and passcode-protected
   - Validate `url` contains expected manifest endpoint format with mandatory parameters

**Verifiable Credential Decoding (VC Enveloped VHL Option):**

When the VHL is received as a Verifiable Credential instead of a QR code, the VHL Receiver SHALL instead:

1. **Parse VC**: Parse the received bytes as a JSON-LD document per [W3C VC Data Model v2](https://www.w3.org/TR/vc-data-model-2.0/). Reject if the media type is not `application/vc+ld+json` or parsing fails.
2. **Verify DataIntegrityProof**: Resolve the `proof.verificationMethod` to the VHL Sharer's key via the trust list (same DSC/trust framework used for CWT verification), then verify the `DataIntegrityProof` per [W3C Verifiable Credential Data Integrity 1.0](https://www.w3.org/TR/vc-data-integrity/). Reject if the proof is invalid or the issuer is untrusted.
3. **Validate Dates**: Reject if `expirationDate` has passed or `issuanceDate` is in the future.
4. **Extract VHL Payload**: Read the VHL payload fields (`url`, `key`, `flag`, `label`, `exp`, `v`, `extension`) directly from `credentialSubject` — these are the same fields otherwise embedded at HCERT claim key 5.
5. **Validate VHL Payload**: Apply the same validation as step 9 above (valid HTTPS `url`, 43-character `key`, `exp` not passed, flag handling).

The VHL Receiver then continues with Post-Decoding Actions below as in the QR code path.

**Post-Decoding Actions:**

After successfully decoding the VHL payload (from either QR code or VC), the VHL Receiver SHALL:

1. **Store Decryption Key Securely**:
   - The `key` parameter from the VHL payload is required to decrypt documents
   - Store the key securely in memory for the session
   - The key will be used during document retrieval (ITI-YY6) to decrypt document contents

2. **Parse Manifest URL**:
   - Extract the manifest URL from the VHL payload
   - The URL format from ITI-YY3 includes mandatory FHIR search parameters:
     - `_id`: The folder ID
     - `code`: Typically "folder"
     - `status`: Typically "current"
     - `patient.identifier`: Patient business identifier via FHIR chained search on the patient reference parameter, in `system|value` format. This is the same identifier the VHL Holder supplied as `sourceIdentifier` at [ITI-YY3](ITI-YY3.html).
     - `_include=List:item`: (if VHL Sharer supports Include DocumentReference Option)
   - Example: `https://vhl-sharer.example.org/List?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item`

3. Prepare to Retrieve Manifest as per ITI-YY5

The VHL Receiver MAY:
- Prompt user for passcode if "P" flag is present (required for ITI-YY5)
- Display VHL label/description to user
- Record audit event per **[Audit Event – Received Health Data](Requirements-AuditEventReceived.html)**
- Cache VHL payload for subsequent access attempts

**Decoding Example (QR Code with HCERT):**

```
Input QR Code Content:
HC1:NCF3R0KLBBA...V8N8W.CE8WY

Step 1: Verify and remove HC1: prefix → NCF3R0KLBBA...V8N8W.CE8WY
Step 2: Base45 decode → [compressed bytes]
Step 3: ZLIB/DEFLATE decompress → [CBOR bytes]
Step 4: Parse CBOR as CWT → Extract protected header (alg: ES256, kid: 8-byte SHA-256)
Step 5: Verify COSE signature using DSC from trust list based on kid
Step 6: Extract CWT claims:
  - iss (claim 1): "US"
  - iat (claim 6): 1704067200
  - exp (claim 4): 1735689600
  - hcert (claim -260): {...}
Step 7: Within hcert (claim -260), extract claim key 5 (VHL payload):
  {
    "url": "https://vhl-sharer.example.org/List/_search?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item",
    "key": "dGhpcyBpcyBhIHNlY3JldCBrZXkgdXNlZCBmb3IgZW5j",
    "flag": "LP",
    "exp": 1735689600,
    "label": "Patient Health Summary",
    "v": 1
  }
Step 8: Validate VHL payload fields
Step 9: Parse manifest URL to extract FHIR search parameters
Step 10: Prepare for ITI-YY5 Retrieve Manifest
```

**Manifest URL Parsing:**

The manifest URL from the VHL payload contains all parameters needed for ITI-YY5 Part 1 (fhir-parameters):

```
URL: https://vhl-sharer.example.org/List?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item

Parsed FHIR Search Parameters (for ITI-YY5 Part 1):
- _id=abc123def456
- code=folder
- status=current
- patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123
- _include=List:item (if present, indicates VHL Sharer supports Include DocumentReference Option)
```

**Error Handling:**

If QR code scanning or decoding fails:
- QR unreadable or damaged
- Invalid HC1: prefix
- Base45 decode error
- ZLIB decompression error
- CBOR parse error
- Invalid CWT structure
- Missing hcert claim or claim key 5
- Signature verification failure

VHL Receiver SHALL:
- Reject the VHL
- Inform user with specific error message
- Request user to rescan QR code
- NOT attempt to retrieve documents

If signature verification fails:
- VHL Receiver SHALL reject the VHL
- VHL Receiver SHALL NOT attempt to retrieve documents
- VHL Receiver SHOULD inform user/operator
- VHL Receiver MAY log failed verification

If VHL expired (either exp in CWT or VHL payload):
- VHL Receiver SHALL reject the VHL
- VHL Receiver SHOULD inform user/operator
- User may request new VHL from VHL Holder
