---
doc_id: ihe-iti-vhl-volume-1
doc_title: "IHE ITI Verifiable Health Link (VHL), Volume 1"
section_id: s035-1-xx-6-2-pcf-privacy-consent-on-fhir
section_title: "1:XX.6.2 PCF - Privacy Consent on FHIR"
file: "input/pagecontent/volume-1.md"
lines: 494-504
source_sha256: 1227bd54486fad1f
granularity: heading
---
### 1:XX.6.2 PCF - Privacy Consent on FHIR

The [IHE Privacy Consent on FHIR (PCF)](https://profiles.ihe.net/ITI/PCF/) profile is the recommended companion for capturing, storing, and enforcing patient consent alongside VHL. When the {{ linkvhls }} implements the Record Consent option, it acts as a Consent Recorder and initiates Access Consent [ITI-108] transactions to record consent declarations by the {{ linkvhlh }}.

Recommended groupings:

- **{{ linkvhlh }} (or the Holder's client app)** MAY be grouped with a PCF **Consent Creator** so that the Holder authors a `Consent` resource when generating a VHL.
- **{{ linkvhls }}** MAY be grouped with a PCF **Consent Recipient** so that consents governing a generated folder are persisted and discoverable, and with a PCF **Policy Enforcement Point (PEP)** so that the set of documents returned at [ITI-YY5](ITI-YY5.html) is filtered by the active `Consent.provision` (actor, purpose, period, class, code).

The `$generate-vhl` operation (ITI-YY3) accepts an optional `purposeOfUse` input parameter bound (extensible) to the HL7 v3 [PurposeOfUse](http://terminology.hl7.org/ValueSet/v3-PurposeOfUse) value set. The {{ linkvhls }} persists this value against the generated folder. When the {{ linkvhls }} is grouped with a PCF Consent Creator or Consent Recipient, the value populates `Consent.provision.purpose` on any `Consent` created for or bound to the folder. At ITI-YY5, the {{ linkvhls }} MAY reject manifest requests whose purpose claim (carried by the chosen authentication option — OAuth token, UDAP assertion, or Verifiable Credential) is inconsistent with the purpose recorded at generation time.
