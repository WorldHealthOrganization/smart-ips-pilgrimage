Instance: ExampleComposition
InstanceOf: HajjIPSComposition
Title : "Hajj IPS Composition"
Description: "Hajj IPS Composition Example"
Usage: #example
* identifier.system = "urn:oid:2.16.724.4.8.10.200.10"
* identifier.value = "3f69e0a5-2177-4540-baab-7a5d0877428f"
* status = #final
* type = $loinc#60591-5 "Patient summary Document"
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* date = "2017-12-11T14:30:00+01:00"
* author = Reference(1c616b24-3895-48c4-9a02-9a64110351ee)
* title = "Patient Summary as of December 11, 2017 14:30"
* text.div =   "<div xmlns=\"http://www.w3.org/1999/xhtml\"><div style=\"display: inline-block; background-color: #d9e0e7; padding: 6px; margin: 4px; border: 1px solid #8da1b4; border-radius: 5px; line-height: 60%\"><p style=\"margin-bottom: 0px\">Resource &quot;30551ce1-5a28-4356-b684-1e639094ad4d&quot; </p></div><p><b>identifier</b>: id: 3f69e0a5-2177-4540-baab-7a5d0877428f</p><p><b>status</b>: final</p><p><b>type</b>: Patient summary Document <span style=\"background: LightGoldenRodYellow; margin: 4px; border: 1px solid khaki\"> (<a href=\"https://loinc.org/\">LOINC</a>#60591-5)</span></p><p><b>date</b>: 2017-12-11 02:30:00+0100</p><p><b>author</b>: Beetje van Hulp, MD</p><p><b>title</b>: Patient Summary as of December 11, 2017 14:30</p><p><b>confidentiality</b>: N</p><blockquote><p><b>attester</b></p><p><b>mode</b>: legal</p><p><b>time</b>: 2017-12-11 02:30:00+0100</p><p><b>party</b>: Beetje van Hulp, MD</p></blockquote><blockquote><p><b>attester</b></p><p><b>mode</b>: legal</p><p><b>time</b>: 2017-12-11 02:30:00+0100</p><p><b>party</b>: Anorg Aniza Tion BV</p></blockquote><p><b>custodian</b>: Anorg Aniza Tion BV</p><h3>RelatesTos</h3><table class=\"grid\"><tr><td>-</td><td><b>Code</b></td><td><b>Target[x]</b></td></tr><tr><td>*</td><td>appends</td><td>id: c2277753-9f90-4a95-8ddb-a0b3f6e7d292</td></tr></table><h3>Events</h3><table class=\"grid\"><tr><td>-</td><td><b>Code</b></td><td><b>Period</b></td></tr><tr><td>*</td><td>care provision <span style=\"background: LightGoldenRodYellow; margin: 4px; border: 1px solid khaki\"> (ActClass#PCPR)</span></td><td>?? --&gt; 2017-12-11 02:30:00+0100</td></tr></table></div>"
* text.status = #generated
* confidentiality = #N
* attester[0].mode = #legal
* attester[=].time = "2017-12-11T14:30:00+01:00"
* attester[=].party = Reference(1c616b24-3895-48c4-9a02-9a64110351ee)
* attester[+].mode = #legal
* attester[=].time = "2017-12-11T14:30:00+01:00"
* attester[=].party = Reference(890751f4-2924-4636-bab7-efffc7f3cf14)
* custodian = Reference(890751f4-2924-4636-bab7-efffc7f3cf14)
* relatesTo.code = #appends
* relatesTo.targetIdentifier.system = "urn:oid:2.16.724.4.8.10.200.10"
* relatesTo.targetIdentifier.value = "c2277753-9f90-4a95-8ddb-a0b3f6e7d292"
* event.code = $v3-ActClass#PCPR
* event.period.end = "2017-12-11T14:30:00+01:00"

* section[sectionProblems].title = "Active Problems"
// * section[sectionProblems].code = $loinc#11450-4 "Problem list - Reported"
* section[sectionProblems].text.status = #generated
* section[sectionProblems].text.div = "<div xmlns=\"http://www.w3.org/1999/xhtml\">Hot75e8bf23bc89 flushes</div>"
* section[sectionProblems].entry = Reference(c64139e7-f02d-409c-bf34-75e8bf23bc89)

