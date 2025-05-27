Instance: display-ips
InstanceOf: Binary
Title: "Display IPS"
Description: "Gherkin file - display IPS."
Usage: #inline
* contentType = #text/x-gherkin
* data = "ig-loader-display-ips.feature"


Instance: issue-vhl
InstanceOf: Binary
Title: "Issue VHL"
Description: "Gherkin file - issue VHL."
Usage: #inline
* contentType = #text/x-gherkin
* data = "ig-loader-issue-vhl.feature"

Instance: record-consent
InstanceOf: Binary
Title: "Record Consent"
Description: "Gherkin file - record consent."
Usage: #inline
* contentType = #text/x-gherkin
* data = "ig-loader-record-consent.feature"

Instance: retrieve-ips
InstanceOf: Binary
Title: "Retrieve IPS"
Description: "Gherkin file - retrieve IPS."
Usage: #inline
* contentType = #text/x-gherkin
* data = "ig-loader-retrieve-ips.feature"

Instance: retrieve-vhl-manifest
InstanceOf: Binary
Title: "Retrieve VHL Manifest"
Description: "Gherkin file - retrieve VHL manifest."
Usage: #inline
* contentType = #text/x-gherkin
* data = "ig-loader-retrieve-vhl-manifest.feature"

Instance: validate-ips
InstanceOf: Binary
Title: "Validate IPS"
Description: "Gherkin file - validate IPS."
Usage: #inline
* contentType = #text/x-gherkin
* data = "ig-loader-validate-ips.feature"


Instance: verify-qr
InstanceOf: Binary
Title: "Verify QR"
Description: "Gherkin file - verify QR."
//Usage: #inline
* contentType = #text/x-gherkin
* data = "ig-loader-verify-qr.feature"


Instance: FunctionalTest
InstanceOf: TestPlan
Title: "End-to-End Functional Tests"
Description: "Test Plan consisting of different test cases expressed in Gherkin for the IPS-Pilgrimage End-to-End Workflow."
* status = #active
* version = "1.0.0"
* name = "FunctionalTestPlan"
* title = "End-to-End Functional Tests for IPS-Pilgrimage Workflow"
* date = "2025-02-17"
* publisher = "World Health Organization (WHO)"
* contact[+]
  * name = "WHO Testing Team"
  * telecom[+]
    * system = #email
    * value = "testing-team@who.int"
* jurisdiction[+]
  * coding[+]
    * system = "urn:iso:std:iso:3166"
    * code = #001
    * display = "World Health Organization"
* purpose = "To validate end-to-end workflows including IPS issuance, verification, and retrieval for international interoperability."
* copyright = "© 2025 World Health Organization. All rights reserved."
* category[+]
  * coding[+]
    * system = "http://hl7.org/fhir/ValueSet/testscript-scope-phase-codes"
    * code = #integration
    * display = "Integration"
* scope[+]
// List actors?
//  * reference = Reference(IPSImplementationGuide)
  * display = "Testing scenarios from WHO IPS Implementation Guide"

* testTools = "ITB with Gherkin+FHIR support"

// * dependency[+]
//   * description = "IPS generation and HIE integration"
//   * predecessor = Reference(IPSTestPlan)

* exitCriteria = "All test cases should pass without errors. Critical paths must be verified."

* testCase[+]
//  * key = "BRecordConsent"
//  * description = "Test case for recording consent"
  * sequence = 1
  * scope[+] = Reference(ConsentRegistry)
  * testRun[+]
    * narrative = "Test cases for successful and failed consent recording"
    * script
      * language = #text/x-gherkin
      * sourceReference = Reference(record-consent)

* testCase[+]
//  * key = "BIssueVHL"
//  * description = "Test case for issuing VHL"
  * sequence = 2
  * scope[+] = Reference(VHLService)
  * testRun[+]
    * narrative = "Test cases for generating QR code with VHL"
    * script
      * language = #text/x-gherkin
      * sourceReference = Reference(issue-vhl)

* testCase[+]
//  * key = "BVerifyQR"
//  * description = "Test case for verifying QR code signature"
  * sequence = 3
  * scope[+] = Reference(VerifierService)
  * testRun[+]
    * narrative = "Test cases for verifying QR code signature"
    * script
      * language = #text/x-gherkin
      * sourceReference = Reference(verify-qr)

* testCase[+]
//  * key = "BRetrieveVHLManifest"
//  * description = "Test case for retrieving VHL manifest"
  * sequence = 4
  * scope[+] = Reference(VHLManifestService)
  * testRun[+]
    * narrative = "Test cases for VHL manifest retrieval"
    * script
      * language = #text/x-gherkin
      * sourceReference = Reference(retrieve-vhl-manifest)

* testCase[+]
//  * key = "BRetrieveIPS"
//  * description = "Test case for retrieving IPS"
  * sequence = 5
  * scope[+] = Reference(IPSServer)
  * testRun[+]
    * narrative = "Test cases for IPS retrieval"
    * script
      * language = #text/x-gherkin
      * sourceReference = Reference(retrieve-ips.feature)

* testCase[+]
//  * key = "BValidateIPS"
//  * description = "Test case for validating IPS content"
// Do we want to add "REQUIREMENT STRENGTH" here?
  * sequence = 6
  * scope[+] = Reference(IPSServer)
  * testRun[+]
    * narrative = "Test cases for IPS content validation"
    * script
      * language = #text/x-gherkin
      * sourceReference = Reference(validate-ips)

* testCase[+]
//  * key = "BDisplayIPS"
//  * description = "Test case for viewing IPS content"
// Do we want to add "REQUIREMENT STRENGTH" here?
  * sequence = 7
  * scope[+] = Reference(EMRViewer)
  * testRun[+]
    * narrative = "Test case for rendering IPS narrative"
    * script
      * language = #text/x-gherkin
      * sourceReference = Reference(display-ips)

// * testData[+]
//   * type = #synthea
//   * content[+] = Reference(SyntheaData)
//   * source[x] = "https://synthea.mitre.org"

// * assertion[+]
//   * type = CodeableConcept
//     * coding[+]
//       * system = "http://hl7.org/fhir/test-assertion-type"
//       * code = #required
//       * display = "Required"
//   * object = Reference(record-consent)
//   * result = Reference(ConsentVerification)