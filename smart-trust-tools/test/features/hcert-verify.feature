# Test-plan case hcert-verify (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-verify
Feature: Verify an HC1 string or raw COSE, or read it explicitly unverified
  The steps upwards: trust lookup by kid, signature, key usage, time and
  payload. Or read the certificate explicitly unverified, for triage.

  @req:stt-ver-003
  @test:tools/hcert-rust/tests/verify.rs::stt_ver_003_headers_are_checked_before_any_signature
  Scenario: Headers are checked before any signature (Rust)
    Given three COSE_Sign1 structures with an empty claim set and a 64-byte zero signature:
      | protected header       | unprotected header |
      | {1: -7}                | {1: -7}            |
      | {1: -7}                | {}                 |
      | {1: -7, 4: h'0102'}    | {}                 |
    When each is verified as COSE against an empty trust store
    Then each fails at step Header with reason HeaderInvalid

  @req:stt-ver-007 @req:stt-sel-004
  @test:tools/hcert-rust/tests/verify.rs::stt_ver_007_stt_sel_004_an_unknown_second_entry_is_kept_raw_unless_the_profile_allows_one
  Scenario: An unknown second entry is kept raw, unless the profile allows only one (Rust)
    Given a claim set whose hcert claim -260 holds the newborn's DVCMin under -6 and an empty map under -7
    And it is signed with the ES256 testkit key
    When it is verified as COSE with the ES256 testkit DSC trusted
    Then the entries' subclaims are -6 and -7, in that order
    And the -6 entry is the newborn's DVCMin
    And the -7 entry is a raw payload with subclaim -7
    And a KeyUsage diagnostic mentions "subclaim -7"
    And verifying it with a profile of at most 1 payload fails at step Hcert with reason MultipleSubclaims

  @req:stt-ver-004 @req:stt-sel-004
  @test:tools/hcert-rust/tests/verify.rs::stt_ver_004_stt_sel_004_key_usage_is_checked_per_entry
  Scenario: Key usage is checked per entry (Rust)
    Given the PS256 testkit DSC, whose extended key usage allows test certificates only
    And a certificate it signs holding the newborn's DVCMin and a live VHL
    When it is verified with that DSC trusted
    Then it verifies, with entries (subclaim 5, key usage authorised) and (subclaim -6, not authorised)
    And a KeyUsage diagnostic mentions "subclaim -6"
    And a certificate holding the DVCMin alone, signed by the same DSC, fails at step KeyUsage with reason KeyUsageMismatch

  @req:stt-ver-011
  @test:tools/hcert-rust/tests/verify.rs::stt_ver_011_read_unverified_says_so
  Scenario: Reading unverified says so (Rust)
    Given the PR 129 "bcg" HC1 string
    When it is read unverified
    Then the first diagnostic starts with "NOT VERIFIED"
    And its entries' subclaims are -6
    And its iss is "XX"

  @req:stt-ver-001 @req:stt-ver-002
  @test:tools/hcert-rust/tests/verify.rs::stt_ver_001_stt_ver_002_a_tampered_payload_fails_at_the_signature_before_any_payload_is_read
  Scenario: A tampered payload fails at the signature, before any payload is read (Rust)
    Given a newborn's DVCMin whose nt is "LA", which would fail its model check
    And a COSE_Sign1 over it, signed with the ES256 testkit key, exp 1000 seconds after iat
    And a copy whose payload has the last byte's low bit flipped
    When the tampered copy is verified with the ES256 testkit DSC trusted
    Then it fails at step Signature with reason SignatureInvalid
    And verified against an empty trust store it fails at step TrustLookup with reason KidNotFound
    And the untampered COSE verified 100000 seconds later fails at step Time with reason Expired
    And the untampered COSE verified on time fails at step Payload with reason PayloadInvalid

  @req:stt-ver-008
  @test:tools/hcert-rust/tests/verify.rs::stt_ver_008_every_failure_is_a_value_naming_its_step_and_reason
  Scenario Outline: Every failure is a value naming its step and reason (Rust)
    Given the ES256 testkit DSC is trusted
    When "<input>" is verified
    Then it fails with reason <reason>
    And the failure's detail is not empty

    Examples:
      | input                        | reason                    |
      | NCFOXN                       | BadPrefix                 |
      | HC2:NCFOXN                   | UnsupportedContextVersion |
      | HC1:abc                      | Base45Invalid             |
      | HC1: followed by 9000 zeros  | LimitExceeded             |

  @req:stt-gen-001 @req:stt-gen-009
  @test:tools/hcert-rust/tests/verify.rs::stt_gen_001_stt_gen_009_issue_and_verify_with_es256_and_ps256_and_the_cose_bytes_travel_alone
  Scenario: Issue and verify with ES256 and PS256, and the COSE bytes travel alone (Rust)
    Given the newborn's DVCMin issued with ES256
    And a test certificate (raw subclaim 4, {"t": "x"}) issued with the PS256 testkit DSC, whose key usage allows test certificates only
    When each HC1 string is verified with its own DSC trusted
    Then the DVC verifies, and its one entry is the newborn's DVCMin
    And the test certificate verifies
    And decoding the DVC's HC1 string gives exactly its COSE bytes
    And each certificate's COSE bytes verify on their own, without the QR layers

  @req:stt-ver-002 @req:stt-sec-001
  @test:tools/hcert-rust/tests/verify.rs::stt_ver_002_stt_sec_001_a_failure_carries_no_payload_and_names_none_of_it
  Scenario: A failure carries no payload and names none of it (Rust)
    Given the newborn's DVCMin issued with ES256
    When it is verified against an empty trust store
    Then it fails at step TrustLookup with reason KidNotFound
    And the failure is only a step, a reason and a detail
    And the detail contains none of "Test CHILD", "Test MOTHER", "XM9V38" or characters 4 to 24 of the HC1 string
    And reading it unverified is a separate call whose first diagnostic starts with "NOT VERIFIED"

  @req:stt-ver-005
  @test:tools/hcert-rust/tests/verify.rs::stt_ver_005_time_is_the_clock_the_caller_passes_with_the_skew_it_allows
  Scenario: Time is the clock the caller passes, with the skew it allows (Rust)
    Given the newborn's DVCMin issued with iat now and exp one day later
    And the default clock skew of 300 seconds
    When it is verified at times the caller passes
    Then at exp + 299 it verifies
    And at exp + 301 it fails with reason Expired
    And at iat - 299 it verifies
    And at iat - 301 it fails with reason NotYetValid
    And with a clock skew of 0, at exp + 1 it fails with reason Expired

  @req:stt-ver-006 @req:stt-kid-002
  @test:tools/hcert-rust/tests/verify.rs::stt_ver_006_stt_kid_002_trust_list_presence_is_the_validity_check
  Scenario: Trust-list presence is the validity check (Rust)
    Given the newborn's DVCMin issued with ES256
    When it is verified against an empty trust store
    Then it fails at step TrustLookup with reason KidNotFound
    And verified 11 years later, with the DSC trusted and a clock skew of 20 years, it verifies
    And a TrustLookup diagnostic mentions "X.509 validity"

  @req:stt-ver-001 @req:stt-ver-002
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VerifyTest.kt::VerifyTest::STT-VER-001_STT-VER-002_a_tampered_payload_fails_at_the_signature,_before_any_payload_is_read
  Scenario: A tampered payload fails at the signature, before any payload is read (Kotlin)
    Given a tagged COSE_Sign1 over the newborn's claim set, signed with the ES256 testkit key
    And a copy whose payload has the last byte's low bit flipped
    When the tampered copy is verified as COSE with the ES256 testkit DSC trusted
    Then it fails at step SIGNATURE with reason SIGNATURE_INVALID

  @req:stt-ver-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VerifyTest.kt::VerifyTest::STT-VER-004_a_DSC_whose_key_usage_allows_test_certificates_only_cannot_sign_a_vaccination
  Scenario: A DSC whose key usage allows test certificates only cannot sign a vaccination (Kotlin)
    Given the newborn's DVCMin issued with the PS256 testkit DSC, whose key usage allows test certificates only
    When it is verified with that DSC trusted
    Then it fails at step KEY_USAGE with reason KEY_USAGE_MISMATCH

  @req:stt-ver-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VerifyTest.kt::VerifyTest::STT-VER-004_a_DCC_is_a_test,_vaccination_or_recovery_certificate_by_its_own_entry
  Scenario: A DCC is a test, vaccination or recovery certificate by its own entry (Kotlin)
    Given the PS256 testkit DSC, whose key usage allows test certificates only, is trusted
    When a raw subclaim 1 payload {"t": [{}]} issued with it is verified
    Then it verifies
    And a raw subclaim 1 payload {"v": [{}]} issued with it fails with reason KEY_USAGE_MISMATCH

  @req:stt-ver-005
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VerifyTest.kt::VerifyTest::STT-VER-005_time_is_the_clock_the_caller_passes,_with_the_skew_it_allows
  Scenario: Time is the clock the caller passes, with the skew it allows (Kotlin)
    Given the newborn's DVCMin issued with iat now and exp one day later
    And a clock skew of 300 seconds
    When it is verified at times the caller passes
    Then at exp + 299 it verifies
    And at exp + 301 it fails with reason EXPIRED
    And at iat - 301 it fails with reason NOT_YET_VALID

  @req:stt-ver-006 @req:stt-kid-002
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VerifyTest.kt::VerifyTest::STT-VER-006_STT-KID-002_a_kid_nobody_trusts_fails_the_trust_lookup
  Scenario: A kid nobody trusts fails the trust lookup (Kotlin)
    Given the newborn's DVCMin issued with ES256
    When it is verified against an empty trust store
    Then it fails at step TRUST_LOOKUP with reason KID_NOT_FOUND

  @req:stt-ver-007
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VerifyTest.kt::VerifyTest::STT-VER-007_the_payload_is_dispatched_to_its_logical_model_by_subclaim
  Scenario: The payload is dispatched to its logical model by subclaim (Kotlin)
    Given the newborn's DVCMin issued with ES256
    When it is verified with the ES256 testkit DSC trusted
    Then it has a single entry with subclaim -6
    And that entry's payload is a DvcMin

  @req:stt-ver-008 @req:stt-ver-009
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VerifyTest.kt::VerifyTest::STT-VER-008_STT-VER-009_every_failure_is_a_value_naming_its_step_and_reason,_offline
  Scenario Outline: Every failure is a value naming its step and reason, offline (Kotlin)
    Given the ES256 testkit DSC is trusted
    When "<input>" is verified
    Then it fails, as a value, with reason <reason>
    And the failure's detail is not empty

    Examples:
      | input                        | reason                      |
      | NCFOXN                       | BAD_PREFIX                  |
      | HC2:NCFOXN                   | UNSUPPORTED_CONTEXT_VERSION |
      | HC1:abc                      | BASE45_INVALID              |
      | HC1: followed by 9000 zeros  | LIMIT_EXCEEDED              |

  @req:stt-ver-011
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VerifyTest.kt::VerifyTest::STT-VER-011_an_unverified_read_for_triage_is_marked_so
  Scenario: An unverified read for triage is marked so (Kotlin)
    Given the newborn's DVCMin issued with ES256
    When it is read unverified
    Then it has a single entry with subclaim -6, a DvcMin whose vx.vp is "XM9V38"
    And the first diagnostic starts with "NOT VERIFIED"
    And reading "HC1:abc" unverified fails with reason BASE45_INVALID

  @req:stt-sec-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/VerifyTest.kt::VerifyTest::STT-SEC-001_a_failure's_message_does_not_carry_the_payload
  Scenario: A failure's message does not carry the payload (Kotlin)
    Given the newborn's DVCMin issued with ES256
    When it is verified against an empty trust store
    Then it fails
    And neither the detail nor any diagnostic contains "Test CHILD", "Test MOTHER" or "XM9V38"

  @req:stt-ver-011
  @test:tools/conformance-ts/suite.ts::STT-VER-011_read-unverified_decodes_and_says_it_is_not_verified
  Scenario: Read-unverified decodes and says it is not verified (TypeScript, either package)
    Given the PR 129 "hepb1" HC1 string
    When it is read unverified
    Then the first diagnostic starts with "NOT VERIFIED"
    And the first entry's subclaim is -6
    And its iss is "XX" and its iat is a bigint

  @req:stt-ver-002
  @test:tools/conformance-ts/suite.ts::STT-VER-002_a_failure_carries_no_payload,_and_an_unverified_read_is_its_own_named_call
  Scenario: A failure carries no payload, and an unverified read is its own named call (TypeScript, either package)
    Given the newborn's DVCMin issued with ES256
    When it is verified against an empty trust store
    Then it fails
    And the failure has no entries, otherClaims, iss or payload
    And neither its detail nor its diagnostics contain "Test CHILD" or "XM9V38"
    And reading it unverified gives a first diagnostic that starts with "NOT VERIFIED"

  @req:stt-ver-003
  @test:tools/conformance-ts/suite.ts::STT-VER-003_a_protected_header_with_an_unsupported_alg,_or_a_short_kid,_is_refused_before_the_signature
  Scenario: A protected header with an unsupported alg, or a short kid, is refused before the signature (TypeScript, either package)
    Given a claim set, exp 1000 seconds after iat, signed with the ES256 testkit key under two protected headers:
      | protected header                    |
      | alg -999 and the testkit kid        |
      | alg -7 and the kid's first 2 bytes  |
    When each is verified as COSE with the ES256 testkit DSC trusted
    Then the unsupported alg fails at step "header"
    And the short kid fails at step "header" with reason "header-invalid"

  @req:stt-ver-004
  @test:tools/conformance-ts/suite.ts::STT-VER-004_key_usage_is_checked_per_entry,_and_alone_a_DVC_under_a_test-only_DSC_is_refused
  Scenario: Key usage is checked per entry, and alone a DVC under a test-only DSC is refused (TypeScript, either package)
    Given the PS256 testkit DSC, whose key usage allows test certificates only, is trusted
    And a certificate it signs holding the newborn's DVCMin and a live VHL
    When it is verified
    Then it verifies, with entries 5 (key usage authorised) and -6 (not authorised)
    And a certificate holding the DVCMin alone, signed by the same DSC, fails at step "key-usage" with reason "key-usage-mismatch"

  @req:stt-ver-005
  @test:tools/conformance-ts/suite.ts::STT-VER-005_time_is_the_clock_the_caller_passes,_with_the_skew_it_allows
  Scenario Outline: Time is the clock the caller passes, with the skew it allows (TypeScript, either package)
    Given the newborn's DVCMin issued with iat now and exp one day later
    And a clock skew of 300 seconds
    When it is verified at <time>
    Then the outcome is <outcome>

    Examples:
      | time      | outcome       |
      | exp + 299 | ok            |
      | exp + 301 | expired       |
      | iat - 299 | ok            |
      | iat - 301 | not-yet-valid |

  @req:stt-ver-007
  @test:tools/conformance-ts/suite.ts::STT-VER-007_each_entry_is_decoded_by_its_subclaim's_codec,_falling_back_to_raw
  Scenario: Each entry is decoded by its subclaim's codec, falling back to raw (TypeScript, either package)
    Given a claim set whose hcert claim holds the newborn's DVCMin under -6 and an empty map under -7
    And it is signed with the ES256 testkit key
    When it is verified as COSE with the ES256 testkit DSC trusted
    Then the entries are -6 as "dvc-min" and -7 as "raw", in that order
