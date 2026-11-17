---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s009-1-xx-1-2-5-retrieve-manifest-iti-yy5
section_title: "1:XX.1.2.5 Retrieve Manifest [ITI-YY5]"
file: "input/pagecontent/volume-1.md"
lines: 207-233
source_sha256: 1227bd54486fad1f
granularity: heading
---
#### 1:XX.1.2.5 Retrieve Manifest [ITI-YY5]

This transaction is initiated by a {{ linkvhlr }} to retrieve a document manifest from a {{ linkvhls }} using a previously validated VHL as authorization. The transaction uses standard FHIR search on the List resource, following the same pattern as MHD ITI-66 Find Document Lists.

**Response:**

The {{ linkvhls }} returns a FHIR Bundle of type "searchset" containing:
- **List resource** with search.mode="match" - references available documents
- **DocumentReference resources** with search.mode="include" (if Include DocumentReference Option supported and `_include` parameter used)

If the {{ linkvhls }} supports the **Include DocumentReference Option**, it processes the `_include=List:item` parameter and returns both List and DocumentReference resources in a single response, reducing network round trips.

If the {{ linkvhls }} does NOT support this option, it ignores the `_include` parameter and returns only the List resource. The {{ linkvhlr }} then retrieves individual DocumentReference resources using separate read requests.

**Capability Statements:**

Client and server requirements are defined in:
- [VHL Receiver Client Capability Statement](CapabilityStatement-VHLReceiverCapabilityStatement.html)
- [VHL Sharer Server Capability Statement](CapabilityStatement-VHLSharerCapabilityStatement.html)

For more details see the detailed [transaction description](ITI-YY5.html)

This transaction is captured as the following requirements:
- [Request VHL Documents](Requirements-RequestVHLDocuments.html)

<a name="actor-options"> </a>
