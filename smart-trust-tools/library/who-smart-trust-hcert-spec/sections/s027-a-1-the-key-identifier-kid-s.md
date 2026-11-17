---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s027-a-1-the-key-identifier-kid-s
section_title: "A.1 The Key Identifier (`kid`s)"
file: "input/pagecontent/hcert_spec.md"
lines: 229-234
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
#### A.1 The Key Identifier (`kid`s)

The Key Identifier (`kid`) is calculated when constructing the list of trusted public keys from DSC certificates and consists of a truncated (first 8 bytes) SHA-256 fingerprint of the DSC encoded in DER (raw) format.

Note that Verifiers do not need to calculate the `kid` based on the DSC certificate and can directly match the Key Identifier in issued health certificates with the `kid` on the trusted list.
