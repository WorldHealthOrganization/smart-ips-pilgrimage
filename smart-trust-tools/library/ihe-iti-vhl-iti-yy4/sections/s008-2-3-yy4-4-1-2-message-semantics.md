---
doc_id: ihe-iti-vhl-iti-yy4
doc_title: "IHE VHL ITI-YY4 Provide VHL"
section_id: s008-2-3-yy4-4-1-2-message-semantics
section_title: "2:3.YY4.4.1.2 Message Semantics"
file: "input/pagecontent/ITI-YY4.md"
lines: 61-81
source_sha256: a01169d66ede4502
granularity: heading
---
##### 2:3.YY4.4.1.2 Message Semantics

The VHL payload structure is defined in [ITI-YY3](ITI-YY3.html) and aligns with the SMART Health Links specification.

**QR Code Transmission**

The VHL is transmitted via QR code with the following characteristics:
- VHL encoded as HCERT QR code with `HC1:` prefix
- Suitable for in-person encounters, walk-in clinics, emergency departments
- QR code contains HCERT/CWT structure with embedded VHL payload
- Can be displayed on screen or printed on paper
- Minimum recommended diagonal size: 35-60mm

**Verifiable Credential Transmission (VC Enveloped VHL)**

When the VHL Sharer supports the [VC Enveloped VHL Option](ITI-YY3.html#vc-enveloped-vhl-carrier-option--formatvc), the VHL MAY alternatively be transmitted as a signed JSON-LD Verifiable Credential:
- Conveyed as `application/vc+ld+json` via any channel that preserves JSON (HTTPS, email attachment, file transfer, NFC with a capable reader)
- Not imaged/scanned — conveyed as a file or blob
- The VC carries the VHL payload under `credentialSubject` and is signed by the VHL Sharer with a `DataIntegrityProof` (cryptosuite per [Cryptographic Algorithm Selection](volume-1.html#1xx53-cryptographic-algorithm-selection))
- Suitable for machine-to-machine transfer and asynchronous delivery scenarios where QR presentation is impractical
