# Test-plan case vhl-receive (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:vhl-receive
Feature: Use a Verifiable Health Link
  Use a VHL (journey J4.1): verify it, build the ITI-YY5 manifest request with
  its HTTP Message Signature, read the manifest Bundle and decrypt each document.

  @req:stt-vhl-005
  @test:tools/hcert-rust/tests/vhl_receive.rs::stt_vhl_005_the_iti_yy5_request_is_the_exact_body_of_the_ihe_example
  Scenario: The ITI-YY5 request is the exact body of the IHE example (Rust)
    Given the IHE example VHL payload, flag "LP"
    When the manifest request is built for recipient "Dr. Smith Hospital", passcode "user-pin" and embeddedLengthMax 10000
    Then its url is "https://vhl-sharer.example.org/List/_search"
    And its content type is "application/x-www-form-urlencoded"
    And its body is exactly "_id=abc123def456&code=folder&status=current&patient.identifier=urn%3Aoid%3A2.16.840.1.113883.2.4.6.3%7CPASSPORT123&_include=List%3Aitem&recipient=Dr.+Smith+Hospital&passcode=user-pin&embeddedLengthMax=10000"

  @req:stt-vhl-005
  @test:tools/hcert-rust/tests/vhl_receive.rs::stt_vhl_005_a_list_url_is_searched_and_the_passcode_follows_the_p_flag
  Scenario: A List URL is searched, and the passcode follows the P flag (Rust)
    Given a VHL with no flag whose url is "https://vhl-sharer.example.org/List?_id=abc&code=folder&status=current&patient.identifier=s%7Cv"
    When the manifest request is built for recipient "Clinic B" with no passcode
    Then its url is "https://vhl-sharer.example.org/List/_search"
    And the IHE example, flagged P, with no passcode fails with a Manifest error
    And the unflagged VHL with passcode "1234" fails with a Manifest error
    And the unflagged VHL whose url has no _id fails with a Manifest error

  @req:stt-vhl-006
  @test:tools/hcert-rust/tests/vhl_receive.rs::stt_vhl_006_the_ihe_case_b_manifest_bundle_reads_as_documents
  Scenario: The IHE Case B manifest Bundle reads as documents (Rust)
    Given the IHE ITI-YY5 Case B manifest Bundle (vectors/ihe-vhl/iti-yy5-manifest-case-b.json)
    When it is parsed
    Then there are 4 documents
    And the first has url "https://vhl-sharer.example.org/Binary/doc001-content" and content type "application/pdf"
    And the other three, abbreviated in the example to bare ids, are handed back as references "DocumentReference/doc002", "DocumentReference/doc003" and "DocumentReference/doc004"

  @req:stt-vhl-006
  @test:tools/hcert-rust/tests/vhl_receive.rs::stt_vhl_006_a_case_a_manifest_without_includes_hands_back_references
  Scenario: A Case A manifest without includes hands back references (Rust)
    Given a searchset Bundle with one List whose one item references "DocumentReference/d1", and no included resources
    When it is parsed
    Then there is 1 document, with reference "DocumentReference/d1" and no url
    And a Bundle of type "document" fails with a Manifest error

  @req:stt-vhl-007
  @test:tools/hcert-rust/tests/vhl_receive.rs::stt_vhl_007_decrypts_what_node_crypto_encrypted_with_and_without_zip_def
  Scenario Outline: Decrypts what node:crypto encrypted, with and without zip DEF (Rust)
    Given the node:crypto fixture vectors/ihe-vhl/jwe-dir-a256gcm.json
    When its "<jwe>" is decrypted with its key
    Then the content is the fixture's plaintext
    And the content type is "application/fhir+json"

    Examples:
      | jwe       |
      | jwe       |
      | jweZipDef |

  @req:stt-vhl-007
  @test:tools/hcert-rust/tests/vhl_receive.rs::stt_vhl_007_a_wrong_key_a_changed_byte_and_another_enc_are_refused
  Scenario: A wrong key, a changed byte and another enc are refused (Rust)
    Given "hello" encrypted as "text/plain" with a new VHL key
    When it is decrypted with another new key
    Then it fails with DecryptFailed
    And with the first ciphertext byte flipped it fails with DecryptFailed
    And with the protected header replaced by {"alg":"dir","enc":"A128GCM"} it fails with Unsupported

  @req:stt-vhl-008
  @test:tools/hcert-rust/tests/vhl_receive.rs::stt_vhl_008_the_content_digest_is_rfc_9530
  Scenario: The Content-Digest is RFC 9530 (Rust)
    Given a POST to vhl-sharer.example.org/List/_search with body {"hello": "world"}
    When its signature base is built
    Then the content digest is "sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:", RFC 9530 Appendix B.1's

  @req:stt-vhl-008
  @test:tools/hcert-rust/tests/vhl_receive.rs::stt_vhl_008_the_rfc_9421_signature_base_has_the_ihe_shape
  Scenario: The RFC 9421 signature base has the IHE shape (Rust)
    Given a POST to vhl-sharer.example.org/List/_search, content type "application/x-www-form-urlencoded", body {"hello": "world"}, keyid "receiver-key-123", alg "ecdsa-p256-sha256", created 1735689600
    When its signature base is built
    Then the Signature-Input is sig1=("@method" "@path" "@authority" "content-type" "content-digest");created=1735689600;keyid="receiver-key-123";alg="ecdsa-p256-sha256"
    And the base is these lines, joined by newlines:
      """
      "@method": POST
      "@path": /List/_search
      "@authority": vhl-sharer.example.org
      "content-type": application/x-www-form-urlencoded
      "content-digest": sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:
      "@signature-params": ("@method" "@path" "@authority" "content-type" "content-digest");created=1735689600;keyid="receiver-key-123";alg="ecdsa-p256-sha256"
      """

  @req:stt-vhl-008
  @test:tools/hcert-rust/tests/vhl_receive.rs::stt_vhl_008_a_der_signature_becomes_the_raw_header_value_and_verifies
  Scenario: A DER signature becomes the raw header value, and verifies (Rust)
    Given the signature base of the same POST request
    And a P-256 key whose secret is 32 bytes of 9
    When the base is signed, the DER signature made into a Signature header for "ecdsa-p256-sha256"
    Then the value between "sig1=:" and ":" decodes to 64 bytes
    And those raw bytes verify over the base with the key

  @req:stt-vhl-009
  @test:tools/hcert-rust/tests/vhl_receive.rs::stt_vhl_009_an_expired_link_fails_verification_by_its_own_exp
  Scenario: An expired link fails verification, by its own exp (Rust)
    Given the IHE example VHL payload, exp 1735689600
    When it is validated at 1735689601
    Then the one issue code is "expired"
    And the payload with exp 1000 seconds before the testkit's now, issued in an HCERT valid at that now, fails verification with Expired

  @req:stt-vhl-005
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlReceiveTest.kt::VhlReceiveTest::STT-VHL-005_the_ITI-YY5_request_is_the_exact_body_of_the_IHE_example
  Scenario: The ITI-YY5 request is the exact body of the IHE example (Kotlin)
    Given the IHE example VHL payload, flag "LP"
    When the manifest request is built for recipient "Dr. Smith Hospital", passcode "user-pin" and embeddedLengthMax 10000
    Then its url is "https://vhl-sharer.example.org/List/_search"
    And its content type is "application/x-www-form-urlencoded"
    And its body is exactly "_id=abc123def456&code=folder&status=current&patient.identifier=urn%3Aoid%3A2.16.840.1.113883.2.4.6.3%7CPASSPORT123&_include=List%3Aitem&recipient=Dr.+Smith+Hospital&passcode=user-pin&embeddedLengthMax=10000"

  @req:stt-vhl-005
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlReceiveTest.kt::VhlReceiveTest::STT-VHL-005_a_List_URL_is_searched,_and_the_passcode_follows_the_P_flag
  Scenario: A List URL is searched, and the passcode follows the P flag (Kotlin)
    Given a VHL with no flag whose url is "https://vhl-sharer.example.org/List?_id=abc&code=folder&status=current&patient.identifier=s%7Cv"
    When the manifest request is built for recipient "Clinic B" with no passcode
    Then its url is "https://vhl-sharer.example.org/List/_search"
    And the IHE example, flagged P, with no passcode fails with a Manifest error
    And the unflagged VHL with passcode "1234" fails with a Manifest error
    And the unflagged VHL whose url has no _id fails with a Manifest error

  @req:stt-vhl-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlReceiveTest.kt::VhlReceiveTest::STT-VHL-006_the_IHE_Case_B_manifest_Bundle_reads_as_documents
  Scenario: The IHE Case B manifest Bundle reads as documents (Kotlin)
    Given the IHE ITI-YY5 Case B manifest Bundle (vectors/ihe-vhl/iti-yy5-manifest-case-b.json)
    When it is parsed
    Then there are 4 documents
    And the first has url "https://vhl-sharer.example.org/Binary/doc001-content" and content type "application/pdf"
    And the other three, abbreviated in the example to bare ids, are handed back as references "DocumentReference/doc002", "DocumentReference/doc003" and "DocumentReference/doc004"

  @req:stt-vhl-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlReceiveTest.kt::VhlReceiveTest::STT-VHL-006_a_Case_A_manifest_without_includes_hands_back_references
  Scenario: A Case A manifest without includes hands back references (Kotlin)
    Given a searchset Bundle with one List whose one item references "DocumentReference/d1", and no included resources
    When it is parsed
    Then there is a single document, with reference "DocumentReference/d1" and no url
    And a Bundle of type "document" fails with a Manifest error

  @req:stt-vhl-007
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlReceiveTest.kt::VhlReceiveTest::STT-VHL-007_decrypts_what_node_crypto_encrypted,_with_and_without_zip_DEF
  Scenario Outline: Decrypts what node:crypto encrypted, with and without zip DEF (Kotlin)
    Given the node:crypto fixture vectors/ihe-vhl/jwe-dir-a256gcm.json
    When its "<jwe>" is decrypted with its key
    Then the content is the fixture's plaintext
    And the content type is "application/fhir+json"

    Examples:
      | jwe       |
      | jwe       |
      | jweZipDef |

  @req:stt-vhl-007
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlReceiveTest.kt::VhlReceiveTest::STT-VHL-007_a_wrong_key,_a_changed_byte_and_another_enc_are_refused
  Scenario: A wrong key, a changed byte and another enc are refused (Kotlin)
    Given "hello" encrypted as "text/plain" with a new VHL key
    When it is decrypted with another new key
    Then it fails with DecryptFailed
    And with the first ciphertext byte flipped it fails with DecryptFailed
    And with the protected header replaced by {"alg":"dir","enc":"A128GCM"} it fails with Unsupported

  @req:stt-vhl-008
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlReceiveTest.kt::VhlReceiveTest::STT-VHL-008_the_Content-Digest_is_RFC_9530
  Scenario: The Content-Digest is RFC 9530 (Kotlin)
    Given a POST to vhl-sharer.example.org/List/_search with body {"hello": "world"}
    When its signature base is built
    Then the content digest is "sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:", RFC 9530 Appendix B.1's

  @req:stt-vhl-008
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlReceiveTest.kt::VhlReceiveTest::STT-VHL-008_the_RFC_9421_signature_base_has_the_IHE_shape
  Scenario: The RFC 9421 signature base has the IHE shape (Kotlin)
    Given a POST to vhl-sharer.example.org/List/_search, content type "application/x-www-form-urlencoded", body {"hello": "world"}, keyid "receiver-key-123", alg "ecdsa-p256-sha256", created 1735689600
    When its signature base is built
    Then the Signature-Input is sig1=("@method" "@path" "@authority" "content-type" "content-digest");created=1735689600;keyid="receiver-key-123";alg="ecdsa-p256-sha256"
    And the base is these lines, joined by newlines:
      """
      "@method": POST
      "@path": /List/_search
      "@authority": vhl-sharer.example.org
      "content-type": application/x-www-form-urlencoded
      "content-digest": sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:
      "@signature-params": ("@method" "@path" "@authority" "content-type" "content-digest");created=1735689600;keyid="receiver-key-123";alg="ecdsa-p256-sha256"
      """

  @req:stt-vhl-008
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlReceiveTest.kt::VhlReceiveTest::STT-VHL-008_a_DER_signature_becomes_the_raw_header_value_and_verifies
  Scenario: A DER signature becomes the raw header value, and verifies (Kotlin)
    Given the signature base of the same POST request
    And a freshly generated P-256 key pair
    When the base is signed with SHA256withECDSA, the DER signature made into a Signature header for "ecdsa-p256-sha256"
    Then the value between "sig1=:" and ":" decodes to 64 bytes
    And those raw bytes, converted back to DER, verify over the base with the public key

  @req:stt-vhl-009
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VhlReceiveTest.kt::VhlReceiveTest::STT-VHL-009_an_expired_link_fails_verification,_by_its_own_exp
  Scenario: An expired link fails verification, by its own exp (Kotlin)
    Given the IHE example VHL payload, exp 1735689600
    When it is validated at 1735689601
    Then the issue codes are exactly "expired"
    And the payload with exp 1000 seconds before the testkit's now, issued in an HCERT valid at that now, fails verification with reason EXPIRED

  @req:stt-vhl-002
  @test:tools/conformance-ts/suite.ts::STT-VHL-002_a_VHL_is_issued_as_a_CBOR_map_at_key_5_and_verifies
  Scenario: A VHL is issued as a CBOR map at key 5, and verifies (TypeScript, either package)
    Given the IHE example VHL payload, expiring a day after the testkit's now
    When it is issued with iss "XX", signed ES256 with the testkit key
    Then the HC1 string verifies against the testkit DSC
    And its first entry is at subclaim 5, tagged "vhl", with the same exp

  @req:stt-vhl-005
  @test:tools/conformance-ts/suite.ts::STT-VHL-005_the_ITI-YY5_request_is_the_exact_body_of_the_IHE_example
  Scenario: The ITI-YY5 request is the exact body of the IHE example (TypeScript, either package)
    Given the IHE example VHL payload, flag "LP"
    When the manifest request is built for recipient "Dr. Smith Hospital", passcode "user-pin" and embeddedLengthMax 10000
    Then its body is exactly "_id=abc123def456&code=folder&status=current&patient.identifier=urn%3Aoid%3A2.16.840.1.113883.2.4.6.3%7CPASSPORT123&_include=List%3Aitem&recipient=Dr.+Smith+Hospital&passcode=user-pin&embeddedLengthMax=10000"
    And building it for "Clinic B" with no passcode throws "manifest"

  @req:stt-vhl-006
  @test:tools/conformance-ts/suite.ts::STT-VHL-006_the_IHE_Case_B_manifest_Bundle_reads_as_documents
  Scenario: The IHE Case B manifest Bundle reads as documents (TypeScript, either package)
    Given the IHE ITI-YY5 Case B manifest Bundle
    When it is parsed
    Then there are 4 documents
    And the first has url "https://vhl-sharer.example.org/Binary/doc001-content"
    And the second has reference "DocumentReference/doc002"

  @req:stt-vhl-007
  @test:tools/conformance-ts/suite.ts::STT-VHL-007_JWE_dir/A256GCM:_the_node:crypto_fixture_decrypts,_and_a_round_trip_refuses_the_wrong_key
  Scenario: JWE dir/A256GCM: the node:crypto fixture decrypts, and a round trip refuses the wrong key (TypeScript, either package)
    Given the node:crypto JWE fixture, with and without zip DEF
    When each is decrypted with the fixture's key
    Then each gives the fixture's plaintext
    And "hello" encrypted as "text/plain" with a new key decrypts with that key to "hello", content type "text/plain"
    And decrypting it with another new key throws "decrypt-failed"

  @req:stt-vhl-008
  @test:tools/conformance-ts/suite.ts::STT-VHL-008_RFC_9421_signature_base,_RFC_9530_digest,_and_a_DER_signature_as_the_raw_header_value
  Scenario: RFC 9421 signature base, RFC 9530 digest, and a DER signature as the raw header value (TypeScript, either package)
    Given a POST to vhl-sharer.example.org/List/_search, content type "application/x-www-form-urlencoded", body {"hello": "world"}, keyid "receiver-key-123", alg "ecdsa-p256-sha256", created 1735689600
    When its signature base is built
    Then the content digest is "sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:"
    And the Signature-Input starts with sig1=("@method" "@path" "@authority" "content-type" "content-digest");created=1735689600
    And the base, signed ES256 by the testkit key as DER and made into a Signature header, carries a 64-byte raw signature
    And that raw signature verifies over the base

  @req:stt-vhl-009
  @test:tools/conformance-ts/suite.ts::STT-VHL-009_an_expired_link_fails_verification_by_its_own_exp
  Scenario: An expired link fails verification, by its own exp (TypeScript, either package)
    Given the IHE example VHL payload with exp 1000 seconds before the testkit's now
    When it is issued in an HCERT valid for a day from that now, signed ES256 with the testkit key
    Then verifying the HC1 string at that now fails with reason "expired"
