---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s005-3-1-structure-of-the-payload
section_title: "3.1 Structure of the Payload"
file: "input/pagecontent/hcert_spec.md"
lines: 24-29
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
##### 3.1 Structure of the Payload

The payload is structured and encoded as a CBOR with a COSE digital signature. This is commonly known as a "CBOR Web Token" (CWT), and is defined in [RFC 8392](https://tools.ietf.org/html/rfc8392). The payload, as defined below, is transported in a `hcert` claim.

The integrity and authenticity of origin of payload data MUST be verifiable by the Verifier. To provide this mechanism, the issuer MUST sign the CWT using an asymmetric electronic signature scheme as defined in the COSE specification ([RFC 8152](https://tools.ietf.org/html/rfc8152)).
