---
doc_id: ihe-iti-vhl-iti-yy4
doc_title: "IHE VHL ITI-YY4 Provide VHL"
section_id: s002-2-3-yy4-1-scope
section_title: "2:3.YY4.1 Scope"
file: "input/pagecontent/ITI-YY4.md"
lines: 8-20
source_sha256: a01169d66ede4502
granularity: heading
---
### 2:3.YY4.1 Scope

{% assign provideVHLTitle = provideVHL.extension  | where: "url", "http://hl7.org/fhir/5.0/StructureDefinition/extension-Requirements.title" | first %}
{% assign provideVHLRespTitle = provideVHLResp.extension  | where: "url", "http://hl7.org/fhir/5.0/StructureDefinition/extension-Requirements.title" | first %}


{% assign provideVHLDescription = provideVHL.extension  | where: "url", "http://hl7.org/fhir/5.0/StructureDefinition/extension-Requirements.description" | first %}
{% assign provideVHLRespDescription = provideVHLResp.extension  | where: "url", "http://hl7.org/fhir/5.0/StructureDefinition/extension-Requirements.description" | first %}

The Provide VHL transaction enables a {{ linkvhlh }} to transmit a Verified Health Link (VHL) to a {{ linkvhlr }}. The VHL serves as a signed authorization mechanism that allows the Receiver to subsequently retrieve one or more health documents from a VHL Sharer (via ITI-YY5).

The VHL is transmitted as a QR code containing an HCERT-encoded payload with the `HC1:` prefix, OR — when the VHL Sharer supports the [VC Enveloped VHL Option](ITI-YY3.html#vc-enveloped-vhl-carrier-option--formatvc) at ITI-YY3 — as a signed W3C Verifiable Credential (`application/vc+ld+json`). VHL Receivers scan the QR code or parse the VC to extract the VHL payload for subsequent document retrieval.
