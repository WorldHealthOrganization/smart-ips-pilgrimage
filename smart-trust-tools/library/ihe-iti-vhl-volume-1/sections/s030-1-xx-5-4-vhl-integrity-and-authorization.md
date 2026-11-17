---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s030-1-xx-5-4-vhl-integrity-and-authorization
section_title: "1:XX.5.4 VHL Integrity and Authorization"
file: "input/pagecontent/volume-1.md"
lines: 456-462
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.5.4 VHL Integrity and Authorization

- VHL signatures SHALL be verified before trusting VHL content.
- VHL expiration timestamps should be enforced.
- Passcodes (if used) should be communicated out-of-band and validated server-side.
- VHL Sharers should implement rate limiting and account lockout for failed passcode attempts.
