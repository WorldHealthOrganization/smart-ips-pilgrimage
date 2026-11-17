---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s009-2-3-yy5-4-1-3-authentication-option-http-message
section_title: "2:3.YY5.4.1.3 Authentication Option - HTTP Message Signatures"
file: "input/pagecontent/ITI-YY5.md"
lines: 139-195
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
##### 2:3.YY5.4.1.3 Authentication Option - HTTP Message Signatures

Implementations MAY authenticate using **HTTP Message Signatures** per RFC 9421. HTTP Message Signatures provide cryptographic proof of the receiver's identity, request integrity, and non-repudiation.

**Request Structure:**

```http
POST /List/_search HTTP/1.1
Host: vhl-sharer.example.org
Content-Type: application/x-www-form-urlencoded
Content-Length: 234
Content-Digest: sha-256=X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=
Signature-Input: sig1=("@method" "@path" "@authority" "content-type" "content-digest");created=1735689600;keyid="receiver-key-123";alg="ecdsa-p256-sha256"
Signature: sig1=:K2qGT5srn2OGbOIDzQ6kYT+ruaycnDAAUpKv+ePFfD6...:
Accept: application/fhir+json

_id=abc123def456&code=folder&status=current&patient.identifier=urn%3Aoid%3A2.16.840.1.113883.2.4.6.3%7CPASSPORT123&_include=List%3Aitem&recipient=Dr.+Smith+Hospital&passcode=user-pin&embeddedLengthMax=10000
```

**HTTP Signature Components:**

1. **Content-Digest Header:**
   - SHA-256 hash of the request body
   - Format: `sha-256=<base64-encoded-hash>`
   - SHALL be included for POST requests with body

2. **Signature-Input Header:**
   - Metadata about the signature
   - Components signed: `@method`, `@path`, `@authority`, `content-type`, `content-digest`
   - `created`: Unix timestamp when signature was created
   - `keyid`: Identifier of receiver's public key (used to locate key in trust list)
   - `alg`: Signature algorithm — selected per [Cryptographic Algorithm Selection](volume-1.html#1xx53-cryptographic-algorithm-selection)

3. **Signature Header:**
   - Contains the actual cryptographic signature
   - Format: `sig1=:<base64-encoded-signature>:`
   - Signature is computed over the signature base constructed from the signed components

**Signature Base Construction:**

The signature base is constructed per RFC 9421 from the signed components:

```
"@method": POST
"@path": /List/_search
"@authority": vhl-sharer.example.org
"content-type": application/x-www-form-urlencoded
"content-digest": sha-256=X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=
"@signature-params": ("@method" "@path" "@authority" "content-type" "content-digest");created=1735689600;keyid="receiver-key-123";alg="ecdsa-p256-sha256"
```

**Signature Algorithms:**

Signature algorithms are selected per [Cryptographic Algorithm Selection](volume-1.html#1xx53-cryptographic-algorithm-selection).

> The {{ linkvhlr }} signing steps are described in [Expected Actions - VHL Receiver](#23yy5416-expected-actions---vhl-receiver). The {{ linkvhls }} verification steps are described in [Expected Actions - VHL Sharer](#23yy5417-expected-actions---vhl-sharer). Security requirements are in [Security Considerations Section 2:3.YY5.5.2](#23yy552-http-message-signatures).
