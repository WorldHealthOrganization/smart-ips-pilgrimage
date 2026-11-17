---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s016-12-3-issuer
section_title: "12.3 Issuer"
file: "input/pagecontent/qr_code_generation.md"
lines: 235-249
source_sha256: 03253100cd38b5c6
granularity: heading
---
##### 12.3 Issuer

The example is issued by GDHCN **DEV participant `XXR`**, not by any Member
State. GDHCN participant codes are ISO 3166-1 alpha-3, while the CWT `iss` claim
and the X.509 country attribute take the alpha-2 form — here `XR`, matching the
`C=XR` attribute of the Document Signing Certificate subject.

Signing uses a key whose public key is onboarded to the GDHCN DEV trust network,
so the example verifies against the DEV trust list. The private key is held in
the build environment and never enters this repository; only the DSC, the SCA,
the QR images and the `HC1:` strings are published.

Because `iat` must fall inside the DSC validity period and `exp` must not exceed
it, the scenario dates sit inside the window of the onboarded DEV certificate.
