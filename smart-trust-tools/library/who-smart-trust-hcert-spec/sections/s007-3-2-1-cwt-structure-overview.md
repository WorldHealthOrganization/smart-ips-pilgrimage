---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s007-3-2-1-cwt-structure-overview
section_title: "3.2.1 CWT Structure Overview"
file: "input/pagecontent/hcert_spec.md"
lines: 32-47
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
###### 3.2.1 CWT Structure Overview

- Protected Header
  - Signature Algorithm (`alg`, label 1)
  - Key Identifier (`kid`, label 4)
- Payload
  - Issuer (`iss`, claim key 1, optional, ISO 3166-1 alpha-2 of issuer)
  - Issued At (`iat`, claim key 6)
  - Expiration Time (`exp`, claim key 4)
  - Health Certificate (`hcert`, claim key -260, see section [3.2.7](hcert_spec.html#327-health-certificate-claim) for subclaim details )
- Signature

The Signature is required to be sent in the CWT and MUST accompany the payload for validation.

The logical model can be found specified [here](StructureDefinition-HCert.html)
