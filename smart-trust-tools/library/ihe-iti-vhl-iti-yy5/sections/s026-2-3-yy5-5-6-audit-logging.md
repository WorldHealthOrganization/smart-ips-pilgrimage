---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s026-2-3-yy5-5-6-audit-logging
section_title: "2:3.YY5.5.6 Audit Logging"
file: "input/pagecontent/ITI-YY5.md"
lines: 854-864
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
#### 2:3.YY5.5.6 Audit Logging
Both {{ linkvhlr }} and {{ linkvhls }} SHOULD log:
- All document access requests (successful and failed)
- Authentication method used (HTTP signatures, OAuth, or Verifiable Credential)
- Receiver identity (from keyid or OAuth token)
- VHL folder ID
- Authorization decisions (approved/denied)
- Timestamps
- IP addresses
- User identifiers (from recipient parameter)
