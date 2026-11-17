---
doc_id: who-smart-trust-cwt-payload-model
doc_title: "CWTPayload logical model (FSH)"
section_id: s001-input-fsh-models-cwt-payload-fsh
section_title: "input/fsh/models/cwt_payload.fsh"
file: "input/fsh/models/cwt_payload.fsh"
lines: 1-15
source_sha256: 14a0acab2e030e0e
granularity: file
---
```text

Logical:       CWTPayload
Title:	       "CBOR Web Token (CWT) Payload (Common)"
Description:   "Logical Model for CBOR Web Token (CWT) Payload Logical Modelin CWT Payload https://www.iana.org/assignments/cwt/cwt.xhtml "


* ^url = "http://smart.who.int/trust/StructureDefinition/CWTPayload"
* ^status = #active

* 1 0..1 Coding "Issuer Code (iss)" "Issuer"
* 4 0..1 dateTime "Expiration Date Time(exp)" "Expiration Time"
* 6 0..1 dateTime "Issued At (iat)" "Issued At"
// HCERT spec 3.2.7 allows several types of health certificate under this claim
* -260 1..* HCert "Health Certificate" "HCert"
```
