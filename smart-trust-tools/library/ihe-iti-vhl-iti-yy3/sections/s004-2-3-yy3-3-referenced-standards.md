---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s004-2-3-yy3-3-referenced-standards
section_title: "2:3.YY3.3 Referenced Standards"
file: "input/pagecontent/ITI-YY3.md"
lines: 32-49
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
### 2:3.YY3.3 Referenced Standards

- **SMART Health Links Specification**: [SMART Health Links and SMART Health Cards](http://hl7.org/fhir/uv/smart-health-cards-and-links/links-specification.html)
- **RFC 4648**: Base64url Encoding
- **RFC 7515**: JSON Web Signature (JWS)
- **ISO/IEC 18004:2015**: QR Code specification
- **FHIR R4**: [HL7 FHIR Release 4](http://hl7.org/fhir/R4/)

**OAuth with SSRAA (Optional):**
- **RFC 7519**: JSON Web Token (JWT)
- **HL7 Security for Scalable Registration, Authentication, and Authorization IG**: [SSRAA](http://hl7.org/fhir/us/udap-security/) — used by the VHL Receiver to perform UDAP Discovery and Dynamic Client Registration with the VHL Sharer prior to making authenticated manifest requests

**VC Enveloped VHL Option(Optional):**
- **W3C VC Data Model v2**: [Verifiable Credentials Data Model v2](https://www.w3.org/TR/vc-data-model-2.0/)
- **W3C Data Integrity**: [Verifiable Credential Data Integrity 1.0](https://www.w3.org/TR/vc-data-integrity/) — `DataIntegrityProof`
- **W3C Data Integrity ECDSA Cryptosuites**: [ecdsa-2019](https://www.w3.org/TR/vc-di-ecdsa/)
