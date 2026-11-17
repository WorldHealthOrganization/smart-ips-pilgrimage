---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s006-5-step-4-serialise-as-cbor
section_title: "5. Step 4 — Serialise as CBOR"
file: "input/pagecontent/qr_code_generation.md"
lines: 101-110
source_sha256: 03253100cd38b5c6
granularity: heading
---
#### 5. Step 4 — Serialise as CBOR

Encode the claim set as CBOR ([RFC 7049](https://tools.ietf.org/html/rfc7049)).
The JSON shown on this page and in the logical models is schema notation only —
**the wire format is CBOR**, and an implementation need never produce the JSON
form at all.

Strings SHOULD be NFC-normalised. Decoders SHOULD be permissive about input that
is not.
