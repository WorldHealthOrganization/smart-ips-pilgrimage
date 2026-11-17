---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s027-1-xx-5-1-trust-network-security
section_title: "1:XX.5.1 Trust Network Security"
file: "input/pagecontent/volume-1.md"
lines: 431-436
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.5.1 Trust Network Security

- All participants ({{ linkvhlr }}, {{ linkvhls }}) SHALL establish trust via the {{ linkta }}. ITI-YY1 (Submit PKI Material) and ITI-YY2 (Retrieve Trust List) transactions MAY be used to support this trust establishment.
- PKI material SHALL be validated before use in signature verification or secure channel establishment.
- Certificates and keys should be regularly updated and revocation status checked.
