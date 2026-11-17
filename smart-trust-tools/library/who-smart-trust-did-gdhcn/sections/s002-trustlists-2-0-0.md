---
doc_id: who-smart-trust-did-gdhcn
doc_title: "GDHCN Trustlists (DID)"
section_id: s002-trustlists-2-0-0
section_title: "Trustlists 2.0.0"
file: "input/pagecontent/concepts_did_gdhcn.md"
lines: 14-37
source_sha256: 3ff5591597ae8324
granularity: heading
---
##### Trustlists 2.0.0

Version 2.0.0 introduces two **variant**s of the trust lists - embedded and by reference.

<img src="did-trustlist-types.png" alt="Types of DID trustlists" style="width:300px; float:none; margin: 0px 0px 0px 0px;"/>

For each of development (DEV), user-acceptence testing (UAT) and production (PROD) **environment**s there is a trust list according to the following table:

|  Environment   |      Variant         | URL                                                                                     |
|---------|------------|--------------------------------------------------------------------------------------------------------------|
|  DEV   |  Embedded    | [https://tng-cdn-dev.who.int/v2/trustlist/did.json](https://tng-cdn-dev.who.int/v2/trustlist/did.json)         |
|  DEV  | Reference  | [https://tng-cdn-dev.who.int/v2/trustlist-ref/did.json](https://tng-cdn-dev.who.int/v2/trustlist-ref/did.json) |
|   UAT   |  Embedded   | [https://tng-cdn-uat.who.int/v2/trustlist/did.json](https://tng-cdn-uat.who.int/v2/trustlist/did.json)         |
|    UAT   | Reference  | [https://tng-cdn-uat.who.int/v2/trustlist-ref/did.json](https://tng-cdn-uat.who.int/v2/trustlist-ref/did.json) |
|  PROD  |  Embedded   | [https://tng-cdn.who.int/v2/trustlist/did.json](https://tng-cdn.who.int/v2/trustlist/did.json)         |
| PROD | Reference  | [https://tng-cdn.who.int/v2/trustlist-ref/did.json](https://tng-cdn.who.int/v2/trustlist-ref/did.json) |

The embedded type of trustlist carries the key material directly within the DID documents' verificationMethod property and supports immediate verification.
On the root level it contains all keys imported from the trust network gateway (TNG).

The reference type lists link other DID documents, which may contain the actual key material.
Therefore reference type trustlists contain only DID ids that can be used to resolve DID documents.
This helps to keep the main trustlist documents concise and supports dynamic discovery of DID structures and key material.
