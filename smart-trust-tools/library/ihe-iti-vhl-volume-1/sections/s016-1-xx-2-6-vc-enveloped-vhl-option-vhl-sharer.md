---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s016-1-xx-2-6-vc-enveloped-vhl-option-vhl-sharer
section_title: "1:XX.2.6 VC Enveloped VHL Option (VHL Sharer)"
file: "input/pagecontent/volume-1.md"
lines: 322-340
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.2.6 VC Enveloped VHL Option (VHL Sharer)

The VC Enveloped VHL Option enables the {{ linkvhls }} to return the VHL as a signed W3C Verifiable Credential (`application/vc+ld+json`) instead of a QR code in the ITI-YY3 Generate VHL transaction. The VC is subsequently transmitted to the {{ linkvhlr }} via ITI-YY4 Provide VHL as an alternative carrier to the HCERT/CWT QR code.

This option provides:
- An alternative carrier for the VHL payload, suitable for machine-to-machine transfer and asynchronous delivery where QR presentation is impractical
- A JSON-LD representation compatible with VC-aware ecosystems
- Reuse of the existing trust network — the VC's `DataIntegrityProof` chains to the same trust anchors used for HCERT/CWT verification (no new trust framework introduced)

**How It Works:**

When the caller of `$generate-vhl` sets `format=vc` and the {{ linkvhls }} supports this option, the {{ linkvhls }} returns the VHL payload under `credentialSubject` of a VC issued per the [W3C Verifiable Credentials Data Model v2](https://www.w3.org/TR/vc-data-model-2.0/), with an embedded `DataIntegrityProof` (cryptosuite `ecdsa-2019`) signed by the {{ linkvhls }} using its trust-network key. The same fields otherwise embedded at HCERT claim key 5 (`url`, `key`, `flag`, `label`, `exp`, `v`, `extension`) are carried in `credentialSubject`. If the option is not supported and `format=vc` is requested, the {{ linkvhls }} SHALL return an OperationOutcome error.

**Naming Note:** This option (a Sharer option carrying the VHL) is distinct from the **Verifiable Credential Option** (a Receiver authentication option at ITI-YY5 where the Receiver self-issues a VC as the manifest request body).

See ITI-YY3 Section [2:3.YY3.4.1.2.1 Output Carrier Options](ITI-YY3.html#output-carrier-options) for VC construction, ITI-YY4 Section [2:3.YY4.4.1.2 Message Semantics](ITI-YY4.html#23yy4412-message-semantics) for transmission, and ITI-YY4 Section [2:3.YY4.4.1.4 Expected Actions - VHL Receiver](ITI-YY4.html#23yy4414-expected-actions---vhl-receiver) for decoding.

<a name="required-groupings"> </a>
