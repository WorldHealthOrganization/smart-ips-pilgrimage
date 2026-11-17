# Test-plan case track-1-vhl (test/plans/who-itb-agreement.test-plan.json).
# One Scenario per WHO-ITB GITB test case, tagged @itb:<suite>/<testcase>. The
# steps are the test case's, read from WHO-ITB at commit 883291d
# (references/who-itb); its test data is cited, not copied (no licence file).
# The plan compares the library with the decode, verify and VHL steps; a tester
# runs the ITB beside the library until bean OI-33 lets CI run it.
@case:track-1-vhl
Feature: WHO-ITB Track 1, HCERT VHL: QR to a verified LAC IPS bundle
  GITB test suite track-1-hcert-vhl-qr-to-verified-lac-ips-bundle. Actors:
  User, HCertDecoder (the gdhcn-helper service), VHLResponder.

  @req:stt-tst-009
  @itb:track-1-hcert-vhl-qr-to-verified-lac-ips-bundle/tc-vhl-001-full-vhl-verification-pipeline
  Scenario: tc-vhl-001 Full VHL verification pipeline
    Given the user uploads a QR code image (test data: Track1_VHL_1234_2026.jpg)
    And the user enters the PIN for retrieving the content
    When the HCertDecoder decodes the QR image
    And it decodes the HC1 string and extracts its metadata
    And it verifies the COSE signature against the GDHCN DEV trust list
    Then the response status is 200 and the signature's "valid" is "true"
    When the HCertDecoder extracts the SHL reference from the payload
    And it authorizes the short link with the PIN
    And it fetches the FHIR content through the manifest
    Then each response status is 200 and an IPS bundle is retrieved from the manifest
    When the validator loads the IG https://ig.racsel.org
    And it validates the bundle against http://racsel.org/StructureDefinition/LACBundleIPS, downgrading slicing errors
    Then the bundle conforms: the count of real (non-downgraded) errors, by FHIRPath, is 0
