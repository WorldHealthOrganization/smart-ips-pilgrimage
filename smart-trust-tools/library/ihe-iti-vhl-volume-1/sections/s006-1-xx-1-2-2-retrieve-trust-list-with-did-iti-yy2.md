---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s006-1-xx-1-2-2-retrieve-trust-list-with-did-iti-yy2
section_title: "1:XX.1.2.2 Retrieve Trust List with DID [ITI-YY2]"
file: "input/pagecontent/volume-1.md"
lines: 143-171
source_sha256: 1227bd54486fad1f
granularity: heading
---
#### 1:XX.1.2.2 Retrieve Trust List with DID [ITI-YY2]

This transaction is used by a {{ linkvhlr }} or {{ linkvhls }} to retrieve a Trust List from a {{ linkta }} containing DID Documents with PKI material. The retrieved DID Documents include public keys and metadata necessary for verifying digital signatures and establishing trust relationships. Received key material should be distinguished by the participating jurisdiction, use case context, and key usage.

**Transaction Optionality:**

This transaction is:
- **REQUIRED (R)** for Trust Anchor actors
- **OPTIONAL (O)** for VHL Sharer and VHL Receiver actors

**When to Implement:**

VHL Sharer and VHL Receiver actors SHALL implement this transaction when:
- They do not have pre-established mechanisms to retrieve PKI material from the {{ linkta }}, OR
- They wish to demonstrate interoperability at IHE Connectathons

**Alternative Implementations:**

Actors that do not implement this transaction SHALL retrieve trust material through jurisdiction-specific mechanisms that are out of scope for this profile. Such implementations:
- Cannot participate in IHE Connectathon testing for trust material retrieval
- SHALL document their trust material retrieval mechanisms in their IHE Integration Statement
- Are responsible for obtaining current PKI material for VHL signature verification

For more details see the detailed [transaction description](ITI-YY2.html)

This transaction is captured as the following requirements:
- [Initiate Retrieve Trust List Request](Requirements-InitiateRetrieveTrustListRequest.html)
- [Respond to Retrieve Trust List Request](Requirements-RespondtoRetrieveTrustListRequest.html)
