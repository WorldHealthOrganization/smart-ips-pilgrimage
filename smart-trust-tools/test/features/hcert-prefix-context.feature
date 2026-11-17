# Test-plan case hcert-prefix-context (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-prefix-context
Feature: Prefix the HC1: context identifier, giving a QR-ready string
  Steps 8 and 9 of issuance: the HC1: context identifier, giving a QR-ready
  string the application renders with its own QR encoder.

  @req:stt-hc1-001
  @test:tools/hcert-rust/tests/prefix_context.rs::stt_hc1_001_the_context_identifier_is_read_and_checked
  Scenario: The context identifier is read and checked (Rust)
    When the context of "HC1:ABC" is detected
    Then the version is "1" and the rest is "ABC"
    And the context of "HCZ:" is detected with version "Z"
    And detecting the context of "HC0:" fails with BadPrefix
    And detecting the context of "hc1:" fails with BadPrefix
    And decoding "HC2:00" as an HC1 string fails with UnsupportedContextVersion

  @req:stt-hc1-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/PrefixContextTest.kt::PrefixContextTest::STT-HC1-001_HC1_is_the_only_context,_version_1_the_only_version
  Scenario: HC1 is the only context, version 1 the only version (Kotlin)
    Given an empty trust store and the default subclaim registry
    When "NCFOXN", with no prefix, is verified
    Then verification fails with reason BAD_PREFIX
    And verifying "HC2:NCFOXN" fails with reason UNSUPPORTED_CONTEXT_VERSION
    And detecting the context of "HC1:NCFOXN" gives version "1" and the rest "NCFOXN"

  @req:stt-qr-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/PrefixContextTest.kt::PrefixContextTest::STT-QR-001_the_output_is_a_QR-ready_string_in_the_Alphanumeric_alphabet
  Scenario: The output is a QR-ready string in the Alphanumeric alphabet (Kotlin)
    Given a newborn's DVCMin issued by the testkit
    When its HC1 string is read
    Then it starts with "HC1:"
    And every character is in the Base45 alphabet or is ":", the QR Alphanumeric set

  @req:stt-gen-009
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/PrefixContextTest.kt::PrefixContextTest::STT-GEN-009_the_COSE_bytes_travel_without_the_QR_layers_too
  Scenario: The COSE bytes travel without the QR layers too (Kotlin)
    Given a newborn's DVCMin issued by the testkit with the ES256 key
    And a trust store holding the testkit ES256 DSC
    When the issued COSE_Sign1 bytes, without compression, Base45 or prefix, are verified at the testkit's time
    Then the result is Verified

  @req:stt-hc1-001 @req:stt-b45-001 @req:stt-zip-001
  @test:tools/conformance-ts/suite.ts::STT-HC1-001_STT-B45-001_STT-ZIP-001_the_PR_129_HC1_string_decodes_to_the_295-byte_COSE_Sign1
  Scenario: The PR 129 HC1 string decodes to the 295-byte COSE_Sign1 (TypeScript, either package)
    Given the PR 129 hepb1 certificate's HC1 string
    When it is decoded from HC1 with the default limits
    Then the COSE_Sign1 is 295 bytes long

  @req:stt-hc1-001
  @test:tools/conformance-ts/suite.ts::STT-HC1-001_the_context_identifier_is_read_and_other_versions_refused
  Scenario: The context identifier is read, and other versions refused (TypeScript, either package)
    When the context of "HC1:XYZ" is detected
    Then the version is "1" and the rest is "XYZ"
    And decoding "HC2:00" as an HC1 string throws "unsupported-context-version"
    And detecting the context of "XYZ" throws "bad-prefix"

  @req:stt-qr-001
  @test:tools/conformance-ts/suite.ts::STT-QR-001_to-hc1_inverts_from-hc1,_in_the_Alphanumeric_alphabet
  Scenario: to-hc1 inverts from-hc1, in the Alphanumeric alphabet (TypeScript, either package)
    Given the COSE_Sign1 decoded from the PR 129 hepb1 certificate's HC1 string
    When it is encoded back to an HC1 string
    Then the string is "HC1:" followed only by QR Alphanumeric characters
    And decoding that string gives the same COSE_Sign1 bytes
