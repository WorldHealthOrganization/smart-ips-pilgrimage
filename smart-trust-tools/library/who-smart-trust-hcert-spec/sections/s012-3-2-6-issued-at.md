---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s012-3-2-6-issued-at
section_title: "3.2.6 Issued At"
file: "input/pagecontent/hcert_spec.md"
lines: 82-89
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
###### 3.2.6 Issued At

The Issued At (`iat`) claim SHALL hold a timestamp in the integer NumericDate format (as specified in [RFC 8392](https://tools.ietf.org/html/rfc8392) section 2) indicating the time when the health certificate was created. 

The Issued At field MUST not predate the validity period of the DSC.

Verifiers MAY apply additional policies with the purpose of restricting the validity of the health certificate based on the time of issue. The Claim Key 6 is used to identify this claim.
