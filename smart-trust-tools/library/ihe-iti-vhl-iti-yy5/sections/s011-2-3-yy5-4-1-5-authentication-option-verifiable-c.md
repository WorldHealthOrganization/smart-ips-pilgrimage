---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s011-2-3-yy5-4-1-5-authentication-option-verifiable-c
section_title: "2:3.YY5.4.1.5 Authentication Option - Verifiable Credential Option"
file: "input/pagecontent/ITI-YY5.md"
lines: 277-382
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
##### 2:3.YY5.4.1.5 Authentication Option - Verifiable Credential Option

Implementations that support the **Verifiable Credential Option** MAY use a self-issued JSON-LD Verifiable Credential (LDP-VC) for authentication. In this option the {{ linkvhlr }} constructs a VC whose `credentialSubject` is the manifest decoded from the VHL (received as a QR code or as a Verifiable Credential per [ITI-YY4](ITI-YY4.html)), and whose embedded **DataIntegrityProof** is signed with the {{ linkvhlr }}'s key from the trust network. The VC is sent directly as the HTTP POST body with `Content-Type: application/vc+ld+json`. No additional HTTP-level signing is required; the DataIntegrityProof inside the VC document is the cryptographic proof of the receiver's identity and QR possession.

**Preconditions:**

Before using the Verifiable Credential Option, the {{ linkvhlr }} SHALL:
- Hold a key pair registered in the trust network (obtained via ITI-YY2 Retrieve Trust List with DID)
- Have decoded the VHL (from QR code or from a Verifiable Credential per the VC Enveloped VHL) and extracted the VHL payload (manifest URL, flags, label, etc.) via ITI-YY4

**Self-Issued VC Construction:**

