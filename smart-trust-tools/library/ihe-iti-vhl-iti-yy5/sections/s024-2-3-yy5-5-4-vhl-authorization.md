---
doc_id: ihe-iti-vhl-iti-yy5
doc_title: "IHE VHL ITI-YY5 Retrieve Manifest"
section_id: s024-2-3-yy5-5-4-vhl-authorization
section_title: "2:3.YY5.5.4 VHL Authorization"
file: "input/pagecontent/ITI-YY5.md"
lines: 835-845
source_sha256: 55f019cb8d2a3f89
granularity: heading
---
#### 2:3.YY5.5.4 VHL Authorization
{{ linkvhls }} SHALL validate VHL before returning documents:
- Verify folder ID (_id parameter) corresponds to valid VHL
- Validate VHL signature (HCERT/CWT COSE signature from ITI-YY3)
- Check VHL expiration (either exp in CWT or VHL payload)
- Verify VHL not revoked (if revocation list maintained)
- Validate passcode if VHL requires it (P flag present):
  - Compare against stored hash using constant-time comparison
  - Use strong hash function (bcrypt, Argon2, PBKDF2)
- Confirm VHL scope authorizes requested documents
