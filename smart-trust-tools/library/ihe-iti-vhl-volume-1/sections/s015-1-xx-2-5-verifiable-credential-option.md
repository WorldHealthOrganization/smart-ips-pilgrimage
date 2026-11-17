---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s015-1-xx-2-5-verifiable-credential-option
section_title: "1:XX.2.5 Verifiable Credential Option"
file: "input/pagecontent/volume-1.md"
lines: 300-321
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.2.5 Verifiable Credential Option

The Verifiable Credential Option enables the {{ linkvhlr }} to self-issue a JSON-LD Verifiable Credential (LDP-VC) per the [W3C Verifiable Credentials Data Model v2](https://www.w3.org/TR/vc-data-model-2.0/) when sending a manifest request in the ITI-YY5 Retrieve Manifest transaction. The VC's `credentialSubject` is the manifest decoded from the QR code, and the VC contains an embedded **DataIntegrityProof** signed with the {{ linkvhlr }}'s key from the trust network.

This option provides:
- Authentication of the {{ linkvhlr }} to the {{ linkvhls }} using a trust network key, without requiring a prior OAuth registration flow
- Cryptographic proof of QR code possession — the manifest content is embedded in the VC `credentialSubject`, binding the request to the specific VHL decoded by the receiver
- Non-repudiation of manifest requests
- An alternative authentication path suitable for deployments that prefer credential-based identity over token-based flows (e.g., those with unlinkability requirements or no central authorization server)

**How It Works:**

When the {{ linkvhlr }} decodes the QR code (ITI-YY4), it extracts the VHL payload containing the manifest URL and metadata. The {{ linkvhlr }} constructs a self-issued LDP-VC in which:
- The `credentialSubject` contains the manifest metadata from the VHL payload (excluding the encryption key), with `id` set to the manifest URL; the SHL-defined manifest parameters (`recipient`, `passcode`, `embeddedLengthMax`) are also included in `credentialSubject`
- An embedded **`proof`** element of type `DataIntegrityProof` is included with a `verificationMethod` resolving to the {{ linkvhlr }}'s key in the trust network, `proofPurpose` = `assertionMethod`, and a `proofValue` signature over the VC document — this is the cryptographic proof of the receiver's identity

The VC (with embedded proof) is sent directly as the HTTP POST body (`Content-Type: application/vc+ld+json`), with FHIR search parameters in the URL query string. No additional HTTP-level signing is required. The {{ linkvhls }} verifies the `proof.proofValue` using the {{ linkvhlr }}'s public key from the trust network before processing the request.

**Complementary Option:** Both the {{ linkvhlr }} and {{ linkvhls }} SHALL support this option for VC-based authentication to be used.

See ITI-YY5 Section 2:3.YY5.4.1.5 for detailed VC construction, request format, and verification process.
