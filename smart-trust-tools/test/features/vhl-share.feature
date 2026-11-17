# Test-plan case vhl-share (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:vhl-share
Feature: Issue a Verifiable Health Link
  Issue a VHL (journey J4.0): a key, documents encrypted as JWE dir / A256GCM,
  and the payload as a CBOR map at HCERT key 5.

  @req:stt-vhl-001
  @test:tools/hcert-rust/tests/vhl_share.rs::stt_vhl_001_the_ihe_iti_yy3_example_payload_is_valid_and_each_rule_is_enforced
  Scenario: The IHE ITI-YY3 example payload is valid, and each rule is enforced (Rust)
    Given the IHE ITI-YY3 example VHL payload, flag "LP", label "Patient Health Summary"
    When it is validated with no current time
    Then there are no issues
    And the payload changed as below gives exactly the one issue code:
      | change                                                              | code               |
      | key "dGhpcyBpcyBhIHNlY3JldCBrZXkgdXNlZCBmb3IgZW5j" (44 chars, 33 bytes) | bad-key            |
      | flag "PL"                                                           | bad-flag           |
      | flag "LU"                                                           | unsupported-flag-U |
      | a label of 81 characters                                            | label-too-long     |
      | url "http://vhl-sharer.example.org/List?_id=1"                      | not-https          |

  @req:stt-vhl-002
  @test:tools/hcert-rust/tests/vhl_share.rs::stt_vhl_002_the_payload_is_a_cbor_map_at_hcert_key_5_and_verifies
  Scenario: The payload is a CBOR map at HCERT key 5, and verifies (Rust)
    Given the IHE example VHL payload, expiring a day after the testkit's now
    When it is issued as an HCERT with the ES256 testkit key
    Then claim -260 key 5 of the COSE_Sign1 is a CBOR map
    And the HC1 string verifies against the testkit DSC
    And its one entry is at subclaim 5 and is the same VHL payload

  @req:stt-vhl-002 @req:stt-vhl-003
  @test:tools/hcert-rust/tests/vhl_share.rs::stt_vhl_002_stt_vhl_003_a_vhlink_string_at_key_5_still_verifies_and_the_map_is_smaller
  Scenario: A vhlink string at key 5 still verifies, and the map is smaller (Rust)
    Given the IHE example VHL payload, expiring a day after the testkit's now
    When its vhlink:/ string is issued as a CBOR text at raw subclaim 5
    Then claim -260 key 5 of the COSE_Sign1 is a CBOR text
    And the HC1 string verifies, and its entry is the same VHL payload
    And the COSE_Sign1 issued with the payload as a map is under 80% of the bytes of the one with the string
    And the HC1 string with the map is shorter than the one with the string

  @req:stt-vhl-003
  @test:tools/hcert-rust/tests/vhl_share.rs::stt_vhl_003_vhlink_round_trips_and_reads_the_ihe_example_link
  Scenario: vhlink round-trips, and reads the IHE example link (Rust)
    Given the IHE example VHL payload
    When it is written as a vhlink
    Then the link starts with "vhlink:/eyJ1cmwiOi"
    And reading the link gives back the same payload
    And the IHE example link reads as the same payload without a fhirBaseUrl, since its "extensions" is not the payload's "extension"
    And reading "shlink:/abc" fails with NotAVhlink

  @req:stt-vhl-004
  @test:tools/hcert-rust/tests/vhl_share.rs::stt_vhl_004_a_new_key_is_32_random_bytes_base64url_without_padding
  Scenario: A new key is 32 random bytes, base64url without padding (Rust)
    When a new VHL key is made
    Then it is 43 characters long
    And it decodes to 32 bytes
    And a second new key is different

  @req:stt-vhl-007
  @test:tools/hcert-rust/tests/vhl_share.rs::stt_vhl_007_a_document_is_encrypted_as_compact_jwe_dir_a256gcm
  Scenario: A document is encrypted as compact JWE dir A256GCM (Rust)
    Given a new VHL key
    When "hello" is encrypted with content type "text/plain"
    Then the JWE has 5 dot-separated parts
    And the second part, the encrypted key, is empty
    And the protected header is {"alg":"dir","enc":"A256GCM","cty":"text/plain"}
    And decrypting with the key gives back "hello"

  @req:stt-vhl-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlShareTest.kt::VhlShareTest::STT-VHL-001_the_IHE_ITI-YY3_example_payload_is_valid,_and_each_rule_is_enforced
  Scenario: The IHE ITI-YY3 example payload is valid, and each rule is enforced (Kotlin)
    Given the IHE ITI-YY3 example VHL payload, flag "LP", label "Patient Health Summary"
    When it is validated with no current time
    Then there are no issues
    And the payload changed as below gives exactly the one issue code:
      | change                                                              | code               |
      | key "dGhpcyBpcyBhIHNlY3JldCBrZXkgdXNlZCBmb3IgZW5j" (44 chars, 33 bytes) | bad-key            |
      | flag "PL"                                                           | bad-flag           |
      | flag "LU"                                                           | unsupported-flag-U |
      | a label of 81 characters                                            | label-too-long     |
      | url "http://vhl-sharer.example.org/List?_id=1"                      | not-https          |

  @req:stt-vhl-002
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlShareTest.kt::VhlShareTest::STT-VHL-002_the_payload_is_a_CBOR_map_at_HCERT_key_5,_and_verifies
  Scenario: The payload is a CBOR map at HCERT key 5, and verifies (Kotlin)
    Given the IHE example VHL payload, expiring a day after the testkit's now
    When it is issued as an HCERT by the testkit
    Then claim -260 key 5 of the COSE_Sign1 is a CBOR map
    And its HC1 string verifies against the testkit ES256 certificate
    And its single entry is at subclaim 5 and is the same VHL payload

  @req:stt-vhl-002 @req:stt-vhl-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlShareTest.kt::VhlShareTest::STT-VHL-002_STT-VHL-003_a_vhlink_string_at_key_5_still_verifies,_and_the_map_is_smaller
  Scenario: A vhlink string at key 5 still verifies, and the map is smaller (Kotlin)
    Given the IHE example VHL payload, expiring a day after the testkit's now
    When its vhlink:/ string is issued as a CBOR text at raw subclaim 5
    Then claim -260 key 5 of the COSE_Sign1 is a CBOR text
    And its HC1 string verifies, and its single entry is the same VHL payload
    And the HC1 string issued with the payload as a map is under 80% of the length of the one with the string

  @req:stt-vhl-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlShareTest.kt::VhlShareTest::STT-VHL-003_vhlink_round-trips,_and_reads_the_IHE_example_link
  Scenario: vhlink round-trips, and reads the IHE example link (Kotlin)
    Given the IHE example VHL payload
    When it is written as a vhlink
    Then the link starts with "vhlink:/eyJ1cmwiOi"
    And reading the link gives back the same payload
    And the IHE example link reads as the same payload without a fhirBaseUrl, since its "extensions" is not the payload's "extension"
    And reading "shlink:/abc" fails with NotAVhlink

  @req:stt-vhl-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlShareTest.kt::VhlShareTest::STT-VHL-004_a_new_key_is_32_random_bytes,_base64url_without_padding
  Scenario: A new key is 32 random bytes, base64url without padding (Kotlin)
    When a new VHL key is made
    Then it is 43 characters long
    And it decodes to 32 bytes
    And a second new key is different

  @req:stt-vhl-007
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlShareTest.kt::VhlShareTest::STT-VHL-007_a_document_is_encrypted_as_compact_JWE_dir_A256GCM
  Scenario: A document is encrypted as compact JWE dir A256GCM (Kotlin)
    Given a new VHL key
    When "hello" is encrypted with content type "text/plain"
    Then the JWE has 5 dot-separated parts
    And the second part, the encrypted key, is empty
    And the protected header is {"alg":"dir","enc":"A256GCM","cty":"text/plain"}
    And decrypting with the key gives back "hello"

  @req:stt-vhl-001 @req:stt-vhl-003
  @test:tools/conformance-ts/suite.ts::STT-VHL-001_STT-VHL-003_the_IHE_example_payload_is_valid_and_round-trips_through_vhlink:/
  Scenario: The IHE example payload is valid, and round-trips through vhlink:/ (TypeScript, either package)
    Given the IHE example VHL payload
    When it is validated with no current time
    Then there are no issues
    And writing it as a vhlink and reading it back gives the same key
    And the payload with flag "PL" gives the one issue code "bad-flag"
    And reading "shlink:/x" throws "not-a-vhlink"

  @req:stt-vhl-004
  @test:tools/conformance-ts/suite.ts::STT-VHL-004_new_keys_are_32_random_bytes,_base64url
  Scenario: New keys are 32 random bytes, base64url (TypeScript, either package)
    When a new VHL key is made
    Then it is 43 characters long, all in the base64url alphabet A-Z a-z 0-9 _ -
    And a second new key is different
