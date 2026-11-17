---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s022-2-3-yy5-5-2-http-message-signatures
section_title: "2:3.YY5.5.2 HTTP Message Signatures"
file: "input/pagecontent/ITI-YY5.md"
lines: 813-823
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
#### 2:3.YY5.5.2 HTTP Message Signatures 
Implementations that support HTTP Message Signatures per RFC 9421:
- Signature SHALL include `@method`, `@path`, `@authority`, `content-type`, `content-digest`
- Content-Digest SHALL be SHA-256 or stronger
- Signature algorithm and key strength — see [Cryptographic Algorithm Selection](volume-1.html#1xx53-cryptographic-algorithm-selection)
- Private keys SHALL be stored securely (Hardware Security Module recommended)
- Public keys SHALL be obtained from trust network
- `keyid` SHALL uniquely identify receiver's public key in trust list
- Timestamp validation SHALL enforce freshness (±2 minutes recommended)
- Replay attacks prevented by timestamp validation
