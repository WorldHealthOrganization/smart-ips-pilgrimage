---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s029-2-3-yy5-5-9-verifiable-credential-option
section_title: "2:3.YY5.5.9 Verifiable Credential Option"
file: "input/pagecontent/ITI-YY5.md"
lines: 879-889
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
#### 2:3.YY5.5.9 Verifiable Credential Option
Implementations that support the Verifiable Credential Option SHALL:
- Include a `proof` element of type `DataIntegrityProof` in the VC with `proofPurpose` = `assertionMethod`, a `verificationMethod` DID URL resolving to the {{ linkvhlr }}'s trust network key, and a `proofValue` computed over the VC document using the {{ linkvhlr }}'s private key per the W3C Data Integrity specification
- Verify `proof.proofValue` before trusting any VC claim; reject the request if proof verification fails
- Resolve `proof.verificationMethod` against the trust network (ITI-YY2); reject VCs whose `verificationMethod` cannot be resolved to a trusted key
- Issue short-lived VCs (`expirationDate`; recommended: 5 minutes maximum)
- Bind the VC to the specific manifest via `credentialSubject.id` (set to the manifest URL matching the `_id` URL query parameter)
- Exclude the VHL payload encryption key from `credentialSubject.manifest`
- Store private keys securely (Hardware Security Module recommended)
- Reject VCs whose `credentialSubject.id` does not match the `_id` URL query parameter
