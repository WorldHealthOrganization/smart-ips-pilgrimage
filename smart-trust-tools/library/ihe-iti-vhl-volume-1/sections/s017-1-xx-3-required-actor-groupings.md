---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s017-1-xx-3-required-actor-groupings
section_title: "1:XX.3 Required Actor Groupings"
file: "input/pagecontent/volume-1.md"
lines: 341-362
source_sha256: 1227bd54486fad1f
granularity: heading
---
## 1:XX.3 Required Actor Groupings

The following actor groupings are required for secure operations within the VHL trust network:

<p id ="tXX.3-1" class="tableTitle">Table XX.3-1: VHL Profile - Required Actor Groupings</p>

| VHL Actor | Grouping Condition | Actor(s) to be grouped with | Reference |
|-----------|--------------------|-----------------------------|-----------|
| {{ linkvhlr }} | Required for ITI-YY5 | ITI ATNA / Secure Node or Secure Application | ITI TF-1: 9.1 |
| {{ linkvhls }} | Required for ITI-YY5 | ITI ATNA / Secure Node or Secure Application | ITI TF-1: 9.1 |
| {{ linkvhls }} | Required for serving document binaries referenced from `DocumentReference.content.attachment.url` | ITI MHD / Document Responder ([ITI-68](https://profiles.ihe.net/ITI/MHD/ITI-68.html)) | ITI TF-2: 3.68 |
| {{ linkvhlr }} | Required for retrieving document binaries referenced from `DocumentReference.content.attachment.url` | ITI MHD / Document Consumer ([ITI-68](https://profiles.ihe.net/ITI/MHD/ITI-68.html)) | ITI TF-2: 3.68 |
| {{ linkta }} | -- | None | -- |
| {{ linkvhlh }} | -- | None | -- |
{: .grid}

Note: The {{ linkvhlr }} and {{ linkvhls }} SHALL be grouped with ATNA Secure Node or Secure Application to support the secure channel requirements of the ITI-YY5 Retrieve Manifest transaction.

Note: The {{ linkvhls }} SHALL be grouped with an MHD Document Responder so that the binary referenced from `DocumentReference.content.attachment.url` can be retrieved via [ITI-68 Retrieve Document](https://profiles.ihe.net/ITI/MHD/ITI-68.html). The {{ linkvhlr }} SHALL be grouped with an MHD Document Consumer to perform that retrieval. Document binaries are encrypted as JWE per RFC 7516/7518 using the `key` from the VHL payload decoded by the {{ linkvhlr }} in ITI-YY4; specific JWE algorithms are selected per [Cryptographic Algorithm Selection](#1xx53-cryptographic-algorithm-selection).

<a name="overview"> </a>
