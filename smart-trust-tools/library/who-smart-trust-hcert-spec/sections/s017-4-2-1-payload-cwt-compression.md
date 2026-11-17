---
doc_id: who-smart-trust-hcert-spec
doc_title: "HCERT Specification"
section_id: s017-4-2-1-payload-cwt-compression
section_title: "4.2.1 Payload (CWT) Compression"
file: "input/pagecontent/hcert_spec.md"
lines: 131-134
source_sha256: 54cc85d1e13d3c26
granularity: heading
---
###### 4.2.1 Payload (CWT) Compression

To lower size and to improve speed and reliability in the reading process of the HCERT, the CWT SHALL be compressed using ZLIB ([RFC 1950](https://tools.ietf.org/html/rfc1950)) and the Deflate compression mechanism in the format defined in ([RFC 1951](https://tools.ietf.org/html/rfc1951)).
