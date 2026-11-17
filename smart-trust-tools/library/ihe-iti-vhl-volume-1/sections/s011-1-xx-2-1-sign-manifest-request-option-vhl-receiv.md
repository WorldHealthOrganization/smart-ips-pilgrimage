---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s011-1-xx-2-1-sign-manifest-request-option-vhl-receiv
section_title: "1:XX.2.1 Sign Manifest Request Option (VHL Receiver)"
file: "input/pagecontent/volume-1.md"
lines: 255-268
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.2.1 Sign Manifest Request Option (VHL Receiver)

The Sign Manifest Request Option enables the {{ linkvhlr }} to digitally sign manifest requests sent to the {{ linkvhls }} and enables the {{ linkvhls }} to verify digital signatures on manifest requests from the {{ linkvhlr }}.

This option provides:
- Mutual authentication between VHL Receiver and VHL Sharer
- Non-repudiation of manifest requests
- Protection against request forgery
- Enhanced audit trail

**Complementary Option:** This option is designed to work with the Sign Manifest Request Option (VHL Sharer). If a {{ linkvhlr }} signs requests, the {{ linkvhls }} should support signature verification.

See ITI-YY5 Section [2:3.YY5.4.1.3 Authentication Option - HTTP Message Signatures](ITI-YY5.html#23yy5413-authentication-option---http-message-signatures) for detailed signature format.
