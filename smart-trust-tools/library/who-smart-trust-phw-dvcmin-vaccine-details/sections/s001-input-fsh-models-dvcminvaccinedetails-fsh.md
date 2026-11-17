---
doc_id: who-smart-trust-phw-dvcmin-vaccine-details
doc_title: "DVCMinVaccineDetails logical model (FSH)"
section_id: s001-input-fsh-models-dvcminvaccinedetails-fsh
section_title: "input/fsh/models/DVCMinVaccineDetails.fsh"
file: "input/fsh/models/DVCMinVaccineDetails.fsh"
lines: 1-25
source_sha256: 3452d47e209c1fbc
granularity: file
---
```text
Logical: DVCMinVaccineDetails
Title:  "DVC HCert Vaccine Details (Minimal)"
Description:     "DVC Vaccine Details for a minimal DVC payload for use within an HCERT Payload"
* ^status = #active
* ^abstract = true
* vp 1..1 code "Vaccine Product ID"
  * ^code[+] = $ICVPCore#ICVP.C5.DE.11
  * ^code[+] = $LOINC#39236-5 "Vaccine code"
  * ^code[+] = $SCT#787859002 "Vaccine product (medicinal product)"
* dv 1..1 date "Date of vaccination"
  * ^code[+] = $ICVPCore#ICVP.C5.DE.13
  * ^code[+] = $LOINC#30952-6 "Date and time of vaccination"
* cn 0..1 string "Name of supervising clinician"
  * ^code[+] = $ICVPCore#ICVP.C5.DE.14
* is 0..1 id "Certificate issuer id (referenced organization)"
  * ^code[+] = $ICVPCore#ICVP.C5.DE.15
* bo 1..1 string "Batch No" "Batch No"
  * ^code[+] = $ICVPCore#ICVP.C5.DE.17
  * ^code[+] = $LOINC#30959-1 "Lot number [Identifier] Vaccine"
* obeys must-have-issuer-or-clinician-name

Invariant: must-have-issuer-or-clinician-name
Description: "Either issuer or clinicianName must be present"
Expression: "is.exists() or cn.exists()"
Severity: #error
```
