---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s036-1-xx-6-3-mhd-mobile-health-document-sharing
section_title: "1:XX.6.3 MHD - Mobile Health Document Sharing"
file: "input/pagecontent/volume-1.md"
lines: 505-508
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.6.3 MHD - Mobile Health Document Sharing

ITI-YY5 (Retrieve Manifest) reuses the FHIR search machinery of [MHD ITI-66 Find Document Lists](https://profiles.ihe.net/ITI/MHD/ITI-66.html): the VHL manifest URL constructed at ITI-YY3 is a FHIR `List` search using the parameters the Document Responder is required to support per ITI-66, and the ITI-YY5 response is an ITI-66 `searchset` Bundle. Binary retrieval is delegated to [MHD ITI-68 Retrieve Document](https://profiles.ihe.net/ITI/MHD/ITI-68.html) per the required grouping in [Section XX.3 Required Actor Groupings](#required-groupings).
