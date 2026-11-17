---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s010-2-3-yy5-4-1-4-authentication-option-oauth-with-s
section_title: "2:3.YY5.4.1.4 Authentication option - OAuth with SSRAA Option"
file: "input/pagecontent/ITI-YY5.md"
lines: 196-276
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
##### 2:3.YY5.4.1.4 Authentication option - OAuth with SSRAA Option

Implementations that support the **OAuth with SSRAA Option** MAY use OAuth 2.0 access tokens for authentication instead of HTTP Message Signatures. This option provides interoperability with systems implementing the [HL7 Security for Scalable Registration, Authentication, and Authorization IG](http://hl7.org/fhir/us/udap-security/) (SSRAA). The following workflow description is informative only, and does not take precedence over underlying requirements from the HL7 Security for Scalable Registration, Authentication, and Authorization IG.

**Preconditions: SSRAA Discovery and Registration**

Before an access token can be obtained, the {{ linkvhlr }} and {{ linkvhls }} SHALL have completed SSRAA Discovery and Dynamic Client Registration (per SSRAA Sections 2 and 3) at least once per {{ linkvhlr }} 
/ {{ linkvhls }} pair — the FHIR Base URL of the {{ linkvhls }} comes from the VHL payload. These steps MAY take place in advance or just in time; the {{ linkvhlr }} steps are described in [Expected Actions - VHL Receiver](#23yy5416-expected-actions---vhl-receiver).

**Option Requirements:**

When both {{ linkvhlr }} and {{ linkvhls }} support the OAuth with SSRAA Option:
- SSRAA Discovery and Registration SHALL be completed before requesting access tokens
- OAuth 2.0 Backend Services authentication MAY be used
- JWT client assertions SHALL be used for client authentication
- Access token scope vocabulary is determined by trust community policies per the HL7 Security for Scalable Registration, Authentication, and Authorization IG

**Step 1: Obtain Access Token**

```http
POST /oauth/token HTTP/1.1
Host: authorization-server.example.org
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&scope=system/List.s system/DocumentReference.r system/Binary.r
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=eyJhbGciOiJSUzI1NiIsIng1YyI6WyJNSUkuLi4iLCJNSUkuLi4iXX0.eyJpc3MiOiI2QjlFRkQ3NDg4MkM0RTZDQjVFNTYxOUU4MjFDNTBGQSIsInN1YiI6IjZCOUVGRDc0ODgyQzRFNkNCNUU1NjE5RTgyMUM1MEZBIiwiYXVkIjoiaHR0cHM6Ly9hdXRob3JpemF0aW9uLXNlcnZlci5leGFtcGxlLm9yZy90b2tlbiIsImlhdCI6MTczNTY4OTYwMCwiZXhwIjoxNzM1Njg5OTAwLCJqdGkiOiJyYW5kb20tdW5pcXVlLWlkIiwiZXh0ZW5zaW9ucyI6eyJobDctYjJiIjp7InZlcnNpb24iOiIxIiwib3JnYW5pemF0aW9uX2lkIjoiaHR0cHM6Ly9kaXJlY3RvcnkuZXhhbXBsZS5vcmcvT3JnYW5pemF0aW9uL3ZobC1yZWNlaXZlci1pZCIsInB1cnBvc2Vfb2ZfdXNlIjoidXJuOm9pZDoyLjE2Ljg0MC4xLjExMzg4My4zLjE4LjcuMSNTWVNERVYifX19.signature-here


```

**JWT Client Assertion:**
- Algorithm: selected per [Cryptographic Algorithm Selection](volume-1.html#1xx53-cryptographic-algorithm-selection); the interoperability baseline is RS256
- Header: `{"alg":"RS256","typ":"JWT","x5c":["<base64-encoded-client-cert>","<base64-encoded-intermediate>"]}`
  - `x5c`: The receiver's X.509 certificate (and optionally the full chain) from the trust community PKI, per the HL7 Security for Scalable Registration, Authentication, and Authorization IG
- Payload:
  - `iss`: Client ID assigned to the {{ linkvhlr }} during SSRAA Registration (same as `sub`)
  - `sub`: Client ID assigned to the {{ linkvhlr }} during SSRAA Registration (same as `iss`)
  - `aud`: Authorization server token endpoint
  - `exp`: Expiration time (typically 5 minutes from iat)
  - `iat`: Issued at time
  - `jti`: Unique identifier for this JWT (prevents replay)
  - `extensions`: An object containing an `hl7-b2b` member with the business-to-business identity context, per Section 5.2.1 of the HL7 Security for Scalable Registration, Authentication, and Authorization IG
- Signature: Signed with receiver's private key associated with the X.509 certificate in the `x5c` header

**Token Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsIng1YyI6WyJNSUkuLi4iLCJNSUkuLi4iXX0.eyJpc3MiOiI2QjlFRkQ3NDg4MkM0RTZDQjVFNTYxOUU4MjFDNTBGQSIsInN1YiI6IjZCOUVGRDc0ODgyQzRFNkNCNUU1NjE5RTgyMUM1MEZBIiwiYXVkIjoiaHR0cHM6Ly9hdXRob3JpemF0aW9uLXNlcnZlci5leGFtcGxlLm9yZy90b2tlbiIsImlhdCI6MTczNTY4OTYwMCwiZXhwIjoxNzM1Njg5OTAwLCJqdGkiOiJyYW5kb20tdW5pcXVlLWlkIiwiZXh0ZW5zaW9ucyI6eyJobDctYjJiIjp7InZlcnNpb24iOiIxIiwib3JnYW5pemF0aW9uX2lkIjoiaHR0cHM6Ly9kaXJlY3RvcnkuZXhhbXBsZS5vcmcvT3JnYW5pemF0aW9uL3ZobC1yZWNlaXZlci1pZCIsInB1cnBvc2Vfb2ZfdXNlIjoidXJuOm9pZDoyLjE2Ljg0MC4xLjExMzg4My4zLjE4LjcuMSNTWVNERVYifX19.signature-here",
  "token_type": "Bearer",
  "expires_in": 3600,
  "scope": "system/List.s system/DocumentReference.r system/Binary.r"
}
```

**Step 2: Retrieve Manifest with Token**

```http
POST /List/_search HTTP/1.1
Host: vhl-sharer.example.org
Content-Type: application/x-www-form-urlencoded
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
Accept: application/fhir+json

_id=abc123def456&code=folder&status=current&patient.identifier=urn%3Aoid%3A2.16.840.1.113883.2.4.6.3%7CPASSPORT123&_include=List%3Aitem&recipient=Dr.+Smith+Hospital&passcode=user-pin&embeddedLengthMax=10000
```

**OAuth Token Requirements:**

- Grant Type: `client_credentials`
- Client Authentication: `private_key_jwt` (JWT client assertion)
- Required Scopes (SMART v2 vocabulary use is illustrative; specific scope requirements are determined by trust community policies per the HL7 Security for Scalable Registration, Authentication, and Authorization IG):
  - `system/List.s` - Search for List resources
  - `system/DocumentReference.r` - Read DocumentReference resources
  - `system/Binary.r` - Read Binary resources (document content)
- Token Lifetime: Typically 1 hour (3600 seconds)
- Token Reuse: Access token MAY be reused for multiple requests until expiration, consistent with underlying requirements from the HL7 Security for Scalable Registration, Authentication, and Authorization IG.

> The {{ linkvhlr }} side (SSRAA Discovery/Registration, JWT client assertion creation, access token acquisition, and Authorization-header inclusion) is described in [Expected Actions - VHL Receiver](#23yy5416-expected-actions---vhl-receiver). The {{ linkvhls }} side (Bearer token validation) is in [Expected Actions - VHL Sharer](#23yy5417-expected-actions---vhl-sharer). Security requirements are in [Security Considerations Section 2:3.YY5.5.3](#23yy553-oauth-with-ssraa-option).
