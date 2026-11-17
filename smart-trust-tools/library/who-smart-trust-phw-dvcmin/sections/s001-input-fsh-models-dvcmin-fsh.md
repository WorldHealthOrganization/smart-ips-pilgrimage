---
doc_id: who-smart-trust-phw-dvcmin
doc_title: "DVCMin logical model (FSH)"
section_id: s001-input-fsh-models-dvcmin-fsh
section_title: "input/fsh/models/DVCMin.fsh"
file: "input/fsh/models/DVCMin.fsh"
lines: 1-33
source_sha256: 4e9458c303c44698
granularity: file
---
```text
Logical:         DVCMin
Title:           "DVC HCERT Payload"
Description:     "Minimal DVC payload for use within an HCERT Payload"
* ^status = #active
* ^abstract = true
* n 1..1 string "Name"
  * ^code[+] = $ICVPCore#ICVP.A9.DE.1
  * ^code[+] = $LOINC#87226-7 "Legal name of patient - first and last"
* dob 1..1 date "Date of birth"
  * ^code[+] = $ICVPCore#ICVP.A9.DE.2
  * ^code[+] = $LOINC#21112-8 "Birth date"
  * ^code[+] = $SCT#184099003 "Date of birth (observable entity)"
* s 1..1 code "Sex"
* s from $GENDER (extensible)
  * ^code[+] = $ICVPCore#ICVP.A9.DE.3
* nt 1..1 code "Nationality"
* nt from $countryVS (extensible)
  * ^code[+] = $ICVPCore#ICVP.A9.DE.8
  * ^code[+] = $LOINC#69433-1 "Citizenship status"
  * ^code[+] = $SCT#223369002 "Country (geographic location)"
* id 0..1 string "National Identification Document"
  * ^code[+] = $ICVPCore#ICVP.A9.DE.9
  * ^code[+] = $LOINC#76435-7 "Patient identifier"
  * ^code[+] = $SCT#900000000000474003 "Universally Unique Identifier (foundation metadata concept)"
* dt 0..1 code "National ID Document Type"
* dt from $identifierTypeVS (extensible)
* gn 0..1 string "Parent or Guardian Name"
  * ^code[+] = $ICVPCore#ICVP.A9.DE.10
  * ^code[+] = $LOINC#79183-0 "First name of Guardian or legally authorized representative"
  * ^code[+] = $SCT#394619001 "Guardian (person)"
* vx 1..1 DVCMinVaccineDetails "Vaccine Details" "Vaccine Details"
* v 1..1 string "Version" "Version of the certificate template"
  * ^code[+] = $ICVPCore#ICVP.D5.DE.27
```
