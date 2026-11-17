# Test-plan case hcert-assemble-payload (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-assemble-payload
Feature: Build and validate the payload against its logical model
  Step 2 of issuance: build the payload and validate it against its logical
  model (DVCMin, or a VHL payload), keeping unknown elements.

  @req:stt-pay-001 @req:stt-pay-008
  @test:tools/hcert-rust/tests/payload.rs::stt_pay_001_stt_pay_008_a_dvcmin_round_trips_and_keeps_unknown_elements
  Scenario: A DVCMin round-trips through CBOR and keeps unknown elements (Rust)
    Given a newborn's DVCMin with an unknown element "zz" holding the text "kept"
    When it is encoded to CBOR and decoded again
    Then the result equals the original, "zz" included

  @req:stt-pay-002 @req:stt-pay-003
  @test:tools/hcert-rust/tests/payload.rs::stt_pay_002_stt_pay_003_the_logical_model_rules_are_checked
  Scenario: The logical model's rules are checked (Rust)
    Given a newborn's DVCMin with nt "LA", dob "2026-13-01" and no vaccine issuer
    When it is validated
    Then the issue codes include "not-alpha3", "invalid-date" and "must-have-issuer-or-clinician-name"
    And the unchanged newborn's DVCMin validates with no issues

  @req:stt-pay-004 @req:stt-pay-007
  @test:tools/hcert-rust/tests/payload.rs::stt_pay_004_stt_pay_007_an_invalid_payload_is_refused_naming_each_rule
  Scenario: An invalid payload is refused, naming each rule (Rust)
    Given a newborn's DVCMin with nt "LA" and neither a vaccine issuer nor a clinician name
    When it is prepared for issuance
    Then it fails with PayloadInvalid
    And the distinct issue codes are exactly "must-have-issuer-or-clinician-name" and "not-alpha3"
    And a newborn's DVCMin with the user-assigned nt "XXA" validates with no issues

  @req:stt-pay-005
  @test:tools/hcert-rust/tests/payload.rs::stt_pay_005_a_newborns_dvcmin_has_no_identity_document_and_names_a_guardian
  Scenario: A newborn's DVCMin has no identity document and names a guardian (Rust)
    Given a newborn's DVCMin with no id, no dt and gn "Test MOTHER"
    Then validating it gives no blocking issue
    When it is issued with ES256 and verified
    Then the verified DVCMin also has no id, no dt and gn "Test MOTHER"

  @req:stt-pay-009 @req:stt-gen-003
  @test:tools/hcert-rust/tests/payload.rs::stt_pay_009_stt_gen_003_another_payload_passes_through_the_core_untouched
  Scenario Outline: Another payload passes through the core untouched (Rust)
    Given a raw payload {"<key>": "x"} under subclaim <subclaim>
    When it is issued with <alg> and verified against the <alg> testkit DSC
    Then the one entry is the raw payload under <subclaim>, its CBOR unchanged

    Examples:
      | subclaim | key | alg   |
      | 4        | t   | PS256 |
      | 1        | v   | ES256 |
      | 3        | v   | ES256 |
      | -7       | m   | ES256 |

  @req:stt-pay-001 @req:stt-pay-002 @req:stt-pay-005
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/AssemblePayloadTest.kt::AssemblePayloadTest::STT-PAY-001_STT-PAY-002_STT-PAY-005_a_newborn's_DVCMin,_with_no_identity_document,_round-trips_as_typed_fields
  Scenario: A newborn's DVCMin, with no identity document, round-trips as typed fields (Kotlin)
    Given a newborn's DVCMin with no identity document
    Then validating it gives no blocking issue
    When it is issued and verified
    Then the verified DVCMin equals the original, extensions aside
    And its vaccine product vx.vp is "XM9V38"

  @req:stt-pay-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/AssemblePayloadTest.kt::AssemblePayloadTest::STT-PAY-003_one_immunization_event_per_DVC
  Scenario: One immunization event per DVC (Kotlin)
    Given a newborn's DVCMin encoded to CBOR
    Then its "vx" element is a map, one event, not an array

  @req:stt-pay-004 @req:stt-pay-007
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/AssemblePayloadTest.kt::AssemblePayloadTest::STT-PAY-004_STT-PAY-007_an_invalid_payload_is_refused,_naming_each_rule
  Scenario: An invalid payload is refused, naming each rule (Kotlin)
    Given a newborn's DVCMin with nt "LA" and neither a vaccine issuer nor a clinician name
    When it is prepared for issuance
    Then it fails with PayloadInvalid
    And the issue codes are exactly "not-alpha3" and "must-have-issuer-or-clinician-name"

  @req:stt-pay-008
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/AssemblePayloadTest.kt::AssemblePayloadTest::STT-PAY-008_unknown_payload_elements_are_kept
  Scenario: Unknown payload elements are kept (Kotlin)
    Given a newborn's DVCMin with an unknown element "zz"
    When it is issued and verified
    Then the verified DVCMin's extensions are "zz" alone, with the same CBOR bytes

  @req:stt-pay-009 @req:stt-gen-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/AssemblePayloadTest.kt::AssemblePayloadTest::STT-PAY-009_STT-GEN-003_another_payload_passes_through_the_core_untouched
  Scenario: Another payload passes through the core untouched (Kotlin)
    Given a raw payload {"t": "x"} under subclaim 4
    When it is issued with PS256 and verified against the PS256 testkit DSC
    Then the one entry is a raw payload with the same CBOR bytes
    And there are no diagnostics

  @req:stt-pay-001 @req:stt-pay-008
  @test:tools/conformance-ts/suite.ts::STT-PAY-001_STT-PAY-008_a_DVCMin_round-trips_through_CBOR
  Scenario: A DVCMin round-trips through CBOR (TypeScript, either package)
    Given a newborn's DVCMin
    When it is encoded to CBOR and decoded again
    Then the decoded gn is "Test MOTHER"
    And the newborn's DVCMin validates with no issues

  @req:stt-pay-002 @req:stt-pay-007
  @test:tools/conformance-ts/suite.ts::STT-PAY-002_STT-PAY-007_the_logical_model's_rules_are_enforced
  Scenario: The logical model's rules are enforced (TypeScript, either package)
    Given a newborn's DVCMin with nt "LA" and no vaccine issuer
    When it is validated
    Then the issue codes include "not-alpha3" and "must-have-issuer-or-clinician-name"

  @req:stt-gen-001 @req:stt-gen-009
  @test:tools/conformance-ts/suite.ts::STT-GEN-001_STT-GEN-009_ES256_and_PS256_issue_and_verify,_and_the_COSE_bytes_travel_without_the_QR_layers
  Scenario: ES256 and PS256 issue and verify, and the COSE bytes travel without the QR layers (TypeScript, either package)
    Given a newborn's DVCMin issued with ES256
    And a raw payload {"t": "x"} under subclaim 4 issued with PS256, whose DSC allows test certificates only
    Then each HC1 string verifies against its own testkit DSC
    And the ES256 HC1 string decodes to exactly the issued COSE bytes
    And each issued COSE_Sign1 verifies on its own, without the QR layers

  @req:stt-pay-009 @req:stt-gen-003
  @test:tools/conformance-ts/suite.ts::STT-PAY-009_STT-GEN-003_payloads_under_1,_3,_4_and_-7_pass_through_the_core_untouched
  Scenario Outline: Payloads under 1, 3, 4 and -7 pass through the core untouched (TypeScript, either package)
    Given a raw payload {"<key>": "x"} under subclaim <subclaim>
    When it is issued with <alg> and verified against the <alg> testkit DSC
    Then it verifies, its first entry a raw payload under <subclaim> with the same CBOR bytes

    Examples:
      | subclaim | key | alg   |
      | 4        | t   | PS256 |
      | 1        | v   | ES256 |
      | 3        | v   | ES256 |
      | -7       | m   | ES256 |

  @req:stt-pay-003
  @test:tools/conformance-ts/suite.ts::STT-PAY-003_one_immunization_event_per_DVC
  Scenario: One immunization event per DVC (TypeScript, either package)
    Given a newborn's DVCMin encoded to CBOR
    Then its "vx" element is a map, one event, whose vp is "XM9V38"

  @req:stt-pay-004 @req:stt-pay-007
  @test:tools/conformance-ts/suite.ts::STT-PAY-004_STT-PAY-007_an_invalid_payload_is_refused,_naming_each_rule
  Scenario: An invalid payload is refused, naming each rule (TypeScript, either package)
    Given a newborn's DVCMin with nt "LA" and neither a vaccine issuer nor a clinician name
    When it is prepared for issuance
    Then it throws "payload-invalid"
    And the distinct issue codes are exactly "must-have-issuer-or-clinician-name" and "not-alpha3"
    And a newborn's DVCMin with nt "XXA" validates with no issues

  @req:stt-pay-005
  @test:tools/conformance-ts/suite.ts::STT-PAY-005_a_newborn's_DVCMin_has_no_identity_document_and_names_a_guardian
  Scenario: A newborn's DVCMin has no identity document and names a guardian (TypeScript, either package)
    Given a newborn's DVCMin issued with ES256
    When the HC1 string is verified
    Then the first entry is a DVCMin with no id, no dt and gn "Test MOTHER"
