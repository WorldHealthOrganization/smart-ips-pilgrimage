---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s012-2-3-yy5-4-1-6-expected-actions-vhl-receiver
section_title: "2:3.YY5.4.1.6 Expected Actions - VHL Receiver"
file: "input/pagecontent/ITI-YY5.md"
lines: 383-438
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
##### 2:3.YY5.4.1.6 Expected Actions - VHL Receiver

The {{ linkvhlr }} SHALL:

1. **Extract Manifest URL from VHL**:
   - Obtain manifest URL from VHL payload (ITI-YY4)
   - URL contains all FHIR search parameters (_id, code, status, and the patient identifier via chained search as patient.identifier, plus optional _include)
   - Parse URL to extract search parameters

2. **Prepare Request Parameters**:
   - Construct request body with FHIR search parameters from URL
   - Add SHL parameters:
     - recipient (required) - identifier of requesting organization/person
     - passcode (if P flag in VHL) - user-provided passcode
     - embeddedLengthMax (optional) - size hint for embedded content
   - Encode parameters as `application/x-www-form-urlencoded`

3. **Authenticate Request** (use atleast one of the following options):
   - **Option A - HTTP Message Signatures** (if supported):
     - Compute Content-Digest (SHA-256 of request body)
     - Construct signature base from HTTP components
     - Sign using receiver's private key
     - Include Content-Digest, Signature-Input, and Signature headers
   - **Option B - OAuth with SSRAA** (if supported):
     - **One-time setup:** if not already registered with this {{ linkvhls }}, perform UDAP Discovery and Dynamic Client Registration (per SSRAA Sections 2 and 3) using the FHIR Base URL from the VHL payload to obtain a client ID.
     - Create a JWT client assertion (`private_key_jwt`) signed with the receiver's trust-network private key — the X.509 cert (or chain) goes in the `x5c` header; `iss` and `sub` are the registered client ID; `aud` is the authorization server token endpoint; include `jti` and the `hl7-b2b` extension per SSRAA Section 5.2.1
     - Request an access token from the authorization server (`grant_type=client_credentials`) with appropriate scopes
     - Include the returned Bearer access token in the `Authorization` header of the manifest request
     - Reuse the access token across requests until expiration
   - **Option C - Verifiable Credential Option** (if supported):
     - Extract VHL payload fields from the decoded QR code (manifest URL, flags, label, expiration)
     - Construct LDP-VC with `credentialSubject.id` = manifest URL, `credentialSubject.manifest` = VHL payload fields (excluding encryption key), SHL manifest parameters (`recipient`, `passcode`, `embeddedLengthMax`) in `credentialSubject`
     - Compute `proof.proofValue` (DataIntegrityProof) over the VC document using trust network private key
     - Set `proof.verificationMethod` to the DID URL of the receiver's trust network key
     - POST the complete VC as `Content-Type: application/vc+ld+json` body; place FHIR search parameters in URL query string

4. **Send Request**:
   - POST to `/List/_search` endpoint at VHL Sharer's base URL
   - Include authentication credentials (HTTP signatures or OAuth token)
   - Set Content-Type: `application/x-www-form-urlencoded`
   - Set Accept: `application/fhir+json`

5. **Process Response**:
   - Receive searchset Bundle with type="searchset"
   - Identify List resources with search.mode="match"
   - Identify DocumentReference resources with search.mode="include" (if present)
   - If no DocumentReferences included and `_include` was requested:
     - VHL Sharer does not support Include DocumentReference Option
     - Use separate read requests to retrieve DocumentReferences
   - Parse List entries to identify available documents

The {{ linkvhlr }} MAY:
- Cache OAuth access tokens for reuse (OAuth with SSRAA Option)
- Implement retry logic for transient failures
- Support multiple authentication options
