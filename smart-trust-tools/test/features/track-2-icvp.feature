# Test-plan case track-2-icvp (test/plans/who-itb-agreement.test-plan.json).
# One Scenario per WHO-ITB GITB test case, tagged @itb:<suite>/<testcase>. The
# steps are the test case's, read from WHO-ITB at commit 883291d
# (references/who-itb); its test data is cited, not copied (no licence file).
# The plan compares the library with the decode and verify steps and the claim
# handed to the transform; a tester runs the ITB beside the library until bean
# OI-33 lets CI run it.
@case:track-2-icvp
Feature: WHO-ITB Track 2, HCERT ICVP: the system uses and validates an HCERT
  GITB test suite track-2-system-utilizes-and-validates-hcert-icvp. Actors:
  User, HCertDecoder (the gdhcn-helper service), FHIRValidator (Matchbox).

  @req:stt-tst-009
  @itb:track-2-system-utilizes-and-validates-hcert-icvp/tc-icvp-001-qr-decode-transform-icvp-ips-conformance
  Scenario: tc-icvp-001 QR, decode, transform, ICVP IPS conformance
    Given the user uploads a QR code image (test data: Track2_ICVP_2026.jpg)
    When the HCertDecoder decodes the QR image and the HC1 string
    And it verifies the COSE signature against the GDHCN DEV trust list
    Then the response status is 200 and the signature's "valid" is "true"
    When the validator loads the IGs smart-trust, pcmt, pcmt-vaxprequal, trust-phw and icvp
    And the decoded claim ("innerContent") is non-empty
    And it is transformed with the StructureMap http://smart.who.int/icvp/StructureMap/ICVPClaimtoIPS
    And the result is validated against http://smart.who.int/icvp/StructureDefinition/Bundle-uv-ips-ICVP, downgrading slicing errors
    Then the bundle conforms: the count of real (non-downgraded) errors, by FHIRPath, is 0
