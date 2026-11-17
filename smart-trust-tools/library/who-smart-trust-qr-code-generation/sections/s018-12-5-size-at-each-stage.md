---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s018-12-5-size-at-each-stage
section_title: "12.5 Size at each stage"
file: "input/pagecontent/qr_code_generation.md"
lines: 289-305
source_sha256: 03253100cd38b5c6
granularity: heading
---
##### 12.5 Size at each stage

For the hepatitis B certificate:

| Stage | Size |
|-------|------|
| CWT claim set, CBOR | 222 bytes |
| COSE_Sign1, signed | 307 bytes |
| ZLIB/Deflate compressed | 293 bytes |
| Base45 + `HC1:` prefix | 444 characters |
| QR symbol | Version 16, error correction `Q`, Alphanumeric mode |

The signature and its headers account for 85 of the 307 bytes — on payloads this
small, the cryptography costs more than the clinical data. This is why the
minimal models use two-character element names, and why a payload much larger
than this does not belong in a QR code at all.
