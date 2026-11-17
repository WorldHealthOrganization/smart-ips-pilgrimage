---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s017-2-3-yy5-4-2-3-expected-actions
section_title: "2:3.YY5.4.2.3 Expected Actions"
file: "input/pagecontent/ITI-YY5.md"
lines: 728-741
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
##### 2:3.YY5.4.2.3 Expected Actions

The {{ linkvhlr }} SHALL:
- Parse the Bundle and distinguish List vs. DocumentReference resources by `search.mode`.
- **If the Bundle does NOT contain DocumentReference resources** (Example A): for each `List.entry[].item.reference`, perform a FHIR read against the {{ linkvhls }} to obtain the DocumentReference metadata.
- For each DocumentReference, retrieve the binary by dereferencing `content.attachment.url` per [Retrieve Document [ITI-68]](#23yy5424-document-content-retrieval), reusing the same authentication option chosen for this ITI-YY5 session.
- Decrypt the retrieved binary using the `key` from the VHL payload cached from ITI-YY4, per [Document Encryption](#23yy5425-document-encryption).
- Verify that the decrypted payload's media type matches `DocumentReference.content.attachment.contentType`.

The {{ linkvhlr }} MAY:
- Display the document list to the user.
- Filter or sort documents based on metadata.
- Retrieve and decrypt document content on demand rather than eagerly.
