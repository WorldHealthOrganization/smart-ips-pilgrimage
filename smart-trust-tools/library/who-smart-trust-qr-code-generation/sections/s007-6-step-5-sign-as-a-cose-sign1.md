---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s007-6-step-5-sign-as-a-cose-sign1
section_title: "6. Step 5 — Sign as a COSE_Sign1"
file: "input/pagecontent/qr_code_generation.md"
lines: 111-140
source_sha256: 03253100cd38b5c6
granularity: heading
---
#### 6. Step 5 — Sign as a COSE_Sign1

Wrap the CBOR payload in a single-signer COSE structure
([RFC 8152](https://tools.ietf.org/html/rfc8152)), CBOR tag `18`, with `alg`
(label 1) and `kid` (label 4) in the protected header.

ES256 is the primary algorithm (`alg` `-7`) and PS256 the secondary (`-37`).
Both MUST be implemented even though only one signs any given certificate; the
secondary exists so that a break in the primary does not strand the whole
network. `kid` MAY instead sit in the unprotected header, and verifiers MUST
accept both placements — but when it appears in both, the protected one wins.

**Deriving the `kid`**: take the DER encoding of the DSC and use the **first 8
bytes of its SHA-256 fingerprint**. Because it is truncated, `kid` is not
unique, so a verifier that finds several DSCs with the same `kid` MUST try all
of them. `kid` is not security-critical; it is a lookup hint.

**Computing the signature**: build the `Sig_structure`

```
Sig_structure = [ "Signature1", protected_header_bstr, external_aad (empty), payload ]
```

serialise it as CBOR, and sign those bytes. For ES256 the COSE signature value
is the fixed-width concatenation `r || s`, 32 bytes each — **not** the ASN.1 DER
encoding that most crypto libraries return by default. Converting between the
two is the single most common interoperability bug in HCERT implementations.

The resulting structure is `18([protected, unprotected, payload, signature])`.
