---
doc_id: who-smart-trust-did-gdhcn
doc_title: "GDHCN Trustlists (DID)"
section_id: s003-did-trustlists-structure
section_title: "DID trustlists structure"
file: "input/pagecontent/concepts_did_gdhcn.md"
lines: 38-79
source_sha256: 3ff5591597ae8324
granularity: heading
---
###### DID trustlists structure

Version 2.0.0 introduces a hierarchical structure for DID documents, to support more fine grained resolution and discovery of key material.
These DID documents are parameterized by the following according to the levels in the following table.

| Level          | Description                                                                                       |
|----------------|---------------------------------------------------------------------------------------------------|
| **root**           | A fixed parameter for all trusted key material or trusted DID references of GDHCN.                                |
| **$domain**         | Contains trusted key material or DID references of GDHCN for a supported trust domain.   **$domain** should be one of the codes in the [GDHCN Trust Domain Value Set](ValueSet-Domains.html).              |
| **$participant**    | Contains trusted key material or DID references of GDHCN for a trusted participant.  **$participant** should be one of the codes in the  [GDHCN Participant Value Set](ValueSet-Participants.html).                  |
| **$usage**  | Contains trusted key material or DID references of a supported key usage type.   **$usage** type is one of the key usages codes in the [GDHCN Key Usage Value Set](CodeSystem-KeyUsage.html). |


The levels are organized hierarchically so that they function as filters following an AND logic operation when resolving or discovering key material.
Note that "-" character can be used as a wildcard on each sublevel of root. 
This allows to omit filtering on the respective level effectively matching all content of that level.

The following examples outline the expected behavior of embedded trustlist: 

* tng-cdn.who.int/v2/trustlist/did.json matches all keys for all **$domain**s, **$participant**s and key **$usage** types.
* tng-cdn.who.int/v2/trustlist/**$domain**/**$participant**/did.json matches all key **$usage** types for a specific **$domain** AND **$participant**.
* tng-cdn.who.int/v2/trustlist/-/**$participant**/did.json matches all key **$usage** types across all **$domain**s for a specific **$participant**.
* tng-cdn.who.int/v2/trustlist/**$domain**/**$participant**/**$usage**/did.json matches all keys for a specific key **$usage** type for a given **$domain** AND **$participant**.
* tng-cdn.who.int/v2/trustlist/-/{{PARTICIPANT_CODE}}/did.json matches key material or references for all **$domain**s for a specific **$participant** without filtering the key usage types.
* tng-cdn.who.int/v2/trustlist/-/**$participant**/**$usage**/did.json matches keys or references in all **$domain**s for a specific **$participant** and specific key **$usage** type.
* tng-cdn.who.int/v2/trustlist/**$domain**/-/**$usage**/did.json matches keys for all **$participant**s of a specific **$domain** filtered by there key **$usage** type.
* tng-cdn-who.int/v2/trustlist/-/- matches key material for all **$domain**s and all **$participant**s without filtering a specific **$usage** type so the did.json may contain SCA and DSC keys.

And the following examples outline the expected behavior of reference type trustlist:

* tng-cdn.who.int/v2/trustlist-ref/did.json contains all DID document references of the next sub-level as DID id.
* tng-cdn.who.int/v2/trustlist-ref/**$domain**/did.json contains all **$participant** level DID document references as DID id for the given **$domain**.
* tng-cdn.who.int/v2/trustlist-ref/**$domain**/**$partcipant**/did.json contains all key **$usage** type level DID document references as DID id for the selected **$domain** and **$participant**.
* tng-cdn.who.int/v2/trustlist-ref/**$domain**/**$participant**/**$usage**/did.json contains a reference to a DID the embedded trustlist that correlates to the selected **$domain**, **$participant** and key **$usage** type and that contains the key material.

Note: all levels of the reference type trustlist may contain additional DID references linking trusted external DID documents.

The [did trustlists structure diagram](https://smart.who.int/trust/did-trustlist-structure.drawio.png) depicts the reference and contains relations of the trustlist types for the defined levels.

<img src="did-trustlist-structure.drawio.png" alt="DID trustlists structure" style="width:600px; float:none; margin: 0px 0px 0px 0px;"/>
