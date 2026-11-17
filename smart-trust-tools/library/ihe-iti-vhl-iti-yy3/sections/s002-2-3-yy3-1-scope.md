---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s002-2-3-yy3-1-scope
section_title: "2:3.YY3.1 Scope"
file: "input/pagecontent/ITI-YY3.md"
lines: 9-22
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
### 2:3.YY3.1 Scope

{% assign reqGenerateVHLRequestTitle = reqGenerateVHLRequest.extension  | where: "url", "http://hl7.org/fhir/5.0/StructureDefinition/extension-Requirements.title" | first %}
{% assign reqGenerateVHLResponseTitle = reqGenerateVHLResponse.extension  | where: "url", "http://hl7.org/fhir/5.0/StructureDefinition/extension-Requirements.title" | first %}


{% assign reqGenerateVHLRequestDescription = reqGenerateVHLRequest.extension  | where: "url", "http://hl7.org/fhir/5.0/StructureDefinition/extension-Requirements.description" | first %}
{% assign reqGenerateVHLResponseDescription = reqGenerateVHLResponse.extension  | where: "url", "http://hl7.org/fhir/5.0/StructureDefinition/extension-Requirements.description" | first %}
The Generate VHL transaction enables a {{ linkvhlh }} to request a Verifiable Health Link (VHL) from a {{ linkvhls }} for a Patient identified by a business identifier (e.g., MRN, passport number, national ID). The {{ linkvhls }} locates the Patient, authorizes the caller, assembles a folder of available health documents, and returns a VHL that the {{ linkvhlh }} can subsequently transmit to a {{ linkvhlr }} via [ITI-YY4 Provide VHL](ITI-YY4.html) for downstream document retrieval via [ITI-YY5 Retrieve Manifest](ITI-YY5.html).

The VHL payload conforms to the [SMART Health Links payload format](https://hl7.org/fhir/uv/smart-health-cards-and-links/links-specification.html) and carries the manifest URL, a symmetric decryption key, and optional metadata (expiration, flags, label, purpose-of-use bindings). By default the VHL is returned as a QR code encoded as an HCERT/CWT structure per the [WHO SMART Trust HCERT specification](https://smart.who.int/trust/hcert_spec.html). When the {{ linkvhls }} supports the [VC Enveloped VHL Carrier Option](#vc-enveloped-vhl-carrier-option--formatvc), the caller MAY instead request the VHL as a signed W3C Verifiable Credential (`application/vc+ld+json`).

The transaction also supports optional passcode protection, purpose-of-use authorization metadata (which MAY populate an IHE PCF `Consent.provision.purpose` when the {{ linkvhls }} is grouped with a Consent Creator/Recipient), and the OAuth with SSRAA Option for downstream authenticated manifest retrieval.