* section[sectionMedications].title = "Medication"
// * section[sectionMedications].code = $loinc#10160-0 "History of Medication use Narrative"
* section[sectionMedications].text.status = #generated
* section[sectionMedications].text.div = "<div xmlns=\"http://www.w3.org/1999/xhtml\"><table><thead><tr><th>Medication</th><th>Strength</th><th>Form</th><th>Dosage</th><th>Comment</th></tr></thead><tbody><tr><td>Anastrozole</td><td>1 mg</td><td>tablet</td><td>once daily</td><td>treatment for breast cancer</td></tr><tr><td>Black Cohosh Extract</td><td></td><td>pil</td><td></td><td>herbal supplement</td></tr></tbody></table></div>"
* section[sectionMedications].entry[0] = Reference(c220e36c-eb67-4fc4-9ba1-2fabc52acec5)
* section[sectionMedications].entry[+] = Reference(47524493-846a-4a26-bae2-4ab03e60f02d)

* section[sectionAllergies].title = "Allergies and Intolerances"
// * section[sectionAllergies].code = $loinc#48765-2 "Allergies and adverse reactions Document"
* section[sectionAllergies].text.status = #generated
* section[sectionAllergies].text.div = "<div xmlns=\"http://www.w3.org/1999/xhtml\">Allergy to penicillin, high criticality</div>"
* section[sectionAllergies].entry[0] = Reference(72884cad-ebe6-4f43-a51a-2f978275f131)

* section[sectionPastIllnessHx].title = "History of Past Illness"
// * section[sectionPastIllnessHx].code = $loinc#11348-0 "History of Past illness Narrative"
* section[sectionPastIllnessHx].text.status = #generated
* section[sectionPastIllnessHx].text.div = "<div xmlns=\"http://www.w3.org/1999/xhtml\">Breast cancer Stage II with no evidence of recurrence following treatment</div>"
* section[sectionPastIllnessHx].entry = Reference(c4597aa2-688a-401b-a658-70acc6de28c5)

* section[sectionPlanOfCare].title = "Plan of Treatment"
// * section[sectionPlanOfCare].code = $loinc#18776-5 "Plan of care note"
* section[sectionPlanOfCare].text.status = #generated
* section[sectionPlanOfCare].text.div = "<div xmlns=\"http://www.w3.org/1999/xhtml\">Continue hormone medication with Anastrozole for total of 5 years and monitor for potential breast cancer recurrence</div>"

* section[sectionResults].title = "Results"
// * section[sectionResults].code = $loinc#30954-2 "Relevant diagnostic tests/laboratory data Narrative"
* section[sectionResults].text.status = #generated
* section[sectionResults].text.div = "<div xmlns=\"http://www.w3.org/1999/xhtml\"><table><thead><tr><th colspan=\"3\">Blood typing</th></tr></thead><tbody><tr><td>Blood group</td><td>A+</td><td/></tr><tr><td>C Ab [Presence] in Serum or Plasma</td><td>Positive</td><td/></tr><tr><td>E Ab [Presence] in Serum or Plasma</td><td>Positive</td><td/></tr><tr><td>Little c Ab [Presence] in Serum or Plasma</td><td>Negative</td><td/></tr></tbody></table><table><thead><tr><th colspan=\"3\">Hemoglobin A1c monitoring</th></tr></thead><tbody><tr><td>Hemoglobin A1c/Hemoglobin.total in Blood by HPLC</td><td>7.5 %</td><td/></tr></tbody></table><table><thead><tr><th colspan=\"3\">Bacteriology</th></tr></thead><tbody><tr><td colspan=\"3\">Methicillin resistant Staphylococcus aureus</td></tr><tr><td colspan=\"3\">Healthy carrier of MRSA</td></tr></tbody></table></div>"
* section[sectionResults].entry[0] = Reference(2639657a-c19a-48e2-82cc-471e13b8ad93)
* section[sectionResults].entry[+] = Reference(cc354e00-a419-47ea-8b6c-1768b2a01645)
* section[sectionResults].entry[+] = Reference(26bee0a9-5997-4557-ab9d-c6adbb05b571)

* section[sectionAdvanceDirectives].title = "Advance Directives"
// * section[sectionAdvanceDirectives].code = $loinc#42348-3
* section[sectionAdvanceDirectives].text.status = #generated
* section[sectionAdvanceDirectives].text.div = "<div xmlns=\"http://www.w3.org/1999/xhtml\">Consent MYS for pilgrimage</div>"
* section[sectionAdvanceDirectives].entry = Reference(c7781f44-6df8-4a8b-9e06-0b34263a47c6)



