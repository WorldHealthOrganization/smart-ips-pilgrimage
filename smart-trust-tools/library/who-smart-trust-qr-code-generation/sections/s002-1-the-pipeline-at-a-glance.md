---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s002-1-the-pipeline-at-a-glance
section_title: "1. The pipeline at a glance"
file: "input/pagecontent/qr_code_generation.md"
lines: 16-31
source_sha256: 03253100cd38b5c6
granularity: heading
---
#### 1. The pipeline at a glance

```
   Step 1  Select payload type              DVC, for this walkthrough
   Step 2  Assemble payload                 { "n": ..., "dob": ..., "vx": {...} }
   Step 3  Wrap in CWT claim set            { 1: iss, 6: iat, 4: exp, -260: { -6: payload } }
   Step 4  Serialise as CBOR                binary
   Step 5  Sign as COSE_Sign1 (ES256)       binary, tag 18
   Step 6  Compress with ZLIB/Deflate       binary
   Step 7  Encode as Base45                 ASCII
   Step 8  Prefix context identifier        "HC1:" + ASCII
   Step 9  Render QR (Alphanumeric, EC Q)   image
```

Steps 3 to 9 never vary with the payload. A verifier runs the same list upwards.
