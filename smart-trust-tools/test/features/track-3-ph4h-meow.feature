# Test-plan case track-3-ph4h-meow (test/plans/who-itb-agreement.test-plan.json).
# One Scenario per WHO-ITB GITB test case, tagged @itb:<suite>/<testcase>. The
# steps are the test case's, read from WHO-ITB at commit 883291d
# (references/who-itb); its test data is cited, not copied (no licence file).
# The plan compares the library with the decode and verify steps and the claim
# handed to the transform; a tester runs the ITB beside the library until bean
# OI-33 lets CI run it.
@case:track-3-ph4h-meow
Feature: WHO-ITB Track 3, HCERT PH4H: the system uses and validates a MeOW HCERT
  GITB test suite track-3-system-utilizes-and-validates-hcert-ph4h-meow.
  Actors: User, HCertDecoder (the gdhcn-helper service), FHIRValidator (Matchbox).

  @req:stt-tst-009
  @itb:track-3-system-utilizes-and-validates-hcert-ph4h-meow/tc-ph4h-qr-001-qr-decode-transform-meow-conformance
  Scenario: tc-ph4h-qr-001 QR, decode, transform, MeOW conformance
    Given the user uploads a QR code image (test data: Track3_MeOW_2026.jpg)
    When the HCertDecoder decodes the QR image and the HC1 string
    And it verifies the COSE signature against the GDHCN DEV trust list
    Then the response status is 200 and the signature's "valid" is "true"
    When the validator loads the IGs smart-ph4h (MeOW-r4) and IHE PHARM MEOW
    And the decoded claim ("innerContent") is non-empty
    And it is transformed with the StructureMap http://smart.who.int/ph4h/StructureMap/MedicationOverviewMinToMedicationOverviewBundle
    And the result is validated against its profile
    Then the count of errors, by FHIRPath, other than the listed known MedicationOverview slicing errors, is 0