Instance: 2b90dd2b-2dab-4c75-9bb9-a355e07401e7
InstanceOf: PatientUvIps
Usage: #example
//* id = "2b90dd2b-2dab-4c75-9bb9-a355e07401e7"
* identifier.system = "urn:oid:2.16.840.1.113883.2.4.6.3"
* identifier.value = "574687583"
* active = true
* name.family = "DeLarosa"
* name.given = "Martha"
* telecom.system = #phone
* telecom.value = "+31788700800"
* telecom.use = #home
* gender = #female
* birthDate = "1972-05-01"
* address.line = "Laan Van Europa 1600"
* address.city = "Dordrecht"
* address.postalCode = "3317 DB"
* address.country = "NL"
* contact.relationship = $v3-RoleCode#MTH
* contact.name.family = "Mum"
* contact.name.given = "Martha"
* contact.telecom.system = #phone
* contact.telecom.value = "+33-555-20036"
* contact.telecom.use = #home
* contact.address.line = "Promenade des Anglais 111"
* contact.address.city = "Lyon"
* contact.address.postalCode = "69001"
* contact.address.country = "FR"

Instance: 1c616b24-3895-48c4-9a02-9a64110351ee
InstanceOf: PractitionerUvIps
Usage: #example
* identifier.system = "urn:oid:2.16.528.1.1007.3.1"
* identifier.value = "129854633"
* identifier.assigner.display = "CIBG"
* active = true
* name.family = "van Hulp"
* name.given = "Beetje"
* qualification.code.coding.version = "2.7"
* qualification.code.coding = $v2-0360#MD "Doctor of Medicine"

Instance: 890751f4-2924-4636-bab7-efffc7f3cf14
InstanceOf: OrganizationUvIps
Usage: #example
* identifier.system = "urn:oid:2.16.528.1.1007.3.3"
* identifier.value = "564738757"
* active = true
* name = "Anorg Aniza Tion BV / The best custodian ever"
* telecom.system = #phone
* telecom.value = "+31-51-34343400"
* telecom.use = #work
* address.use = #work
* address.line = "Houttuinen 27"
* address.city = "Dordrecht"
* address.postalCode = "3311 CE"
* address.country = "NL"

Instance: c64139e7-f02d-409c-bf34-75e8bf23bc89
InstanceOf: ConditionUvIps
Usage: #example
* identifier.system = "urn:oid:1.2.3.999"
* identifier.value = "c87bf51c-e53c-4bfe-b8b7-aa62bdd93002"
* clinicalStatus = $condition-clinical#active
* verificationStatus = $condition-ver-status#confirmed
* category = $loinc#75326-9 "Problem"
* severity = $loinc#LA6751-7 "Moderate"
* code.coding[0] = $sct#198436008 "Menopausal flushing (finding)"
* code.coding[=].display.extension.extension[0].url = "lang"
* code.coding[=].display.extension.extension[=].valueCode = #nl-NL
* code.coding[=].display.extension.extension[+].url = "content"
* code.coding[=].display.extension.extension[=].valueString = "opvliegers"
* code.coding[=].display.extension.url = "http://hl7.org/fhir/StructureDefinition/translation"
* code.coding[+] = $icd-10#N95.1 "Menopausal and female climacteric states"
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* onsetDateTime = "2015"
* recordedDate = "2016-10"

Instance: c220e36c-eb67-4fc4-9ba1-2fabc52acec5
InstanceOf: MedicationStatementIPS
Usage: #example
* identifier.system = "urn:oid:1.2.3.999"
* identifier.value = "b75f92cb-61d4-469a-9387-df5ef70d25f0"
* status = #active
* medicationReference = Reference(urn:uuid:976d0804-cae0-45ae-afe3-a19f3ceba6bc)
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* effectivePeriod.start = "2015-03"
* dosage.timing.repeat.count = 1
* dosage.timing.repeat.periodUnit = #d
* dosage.route = $standardterms#20053000 "Oral use"
* dosage.doseAndRate.type = $dose-rate-type#ordered "Ordered"
* dosage.doseAndRate.doseQuantity = 1 '1' "tablet"

