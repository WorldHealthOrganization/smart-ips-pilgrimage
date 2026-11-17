---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s008-2-3-yy5-4-1-2-message-semantics
section_title: "2:3.YY5.4.1.2 Message Semantics"
file: "input/pagecontent/ITI-YY5.md"
lines: 102-138
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
##### 2:3.YY5.4.1.2 Message Semantics

This transaction uses a standard FHIR search on the List resource. The request is sent to the manifest URL decoded from the VHL (from ITI-YY4). The manifest URL contains all necessary FHIR search parameters.

**Manifest URL Structure**

The {{ linkvhlr }} performs an HTTP POST to the `_search` endpoint with the manifest URL parameters from the VHL payload:

**Example Manifest URL from VHL:**
```
https://vhl-sharer.example.org/List?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item
```

**FHIR Search Parameters**

The following FHIR search parameters are extracted from the manifest URL:

| Parameter | Type | Cardinality | Description | Example |
|-----------|------|-------------|-------------|---------|
| _id | token | [1..1] | The folder ID (with 256-bit entropy) from the VHL - primary authorization mechanism | `_id=abc123def456` |
| code | token | [1..1] | The type of List (typically "folder") | `code=folder` |
| status | token | [1..1] | The status of the List (typically "current") | `status=current` |
| patient.identifier | token (chained) | [1..1] | FHIR chained search on the patient reference parameter; resolves the patient by business identifier (`system\|value`) without requiring a direct Patient resource reference. | `patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123` |
| _include | special | [0..1] | Include referenced DocumentReference resources; SHALL be "List:item" if used. Only processed if VHL Sharer supports Include DocumentReference Option | `_include=List:item` |
{: .grid}

**SHL Manifest Request Parameters**

In addition to the FHIR search parameters in the URL, the following SHL-defined manifest parameters (per the [SMART Health Links specification](http://hl7.org/fhir/uv/smart-health-cards-and-links/links-specification.html)) SHALL be included in the request body:

| Parameter | Type | Cardinality | Description |
|-----------|------|-------------|-------------|
| recipient | string | [1..1] | Identifier of the requesting organization or person (e.g., "Dr. Smith Hospital", "Emergency Department - General Hospital") |
| passcode | string | [0..1] | User-provided passcode if the VHL is passcode-protected (P flag present in VHL) |
| embeddedLengthMax | integer | [0..1] | Integer upper bound on the length of embedded payloads (optional optimization hint) |
{: .grid}
