# Test-plan case hcert-build-cwt (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-build-cwt
Feature: Wrap the payload in a CWT claim set inside the DSC's validity
  Step 3 of issuance: the payload goes into a CWT claim set (iss, iat, exp,
  hcert -260), whose validity must sit inside the DSC's.

  @req:stt-cwt-001 @req:stt-cos-002 @req:stt-cos-003
  @test:tools/hcert-rust/tests/build_cwt_sign_cose.rs::stt_cwt_001_stt_cos_002_stt_cos_003_prepare_builds_the_claims_and_a_protected_alg_and_kid
  Scenario: Prepare builds the claims and a protected alg and kid (Rust)
    Given an ES256 issue request for the newborn's DVCMin with iss "XX"
    When it is prepared
    Then the protected header has alg (1) -7 and kid (4) the ES256 testkit DSC's kid
    And the claim set has iss (1) "XX", iat (6) the issue time, and an hcert claim -260 holding entry -6
    And the bytes to be signed are the Sig_structure over the protected header and the claim set

  @req:stt-cwt-004
  @test:tools/hcert-rust/tests/build_cwt_sign_cose.rs::stt_cwt_004_validity_outside_the_dsc_is_refused
  Scenario: A validity outside the DSC's is refused (Rust)
    Given an ES256 issue request whose exp is 20 years after its iat
    When it is prepared
    Then it is refused with ValidityOutsideDsc

  @req:stt-cwt-002
  @test:tools/hcert-rust/tests/build_cwt_sign_cose.rs::stt_cwt_002_iat_and_exp_are_integer_numeric_dates
  Scenario: iat and exp are integer NumericDates (Rust)
    Given an ES256 issue request with iat now and exp 365 days later
    When it is prepared
    Then the claim set's keys are the integers 1, 4, 6 and -260, in that order
    And exp (4) is the integer now + 365 days
    And iat (6) is the integer now

  @req:stt-cwt-003
  @test:tools/hcert-rust/tests/build_cwt_sign_cose.rs::stt_cwt_003_an_hcert_without_exp_is_refused_on_issue_and_on_verify
  Scenario: An HCERT without exp is refused on issue and on verify (Rust)
    Given an ES256 issue request whose exp equals its iat
    When it is prepared
    Then it is refused with PayloadInvalid, the first issue's code "exp-not-after-iat"
    And a claim set without exp, signed with the ES256 testkit key, fails verification at step Cwt with reason CoseMalformed

  @req:stt-cwt-005
  @test:tools/hcert-rust/tests/build_cwt_sign_cose.rs::stt_cwt_005_iss_is_optional_and_two_upper_case_letters_when_present
  Scenario: iss is optional, and two upper-case letters when present (Rust)
    Given an ES256 issue request for the newborn's DVCMin
    When it is prepared with iss "Xx", "XXX" or "x"
    Then each is refused with PayloadInvalid, the first issue's code "not-alpha2"
    And prepared with no iss, the claim set has no claim 1
    And that certificate, signed and verified, has no iss
    And a certificate issued with iss "XX" verifies with iss "XX"

  @req:stt-cwt-006
  @test:tools/hcert-rust/tests/build_cwt_sign_cose.rs::stt_cwt_006_claims_this_version_does_not_know_are_kept
  Scenario: Claims this version does not know are kept (Rust)
    Given a claim set with the extra claim -70000: "future", signed with the ES256 testkit key
    When it is verified as COSE with the ES256 testkit DSC trusted
    Then it verifies with exactly one other claim
    And that claim decodes to key -70000 and value "future"

  @req:stt-cwt-001 @req:stt-cwt-002
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/BuildCwtTest.kt::BuildCwtTest::STT-CWT-001_STT-CWT-002_claim_keys_are_integers_and_dates_are_integer_NumericDates
  Scenario: Claim keys are integers and dates are integer NumericDates (Kotlin)
    Given the newborn's DVCMin issued with ES256
    When its claim set is read from the COSE payload
    Then its keys are the integers 1, 4, 6 and -260
    And exp (4) and iat (6) are integers

  @req:stt-cwt-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/BuildCwtTest.kt::BuildCwtTest::STT-CWT-003_an_HCERT_without_exp_is_refused_on_issue_and_on_verify
  Scenario: An HCERT without exp is refused on issue and on verify (Kotlin)
    Given an issue request for the newborn's DVCMin whose exp equals its iat
    When it is prepared
    Then it is refused with PayloadInvalid, with the one issue code "exp-not-after-iat"
    And a claim set without exp, signed with the ES256 testkit key, fails verification at step CWT with reason COSE_MALFORMED

  @req:stt-cwt-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/BuildCwtTest.kt::BuildCwtTest::STT-CWT-004_the_validity_must_fit_inside_the_DSC's
  Scenario: The validity must fit inside the DSC's (Kotlin)
    Given an issue request for the newborn's DVCMin whose exp is 20 years after its iat
    When it is prepared
    Then it is refused with ValidityOutsideDsc

  @req:stt-cwt-005
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/BuildCwtTest.kt::BuildCwtTest::STT-CWT-005_iss_is_optional,_and_alpha-2_when_present
  Scenario: iss is optional, and alpha-2 when present (Kotlin)
    Given issue requests for the newborn's DVCMin with iss "Xx", "XXX" and "x"
    When each is prepared
    Then each is refused with PayloadInvalid, with the one issue code "not-alpha2"
    And issued with no iss, its claim set has no claim 1
    And that COSE verifies with no iss
    And the testkit's certificate, issued with iss "XX", verifies with iss "XX"

  @req:stt-cwt-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/BuildCwtTest.kt::BuildCwtTest::STT-CWT-006_claims_this_version_does_not_know_are_kept
  Scenario: Claims this version does not know are kept (Kotlin)
    Given a claim set with the extra claim -70000: "future", signed with the ES256 testkit key
    When it is verified as COSE with the ES256 testkit DSC trusted
    Then it verifies with a single other claim
    And that claim decodes to key -70000 and value "future"

  @req:stt-cwt-001 @req:stt-cwt-002
  @test:tools/conformance-ts/suite.ts::STT-CWT-001_STT-CWT-002_the_claim_set_has_integer_keys_and_integer_NumericDates
  Scenario: The claim set has integer keys and integer NumericDates (TypeScript, either package)
    Given the newborn's DVCMin issued with ES256, iss "XX", iat now and exp one day later
    When its claim set is read from the COSE payload
    Then its keys are 1, 4, 6 and -260, in that order
    And exp (4) is the number now + 86400 and iat (6) the number now
    And iss (1) is "XX"
    And the hcert claim -260 has the single key -6

  @req:stt-cwt-003
  @test:tools/conformance-ts/suite.ts::STT-CWT-003_an_HCERT_without_exp_is_refused_on_issue_and_on_verify
  Scenario: An HCERT without exp is refused on issue and on verify (TypeScript, either package)
    Given an issue request whose exp equals its iat
    When it is prepared
    Then it throws "payload-invalid"
    And a claim set without exp, signed with the ES256 testkit key, fails verification at step "cwt" with reason "cose-malformed"

  @req:stt-cwt-005
  @test:tools/conformance-ts/suite.ts::STT-CWT-005_iss_is_optional,_and_two_upper-case_letters_when_present
  Scenario: iss is optional, and two upper-case letters when present (TypeScript, either package)
    Given an issue request for the newborn's DVCMin
    When it is prepared with iss "Xx" or "XXX"
    Then each throws "payload-invalid"
    And issued with no iss, its claim set has no claim 1
    And that HC1 string verifies with no iss

  @req:stt-cwt-006
  @test:tools/conformance-ts/suite.ts::STT-CWT-006_claims_this_version_does_not_know_are_kept
  Scenario: Claims this version does not know are kept (TypeScript, either package)
    Given a claim set with the extra claim -70000: "future", signed with the ES256 testkit key
    When it is verified as COSE with the ES256 testkit DSC trusted
    Then it verifies with exactly one other claim
    And that claim reads as key -70000 and value "future"

  @req:stt-sel-004
  @test:tools/conformance-ts/suite.ts::STT-SEL-004_one_entry_per_payload,_in_wire_order;_no_payload_and_a_duplicate_subclaim_are_refused
  Scenario: One entry per payload, in wire order; no payload and a duplicate subclaim are refused (TypeScript, either package)
    Given a certificate issued with ES256 holding the newborn's DVCMin and a live VHL
    When it is verified
    Then its entries' subclaims are 5 and -6, in that order
    And preparing a request with no payloads throws "no-payload"
    And preparing a request with the DVCMin twice throws "duplicate-subclaim"
