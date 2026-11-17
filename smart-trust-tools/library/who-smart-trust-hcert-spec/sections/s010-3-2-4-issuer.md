---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s010-3-2-4-issuer
section_title: "3.2.4 Issuer"
file: "input/pagecontent/hcert_spec.md"
lines: 72-75
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
###### 3.2.4 Issuer

The Issuer (`iss`) claim is a string value that MAY optionally hold the ISO 3166-1 alpha-2 Country Code of the entity issuing the health certificate. This claim can be used by a Verifier to identify which set of DSCs to use for validation. The Claim Key 1 is used to identify this claim.
