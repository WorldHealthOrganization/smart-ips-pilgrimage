---
title: User journey coverage
nav_order: 2
---

# User journey coverage (DRAFT journeys J1 to J4)

What the HCERT library must do for each step of the workshop storyline, and
whether it does. OHS Player, OHS Stack and the CHW and wallet apps are
consumers of the Kotlin library; rendering, scanning, storage, HTTP and
FHIR record keeping are theirs. Source: stakeholder directive
`dir-journeys`, 2026-10-20.

| Journey step | Library capability | Status |
|---|---|---|
| **J1** Country A clinic issues a DVC for each newborn vaccine (Hep B, polio) | DVCMin payload, one event per certificate (STT-PAY-003); no identity document for a newborn (STT-PAY-005); guardian name `gn`; any national vaccine code in `vp` (extensible binding) | Done: `HcertIssuer.prepare` / `finish` |
| J1 signs with the clinic's DSC key held in Android Keystore or an HSM | Two-phase signing, no private key in process (STT-ISS-004, STT-COS-006) | Done |
| J1 printed paper QR, or SMS/MMS | HC1 string is QR Alphanumeric only (STT-QR-001); the app renders it at error correction Q | Done (rendering is the app's) |
| J1 DEV keys and DEV trust list | Trust store loads GDHCN DID trustlist v2 documents (DEV, UAT, PROD alike) and PEM | Done: `addDidDocument`, `addPem`; the app fetches from the [trust list distribution endpoints](https://smart.who.int/trust/endpoints.html#trustlist-distribution-endpoints) |
| **J2** CHW, offline, reads the foreign QR to register the child and refer | Explicitly named unverified read, its result typed as unverified (STT-VER-011) | Done: `HcertVerifier.readUnverified` |
| J2 alternative: verify offline on the CHW device | Verification is synchronous and offline against a store the app filled earlier (STT-GEN-012, STT-VER-009) | Done; which one J2 uses is the journey's open question |
| **J3** Clinic verifies the foreign DVC | GDHCN verification in the STT-VER-001 order, typed failures (STT-VER-008), EKU check (STT-VER-004) | Done: `HcertVerifier.verify`, PR 129 vector verifies on JVM and Node |
| J3 imports the immunization into the domestic record | The verified DVCMin fields; mapping to FHIR R4 `Immunization`/`Patient` | Not in this library (the app maps). Worked examples in smart-trust-demo: [TrustDemoJ3HepB](https://litlfred.github.io/smart-trust-demo/Immunization-TrustDemoJ3HepB.html) and [TrustDemoJ3Bcg](https://litlfred.github.io/smart-trust-demo/Immunization-TrustDemoJ3Bcg.html), with their [verification provenance](https://litlfred.github.io/smart-trust-demo/Provenance-TrustDemoJ3Verification.html) |
| J3 adds the national schedule code beside the foreign vaccine code | The library passes the issuer's `vp` code through unchanged and rejects nothing for an unknown code. The translation is a FHIR `ConceptMap` (`$translate`) the clinic EHR applies, adding the national coding and never replacing the issuer's | Not in this library. Worked example in smart-trust-demo: ConceptMap [TrustDemoProductToOnesaEpi](https://litlfred.github.io/smart-trust-demo/ConceptMap-TrustDemoProductToOnesaEpi.html) (product → national schedule dose of Onesa, the demo's fictional home country); a product with no entry goes to the nurse, whose decision is recorded ([TrustDemoJ3Adjudication](https://litlfred.github.io/smart-trust-demo/Provenance-TrustDemoJ3Adjudication.html)) and added to the map |
| **J4.0** National portal issues one passcode-protected VHL QR per family member | VHL payload (SHL payload format, flag P) as a CBOR map at HCERT claim -260 key 5 (STT-VHL-001, STT-VHL-002); key generation (STT-VHL-004); JWE dir / A256GCM encryption of each document (STT-VHL-007) | Done: `HcertIssuer` with `Payload.Vhl`, `HcertVhl.newKey`, `HcertVhl.encrypt`; hosting the manifest and enforcing the passcode are the VHL host's |
| **J4.1** Clinic abroad scans a VHL, fetches with passcode, reads IPS | Verify the VHL HCERT, map or `vhlink:/` string at key 5, and the link's exp (STT-VHL-002, STT-VHL-009); ITI-YY5 request (STT-VHL-005); HTTP Message Signatures (STT-VHL-008); manifest Bundle (STT-VHL-006); decrypt each document (STT-VHL-007) | Done: `HcertVerifier.verify`, `HcertVhl.buildManifestRequest`, `buildSignatureBase`/`signatureHeader`, `parseManifest`, `decrypt`; the HTTP, mutual TLS and AuditEvents are the app's |

## VHL: what the specifications say, and where they disagree

Changes raised upstream: WorldHealthOrganization/smart-trust#130 (subclaim 5
is a VHL, a CBOR map), WorldHealthOrganization/smart-trust-phw#17 (payload
types match SMART Health Links), and a patch for IHE ITI.VHL in
[`upstream/ihe-iti-vhl/`](https://github.com/litlfred/smart-trust-tools/tree/cat/smart-trust-tools/upstream-patches/upstream/ihe-iti-vhl)
(ITI-YY3 key 5 as a CBOR map, example fixes). Open issues OI-21 to OI-29.

The IHE ITI VHL profile and the WHO `VerifiableHealthLinkPayload` model
share the SMART Health Links payload fields, but:

- IHE's manifest is a FHIR `List` search returning a searchset Bundle of
  `DocumentReference`s (ITI-YY5), not the SMART Health Links `files[]`
  manifest; the Bundle is not signed, and the journey's "signed VHL
  manifests" exist in neither specification.
- The value at hcert key 5 is a `vhlink:/` text string in ITI-YY3 but a
  decoded JSON object in the ITI-YY4 example; HCERT 3.2.7.1.5 calls it a
  SMART Health Link (OI-06).
- WHO requires `type` (`vhl`) and types `exp` and `v` as strings; IHE has no
  `type` and uses numbers.
- JWE `alg`/`enc` are not normative (the example is `dir` / `A256GCM`); no
  `zip`.
- Requester authentication (RFC 9421 HTTP signatures, UDAP, or a VC) and the
  DID trust list's mapping to a COSE `kid` are under-specified.
