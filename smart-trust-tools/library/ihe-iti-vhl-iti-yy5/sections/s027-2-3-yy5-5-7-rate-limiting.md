---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s027-2-3-yy5-5-7-rate-limiting
section_title: "2:3.YY5.5.7 Rate Limiting"
file: "input/pagecontent/ITI-YY5.md"
lines: 865-871
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
#### 2:3.YY5.5.7 Rate Limiting
{{ linkvhls }} SHOULD implement rate limiting:
- Per receiver (identified by keyid or OAuth client_id)
- Per folder ID (to prevent brute force on VHL tokens)
- Per IP address
- Return 429 Too Many Requests when limits exceeded
