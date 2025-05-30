Alias: $testscript-scope-phase-codes = http://hl7.org/fhir/ValueSet/testscript-scope-phase-codes


Instance: HostCountryTestPlan
InstanceOf: TestPlan
Usage: #example
* status = #active
* version = "1.0.0"
* name = "HostCountryTestPlan"
* title = "Functional Unit Tests for the Host Country System Actor during the IPS-Pilgrimage Workflow"
* publisher = "World Health Organization (WHO)"
* contact.name = "WHO SMART Guidelines"
* contact.telecom.system = #email
* contact.telecom.value = "SMART@who.int"
* jurisdiction = urn:iso:std:iso:3166#001 "World Health Organization"
* purpose = "Unit Tests for the Host Country EMR to verify, retrieve and display of IPS for pilgrims."
* copyright = "© 2025 World Health Organization. All rights reserved."
* category = $testscript-scope-phase-codes#unit "unit"
* scope[0].display = "Unit Tests for the Host Country EMR to verify, retrieve and display of IPS for pilgrims."
* testTools = "ITB with Gherkin+FHIR support"
* exitCriteria = "All test cases should pass without errors. Critical paths must be verified."
* testCase[0].sequence = 1
* testCase[=].scope = Reference(https://profiles.ihe.net/ITI/VHL/Requirements/ReceiveVHL)
* testCase[=].testRun.narrative = "Test cases for verifying QR code signature"
* testCase[=].testRun.script.language.coding.code = #text/x-gherkin
* testCase[=].testRun.script.sourceReference = Reference(Binary/verify-qr)
* testCase[+].sequence = 2
* testCase[=].scope = Reference(https://profiles.ihe.net/ITI/VHL/Requirements/RequestVHLDocuments)
* testCase[=].testRun.narrative = "Test cases for VHL manifest retrieval"
* testCase[=].testRun.script.language.coding.code = #text/x-gherkin
* testCase[=].testRun.script.sourceReference = Reference(Binary/retrieve-vhl-manifest)
* testCase[+].sequence = 3
* testCase[=].scope = Reference(https://profiles.ihe.net/ITI/VHL/RequestVHLDocument)
* testCase[=].testRun.narrative = "Test cases for IPS retrieval"
* testCase[=].testRun.script.language.coding.code = #text/x-gherkin
* testCase[=].testRun.script.sourceReference = Reference(Binary/retrieve-ips)
* testCase[+].sequence = 4
* testCase[=].scope = Reference(http://hl7.org/fhir/uv/ips/StructureDefinition/Bundle-uv-ips)
* testCase[=].testRun.narrative = "Test cases for IPS content validation"
* testCase[=].testRun.script.language.coding.code = #text/x-gherkin
* testCase[=].testRun.script.sourceReference = Reference(Binary/validate-ips)
* testCase[+].sequence = 5
* testCase[=].scope = Reference(EMRViewer)
* testCase[=].testRun.narrative = "Test case for rendering IPS narrative"
* testCase[=].testRun.script.language.coding.code = #text/x-gherkin
* testCase[=].testRun.script.sourceReference = Reference(Binary/display-ips)