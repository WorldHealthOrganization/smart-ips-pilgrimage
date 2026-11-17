---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s014-2-3-yy3-4-2-3-expected-actions
section_title: "2:3.YY3.4.2.3 Expected Actions"
file: "input/pagecontent/ITI-YY3.md"
lines: 306-320
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
##### 2:3.YY3.4.2.3 Expected Actions

The VHL Holder SHALL:
- Display or print the QR code for scanning by VHL Receivers
- Cache the encryption key securely (extracted from VHL payload) for future document decryption
- If a passcode was provided during generation:
  - Securely store the plaintext passcode separately from the QR code
  - Provide the passcode to authorized VHL Receivers for manifest retrieval (ITI-YY5)
  - Use secure transmission methods when sharing the passcode out-of-band

The VHL Holder MAY:
- Maintain record of QR code presentations
- Revoke VHL access if supported by VHL Sharer
