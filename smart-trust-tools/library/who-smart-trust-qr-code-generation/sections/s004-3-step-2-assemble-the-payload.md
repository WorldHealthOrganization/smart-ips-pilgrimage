---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s004-3-step-2-assemble-the-payload
section_title: "3. Step 2 — Assemble the payload"
file: "input/pagecontent/qr_code_generation.md"
lines: 57-85
source_sha256: 03253100cd38b5c6
granularity: heading
---
#### 3. Step 2 — Assemble the payload

Populate the logical model for the payload type you selected. For a DVC that is
[DVCMinPreQual](http://smart.who.int/trust-phw/StructureDefinition-DVCMinPreQual.html),
whose vaccine details are
[DVCMinVaccineDetailsPreQual](http://smart.who.int/trust-phw/StructureDefinition-DVCMinVaccineDetailsPreQual.html).
Follow those definitions for the element list, cardinalities and bindings rather
than any copy of them.

`DVCMinPreQual` is the concrete model: its parent `DVCMin` is abstract, as is
`DVCMinVaccineDetails`, so neither can be instantiated directly.

The element names are two and three characters long because every byte is paid
for twice — once in the CBOR encoding and again in the QR's module count.

Four points about *using* the model are not apparent from the StructureDefinition
and are worth stating here:

* `vx` is **1..1**. One DVC documents one immunization event. A visit at which
  two vaccines are administered produces two certificates and two QR codes.
* At least one of `is` or `cn` **must** be present — the
  `must-have-issuer-or-clinician-name` invariant.
* `id` is optional precisely because many certificate subjects have no
  identification document. A newborn is the obvious case; `gn` carries the
  parent or guardian instead.
* `vp` has a **required** binding to the WHO PreQual product identifiers, so the
  administered product must be resolved in the PreQual vaccine database and that
  identifier used. A clinical code for the vaccine *type* will not satisfy it.
