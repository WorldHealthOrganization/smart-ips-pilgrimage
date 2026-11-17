---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s001-generating-a-qr-code
section_title: "Generating a QR Code"
file: "input/pagecontent/qr_code_generation.md"
lines: 1-15
source_sha256: 03253100cd38b5c6
granularity: heading
---
### Generating a QR Code

This page is a step-by-step, implementer-facing walkthrough of how a signed
health certificate becomes a QR code on a piece of paper or a phone screen, and
how a verifier turns that QR code back into trustworthy data.

The container, the signature and the transport encoding are the *same* for every
GDHCN trust domain, and are specified normatively in the
[HCERT Specification](hcert_spec.html). What changes from one use case to the
next is only the **payload**: which logical model goes inside the `hcert` claim,
and under which subclaim. Everything after that choice is mechanical.

Where this page and the [HCERT Specification](hcert_spec.html) appear to differ,
the HCERT Specification is authoritative.
