---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s007-1-xx-1-2-3-generate-vhl-iti-yy3
section_title: "1:XX.1.2.3 Generate VHL [ITI-YY3]"
file: "input/pagecontent/volume-1.md"
lines: 172-188
source_sha256: 1227bd54486fad1f
granularity: heading
---
#### 1:XX.1.2.3 Generate VHL [ITI-YY3]

This transaction is used by a {{ linkvhlh }} to request that a {{ linkvhls }} generate a QR code containing a VHL. The QR code is encoded as an HCERT/CWT structure.

A {{ linkvhls }} MAY:
- Record consent of the individual
- Create audit trail of VHL creation
- Set passcode protection (P flag) with secure hash storage
- Set expiration time for time-limited access
- Set long-term flag (L) for ongoing access

For more details see the detailed [transaction description](ITI-YY3.html)

This transaction is captured as the following requirements:
- [Initiate VHL Generation Request](Requirements-InitiateVHLGenerationRequest.html)
- [Respond to VHL Generation Request](Requirements-RespondtoGenerateVHLRequest.html)