Instance: 47524493-846a-4a26-bae2-4ab03e60f02d
InstanceOf: MedicationStatementIPS
Usage: #example
* identifier.system = "urn:oid:1.2.3.999"
* identifier.value = "9e312d6b-c6b6-439a-a730-6efaa5dcf8bc"
* status = #active
* medicationReference = Reference(urn:uuid:8adc0999-9468-4ac9-9557-680fa133d626)
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* effectivePeriod.start = "2016-01"
* dosage.route = $standardterms#20053000 "Oral use"

Instance: 976d0804-cae0-45ae-afe3-a19f3ceba6bb
InstanceOf: MedicationIPS
Usage: #example
* code.coding[0] = $sct#108774000 "Product containing anastrozole (medicinal product)"
* code.coding[+] = urn:oid:2.16.840.1.113883.2.4.4.1#99872 "ANASTROZOL 1MG TABLET"
* code.coding[+] = urn:oid:2.16.840.1.113883.2.4.4.7#2076667 "ANASTROZOL CF TABLET FILMOMHULD 1MG"
* code.coding[+] = $atc#L02BG03 "anastrozole"

Instance: 8adc0999-9468-4ac9-9557-680fa133d625
InstanceOf: MedicationIPS
Usage: #example
* code.coding[0] = $sct#412588001 "Cimicifuga racemosa extract (substance)"
* code.coding[=].display.extension.extension[0].url = "lang"
* code.coding[=].display.extension.extension[=].valueCode = #nl-NL
* code.coding[=].display.extension.extension[+].url = "content"
* code.coding[=].display.extension.extension[=].valueString = "Zwarte Cohosh Extract"
* code.coding[=].display.extension.url = "http://hl7.org/fhir/StructureDefinition/translation"
* code.coding[+] = $atc#G02CX04 "Cimicifugae rhizoma"
* code.text = "Black Cohosh Extract herbal supplement"

Instance: 72884cad-ebe6-4f43-a51a-2f978275f131
InstanceOf: AllergyIntoleranceUvIps
Usage: #example
//* identifier.system = "urn:oid:1.2.3.999"
//* identifier.value = "72884cad-ebe6-4f43-a51a-2f978275f132"
* clinicalStatus = $allergyintolerance-clinical#active
* verificationStatus = $allergyintolerance-verification#confirmed
* type = #allergy
* category = #medication
* criticality = #high
* extension.url = "http://hl7.org/fhir/StructureDefinition/allergyintolerance-abatement"
* extension.valueDateTime = "2010"
* code = $sct#373270004 "Substance with penicillin structure and antibacterial mechanism of action (substance)"
* patient = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* onsetDateTime.extension.url = "http://hl7.org/fhir/StructureDefinition/data-absent-reason"
* onsetDateTime.extension.valueCode = #unknown
//* onsetDateTime = "2010"

Instance: c4597aa2-688a-401b-a658-70acc6de28c5
InstanceOf: ConditionUvIps
Usage: #example
* identifier.system = "urn:oid:1.2.3.999"
* identifier.value = "66d4a8c7-9081-43e0-a63f-489c2ae6edd6"
* clinicalStatus = $condition-clinical#remission
* verificationStatus = $condition-ver-status#confirmed
* category = $loinc#75326-9 "Problem"
* severity = $loinc#LA6750-9 "Severe"
* code.coding[0] = $sct#254837009 "Malignant tumor of breast"
* code.coding[=].display.extension.extension[0].url = "lang"
* code.coding[=].display.extension.extension[=].valueCode = #nl-NL
* code.coding[=].display.extension.extension[+].url = "content"
* code.coding[=].display.extension.extension[=].valueString = "Borstkanker stadium II zonder aanwijzingen van recidieven na behandeling"
* code.coding[=].display.extension.url = "http://hl7.org/fhir/StructureDefinition/translation"
* code.coding[+] = $icd-o-3#8500/3 "Infiltrating duct carcinoma, NOS"
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* onsetDateTime = "2015-01"
* abatementDateTime = "2015-03"

Instance: 45a5c5b1-4ec1-4d60-b4b2-ff5a84a41fd6
InstanceOf: OrganizationUvIps
Usage: #example
* active = true
* type = $organization-type#other
* name = "Laboratoire de charme"

