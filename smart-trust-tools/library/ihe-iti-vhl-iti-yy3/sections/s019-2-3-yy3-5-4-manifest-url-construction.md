---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s019-2-3-yy3-5-4-manifest-url-construction
section_title: "2:3.YY3.5.4 Manifest URL Construction"
file: "input/pagecontent/ITI-YY3.md"
lines: 344-348
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
#### 2:3.YY3.5.4 Manifest URL Construction
- The manifest URL SHALL include all mandatory FHIR search parameters
- The `_include` parameter SHOULD only be included if the VHL Sharer supports the Include DocumentReference Option
- This ensures VHL Receivers can successfully retrieve the manifest using ITI-YY5
