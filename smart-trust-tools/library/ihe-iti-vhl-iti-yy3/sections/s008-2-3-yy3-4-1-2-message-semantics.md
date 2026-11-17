---
doc_id: ihe-iti-vhl-iti-yy3
doc_title: "IHE VHL ITI-YY3 Generate VHL"
section_id: s008-2-3-yy3-4-1-2-message-semantics
section_title: "2:3.YY3.4.1.2 Message Semantics"
file: "input/pagecontent/ITI-YY3.md"
lines: 68-103
source_sha256: 07a1e4ecc7240dff
granularity: heading
---
##### 2:3.YY3.4.1.2 Message Semantics

The Generate VHL message is a FHIR operation request as defined in FHIR (<http://hl7.org/fhir/operations.html>) with the [$generate-vhl operation definition](OperationDefinition-generate-vhl.html).

Given that the parameters are not complex types, the HTTP GET operation shall be used as defined in FHIR (<http://hl7.org/fhir/operations.html#request>).

The name of the operation is `$generate-vhl`, and it is applied to FHIR Patient Resource type.

The URL for this operation is: `[base]/Patient/$generate-vhl`

Where **[base]** is the URL of VHL Sharer Service provider.

The Generate VHL message is performed by an HTTP GET command shown below:

```
GET [base]/Patient/$generate-vhl?sourceIdentifier=[token]{&exp=[positiveInt]}{&flag=[string]}{&label=[string]}{&passcode=[string]}{&purposeOfUse=[token]}{&format=[token]}
```

Each `purposeOfUse` value is serialized in FHIR token form (`system|code`, e.g., `http://terminology.hl7.org/CodeSystem/v3-ActReason|TREAT`) and MAY repeat.

**Note:** By default the operation generates a QR code containing the VHL encoded as an HCERT/CWT structure. When the VHL Sharer supports the **VC Enveloped VHL Option** the caller MAY set `format=vc` to request the VHL as a signed Verifiable Credential instead. See [Output Carrier Options](#output-carrier-options) below for both carrier definitions.

**Table 2:3.YY3.4.1.2-1: $generate-vhl Message HTTP query Parameters**

| Query parameter Name | Cardinality | Search Type | Description |
| -------------------- | ----------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| sourceIdentifier     | [1..1]    | token  | A FHIR [Identifier](http://hl7.org/fhir/R4/datatypes.html#Identifier) (business identifier — e.g., MRN, passport number, national ID) that the VHL Sharer uses to locate the Patient record and that Patient's documents.|
| exp      |  [0..1]  | postiveInt        | Optional. Number representing expiration time in Epoch seconds. |
| flag |  [0..1]  | string        | Optional. String created by concatenating single-character flags in alphabetical order. L (long-term use), P (Passcode required), U (direct file access). |
| label |  [0..1]  | string        | Optional. String no longer than 80 characters that provides a short description of the data behind the VHL. |
| passcode |  [0..1]  | string        | Optional. User-supplied passcode for passcode-protected VHLs. If provided, the VHL Sharer SHALL securely hash and store this passcode for validation during manifest retrieval (ITI-YY5). The 'P' flag SHALL be included in the flag parameter when a passcode is set. |
| purposeOfUse | [0..*] | token | Optional. Purpose(s) of use the VHL Holder is authorizing for this share, bound (extensible) to [PurposeOfUse](http://terminology.hl7.org/ValueSet/v3-PurposeOfUse) (e.g., `TREAT`, `HPAYMT`, `HRESCH`). Serialized as FHIR `system|code`. See [Purpose of Use Handling](#purpose-of-use-handling). |
| format | [0..1] | token | Optional. Requested carrier for the returned VHL. Allowed values: `qrcode` (default) or `vc`. `vc` requires the VHL Sharer to support the [VC Enveloped VHL Carrier Option](#vc-enveloped-vhl-carrier-option--formatvc); if unsupported, the VHL Sharer SHALL return an OperationOutcome error. See [Output Carrier Options](#output-carrier-options) below. |

<a name="output-carrier-options"></a>
