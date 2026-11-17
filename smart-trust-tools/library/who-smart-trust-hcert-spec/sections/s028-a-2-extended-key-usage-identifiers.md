---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s028-a-2-extended-key-usage-identifiers
section_title: "A.2 Extended Key Usage Identifiers"
file: "input/pagecontent/hcert_spec.md"
lines: 235-246
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
#### A.2 Extended Key Usage Identifiers

The document signing certificate MAY contain Extended Key Usage extension fields; these being:

* OID 1.3.6.1.4.1.1847.2021.1.1 --  valid for test
* OID 1.3.6.1.4.1.1847.2021.1.2  -- valid for vaccinations
* OID 1.3.6.1.4.1.1847.2021.1.3  -- valid for recovery

The DSC may contain an extended key usage extension with *zero or more* key usage policy identifiers that constrain the types of HCERTs this certificate is allowed to verify. If one or more are present, the verifiers SHALL verify the key usage against the stored HCERT. 

In absence of any key usage extension (i.e. no extensions or zero extensions), this certificate can be used to validate any type of HCERT.  Other documents MAY define relevant additional extended key usage policy identifiers used with validation of HCERTs.
_________________
