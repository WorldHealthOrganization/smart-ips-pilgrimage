---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s018-2-3-yy5-4-2-4-document-content-retrieval
section_title: "2:3.YY5.4.2.4 Document Content Retrieval"
file: "input/pagecontent/ITI-YY5.md"
lines: 742-775
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
##### 2:3.YY5.4.2.4 Document Content Retrieval

The {{ linkvhls }} returns FHIR `DocumentReference` metadata as part of (or referenced from) the manifest Bundle. The actual document binary is retrieved separately by dereferencing `DocumentReference.content.attachment.url`.

The binary retrieval SHALL conform to the IHE MHD **[Retrieve Document [ITI-68]](https://profiles.ihe.net/ITI/MHD/ITI-68.html)** transaction:

- **Method:** HTTP `GET` against `DocumentReference.content.attachment.url`.
- **Transport:** Same ATNA secure channel used for ITI-YY5.
- **Authentication:** The {{ linkvhlr }} SHALL reuse the same authentication option chosen for the originating ITI-YY5 request (HTTP Message Signatures, OAuth with SSRAA, or Verifiable Credential). A {{ linkvhlr }} SHALL NOT mix options across the manifest and binary retrievals of a single VHL session.
- **Response Content-Type:**
  - `application/jose` when the binary is encrypted per [Document Encryption](#23yy5425-document-encryption) (the default for VHL flows where the VHL payload carries a `key`).
  - The `DocumentReference.content.attachment.contentType` value when the binary is not encrypted.

A {{ linkvhls }} that supports ITI-YY5 SHALL be grouped with an MHD **Document Responder** so that ITI-68 GETs against `attachment.url` succeed. A {{ linkvhlr }} SHALL be grouped with an MHD **Document Consumer**.

**Example — ITI-68 retrieval of an encrypted document (HTTP Message Signatures option):**

```http
GET /Binary/doc001-content HTTP/1.1
Host: vhl-sharer.example.org
Accept: application/jose
Signature-Input: sig1=("@method" "@path" "@authority");created=1705315800;keyid="receiver-key-123";alg="ecdsa-p256-sha256"
Signature: sig1=:MEUCIQD...:
```

```http
HTTP/1.1 200 OK
Content-Type: application/jose

eyJhbGciOiJkaXIiLCJlbmMiOiJBMjU2R0NNIn0..<base64url-iv>.<base64url-ciphertext>.<base64url-tag>
```

The five dot-separated segments are the JWE Compact Serialization (RFC 7516): protected header, empty encrypted key (because `alg=dir`), IV, ciphertext, and authentication tag.
