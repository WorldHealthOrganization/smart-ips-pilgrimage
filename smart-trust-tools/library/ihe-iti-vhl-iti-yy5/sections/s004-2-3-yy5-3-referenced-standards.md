---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s004-2-3-yy5-3-referenced-standards
section_title: "2:3.YY5.3 Referenced Standards"
file: "input/pagecontent/ITI-YY5.md"
lines: 43-82
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
### 2:3.YY5.3 Referenced Standards

**Core Standards:**
- **RFC 5280**: X.509 PKI Certificate and CRL Profile
- **RFC 9110**: HTTP Semantics
- **RFC 9421**: HTTP Message Signatures
- **RFC 6234**: SHA-256 Hash Function
- **W3C VC Data Model v2**: [Verifiable Credentials Data Model v2](https://www.w3.org/TR/vc-data-model-2.0/) - for Verifiable Credential Option
- **W3C Data Integrity**: [Verifiable Credential Data Integrity 1.0](https://www.w3.org/TR/vc-data-integrity/) - DataIntegrityProof for Verifiable Credential Option
- **W3C Data Integrity ECDSA Cryptosuites**: [ecdsa-2019](https://www.w3.org/TR/vc-di-ecdsa/)

**FHIR Specifications:**
- **FHIR R4**: [HL7 FHIR Release 4](http://hl7.org/fhir/R4/)
- **FHIR List Resource**: [List Resource](http://hl7.org/fhir/R4/list.html)
- **FHIR DocumentReference**: [DocumentReference Resource](http://hl7.org/fhir/R4/documentreference.html)
- **FHIR Bundle**: [Bundle Resource](http://hl7.org/fhir/R4/bundle.html)
- **FHIR Search**: [Search Parameters](http://hl7.org/fhir/R4/search.html)
- **FHIR _include**: [_include Parameter](http://hl7.org/fhir/R4/search.html#include)

**IHE Profiles:**
- **ITI TF-2: Mobile Health Document Sharing (MHD)**: [ITI-66 Find Document Lists](https://profiles.ihe.net/ITI/MHD/ITI-66.html)
- **ITI TF-2: Mobile Health Document Sharing (MHD)**: [ITI-68 Retrieve Document](https://profiles.ihe.net/ITI/MHD/ITI-68.html) - used to retrieve the binary content referenced from `DocumentReference.content.attachment.url`
- **ITI TF-1: Section 9**: ATNA Profile
- **ITI TF-2: 3.19**: Authenticate Node transaction

**OAuth with SSRAA (Optional):**
- **RFC 7515**: JSON Web Signature (JWS) - for OAuth with SSRAA Option
- **RFC 7519**: JSON Web Token (JWT) - for OAuth with SSRAA Option
- **SMART App Launch Backend Services**: [Backend Services](http://hl7.org/fhir/smart-app-launch/backend-services.html)
- **HL7 Security for Scalable Registration, Authentication, and Authorization IG**: [SSRAA](http://hl7.org/fhir/us/udap-security/)
- **ITI Internet User Authorization (IUA)**: [IUA Profile](https://profiles.ihe.net/ITI/IUA/)

**SHL Specifications:**
- **SHL Manifest Request**: [SHL Manifest Request](http://hl7.org/fhir/uv/smart-health-cards-and-links/STU1/links-specification.html#smart-health-link-manifest-request)
- **SHL Encrypting and Decrypting Files**: [SHL Encryption](https://hl7.org/fhir/uv/smart-health-cards-and-links/links-specification.html#encrypting-and-decrypting-files) - JWE `dir` + `A256GCM` convention used to encrypt document binaries

**Encryption Standards:**
- **RFC 7516**: JSON Web Encryption (JWE) - compact serialization used for document encryption
- **RFC 7518**: JSON Web Algorithms (JWA) - `dir` key management and `A256GCM` content encryption
