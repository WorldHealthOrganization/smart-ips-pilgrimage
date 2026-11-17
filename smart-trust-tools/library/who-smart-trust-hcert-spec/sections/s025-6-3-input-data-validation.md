---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s025-6-3-input-data-validation
section_title: "6.3 Input Data Validation"
file: "input/pagecontent/hcert_spec.md"
lines: 203-206
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
##### 6.3 Input Data Validation

This specification may be used in a way that implies receiving data from untrusted sources into systems that may be of mission-critical nature. To minimise the risks associated with this attack vector, all input fields MUST be properly validated by data types, lengths and contents. The Issuer Signature SHALL also be verified before any processing of the contents of the HCERT takes place. However, the validation of the Issuer Signature implies parsing the Protected Issuer Header first, in which a potential attacker may attempt to inject carefully crafted information designed to compromise the security of the system.
