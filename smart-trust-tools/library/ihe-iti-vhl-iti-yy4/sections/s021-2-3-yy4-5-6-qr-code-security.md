---
doc_id: ihe-iti-vhl-iti-yy4
doc_title: "IHE VHL ITI-YY4 Provide VHL"
section_id: s021-2-3-yy4-5-6-qr-code-security
section_title: "2:3.YY4.5.6 QR Code Security"
file: "input/pagecontent/ITI-YY4.md"
lines: 347-361
source_sha256: a01169d66ede4502
granularity: heading
---
#### 2:3.YY4.5.6 QR Code Security

**QR Code Characteristics:**
- Can be photographed/copied - use time-limited expiration
- Suitable for supervised encounters (in-person, on-screen display)
- Digital signature provides authenticity verification
- Recommended for higher security scenarios

**Best Practices:**
- Include short expiration times in CWT exp claim
- Use passcode protection (P flag) for sensitive data
- Display QR codes in controlled environments
- Avoid printing QR codes for long-term use unless necessary
- Implement single-use VHLs where appropriate
