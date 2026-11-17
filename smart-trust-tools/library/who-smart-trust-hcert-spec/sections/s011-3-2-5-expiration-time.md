---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s011-3-2-5-expiration-time
section_title: "3.2.5 Expiration Time"
file: "input/pagecontent/hcert_spec.md"
lines: 76-81
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
###### 3.2.5 Expiration Time

The Expiration Time (`exp`) claim SHALL hold a timestamp in the integer NumericDate format (as specified in [RFC 8392](https://tools.ietf.org/html/rfc8392) section 2) indicating for how long this particular signature over the Payload SHALL be considered valid, after which a Verifier MUST reject the Payload as expired. The purpose of the expiry parameter is to force a limit of the validity period of the health certificate. The Claim Key 4 is used to identify this claim.

The Expiration Time MUST not exceed the validity period of the DSC.
