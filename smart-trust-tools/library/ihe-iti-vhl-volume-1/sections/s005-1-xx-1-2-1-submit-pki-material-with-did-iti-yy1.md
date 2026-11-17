---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s005-1-xx-1-2-1-submit-pki-material-with-did-iti-yy1
section_title: "1:XX.1.2.1 Submit PKI Material with DID [ITI-YY1]"
file: "input/pagecontent/volume-1.md"
lines: 122-142
source_sha256: 1227bd54486fad1f
granularity: heading
---
#### 1:XX.1.2.1 Submit PKI Material with DID [ITI-YY1]

This transaction is used by a {{ linkvhlr }} or {{ linkvhls }} to submit PKI material to a {{ linkta }} using Decentralized Identifiers (DIDs). The submitted material is formatted as DID Documents containing public keys and associated metadata for validation and inclusion in the Trust List.

**Transaction Optionality:**

This transaction is:
- **REQUIRED (R)** for Trust Anchor actors
- **OPTIONAL (O)** for VHL Sharer and VHL Receiver actors


**Alternative Implementations:**

Actors that do not implement this transaction SHALL establish trust relationships through jurisdiction-specific mechanisms that are out of scope for this profile.

For more details see the detailed [transaction description](ITI-YY1.html)

This transaction is captured as the following requirements:
- [Initiate Submit PKI Material Request](Requirements-InitiateSubmitPKIMaterialRequest.html)
- [Respond to Submit PKI Material Request](Requirements-RespondtoSubmitPKIMaterialRequest.html)