Instance: aa11a2be-3e36-4be7-b58a-6fc3dace2740
InstanceOf: ObservationResultsLaboratoryPathologyUvIps
Usage: #example
* status = #final
//* category = $observation-category#laboratory
* code = $loinc#882-1 "ABO and Rh group [Type] in Blood"
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* effectiveDateTime = "2015-10-10T09:15:00+01:00"
* performer = Reference(urn:uuid:45a5c5b1-4ec1-4d60-b4b2-ff5a84a41fd7)
* valueCodeableConcept = $sct#278149003 "Blood group A Rh(D) positive"

Instance: 6e39ccf3-f997-4a2b-8f28-b4b71c778c79
InstanceOf: ObservationResultsLaboratoryPathologyUvIps
Usage: #example
* status = #final
//* category = $observation-category#laboratory
* code = $loinc#945-6 "C Ab [Presence] in Serum or Plasma"
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* effectiveDateTime = "2015-10-10T09:35:00+01:00"
* performer = Reference(urn:uuid:45a5c5b1-4ec1-4d60-b4b2-ff5a84a41fd7)
* valueCodeableConcept = $sct#10828004 "Positive"

Instance: b4916505-a06b-460c-9be8-011609282456
InstanceOf: ObservationResultsLaboratoryPathologyUvIps
Usage: #example
* status = #final
// * category = $observation-category#laboratory
* code = $loinc#1018-1 "E Ab [Presence] in Serum or Plasma"
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* effectiveDateTime = "2015-10-10T09:35:00+01:00"
* performer = Reference(urn:uuid:45a5c5b1-4ec1-4d60-b4b2-ff5a84a41fd7)
* valueCodeableConcept = $sct#10828004 "Positive"

Instance: a6a5a1d5-c896-4c7e-b922-888fcc7e6ae3
InstanceOf: ObservationResultsLaboratoryPathologyUvIps
Usage: #example
* status = #final
// * category = $observation-category#laboratory
* code = $loinc#1156-9 "little c Ab [Presence] in Serum or Plasma"
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* effectiveDateTime = "2015-10-10T09:35:00+01:00"
* performer = Reference(urn:uuid:45a5c5b1-4ec1-4d60-b4b2-ff5a84a41fd7)
* valueCodeableConcept = $sct#260385009 "Negative"

Instance: 2639657a-c19a-48e2-82cc-471e13b8ad93
InstanceOf: ObservationResultsLaboratoryPathologyUvIps
Usage: #example
* status = #final
// * category = $observation-category#laboratory
* code.text = "Blood typing"
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* effectiveDateTime = "2015-10-10"
* performer = Reference(urn:uuid:45a5c5b1-4ec1-4d60-b4b2-ff5a84a41fd7)
* hasMember[0] = Reference(urn:uuid:aa11a2be-3e36-4be7-b58a-6fc3dace2741)
* hasMember[+] = Reference(urn:uuid:6e39ccf3-f997-4a2b-8f28-b4b71c778c70)
* hasMember[+] = Reference(urn:uuid:b4916505-a06b-460c-9be8-011609282457)
* hasMember[+] = Reference(urn:uuid:a6a5a1d5-c896-4c7e-b922-888fcc7e6ae4)

Instance: cc354e00-a419-47ea-8b6c-1768b2a01645
InstanceOf: ObservationResultsLaboratoryPathologyUvIps
Usage: #example
* status = #final
// * category = $observation-category#laboratory
* code = $loinc#17856-6 "Hemoglobin A1c/Hemoglobin.total in Blood by HPLC"
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* effectiveDateTime = "2017-11-10T08:20:00+01:00"
* performer = Reference(urn:uuid:45a5c5b1-4ec1-4d60-b4b2-ff5a84a41fd7)
* valueQuantity = 7.5 '%' "%"
* note.text = "Above stated goal of 7.0 %"

Instance: 26bee0a9-5997-4557-ab9d-c6adbb05b571
InstanceOf: ObservationResultsLaboratoryPathologyUvIps
Usage: #example
* status = #final
// * category = $observation-category#laboratory
* code = $loinc#42803-7 "Bacteria identified in Isolate"
* subject = Reference(2b90dd2b-2dab-4c75-9bb9-a355e07401e7)
* effectiveDateTime = "2017-12-10T08:20:00+01:00"
* performer = Reference(urn:uuid:45a5c5b1-4ec1-4d60-b4b2-ff5a84a41fd7)
* valueCodeableConcept = $sct#115329001 "Methicillin resistant Staphylococcus aureus"
* note.text = "Healthy carrier of MRSA"
