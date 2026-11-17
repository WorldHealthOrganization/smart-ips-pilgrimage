---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s012-1-xx-2-2-include-documentreference-option-vhl-sh
section_title: "1:XX.2.2 Include DocumentReference Option (VHL Sharer)"
file: "input/pagecontent/volume-1.md"
lines: 269-281
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.2.2 Include DocumentReference Option (VHL Sharer)

The Include DocumentReference Option enables the {{ linkvhls }} to process the `_include=List:item` parameter in manifest requests and return DocumentReference resources along with the List resource in a single response.

**Benefits:**
- Reduces network round trips for VHL Receiver
- Improves performance for document discovery
- Simplifies workflow for retrieving document metadata

**Implementation Note:** When generating VHLs in ITI-YY3, VHL Sharers supporting this option SHOULD include `_include=List:item` in the manifest URL. VHL Sharers not supporting this option SHOULD NOT include the `_include` parameter in the manifest URL.

See ITI-YY5 Section [2:3.YY5.4.2.2 Message Semantics](ITI-YY5.html#23yy5422-message-semantics) and [2:3.YY5.4.1.7 Expected Actions - VHL Sharer](ITI-YY5.html#23yy5417-expected-actions---vhl-sharer) for detailed behavior.
