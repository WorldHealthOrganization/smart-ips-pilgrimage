---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s013-1-xx-2-3-verify-document-signature-option-vhl-re
section_title: "1:XX.2.3 Verify Document Signature Option (VHL Receiver)"
file: "input/pagecontent/volume-1.md"
lines: 282-290
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.2.3 Verify Document Signature Option (VHL Receiver)

In this option the {{ linkvhlr }}, after receipt of a digitally signed document from a {{ linkvhls }}, shall verify the digital signature using previously retrieved PKI material. This key material may or may not be distributed under the same trust network under which the VHL was distributed. This key material may or may not be the same key material that was used to verify the VHL.

See cross-profile considerations for a discussion of the relationship of this option to the IHE Document Signature profile.

This option is captured in the following business requirement:
- [Verify Document Signature](Requirements-VerifyDocumentSignature.html)
