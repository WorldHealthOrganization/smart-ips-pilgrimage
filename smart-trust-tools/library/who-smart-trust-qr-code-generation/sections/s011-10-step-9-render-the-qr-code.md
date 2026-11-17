---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s011-10-step-9-render-the-qr-code
section_title: "10. Step 9 — Render the QR code"
file: "input/pagecontent/qr_code_generation.md"
lines: 162-174
source_sha256: 03253100cd38b5c6
granularity: heading
---
#### 10. Step 9 — Render the QR code

| Property | Requirement |
|----------|-------------|
| Symbology | QR Code, ISO/IEC 18004:2015 — SHALL |
| Encoding mode | Alphanumeric (Mode 2, symbols `0010`) — MUST, in conjunction with Base45 |
| Error correction | Level `Q`, approximately 25% — RECOMMENDED |
| Rendered size | 35 mm to 60 mm diagonal — RECOMMENDED |

If you are printing below 300 dpi, make sure each module is rendered as an exact
square. Non-proportional scaling turns modules into rectangles and is a frequent
cause of certificates that scan on screen but not on paper.
