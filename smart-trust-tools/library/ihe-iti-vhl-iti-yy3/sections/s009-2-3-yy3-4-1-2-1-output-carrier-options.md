---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s009-2-3-yy3-4-1-2-1-output-carrier-options
section_title: "2:3.YY3.4.1.2.1 Output Carrier Options"
file: "input/pagecontent/ITI-YY3.md"
lines: 104-120
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
###### 2:3.YY3.4.1.2.1 Output Carrier Options

The `format` request parameter selects one of two carriers for the returned VHL. Both carriers convey the same VHL payload (manifest URL, decryption key, flags, label, expiration, optional extension); they differ only in encoding, signature format, and the trust chain used for verification. **On a successful response**, exactly one of the response output parameters `qrcode` or `verifiableCredential` (see [2:3.YY3.4.2.2 Message Semantics](#23yy3422--message-semantics)) SHALL be populated; on failure, the response is an `OperationOutcome` with neither output parameter populated.

**QR Code Carrier (Default — `format=qrcode`)**

The default carrier when `format` is omitted or set to `qrcode`. The VHL payload is embedded in an [HCERT](https://smart.who.int/trust/StructureDefinition-HCert.html) structure at claim key 5 per the [WHO SMART Trust HCERT specification](https://smart.who.int/trust/hcert_spec.html), signed as a CWT, and rendered as a QR code with the `HC1:` prefix. The VHL Receiver verifies the CWT signature against the trust list. See [2:3.YY3.4.1.3 Expected Actions](#23yy3413-expected-actions) for the full VHL Payload Construction and HCERT/CWT encoding steps, including a worked example.

<a name="vc-enveloped-vhl-carrier-option--formatvc"></a>

**VC Enveloped VHL Carrier (Option — `format=vc`)**

Optional carrier. Available only when the {{ linkvhls }} supports the **VC Enveloped VHL Option** (see [Volume 1 Section 1:XX.2.6 VC Enveloped VHL Option](volume-1.html#1xx26-vc-enveloped-vhl-option-vhl-sharer)); if requested but unsupported, the {{ linkvhls }} SHALL return an `OperationOutcome` error. The same VHL payload is carried under `credentialSubject` of a JSON-LD W3C Verifiable Credential ([VC Data Model v2](https://www.w3.org/TR/vc-data-model-2.0/)) with an embedded `DataIntegrityProof` ([VC Data Integrity 1.0](https://www.w3.org/TR/vc-di-ecdsa/)) signed by the {{ linkvhls }} using its trust-network key — no new trust framework is introduced. See [2:3.YY3.4.1.3 Expected Actions](#23yy3413-expected-actions) for the full construction steps and a worked example.

> **Naming note:** This "VC Enveloped VHL Option" at ITI-YY3/YY4 carries the VHL itself. It is distinct from the "Verifiable Credential Option" at [ITI-YY5](ITI-YY5.html#23yy5415-authentication-option---verifiable-credential-option), which is a separate option for {{ linkvhlr }} authentication where the Receiver self-issues a VC as the manifest request body.
