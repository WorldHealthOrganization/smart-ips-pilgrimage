---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s003-2-step-1-select-the-payload-type
section_title: "2. Step 1 — Select the payload type"
file: "input/pagecontent/qr_code_generation.md"
lines: 32-56
source_sha256: 03253100cd38b5c6
granularity: heading
---
#### 2. Step 1 — Select the payload type

A payload is identified by a **subclaim** inside the `hcert` claim (`-260`).
The subclaims, and the logical model each one carries, are enumerated in the
[HCert logical model](StructureDefinition-HCert.html); section
[3.2.7.1](hcert_spec.html#3271-subclaims) of the HCERT Specification is
authoritative for which are assigned. The registered trust domains are listed in
the [GDHCN Trust Domain value set](ValueSet-Domains.html) and described under
[Trust Domains](trust_domains.html).

Two things are worth knowing before picking a number. Subclaims **0 and above are
reserved by WHO** and are allocated together with a trust domain, through the
GDHCN Secretariat. Subclaims that are **negative integers are the development
range** and are free to use, so an implementation using one is a pilot or a
development deployment and the number is not guaranteed to be stable.

[Section 3.2.7](hcert_spec.html#327-health-certificate-claim) of the
specification allows several types of health certificate to exist under the
`hcert` claim. Carrying exactly one is an implementation choice, not a
constraint of the container, and it is the choice made throughout this page.

> **For this walkthrough the payload is a DVC — a Digital Vaccine Certificate —
> carried under subclaim `-6`. The steps below are the steps for that payload.**
> A different payload changes only Step 2; Steps 3 to 9 are identical.
