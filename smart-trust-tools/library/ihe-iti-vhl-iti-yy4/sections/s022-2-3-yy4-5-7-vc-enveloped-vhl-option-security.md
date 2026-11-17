---
doc_id: ihe-iti-vhl-iti-yy4
doc_title: "IHE VHL ITI-YY4 Provide VHL"
section_id: s022-2-3-yy4-5-7-vc-enveloped-vhl-option-security
section_title: "2:3.YY4.5.7 VC Enveloped VHL Option Security"
file: "input/pagecontent/ITI-YY4.md"
lines: 362-369
source_sha256: a01169d66ede4502
granularity: heading
---
#### 2:3.YY4.5.7 VC Enveloped VHL Option Security
When the VHL is carried as a Verifiable Credential:
- The `DataIntegrityProof` SHALL chain to a trust anchor in the trust list (same framework used for CWT/HCERT verification)
- The VC `expirationDate` and the VHL payload's `exp` SHALL both be honored — VHL Receivers SHALL reject if either has passed
- Confidentiality is equivalent to the QR form: the VC carries the decryption `key` and MUST be treated as sensitive
- VHL Sharers SHOULD issue VCs with short lifetimes; single-use VCs are RECOMMENDED for high-security scenarios
