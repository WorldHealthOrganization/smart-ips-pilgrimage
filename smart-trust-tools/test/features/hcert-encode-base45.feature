# Test-plan case hcert-encode-base45 (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-encode-base45
Feature: Encode the compressed bytes as RFC 9285 Base45, and decode strictly
  Step 7 of issuance: RFC 9285 Base45. On the way back, decoding is strict:
  anything outside the alphabet, a dangling character or an out-of-range group
  is refused.

  @req:stt-b45-001
  @test:tools/hcert-rust/tests/base45.rs::stt_b45_001_rfc_9285_examples_encode_and_decode
  Scenario Outline: The RFC 9285 examples encode and decode (Rust)
    Given the text "<plain>"
    When its bytes are Base45-encoded
    Then the result is "<encoded>"
    And Base45-decoding "<encoded>" gives back the bytes of "<plain>"

    Examples:
      | plain   | encoded     |
      | AB      | BB8         |
      | Hello!! | %69 VD92EX0 |
      | base-45 | UJCLQE7W581 |
      | ietf!   | QED8WEX0    |

  @req:stt-b45-002
  @test:tools/hcert-rust/tests/base45.rs::stt_b45_002_decoding_is_strict
  Scenario Outline: Base45 decoding is strict (Rust)
    Given the Base45 text "<text>"
    When it is decoded
    Then it fails with Base45Invalid

    Examples:
      | text |
      | GGW  |
      | A    |
      | abc  |
      | :::: |

  @req:stt-b45-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/Base45Test.kt::Base45Test::STT-B45-001_the_RFC_9285_section_4-3_examples
  Scenario: The RFC 9285 section 4.3 examples (Kotlin)
    When the text "AB" is Base45-encoded
    Then the result is "BB8"
    And "Hello!!" encodes to "%69 VD92EX0"
    And "base-45" encodes to "UJCLQE7W581"
    And "QED8WEX0" decodes to the text "ietf!"

  @req:stt-b45-002
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/Base45Test.kt::Base45Test::STT-B45-002_lower_case,_a_dangling_character_and_an_out-of-range_triple_are_refused
  Scenario Outline: Lower case, a dangling character and an out-of-range group are refused (Kotlin)
    Given an empty trust store and the default subclaim registry
    When "<hc1>" is verified
    Then verification fails with reason BASE45_INVALID

    Examples:
      | hc1     |
      | HC1:abc |
      | HC1:A   |
      | HC1:::: |

  @req:stt-b45-001 @req:stt-b45-002
  @test:tools/conformance-ts/suite.ts::STT-B45-001_STT-B45-002_Base45:_RFC_9285_examples,_and_strict_decoding
  Scenario: RFC 9285 examples, and strict decoding (TypeScript, either package)
    When the text "Hello!!" is Base45-encoded
    Then the result is "%69 VD92EX0"
    And "UJCLQE7W581" decodes to the text "base-45"
    And decoding "abc" throws "base45-invalid"
