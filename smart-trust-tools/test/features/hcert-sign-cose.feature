# Test-plan case hcert-sign-cose (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-sign-cose
Feature: Sign the CWT as a COSE_Sign1, in two phases
  Step 5 of issuance: sign as COSE_Sign1 (ES256 or PS256) in two phases. The
  library prepares what is to be signed; the private key stays with its holder.

  @req:stt-iss-004 @req:stt-cos-005
  @test:tools/hcert-rust/tests/build_cwt_sign_cose.rs::stt_iss_004_stt_cos_005_two_phase_issuance_with_es256_and_ps256_verifies
  Scenario: Two-phase issuance with ES256 and PS256 verifies (Rust)
    Given under ES256 a newborn's DVCMin, and under PS256 a test certificate (subclaim 4, the map {"t": "x"}), since the PS256 testkit DSC's EKU allows test certificates only
    And each prepared for issuance and signed by its testkit key as a host would
    When each is finished into an HC1 string and verified against its own testkit DSC at the testkit time
    Then each HC1 string starts with "HC1:"
    And each certificate verifies, with its payload as its one entry
    And a newborn's DVCMin issued under PS256 fails at step KeyUsage with reason KeyUsageMismatch

  @req:stt-cos-006
  @test:tools/hcert-rust/tests/build_cwt_sign_cose.rs::stt_cos_006_finish_refuses_a_signature_from_another_key
  Scenario: finish refuses a signature from another key, and accepts DER (Rust)
    Given a newborn's DVCMin prepared for ES256 issuance
    And an r||s signature over its to-be-signed bytes by a P-256 key that is not the DSC's
    When the issuance is finished with that signature
    Then it fails with BadSignatureFormat
    And finishing with the DSC key's signature with one bit of byte 10 flipped fails with BadSignatureFormat
    And finishing with a correct signature converted to DER, as JCA gives it, succeeds

  @req:stt-cos-001
  @test:tools/hcert-rust/tests/build_cwt_sign_cose.rs::stt_cos_001_the_issued_cose_sign1_is_tagged_18_and_an_untagged_one_also_verifies
  Scenario: The issued COSE_Sign1 is tagged 18, and an untagged one also verifies (Rust)
    Given a newborn's DVCMin issued with ES256 by the testkit
    When its COSE bytes are decoded as CBOR
    Then they are tag 18 around an array of 4 items: a byte string, a map, a byte string and a byte string
    And parsing it as a COSE_Sign1 reports it tagged, with the kid in the protected header
    And the same four items encoded without the tag verify, giving the newborn's DVCMin
    And the verification carries a Cose-step diagnostic saying it is "not tagged 18"

  @req:stt-cos-004
  @test:tools/hcert-rust/tests/build_cwt_sign_cose.rs::stt_cos_004_the_signature1_structure_uses_the_protected_bytes_as_received
  Scenario: The Signature1 structure uses the protected header bytes as received (Rust)
    Given a newborn's DVCMin prepared for ES256 issuance
    Then its to-be-signed bytes are the CBOR array ["Signature1", protected bytes, empty bytes, payload bytes]
    And sig_structure over the same protected and payload bytes gives the same array
    Given a protected header hand-encoded out of deterministic order, {4: kid, 1: -7}, which differs from the one the issuer builds
    When the payload is signed over that header as sent and assembled into a COSE_Sign1
    Then it verifies, giving the newborn's DVCMin

  @req:stt-cos-001 @req:stt-cos-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SignCoseTest.kt::SignCoseTest::STT-COS-001_STT-COS-003_a_tagged_COSE_Sign1_with_alg_and_kid_in_the_protected_header
  Scenario: A tagged COSE_Sign1 with alg and kid in the protected header (Kotlin)
    Given a newborn's DVCMin issued by the testkit
    When its COSE bytes are decoded as CBOR
    Then they are tag 18 around an array of 4 items
    And parsing it as a COSE_Sign1 reports it tagged, with the kid in the protected header
    And the protected header maps 1 (alg) to -7 (ES256)
    And it maps 4 (kid) to the kid derived from the ES256 testkit DSC

  @req:stt-cos-004 @req:stt-iss-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SignCoseTest.kt::SignCoseTest::STT-COS-004_STT-ISS-004_what_is_signed_is_the_Signature1_structure_prepare_returns
  Scenario: What is signed is the Signature1 structure prepare returns (Kotlin)
    Given a newborn's DVCMin prepared for issuance, and the same DVCMin issued by the testkit
    When the issued COSE_Sign1 is parsed
    Then sigStructure over its protected and payload bytes is the CBOR array ["Signature1", protected bytes, empty bytes, payload bytes]
    And the prepared issuance's to-be-signed bytes are that same array

  @req:stt-cos-002 @req:stt-gen-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SignCoseTest.kt::SignCoseTest::STT-COS-002_STT-GEN-001_both_ES256_and_PS256_sign_and_verify
  Scenario: Both ES256 and PS256 sign and verify (Kotlin)
    Given a newborn's DVCMin issued with ES256
    And a raw test-certificate payload {"t": "x"} under subclaim 4 issued with PS256, whose DSC may sign test certificates only
    When each HC1 string is verified against its own testkit DSC
    Then both are verified

  @req:stt-cos-005
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SignCoseTest.kt::SignCoseTest::STT-COS-005_an_ES256_signature_is_a_fixed-width_64-byte_r_and_s,_whatever_the_signer_returns
  Scenario: An ES256 signature is a fixed-width 64-byte r and s, whatever the signer returns (Kotlin)
    Given a newborn's DVCMin issued by the testkit, whose signer returns DER
    Then the COSE_Sign1's signature is 64 bytes
    And 64 bytes of r||s converted to DER and back are unchanged
    And r||s with leading zeros in r and s (r = 1, s = 2) converted to DER and back is unchanged, still 64 bytes

  @req:stt-cos-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SignCoseTest.kt::SignCoseTest::STT-COS-006_the_library_holds_no_private_key,_and_refuses_a_signature_from_another_key
  Scenario: The library holds no private key, and refuses a signature from another key (Kotlin)
    Given a newborn's DVCMin prepared for ES256 issuance
    And a SHA256withECDSA signature over its to-be-signed bytes from a freshly generated P-256 key, not the DSC's
    When the issuance is finished with that signature
    Then it fails with BadSignatureFormat

  @req:stt-ver-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SignCoseTest.kt::SignCoseTest::STT-VER-003_a_protected_header_with_an_unsupported_alg_is_refused
  Scenario: A protected header with an unsupported alg is refused (Kotlin)
    Given an untagged COSE_Sign1 whose protected header is {1: -8}, with an empty unprotected header, payload and signature
    When it is verified against an empty trust store
    Then it fails at step HEADER with reason UNSUPPORTED_ALGORITHM

  @req:stt-cos-001 @req:stt-cos-002 @req:stt-cos-003 @req:stt-kid-001
  @test:tools/conformance-ts/suite.ts::STT-COS-001_STT-COS-002_STT-COS-003_STT-KID-001_the_COSE_Sign1_is_tagged_ES256_with_the_vector's_kid_in_the_protected_header
  Scenario: The PR 129 COSE_Sign1 is tagged, ES256, with the vector's kid in the protected header (TypeScript, either package)
    Given the PR 129 hepb1 HC1 string
    When it is decoded to its COSE_Sign1 and parsed
    Then it is tagged, its alg is es256 and its kid is in the protected header
    And the kid is 58733e058aaa6621

  @req:stt-cos-004 @req:stt-cos-002
  @test:tools/conformance-ts/suite.ts::STT-COS-004_STT-COS-002_verify-sign1_checks_the_Sig_structure_against_the_DSC
  Scenario: verify-sign1 checks the Sig_structure against the DSC (TypeScript, either package)
    Given the PR 129 hepb1 COSE_Sign1, and the DSC the PR 129 PEM holds for its kid
    When verify-sign1 checks it against that DSC
    Then it passes
    And with the first signature byte's lowest bit flipped it throws "signature-invalid"
    And the Sig_structure over its protected and payload bytes starts with 0x84, a 4-item array

  @req:stt-cos-005
  @test:tools/conformance-ts/suite.ts::STT-COS-005_ECDSA_DER_and_r||s_convert_both_ways
  Scenario: ECDSA DER and r||s convert both ways (TypeScript, either package)
    Given a DER ES256 signature by the testkit key over the bytes 1, 2, 3
    When it is converted to r||s
    Then the result is 64 bytes
    And converting it to DER and back gives the same 64 bytes
    And converting 10 bytes of r||s to DER throws "bad-signature-format"

  @req:stt-iss-004 @req:stt-cos-005
  @test:tools/conformance-ts/suite.ts::STT-ISS-004_STT-COS-005_two-phase_issuance_with_a_host_DER_signature_verifies
  Scenario: Two-phase issuance with a host DER signature verifies (TypeScript, either package)
    Given a newborn's DVCMin prepared for ES256 issuance with iss "XX", valid for one day from the testkit time
    Then the pending signature's algorithm is es256 and its kid is the kid of the ES256 testkit DSC
    When the host signs its to-be-signed bytes as DER and the issuance is finished
    Then the HC1 string verifies against the testkit DSC
    And its first entry is a DVCMin named "Test CHILD"

  @req:stt-cos-006
  @test:tools/conformance-ts/suite.ts::STT-COS-006_finish_refuses_a_signature_from_another_key
  Scenario: finish refuses a signature from another key (TypeScript, either package)
    Given a newborn's DVCMin prepared for ES256 issuance
    And a DER signature over its to-be-signed bytes by a fresh P-256 key that no DSC holds
    When the issuance is finished with that signature
    Then it throws "bad-signature-format"
