---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s019-5-trusted-list-format-dsc-list
section_title: "5 Trusted List Format (DSC list)"
file: "input/pagecontent/hcert_spec.md"
lines: 147-163
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
#### 5 Trusted List Format (DSC list)

Each Participating country is REQUIRED to provide a list of one or more Signing Certificate Authorities (SCAs) and a list of all valid Document Signing Certificates (DSCs), and keep these lists current.

For the list of SCA certificates, each certificate:

- MUST contain a valid Country attribute in the subject DN that matches the country of issuance.
- MUST contain DN that is unique within the specified country.
- MUST contain a unique Subject Key Identifier (SKI) according to ([RFC5280](https://tools.ietf.org/html/rfc5280)).

In addition, for the list of DSC certificates, each certificate:

- MUST be signed with the private key corresponding to a SCA certificate published on the aforementioned list.
- MUST contain an Authority Key Identifier (AKI) matching the Subject Key Identifier (SKI) of the issuing SCA certificate.
- MUST have a validity period that is in line with or longer than the validity period of all certificates signed using that key.
- SHOULD contain a unique Subject Key Identifier derived from the subject public key.
