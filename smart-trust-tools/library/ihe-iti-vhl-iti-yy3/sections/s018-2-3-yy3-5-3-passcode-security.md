---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s018-2-3-yy3-5-3-passcode-security
section_title: "2:3.YY3.5.3 Passcode Security"
file: "input/pagecontent/ITI-YY3.md"
lines: 336-343
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
#### 2:3.YY3.5.3 Passcode Security
- If a passcode is provided, it SHALL be securely hashed before storage using industry-standard algorithms (bcrypt, Argon2, PBKDF2)
- The plaintext passcode SHALL NOT be included in the VHL URL or QR code
- The plaintext passcode SHALL NOT be stored by the VHL Sharer
- The VHL Holder SHOULD securely store the plaintext passcode for sharing with authorized VHL Receivers
- During ITI-YY5 Retrieve Manifest, the VHL Receiver provides the passcode which the VHL Sharer validates against the stored hash
- Use of passcode adds an additional authentication factor beyond VHL possession
