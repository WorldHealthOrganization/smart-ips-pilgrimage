---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s009-3-2-3-key-identifier
section_title: "3.2.3 Key Identifier"
file: "input/pagecontent/hcert_spec.md"
lines: 66-71
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
###### 3.2.3 Key Identifier

The Key Identifier (`kid`) claim is used by Verifiers for selecting the correct public key from a list of keys pertaining to the Issuer (`iss`) Claim. Several keys may be used in parallel by an Issuer for administrative reasons and when performing key rollovers. The Key Identifier is not a security-critical field. For this reason, it MAY also be placed in an unprotected header if required. Verifiers MUST accept both options.  If both options are present, the Key Identifier in the protected header MUST be used.

Due to the shortening of the identifier (for space-preserving reasons) there is a slim but non-zero chance that the overall list of DSCs accepted by a validator may contain DSCs with duplicate `kid`s. For this reason, a verifier MUST check all DSCs with that `kid`.
