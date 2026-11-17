---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s016-2-3-yy3-5-1-encryption-key-security
section_title: "2:3.YY3.5.1 Encryption Key Security"
file: "input/pagecontent/ITI-YY3.md"
lines: 323-328
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
#### 2:3.YY3.5.1 Encryption Key Security
- The 32-byte encryption key SHALL be generated using a cryptographically secure random number generator
- The key is embedded in the VHL payload within the QR code and SHALL be kept confidential
- Loss of the key means loss of access to encrypted documents
- The encryption key is not directly visible in the QR code as it is embedded within the signed and compressed HCERT structure
