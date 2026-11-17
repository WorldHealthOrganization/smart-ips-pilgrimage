---
doc_id: ihe-iti-vhl-iti-yy4
doc_title: "IHE VHL ITI-YY4 Provide VHL"
section_id: s009-2-3-yy4-4-1-3-expected-actions-vhl-holder
section_title: "2:3.YY4.4.1.3 Expected Actions - VHL Holder"
file: "input/pagecontent/ITI-YY4.md"
lines: 82-102
source_sha256: a01169d66ede4502
granularity: heading
---
##### 2:3.YY4.4.1.3 Expected Actions - VHL Holder

**QR Code Transmission:**

The VHL Holder SHALL:
1. Verify QR code validity (not expired, CWT signature valid)
2. Display QR code on device screen or provide printed copy
3. Ensure QR code is displayed at appropriate size for reliable scanning
4. Provide passcode out-of-band if VHL is passcode-protected (P flag present)

**Verifiable Credential Transmission (VC Enveloped VHL Option):**

When the VHL Sharer supports the [VC Enveloped VHL Option](ITI-YY3.html#vc-enveloped-vhl-carrier-option--formatvc), the VHL Holder SHALL:
1. Verify the VC is valid (not expired, `DataIntegrityProof` intact)
2. Transmit the `application/vc+ld+json` document to the VHL Receiver via an agreed channel (HTTPS, email attachment, file transfer, or NFC)
3. Provide passcode out-of-band if VHL is passcode-protected (P flag present)

The VHL Holder MAY:
- Maintain record of VHL presentations (QR or VC)
- Revoke VHL access if supported by VHL Sharer
