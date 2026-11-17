---
doc_id: ihe-iti-vhl-iti-yy4
doc_title: "IHE VHL ITI-YY4 Provide VHL"
section_id: s013-2-3-yy4-4-2-2-message-semantics
section_title: "2:3.YY4.4.2.2 Message Semantics"
file: "input/pagecontent/ITI-YY4.md"
lines: 294-305
source_sha256: a01169d66ede4502
granularity: heading
---
##### 2:3.YY4.4.2.2 Message Semantics

For transmission mechanisms supporting bidirectional communication, response MAY include:

| Element | Cardinality | Description |
|---------|-------------|-------------|
| Acknowledgment | 0..1 | Confirmation VHL received and validated |
| Receipt Identifier | 0..1 | Unique identifier for receipt transaction |
| Receiver Identifier | 0..1 | Identifier of VHL Receiver organization |
| Timestamp | 0..1 | ISO 8601 timestamp of receipt |
{: .grid}
