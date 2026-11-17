---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s013-2-3-yy5-4-1-7-expected-actions-vhl-sharer
section_title: "2:3.YY5.4.1.7 Expected Actions - VHL Sharer"
file: "input/pagecontent/ITI-YY5.md"
lines: 439-560
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
##### 2:3.YY5.4.1.7 Expected Actions - VHL Sharer

Upon receiving Retrieve Manifest Request, the {{ linkvhls }} SHALL:

1. **Parse Request**:
   - Extract FHIR search parameters from request body
   - Extract SHL parameters (recipient, passcode, embeddedLengthMax)
   - Identify authentication method used (HTTP signatures or OAuth token)

2. **Authenticate Receiver**:
   - **HTTP Message Signatures**:
     - Extract `keyid` from Signature-Input header
     - Retrieve receiver's public key from trust list using `keyid`
     - Reconstruct signature base from request components
     - Verify signature using receiver's public key
     - Verify Content-Digest matches request body
     - Verify `created` timestamp is within acceptable range (±2 minutes)
     - Reject if signature invalid or receiver not in trust list (401 Unauthorized)
   - **OAuth with SSRAA Option**:
     - Extract Bearer token from Authorization header
     - Validate that the token was issued by the authorization server
     - Verify token expiration
     - Verify token scope authorizes access to the VHL
     - Reject if token invalid or expired (401 Unauthorized)
   - **Verifiable Credential Option**:
     - Parse `application/vc+ld+json` request body as JSON-LD VC document
     - Resolve `proof.verificationMethod` DID URL to retrieve {{ linkvhlr }}'s public key from the trust network
     - Verify the **`proof.proofValue`** (DataIntegrityProof) over the VC document using the retrieved trust network key
     - Verify `proof.proofPurpose` is `assertionMethod`
     - Verify VC `expirationDate` has not passed; verify `proof.created` freshness (±2 minutes recommended)
     - Verify `credentialSubject.id` matches the `_id` URL query parameter
     - Extract SHL params from `credentialSubject` (`recipient`, `passcode`, `embeddedLengthMax`)
     - Reject if any verification fails (401 Unauthorized)

3. **Authorize Request**:
   - Validate folder ID (_id parameter) corresponds to valid VHL
   - Verify VHL signature matches original issuance
   - Confirm VHL not expired (check against exp claim in HCERT)
   - Verify VHL not revoked (check revocation list if maintained)
   - If passcode provided:
     - Verify VHL requires passcode (P flag present)
     - Validate passcode against stored hash (secure comparison)
     - Reject if passcode incorrect (422 Unprocessable Entity)
   - Confirm VHL authorizes requested documents
   - Reject if authorization fails (403 Forbidden)

4. **Execute Search**:
   - Query for List resource matching FHIR search parameters:
     - _id (folder ID - required)
     - code (typically "folder" - required)
     - status (typically "current" - required)
     - patient.identifier (chained search on the patient reference parameter - required)
   - Validate List exists and is accessible
   - Apply VHL scope filters (only include documents authorized by VHL)
   - Apply consent filters if applicable
   - If `_include=List:item` parameter present:
     - **If {{ linkvhls }} supports Include DocumentReference Option:**
       - Retrieve DocumentReference resources referenced by List.entry.item
       - Apply VHL scope and consent filters to DocumentReferences
       - Include DocumentReferences in response Bundle with search.mode="include"
     - **If {{ linkvhls }} does NOT support Include DocumentReference Option:**
       - Ignore `_include` parameter
       - Return only List resource in response
       - {{ linkvhlr }} will retrieve DocumentReferences separately

5. **Prepare Response**:
   - Construct FHIR Bundle with type="searchset"
   - Add List resource with search.mode="match"
   - If Include DocumentReference Option supported and `_include` used:
     - Add DocumentReference resources with search.mode="include"
   - Set Bundle.total to count of matching resources
   - Include only documents authorized by VHL

6. **Return Response**:
   - Send HTTP 200 OK with FHIR Bundle (application/fhir+json)
   - Handle errors with appropriate HTTP status codes

The {{ linkvhls }} MAY:
- Record audit event per **[Audit Event – Accessed Health Data](Requirements-AuditEventAccess.html)**
- Implement rate limiting per receiver or per folder ID
- Log failed authentication/authorization attempts
- Provide OperationOutcome with error details

**Supported Search Parameters:**

Per the [VHL Sharer Server Capability Statement](CapabilityStatement-VHLSharerCapabilityStatement.html), the {{ linkvhls }} SHALL support:
- `_id` (token) - Required
- `code` (token) - Required
- `status` (token) - Required
- `patient.identifier` (chained search on the patient reference parameter, token — `system|value`) - required. This is the same business identifier the VHL Holder supplied as `sourceIdentifier` at ITI-YY3. The direct `patient` reference parameter is not used in VHL manifest URLs.

The {{ linkvhls }} that supports the **Include DocumentReference Option** SHALL additionally support:
- `_include=List:item` (special)

**Error Responses:**

| HTTP Status | Condition | OperationOutcome.issue.code |
|-------------|-----------|------------------------------|
| 400 Bad Request | Malformed request or missing required parameters | invalid |
| 401 Unauthorized | Signature verification failed, token invalid, or receiver not in trust list | security |
| 403 Forbidden | VHL expired, revoked, or doesn't authorize documents | forbidden |
| 404 Not Found | List resource with specified _id not found | not-found |
| 422 Unprocessable Entity | Invalid passcode or passcode required but not provided | invalid |
| 429 Too Many Requests | Rate limit exceeded | throttled |
| 500 Internal Server Error | Server-side error during processing | exception |
{: .grid}

**Example Error Response:**

```json
{
  "resourceType": "OperationOutcome",
  "issue": [
    {
      "severity": "error",
      "code": "security",
      "diagnostics": "HTTP signature verification failed: signature does not match"
    }
  ]
}
```
