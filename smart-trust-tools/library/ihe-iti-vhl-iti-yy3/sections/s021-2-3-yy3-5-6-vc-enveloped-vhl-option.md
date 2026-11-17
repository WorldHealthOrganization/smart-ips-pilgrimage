---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s021-2-3-yy3-5-6-vc-enveloped-vhl-option
section_title: "2:3.YY3.5.6 VC Enveloped VHL Option"
file: "input/pagecontent/ITI-YY3.md"
lines: 356-360
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
#### 2:3.YY3.5.6 VC Enveloped VHL Option
- The VC's `DataIntegrityProof` SHALL chain to a trust anchor in the trust list (same framework used for HCERT/CWT verification).
- The VC `expirationDate` SHOULD be consistent with the VHL payload `exp`; the VHL Receiver SHALL reject the VHL if either has passed.
- Confidentiality considerations are equivalent to the QR form: the VC carries the `key` and MUST be treated as sensitive.
- VHL Sharers MAY issue single-use VCs; short lifetimes are RECOMMENDED for high-security scenarios.
