---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s038-1-xx-6-5-dsg-dsgj-document-digital-signature
section_title: "1:XX.6.5 DSG/DSGj - Document Digital Signature"
file: "input/pagecontent/volume-1.md"
lines: 513-519
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.6.5 DSG/DSGj - Document Digital Signature

The Verify Document Signature option enables {{ linkvhlr }} to verify digital signatures on retrieved documents. This may use:
- DSG (Document Digital Signature) profile for XML-based documents
- DSGj (JSON Document Signature) profile for JSON-based documents

The key material used for document signature verification may or may not be the same as the key material used to verify the VHL itself, and may or may not be distributed under the same trust network.
