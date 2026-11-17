---
doc_id: ihe-iti-vhl-iti-yy4
doc_title: "IHE VHL ITI-YY4 Provide VHL"
section_id: s020-2-3-yy4-5-5-trust-network-validation
section_title: "2:3.YY4.5.5 Trust Network Validation"
file: "input/pagecontent/ITI-YY4.md"
lines: 340-346
source_sha256: a01169d66ede4502
granularity: heading
---
#### 2:3.YY4.5.5 Trust Network Validation
VHL Receivers SHALL:
- Validate VHL Sharer is current participant in trust network
- Retrieve DSC from trust list using kid from CWT protected header
- Check certificate revocation status where applicable
- Reject VHLs from untrusted participants
