---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s029-1-xx-5-3-cryptographic-algorithm-selection
section_title: "1:XX.5.3 Cryptographic Algorithm Selection"
file: "input/pagecontent/volume-1.md"
lines: 443-455
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.5.3 Cryptographic Algorithm Selection

The transactions in this profile (ITI-YY1 through ITI-YY5) rely on cryptographic primitives for digital signatures, message authentication, and content encryption. This IG does not mandate a single algorithm suite for deployment. Implementers select algorithms consistent with the underlying specifications — for example, RFC 9421 (HTTP Message Signatures), RFC 7515/7516/7518 (JWS/JWE/JWA), RFC 8152 (COSE), W3C Data Integrity (Verifiable Credentials), the HL7 SSRAA IG (OAuth with SSRAA Option), and the WHO SMART Trust specification (HCERT). The preceding list is illustrative, not exhaustive.

**Interoperability baseline:** For the purpose of interoperability testing, implementations SHALL support **RS256** (RSASSA-PKCS1-v1_5 using SHA-256, per RFC 7518) as a common baseline across signature operations where a JWS/JWT algorithm is applicable. This baseline ensures that two independent conformant implementations can always interoperate during testing. It does not preclude support for — or preferred deployment use of — other algorithms (ECDSA families, EdDSA, RSA-PSS, COSE equivalents, or future post-quantum algorithms).

**Deployment considerations:** Implementers SHOULD take into account additional considerations beyond the interoperability baseline when selecting algorithms for production deployments, including but not limited to:
- **Jurisdictional policies and regulatory requirements** (e.g., national cryptographic agency guidance, healthcare-sector rules, data-protection law);
- **Post-quantum / quantum-safe cryptography** as standards mature (e.g., NIST PQC) and migration guidance evolves;
- **Evolving industry guidance** on algorithm deprecation, minimum key strengths, and cryptosuite lifecycle (e.g., updates from IETF, W3C, NIST, ENISA).

Algorithms named in examples, tables, and code blocks throughout this IG are illustrative. Except for the RS256 interoperability baseline stated above, they do not constrain deployment choices. Jurisdictions and trust networks MAY define additional profiles (permitted algorithm lists, minimum key lengths, deprecation schedules) consistent with this guidance.
