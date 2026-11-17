---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s020-2-3-yy3-5-5-oauth-with-ssraa-option-fhir-base-ur
section_title: "2:3.YY3.5.5 OAuth with SSRAA Option — FHIR Base URL Extension"
file: "input/pagecontent/ITI-YY3.md"
lines: 349-355
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
#### 2:3.YY3.5.5 OAuth with SSRAA Option — FHIR Base URL Extension
When the {{ linkvhls }} supports the OAuth with SSRAA Option, it SHALL include `extension.fhirBaseUrl` in the VHL payload:
- The `fhirBaseUrl` value SHALL be the canonical FHIR base URL of the {{ linkvhls }} (e.g., `https://vhl-sharer.example.org`)
- This URL is used by the {{ linkvhlr }} to perform UDAP Discovery (`{fhirBaseUrl}/.well-known/udap`) and, if not already registered, Dynamic Client Registration with the {{ linkvhls }} before initiating ITI-YY5
- The `fhirBaseUrl` value is typically derivable from the `url` field (manifest URL) by stripping the path, but including it explicitly avoids ambiguity when the authorization server is hosted separately
- The `fhirBaseUrl` field SHALL NOT be present if the {{ linkvhls }} does not support the OAuth with SSRAA Option, to avoid misleading {{ linkvhlr }}s into attempting UDAP Discovery unnecessarily