The {{ linkvhlr }} SHALL construct the VC as a JSON-LD document per the [W3C Verifiable Credentials Data Model v2](https://www.w3.org/TR/vc-data-model-2.0/) with an embedded `proof` of type `DataIntegrityProof` per the [W3C Verifiable Credential Data Integrity 1.0](https://www.w3.org/TR/vc-data-integrity/) specification:

```json
{
  "@context": [
    "https://www.w3.org/ns/credentials/v2"
  ],
  "type": ["VerifiableCredential", "VHLManifestCredential"],
  "issuer": "did:web:vhl-receiver.example.org",
  "issuanceDate": "2024-01-15T10:00:00Z",
  "expirationDate": "2024-01-15T10:05:00Z",
  "credentialSubject": {
    "id": "https://vhl-sharer.example.org/List?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item",
    "manifest": {
      "url": "https://vhl-sharer.example.org/List?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item",
      "exp": 1735689600,
      "flag": "LP",
      "label": "Patient Health Summary",
      "v": 1
    },
    "recipient": "Dr. Smith Hospital",
    "passcode": "user-pin",
    "embeddedLengthMax": 10000
  },
  "proof": {
    "type": "DataIntegrityProof",
    "cryptosuite": "ecdsa-2019",
    "created": "2024-01-15T10:00:00Z",
    "verificationMethod": "did:web:vhl-receiver.example.org#receiver-key-123",
    "proofPurpose": "assertionMethod",
    "proofValue": "z3FD9sJ8kL2m9pQ7rT4vW5xY6zAb3cD4eF5gH6iJ7kL8mN9oP0qR1sT2uV3wX4yZ"
  }
}
```

**VC Fields:**

| Field | Description |
|-------|-------------|
| `issuer` | The {{ linkvhlr }}'s DID or identifier corresponding to its trust network key |
| `issuanceDate` | Timestamp when the VC was created |
| `expirationDate` | Expiration (SHALL be short-lived; recommended: 5 minutes from `issuanceDate`) |
| `credentialSubject.id` | The manifest URL — binds the VC to the specific manifest decoded from the QR code |
| `credentialSubject.manifest` | VHL payload fields from the QR code: MUST include `url`; SHOULD include `exp`, `flag`, `label`, `v`; SHALL NOT include the encryption `key` |
| `credentialSubject.recipient` | Identifier of the requesting organization or person (replaces SHL `recipient` body parameter) |
| `credentialSubject.passcode` | User-provided passcode if the VHL is passcode-protected (replaces SHL `passcode` body parameter) |
| `credentialSubject.embeddedLengthMax` | Optional size hint for embedded content (replaces SHL `embeddedLengthMax` body parameter) |
| **`proof`** | **Embedded DataIntegrityProof — the cryptographic proof of the {{ linkvhlr }}'s identity** |
| `proof.type` | `DataIntegrityProof` — W3C Data Integrity proof |
| `proof.cryptosuite` | Cryptosuite used — selected per [Cryptographic Algorithm Selection](volume-1.html#1xx53-cryptographic-algorithm-selection) |
| `proof.created` | Timestamp when the proof was created (SHALL match `issuanceDate`) |
| `proof.verificationMethod` | DID URL resolving to the {{ linkvhlr }}'s public key in the trust network (e.g., `did:web:receiver.example.org#key-id`) |
| `proof.proofPurpose` | `assertionMethod` — the {{ linkvhlr }} is asserting this credential |
| `proof.proofValue` | Multibase-encoded cryptographic signature over the VC document (computed with the {{ linkvhlr }}'s private key from the trust network) |
{: .grid}

> **Note:** The `proof.proofValue` is the sole cryptographic proof of the {{ linkvhlr }}'s identity. No outer JWT or HTTP Message Signature is needed. The `verificationMethod` resolves to the receiver's public key in the trust network (obtainable via ITI-YY2). The {{ linkvhls }} MUST verify this proof. The VHL payload encryption key (`key` field from the VHL payload) SHALL NOT appear anywhere in the VC.

**Request Structure:**

The {{ linkvhlr }} sends the VC as the POST body. FHIR search parameters are placed in the URL query string (since the body is `application/vc+ld+json`). The SHL parameters (`recipient`, `passcode`, `embeddedLengthMax`) are included in `credentialSubject`:

```http
POST /List/_search?_id=abc123def456&code=folder&status=current&patient.identifier=urn%3Aoid%3A2.16.840.1.113883.2.4.6.3%7CPASSPORT123&_include=List%3Aitem HTTP/1.1
Host: vhl-sharer.example.org
Content-Type: application/vc+ld+json
Accept: application/fhir+json

{
  "@context": ["https://www.w3.org/ns/credentials/v2"],
  "type": ["VerifiableCredential", "VHLManifestCredential"],
  "issuer": "did:web:vhl-receiver.example.org",
  "issuanceDate": "2024-01-15T10:00:00Z",
  "expirationDate": "2024-01-15T10:05:00Z",
  "credentialSubject": {
    "id": "https://vhl-sharer.example.org/List?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item",
    "manifest": { "url": "...", "exp": 1735689600, "flag": "LP", "label": "Patient Health Summary", "v": 1 },
    "recipient": "Dr. Smith Hospital",
    "passcode": "user-pin",
    "embeddedLengthMax": 10000
  },
  "proof": {
    "type": "DataIntegrityProof",
    "cryptosuite": "ecdsa-2019",
    "created": "2024-01-15T10:00:00Z",
    "verificationMethod": "did:web:vhl-receiver.example.org#receiver-key-123",
    "proofPurpose": "assertionMethod",
    "proofValue": "z3FD9sJ8kL2m9pQ7rT4vW5xY6zA..."
  }
}
```

> The {{ linkvhlr }} VC issuance steps are described in [Expected Actions - VHL Receiver](#23yy5416-expected-actions---vhl-receiver). The {{ linkvhls }} VC verification steps are in [Expected Actions - VHL Sharer](#23yy5417-expected-actions---vhl-sharer). Security requirements are in [Security Considerations Section 2:3.YY5.5.9](#23yy559-verifiable-credential-option).
