# Test-plan case hcert-conformance-testing (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-conformance-testing
Feature: Test an implementation against the shared vectors
  The PR 129 DVC example, the merged guide's XXR example, the negative
  vectors, seeded fuzzing of every decoder, and cross-implementation checks
  between the two packages.

  # --- PR 129 example (XXA) -------------------------------------------------

  @req:stt-tst-001 @req:stt-kid-001
  @test:tools/hcert-rust/tests/conformance.rs::stt_tst_001_stt_kid_001_the_vectors_kid_is_the_dscs
  Scenario: The vector's kid is the DSC's (Rust)
    Given a trust store holding the PR 129 DSC (dvc-qr-example-XXA-dsc.pem)
    When it is asked for candidates for the kid "WHM+BYqqZiE=", base64-decoded
    Then exactly one candidate comes back
    And its kid is 58733e058aaa6621

  @req:stt-tst-001 @req:stt-kid-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ConformanceVectorsTest.kt::ConformanceVectorsTest::STT-TST-001_STT-KID-001_the_vector's_kid_is_the_DSC's
  Scenario: The vector's kid is the DSC's (Kotlin)
    Given a trust store holding the PR 129 DSC (dvc-qr-example-XXA-dsc.pem)
    When it is asked for candidates for the kid "WHM+BYqqZiE=", base64-decoded
    Then exactly one candidate comes back
    And its kid is 58733e058aaa6621

  @req:stt-tst-001 @req:stt-pay-001
  @test:tools/hcert-rust/tests/conformance.rs::stt_tst_001_stt_pay_001_both_pr129_certificates_verify_and_decode_as_published
  Scenario: Both PR 129 certificates verify and decode as published (Rust)
    Given a trust store holding the PR 129 DSC
    And the clock at 1792454400 (2026-10-20T00:00:00Z) with the default verifier options
    When the "hepb1" and the "bcg" HC1 strings of the PR 129 vector are each verified
    Then each verifies with iss "XX"
    And each has exactly one entry, under subclaim -6, and it is a DVCMin
    And its n, nt, vx.vp and vx.bo are the vector's published payload values
    And there are no diagnostics

  @req:stt-tst-001 @req:stt-pay-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ConformanceVectorsTest.kt::ConformanceVectorsTest::STT-TST-001_STT-PAY-001_both_PR_129_certificates_verify_and_decode_as_published
  Scenario: Both PR 129 certificates verify and decode as published (Kotlin)
    Given a trust store holding the PR 129 DSC
    And the clock at 1792454400 (2026-10-20T00:00:00Z) with a clock skew of 300 seconds
    When the "hepb1" and the "bcg" HC1 strings of the PR 129 vector are each verified
    Then each verifies with iss "XX"
    And each has exactly one entry, under subclaim -6, and it is a DVCMin
    And its n, nt, vx.vp and vx.bo are the vector's published payload values
    And there are no diagnostics

  @req:stt-tst-001 @req:stt-ver-001
  @test:tools/conformance-ts/suite.ts::STT-TST-001-STT-VER-001-PR-129-certificate-verifies-as-published[${name}]
  Scenario Outline: The PR 129 <name> certificate verifies as published (TypeScript, either package)
    Given a trust store holding the PR 129 DSC
    And the clock at 1792454400 (2026-10-20T00:00:00Z)
    When the PR 129 vector's "<name>" HC1 string is verified
    Then it verifies with iss "XX"
    And it has exactly one entry, under subclaim -6, a DVCMin whose n is the vector's
    And the DSC's notBefore is before the clock

    Examples:
      | name  |
      | hepb1 |
      | bcg   |

  @req:stt-tst-002 @req:stt-cbr-001
  @test:tools/hcert-rust/tests/conformance.rs::stt_tst_002_stt_cbr_001_deterministic_re_encoding_reproduces_the_issued_cwt_byte_for_byte
  Scenario: Deterministic re-encoding reproduces the issued CWT byte for byte (Rust)
    Given the PR 129 "hepb1" HC1 string, decoded through the QR layers to its COSE_Sign1
    When the COSE_Sign1 is parsed and its CWT payload re-encoded deterministically
    Then the re-encoding is byte for byte the issued CWT
    And the CWT is 210 bytes and the COSE_Sign1 295 bytes
    And encoding the COSE_Sign1 back to HC1 and decoding it again gives the same COSE_Sign1

  @req:stt-tst-002 @req:stt-cbr-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ConformanceVectorsTest.kt::ConformanceVectorsTest::STT-TST-002_STT-CBR-001_deterministic_re-encoding_reproduces_the_issued_CWT_byte_for_byte
  Scenario: Deterministic re-encoding reproduces the issued CWT byte for byte (Kotlin)
    Given the PR 129 "hepb1" HC1 string, decoded through the QR layers to its COSE_Sign1
    When the COSE_Sign1 is parsed and its CWT payload re-encoded deterministically
    Then the re-encoding is byte for byte the issued CWT
    And the CWT is 210 bytes and the COSE_Sign1 295 bytes

  # --- The merged guide's example (XXR, GDHCN DEV) -----------------------------

  @req:stt-tst-011 @req:stt-tst-002
  @test:tools/hcert-rust/tests/conformance.rs::stt_tst_011_stt_tst_002_the_merged_guides_xxr_certificates_decode_as_published
  Scenario: The merged guide's XXR certificates decode as published (Rust)
    Given the "hepb1" and the "bcg" certificates of the XXR vector (dvc-qr-example-XXR.json)
    When each HC1 string is read unverified
    Then its kid is 916ffa567c0f44a2, its iss "XR", its iat 1792657800 and its exp 1824193800
    And it has exactly one entry, under subclaim -6, a DVCMin
    And its n, dob, vx.vp, vx.is and vx.bo are the vector's published payload values
    And re-encoding its CWT deterministically gives back the same bytes
    And the CWT, the COSE_Sign1, the deflated bytes and the HC1 string have exactly the vector's cwt_cbor_bytes, cose_sign1_bytes, deflated_bytes and hc1_chars
    And verifying it against a store holding only the PR 129 DSC fails at step TrustLookup with reason KidNotFound
    And the hepb1 figures are 222, 307, 293 and 444, as section 12.5 prints them

  @req:stt-tst-011 @req:stt-tst-002
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ConformanceVectorsTest.kt::ConformanceVectorsTest::STT-TST-011_STT-TST-002_the_merged_guide's_XXR_certificates_decode_as_published
  Scenario: The merged guide's XXR certificates decode as published (Kotlin)
    Given the "hepb1" and the "bcg" certificates of the XXR vector (dvc-qr-example-XXR.json)
    When each HC1 string is read unverified
    Then its kid is 916ffa567c0f44a2, its iss "XR", its iat 1792657800 and its exp 1824193800
    And it has exactly one entry, under subclaim -6, a DVCMin
    And its n, dob, vx.vp, vx.is and vx.bo are the vector's published payload values
    And re-encoding its CWT deterministically gives back the same bytes
    And the CWT, the COSE_Sign1, the deflated bytes and the HC1 string have exactly the vector's cwt_cbor_bytes, cose_sign1_bytes, deflated_bytes and hc1_chars
    And verifying it against a store holding only the PR 129 DSC fails at step TRUST_LOOKUP with reason KID_NOT_FOUND
    And the hepb1 figures are 222, 307, 293 and 444, as section 12.5 prints them

  @req:stt-tst-011 @req:stt-tst-002
  @test:tools/conformance-ts/suite.ts::STT-TST-011_STT-TST-002_the_merged_guide's_XXR_certificates_decode_as_published,_at_the_published_sizes
  Scenario: The merged guide's XXR certificates decode as published, at the published sizes (TypeScript, either package)
    Given every certificate of the XXR vector
    When each HC1 string is read unverified
    Then its kid is the vector's kid_hex and its iss the certificate's iss
    And it has exactly one entry, under subclaim -6, a DVCMin whose n, vx.vp and vx.bo are the vector's
    And re-encoding its CWT deterministically gives back the same bytes
    And the CWT, the COSE_Sign1, the deflated bytes and the HC1 string have exactly the vector's cwt_cbor_bytes, cose_sign1_bytes, deflated_bytes and hc1_chars
    And verifying it at 1792454400 against a store holding only the PR 129 DSC fails at step "trust-lookup" with reason "kid-not-found"

  @req:stt-tst-011
  @test:tools/hcert-rust/tests/conformance.rs::stt_tst_011_the_merged_guides_xxr_certificates_verify_against_the_dev_trust_lists_dsc
  Scenario: The merged guide's XXR certificates verify against the DEV trust list's DSC (Rust)
    Given a trust store to which XXR's DSC DID document (XXR-DSC-did.json) adds exactly 1 DSC
    When the XXR vector's "hepb1" and "bcg" HC1 strings are each verified one hour after their iat
    Then each verifies with iss "XR"
    And the DSC's country is "XR" and its kid 916ffa567c0f44a2
    And its one entry is key-usage authorised and is a DVCMin whose vx.vp is the vector's
    And there are no diagnostics

  @req:stt-tst-011
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ConformanceVectorsTest.kt::ConformanceVectorsTest::STT-TST-011_the_merged_guide's_XXR_certificates_verify_against_the_DEV_trust_list's_DSC
  Scenario: The merged guide's XXR certificates verify against the DEV trust list's DSC (Kotlin)
    Given a trust store to which XXR's DSC DID document (XXR-DSC-did.json) adds exactly 1 DSC
    When the XXR vector's "hepb1" and "bcg" HC1 strings are each verified one hour after their iat
    Then each verifies with iss "XR"
    And the DSC's country is "XR" and its kid 916ffa567c0f44a2
    And its one entry is key-usage authorised and is a DVCMin whose vx.vp is the vector's
    And there are no diagnostics

  @req:stt-tst-011
  @test:tools/conformance-ts/suite.ts::STT-TST-011_the_merged_guide's_XXR_certificates_verify_against_the_DEV_trust_list's_DSC
  Scenario: The merged guide's XXR certificates verify against the DEV trust list's DSC (TypeScript, either package)
    Given a trust store to which XXR's DSC DID document adds exactly 1 DSC
    When every XXR certificate's HC1 string is verified one hour after its iat
    Then each verifies with iss "XR"
    And the DSC's country is "XR" and its kid the vector's kid_hex
    And it has exactly one entry, key-usage authorised, a DVCMin whose vx.vp is the vector's
    And there are no diagnostics

  # --- Negative vectors ---------------------------------------------------------

  @req:stt-tst-004 @req:stt-tst-005
  @test:tools/hcert-rust/tests/conformance.rs::stt_tst_004_stt_tst_005_the_shared_negative_vectors_fail_at_the_named_step_with_the_named_reason
  Scenario: The shared negative vectors fail at the named step with the named reason (Rust)
    Given the shared negative vectors (vectors/negative/negative-vectors.json), at least 15 cases
    And for each case a trust store of its PEMs, or the defaults' when it names none
    And the case's clock, or the defaults', with the defaults' clock skew
    When each case's coseHex is verified as COSE bytes, or else its hc1 as an HC1 string
    Then verification fails
    And the failure's step and reason, by wire name, are the case's expect.step and expect.reason

  @req:stt-tst-004 @req:stt-tst-005
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ConformanceVectorsTest.kt::ConformanceVectorsTest::STT-TST-004_STT-TST-005_the_shared_negative_vectors_fail_at_the_named_step_with_the_named_reason
  Scenario: The shared negative vectors fail at the named step with the named reason (Kotlin)
    Given the shared negative vectors (vectors/negative/negative-vectors.json), at least 15 cases
    And for each case a trust store of its PEMs, or the defaults' when it names none
    And the case's clock, or the defaults', with the defaults' clock skew
    When each case's coseHex is verified as COSE bytes, or else its hc1 as an HC1 string
    Then verification fails
    And the failure's step and reason names are the case's expect.step and expect.reason

  @req:stt-tst-004 @req:stt-tst-005 @req:stt-ver-008
  @test:tools/conformance-ts/suite.ts::STT-TST-004-STT-TST-005-STT-VER-008-negative-vector-stops-at-the-named-step[${key}]
  Scenario: Each shared negative vector stops at its named step and reason (TypeScript, either package)
    Given each case of the shared negative vectors (vectors/negative/negative-vectors.json), run as its own check
    And a trust store of the case's PEMs, or the defaults' when it names none
    And the case's clock, or the defaults', with the defaults' clock skew of 300 seconds
    When the case's coseHex is verified as COSE bytes, or else its hc1 as an HC1 string
    Then verification fails at the case's expected step with its expected reason, written lower case with "-" for "_"

  # --- Fuzzing --------------------------------------------------------------------
  # Each fuzz test mutates seeds taken from the PR 129 vector (both certificates)
  # 1500 times (STT_FUZZ_ITERATIONS raises it), from a seed derived from the
  # target's name, so each run is reproducible.

  @req:stt-tst-006
  @test:tools/hcert-rust/tests/fuzz.rs::stt_tst_006_fuzzed_base45_never_panics_and_never_decodes_more_than_its_input
  Scenario: Fuzzed Base45 never panics and never decodes more than its input (Rust)
    Given the Base45 text of the PR 129 HC1 strings, without "HC1:"
    When it is mutated with Base45 characters (replaced, inserted, removed, truncated) and decoded
    Then no call panics and none takes a second
    And any decoded result has no more bytes than the input has characters

  @req:stt-tst-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/FuzzTest.kt::FuzzTest::STT-TST-006_fuzzed_Base45_never_throws_and_never_decodes_more_than_its_input
  Scenario: Fuzzed Base45 never throws and never decodes more than its input (Kotlin)
    Given the Base45 text of the PR 129 HC1 strings, without "HC1:"
    When it is mutated (characters replaced, inserted, some outside Base45, removed, truncated, duplicated) and decoded
    Then no call throws and none takes a second
    And any decoded result has no more bytes than the input has characters

  @req:stt-tst-006
  @test:tools/hcert-rust/tests/fuzz.rs::stt_tst_006_fuzzed_zlib_never_panics_and_never_inflates_past_the_limit
  Scenario: Fuzzed ZLIB never panics and never inflates past the limit (Rust)
    Given the deflated bytes of the PR 129 HC1 strings
    When they are mutated (bit flips, inserted, removed and special bytes, truncation, duplicated runs) and inflated with the default limit
    Then no call panics and none takes a second
    And any inflated result is no larger than the default maximum inflated size

  @req:stt-tst-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/FuzzTest.kt::FuzzTest::STT-TST-006_fuzzed_ZLIB_never_throws_and_never_inflates_past_the_limit
  Scenario: Fuzzed ZLIB never throws and never inflates past the limit (Kotlin)
    Given the deflated bytes of the PR 129 HC1 strings
    When they are mutated (bit flips, inserted, removed and special bytes, truncation, duplicated runs) and inflated with the default limit
    Then no call throws and none takes a second
    And any inflated result is no larger than the default maximum inflated size

  @req:stt-tst-006
  @test:tools/hcert-rust/tests/fuzz.rs::stt_tst_006_fuzzed_cbor_never_panics_in_the_deterministic_re_encoder
  Scenario: Fuzzed CBOR never panics in the deterministic re-encoder (Rust)
    Given the CWT payloads of the PR 129 certificates
    When they are mutated and re-encoded deterministically with the default limits
    Then no call panics and none takes a second

  @req:stt-tst-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/FuzzTest.kt::FuzzTest::STT-TST-006_fuzzed_CBOR_never_throws_in_the_deterministic_re-encoder
  Scenario: Fuzzed CBOR never throws in the deterministic re-encoder (Kotlin)
    Given the CWT payloads of the PR 129 certificates
    When they are mutated and re-encoded deterministically with the default limits
    Then no call throws and none takes a second

  @req:stt-tst-006
  @test:tools/hcert-rust/tests/fuzz.rs::stt_tst_006_fuzzed_cose_never_panics_in_the_sign1_parser
  Scenario: Fuzzed COSE never panics in the Sign1 parser (Rust)
    Given the COSE_Sign1 bytes of the PR 129 certificates
    When they are mutated and parsed as COSE_Sign1 with the default limits
    Then no call panics and none takes a second

  @req:stt-tst-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/FuzzTest.kt::FuzzTest::STT-TST-006_fuzzed_COSE_never_throws_in_the_Sign1_parser
  Scenario: Fuzzed COSE never throws in the Sign1 parser (Kotlin)
    Given the COSE_Sign1 bytes of the PR 129 certificates
    When they are mutated and parsed as COSE_Sign1 with the default limits
    Then no call throws and none takes a second

  @req:stt-tst-006
  @test:tools/hcert-rust/tests/fuzz.rs::stt_tst_006_fuzzed_hc1_strings_never_panic_in_the_qr_layers_or_the_verifier
  Scenario: Fuzzed HC1 strings never panic in the QR layers or the verifier (Rust)
    Given the PR 129 HC1 strings and a trust store holding the PR 129 DSC
    When they are mutated with Base45 characters and each is decoded through the QR layers, verified at 1792454400, and read unverified
    Then no call panics and none takes a second
    And any COSE_Sign1 the QR layers give is no larger than the default maximum inflated size

  @req:stt-tst-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/FuzzTest.kt::FuzzTest::STT-TST-006_fuzzed_HC1_strings_never_throw_in_the_QR_layers_or_the_verifier
  Scenario: Fuzzed HC1 strings never throw in the QR layers or the verifier (Kotlin)
    Given the PR 129 HC1 strings and a trust store holding the PR 129 DSC
    When they are mutated and each is decoded through the QR layers, verified at 1792454400, and read unverified
    Then no call throws and none takes a second
    And any COSE_Sign1 the QR layers give is no larger than the default maximum inflated size

  @req:stt-tst-006
  @test:tools/hcert-rust/tests/fuzz.rs::stt_tst_006_fuzzed_cose_bytes_never_panic_in_the_verifier
  Scenario: Fuzzed COSE bytes never panic in the verifier (Rust)
    Given the COSE_Sign1 bytes of the PR 129 certificates and a trust store holding the PR 129 DSC
    When they are mutated and each is verified as COSE bytes at 1792454400
    Then no call panics and none takes a second

  @req:stt-tst-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/FuzzTest.kt::FuzzTest::STT-TST-006_fuzzed_COSE_bytes_never_throw_in_the_verifier
  Scenario: Fuzzed COSE bytes never throw in the verifier (Kotlin)
    Given the COSE_Sign1 bytes of the PR 129 certificates and a trust store holding the PR 129 DSC
    When they are mutated and each is verified as COSE bytes at 1792454400
    Then no call throws and none takes a second

  @req:stt-tst-006
  @test:tools/conformance-ts/suite.ts::STT-TST-006_seeded_mutations_of_an_HC1_string_never_throw_out_of_verify
  Scenario: Seeded mutations of an HC1 string never throw out of verify (TypeScript, either package)
    Given a newborn's DVCMin issued as an HC1 string with the ES256 testkit DSC
    And a trust store holding that DSC
    When 300 seeded mutations of it, each with 1 to 4 characters after "HC1:" replaced by Base45 characters and up to 2 trailing characters cut, are verified
    Then every verification returns a "verified" or a "failed" result, and none throws

  # --- Cross-implementation (both packages at once) -------------------------------

  @req:stt-tst-003 @req:stt-gen-006
  @test:tools/conformance-ts/cross.ts::STT-TST-003-STT-GEN-006-issued-verifies-across-from-the-same-bytes[${key}]
  Scenario Outline: <ALG> <label> issued by one package verifies in the other, from the same bytes (TypeScript, both packages)
    Given an issue request for <payloads>, iss "XX", valid for one day from the testkit clock, with the <ALG> testkit DSC and development subclaims allowed
    When the issuing package and the verifying package each prepare it
    Then both build the same Sig_structure to sign
    And with the same <ALG> signature attached, both finish to the same COSE_Sign1
    And the verifying package checks the issued COSE_Sign1's signature against the DSC
    And verifying the issued HC1 string in the verifying package, with a store holding the DSC, <outcome>

    # Each row runs twice: issued by the first package and verified in the second, and the other way round.
    Examples:
      | ALG   | label   | payloads                                       | outcome                                                                                                          |
      | ES256 | DVC     | the newborn's DVCMin                           | verifies with one entry, -6, the same DVCMin, key-usage authorised                                               |
      | ES256 | VHL     | the IHE VHL with an exp one day out            | verifies with one entry, 5, the same VHL, key-usage authorised                                                   |
      | ES256 | DVC+VHL | the newborn's DVCMin and the IHE VHL           | verifies with the VHL at 5 then the DVCMin at -6, both key-usage authorised                                      |
      | PS256 | DVC     | the newborn's DVCMin                           | fails at step "key-usage" with reason "key-usage-mismatch", the PS256 DSC being for test certificates only       |
      | PS256 | VHL     | the IHE VHL with an exp one day out            | verifies with one entry, 5, the same VHL, key-usage authorised                                                   |
      | PS256 | DVC+VHL | the newborn's DVCMin and the IHE VHL           | verifies with the VHL at 5, key-usage authorised, then the DVCMin at -6, not key-usage authorised                |

  @req:stt-tst-003
  @test:tools/conformance-ts/cross.ts::STT-TST-003-signature-over-other-bytes-refused[${pair}]
  Scenario: A signature over one package's bytes, attached by the other to a different payload, is refused (TypeScript, both packages)
    Given the first package prepares the newborn's DVCMin, iss "XX", ES256 with the testkit DSC
    And the testkit key signs its Sig_structure
    And the second package prepares the same request with n "Other CHILD"
    When the second package finishes its request with that signature
    Then finish refuses it with "bad-signature-format"
