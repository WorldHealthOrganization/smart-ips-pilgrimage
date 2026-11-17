---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s008-1-xx-1-2-4-provide-vhl-iti-yy4
section_title: "1:XX.1.2.4 Provide VHL [ITI-YY4]"
file: "input/pagecontent/volume-1.md"
lines: 189-206
source_sha256: 1227bd54486fad1f
granularity: heading
---
#### 1:XX.1.2.4 Provide VHL [ITI-YY4]

This transaction is initiated by a {{ linkvhlh }} to transmit a VHL to a {{ linkvhlr }} by displaying or providing a QR code for scanning. 

**QR Code Transmission:**

The {{ linkvhlh }} presents the VHL by:
- Displaying the QR code on their device screen for the {{ linkvhlr }} to scan, OR
- Providing a printed QR code generated during ITI-YY3

The {{ linkvhlr }} scans the QR code using a camera-equipped device and processes the HCERT-encoded VHL through a 9-step decoding process:

For more details see the detailed [transaction description](ITI-YY4.html)

This transaction is captured as the following requirements:
- [Provide VHL](Requirements-ProvideVHL.html)
- [Respond to Provide VHL](Requirements-RespondtoProvideVHL.html)
