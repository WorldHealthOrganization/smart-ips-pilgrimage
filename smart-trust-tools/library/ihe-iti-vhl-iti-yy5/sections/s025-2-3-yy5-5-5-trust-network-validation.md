---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s025-2-3-yy5-5-5-trust-network-validation
section_title: "2:3.YY5.5.5 Trust Network Validation"
file: "input/pagecontent/ITI-YY5.md"
lines: 846-853
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
#### 2:3.YY5.5.5 Trust Network Validation
Both {{ linkvhlr }} and {{ linkvhls }} SHALL:
- Authenticate each other's participation in trust network
- Obtain public keys from trust list (ITI-YY2 Retrieve Trust List with DID)
- Validate certificates are not expired or revoked
- Use `keyid` (HTTP signatures) or the client key (OAuth JWT) to identify the client's key
- Reject requests from participants not in trust list (401 Unauthorized)
