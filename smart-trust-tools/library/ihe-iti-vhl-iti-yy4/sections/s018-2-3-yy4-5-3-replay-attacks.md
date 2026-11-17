---
doc_id: ihe-iti-vhl-iti-yy4
doc_title: "IHE VHL ITI-YY4 Provide VHL"
section_id: s018-2-3-yy4-5-3-replay-attacks
section_title: "2:3.YY4.5.3 Replay Attacks"
file: "input/pagecontent/ITI-YY4.md"
lines: 328-333
source_sha256: a01169d66ede4502
granularity: heading
---
#### 2:3.YY4.5.3 Replay Attacks
- VHL Sharers SHOULD include expiration timestamps in both CWT and VHL payload
- VHL Receivers SHOULD enforce expiration validation
- VHL Sharers MAY implement single-use VHLs
- Short expiration times reduce replay attack window
