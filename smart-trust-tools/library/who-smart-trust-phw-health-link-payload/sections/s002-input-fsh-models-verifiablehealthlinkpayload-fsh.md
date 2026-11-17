---
doc_id: who-smart-trust-phw-health-link-payload
doc_title: "HealthLinkPayload and VerifiableHealthLinkPayload logical models (FSH)"
section_id: s002-input-fsh-models-verifiablehealthlinkpayload-fsh
section_title: "input/fsh/models/VerifiableHealthLinkPayload.fsh"
file: "input/fsh/models/VerifiableHealthLinkPayload.fsh"
lines: 1-24
source_sha256: 98727a1cccc936bc
granularity: file
---
```text
Logical: 	VerifiableHealthLinkPayload
Parent: 	HealthLinkPayload
Title: 		"Verifiable Health Link Payload (DRAFT)"
Description:	"Verifiable Health Link Payload (DRAFT)

This logical model constrains the Health Link Payload for a Verifiable Health Link
"
Characteristics: #can-be-target
//* ^url = "https://profiles.ihe.net/ITI/VHL/StructureDefinition/VerifiableHealthLinkPayload"
* ^version = "RC2"
* ^status = #active
* type 1..1
* type from HL_TYPE (preferred)
/* obeys is-a-verifiable-health-link


Invariant: is-a-verifiable-health-link
Description: "The Health Link type is is a verifiable health link"
Severity: #error
Expression: "type = 'vhl'"



*/
```
