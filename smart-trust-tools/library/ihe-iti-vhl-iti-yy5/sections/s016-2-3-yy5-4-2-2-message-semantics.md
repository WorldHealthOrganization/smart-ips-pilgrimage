---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s016-2-3-yy5-4-2-2-message-semantics
section_title: "2:3.YY5.4.2.2 Message Semantics"
file: "input/pagecontent/ITI-YY5.md"
lines: 567-727
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
##### 2:3.YY5.4.2.2 Message Semantics

Because the VHL manifest URL constructed at [ITI-YY3](ITI-YY3.html) is a FHIR search on `List` using the search parameters required by the Document Responder in [IHE MHD ITI-66 Find Document Lists](https://profiles.ihe.net/ITI/MHD/ITI-66.html), the Retrieve Manifest response is — at the FHIR level — an [MHD ITI-66 response message](https://profiles.ihe.net/ITI/MHD/ITI-66.html#23662-message-semantics): a FHIR `searchset` Bundle. The shape of the Bundle depends on whether the {{ linkvhls }} supports the **Include DocumentReference Option** AND the {{ linkvhlr }} included `_include=List:item` in the request:

| Case | Bundle contents | Receiver follow-up |
|------|-----------------|--------------------|
| **A. Include DocumentReference Option NOT used** (option unsupported, or `_include` not requested) | Standard MHD ITI-66 response: only `List` resource(s) with `search.mode="match"`. `List.entry[].item.reference` points to a DocumentReference on the {{ linkvhls }}. | Receiver SHALL FHIR-read each referenced DocumentReference (`GET /DocumentReference/<id>`) before retrieving binaries. |
| **B. Include DocumentReference Option used** | `List` resource(s) with `search.mode="match"` PLUS the referenced `DocumentReference` resources with `search.mode="include"`. | Receiver proceeds directly to binary retrieval; no extra metadata round-trip. |
{: .grid}

In both cases the Receiver subsequently retrieves each binary via [Retrieve Document [ITI-68]](#23yy5424-document-content-retrieval) and decrypts it as described in [Document Encryption](#23yy5425-document-encryption).

**Case A — Bundle without Include DocumentReference Option**

The Bundle conforms to the standard MHD ITI-66 response. For Bundle structure, element semantics, and a worked example, see [ITI-66 Message Semantics](https://profiles.ihe.net/ITI/MHD/ITI-66.html#23662-message-semantics). The {{ linkvhlr }} SHALL resolve each `List.entry[].item.reference` via a separate FHIR read on the {{ linkvhls }} before retrieving binaries.

**Case B — Bundle with Include DocumentReference Option**

The Bundle extends the ITI-66 response by including each referenced DocumentReference resource (`search.mode="include"`) — this `_include=List:item` behaviour is not defined by ITI-66. The {{ linkvhlr }} can move directly to binary retrieval.

```json
{
  "resourceType": "Bundle",
  "type": "searchset",
  "total": 5,
  "link": [
    {
      "relation": "self",
      "url": "https://vhl-sharer.example.org/List/_search?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item"
    }
  ],
  "entry": [
    {
      "fullUrl": "https://vhl-sharer.example.org/List/abc123def456",
      "resource": {
        "resourceType": "List",
        "id": "abc123def456",
        "status": "current",
        "mode": "working",
        "code": {
          "coding": [
            {
              "system": "https://profiles.ihe.net/ITI/MHD/CodeSystem/MHDlistTypes",
              "code": "folder"
            }
          ]
        },
        "subject": {
          "identifier": {
            "system": "urn:oid:2.16.840.1.113883.2.4.6.3",
            "value": "PASSPORT123"
          }
        },
        "date": "2024-01-15T10:30:00Z",
        "entry": [
          {
            "item": {
              "reference": "DocumentReference/doc001"
            }
          },
          {
            "item": {
              "reference": "DocumentReference/doc002"
            }
          },
          {
            "item": {
              "reference": "DocumentReference/doc003"
            }
          },
          {
            "item": {
              "reference": "DocumentReference/doc004"
            }
          }
        ]
      },
      "search": {
        "mode": "match"
      }
    },
    {
      "fullUrl": "https://vhl-sharer.example.org/DocumentReference/doc001",
      "resource": {
        "resourceType": "DocumentReference",
        "id": "doc001",
        "status": "current",
        "type": {
          "coding": [
            {
              "system": "http://loinc.org",
              "code": "34133-9",
              "display": "Summarization of Episode Note"
            }
          ]
        },
        "subject": {
          "identifier": {
            "system": "urn:oid:2.16.840.1.113883.2.4.6.3",
            "value": "PASSPORT123"
          }
        },
        "date": "2024-01-15T09:00:00Z",
        "content": [
          {
            "attachment": {
              "contentType": "application/pdf",
              "url": "https://vhl-sharer.example.org/Binary/doc001-content"
            }
          }
        ]
      },
      "search": {
        "mode": "include"
      }
    },
    {
      "fullUrl": "https://vhl-sharer.example.org/DocumentReference/doc002",
      "resource": {
        "resourceType": "DocumentReference",
        "id": "doc002"
      },
      "search": {
        "mode": "include"
      }
    },
    {
      "fullUrl": "https://vhl-sharer.example.org/DocumentReference/doc003",
      "resource": {
        "resourceType": "DocumentReference",
        "id": "doc003"
      },
      "search": {
        "mode": "include"
      }
    },
    {
      "fullUrl": "https://vhl-sharer.example.org/DocumentReference/doc004",
      "resource": {
        "resourceType": "DocumentReference",
        "id": "doc004"
      },
      "search": {
        "mode": "include"
      }
    }
  ]
}
```

**Key Elements:**

- `Bundle.type`: Always "searchset"
- `Bundle.total`: Total number of matching resources (List + included DocumentReferences)
- `Bundle.entry[].search.mode`:
  - "match" for List resource(s) matching search criteria
  - "include" for DocumentReference resources included via `_include` parameter
- `List.entry[].item`: References to DocumentReference resources on the {{ linkvhls }}
- `DocumentReference.content.attachment.url`: Absolute URL the {{ linkvhlr }} dereferences via [Retrieve Document [ITI-68]](#23yy5424-document-content-retrieval) to obtain the (encrypted) binary
- `DocumentReference.content.attachment.contentType`: The **decrypted** content type (e.g. `application/fhir+json`, `application/pdf`). The transport content type observed during ITI-68 retrieval is `application/jose` whenever the binary is encrypted (see [Document Encryption](#23yy5425-document-encryption))
