# Test-plan case hcert-select-payload (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-select-payload
Feature: Choose the logical model and hcert subclaim for a use case
  Step 1 of issuance: choose the logical model and hcert subclaim for a use
  case, from the registry the guide defines.

  @req:stt-sel-004 @req:stt-iss-004
  @test:tools/hcert-rust/tests/payload.rs::stt_sel_004_stt_iss_004_a_certificate_with_a_dvc_and_a_vhl_verifies_with_both_entries
  Scenario: A certificate with a DVC and a VHL verifies with both entries (Rust)
    Given a newborn's DVCMin and the IHE VHL example, live at the testkit time, issued together with ES256
    When the HC1 string is verified
    Then its entries are subclaim 5 then -6, in wire order, each with key usage authorised
    And entry 5 is the VHL and entry -6 the newborn's DVCMin
    And read-unverified gives entries 5 then -6, each with its payload

  @req:stt-sel-004
  @test:tools/hcert-rust/tests/payload.rs::stt_sel_004_max_payloads_refuses_more_entries_than_the_profile_allows
  Scenario: max_payloads refuses more entries than the profile allows (Rust)
    Given a certificate with a newborn's DVCMin and a VHL, issued with ES256
    When it is verified with max_payloads 1
    Then it fails at step Hcert with reason MultipleSubclaims
    And verified with max_payloads 2 it gives 2 entries

  @req:stt-sel-004
  @test:tools/hcert-rust/tests/payload.rs::stt_sel_004_an_invalid_entry_is_left_out_and_reported
  Scenario: An invalid entry is left out and reported (Rust)
    Given a signed claim set whose hcert holds a live VHL under 5 and, under -6, a DVCMin whose nt is "LA"
    When it is verified
    Then its one entry is subclaim 5
    And a Payload-step diagnostic starts "subclaim -6:"
    And a claim set with only that invalid DVCMin under -6 fails at step Payload with reason PayloadInvalid

  @req:stt-sel-004
  @test:tools/hcert-rust/tests/payload.rs::stt_sel_004_issuance_refuses_no_payload_and_a_duplicate_subclaim
  Scenario: Issuance refuses no payload and a duplicate subclaim (Rust)
    Given an ES256 issuance request
    When it is prepared with no payloads
    Then it fails with NoPayload
    When it is prepared with two DVCMin payloads
    Then it fails with DuplicateSubclaim(-6)

  @req:stt-sel-001 @req:stt-sel-003
  @test:tools/hcert-rust/tests/payload.rs::stt_sel_001_stt_sel_003_the_subclaims_are_the_guides_and_development_ones_need_opting_in
  Scenario: The subclaims are the guide's, and development ones need opting in (Rust)
    Given the default subclaim registry
    Then its keys are 1, 3, 4, 5, -6 and -7, in that order
    When a newborn's DVCMin is prepared for issuance without allowing development subclaims
    Then it fails with DevelopmentSubclaimNotAllowed(-6)

  @req:stt-sel-002
  @test:tools/hcert-rust/tests/payload.rs::stt_sel_002_a_host_registers_its_own_subclaim_and_issues_under_it
  Scenario: A host registers its own subclaim and issues under it (Rust)
    Given the default registry, which has no subclaim 42
    And a raw payload {"k": "v"} under subclaim 42
    When it is prepared for issuance
    Then it fails with UnknownSubclaim(42)
    When the host registers subclaim 42 as "Local payload" and issues it with ES256
    Then the HC1 string verifies with that registry, its one entry the raw payload under 42, unchanged
    When the host registers -7 again as "Local medication list"
    Then looking up -7 gives "Local medication list", and the registry holds -7 once

  @req:stt-sel-003
  @test:tools/hcert-rust/tests/payload.rs::stt_sel_003_dvc_moves_to_an_assigned_subclaim_without_an_api_change
  Scenario: DVC moves to an assigned subclaim without an API change (Rust)
    Given a registry where subclaim 6 is registered as DVCMin, with the DVCMin profile, and DVCMin is set to subclaim 6
    When a newborn's DVCMin is issued with ES256 and with PS256, development subclaims not allowed
    Then each issues, a production number needing no opt-in
    And the ES256 certificate verifies with that registry, its one entry the newborn's DVCMin under 6
    And the PS256 certificate fails at step KeyUsage with reason KeyUsageMismatch, its DSC's EKU allowing test certificates only

  @req:stt-sel-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SelectPayloadTest.kt::SelectPayloadTest::STT-SEL-001_the_registry_holds_the_subclaims_the_guide_defines
  Scenario: The registry holds the subclaims the guide defines (Kotlin)
    Given a new subclaim registry
    Then its keys are 1, 3, 4, 5, -6 and -7
    And subclaim -6's logical model is "http://smart.who.int/trust-phw/StructureDefinition/DVCMin"
    And DVCMin maps to subclaim -6 and VHL to subclaim 5

  @req:stt-sel-002
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SelectPayloadTest.kt::SelectPayloadTest::STT-SEL-002_a_host_registers_its_own_subclaim_and_issues_under_it
  Scenario: A host registers its own subclaim and issues under it (Kotlin)
    Given a new registry, which has no subclaim 42
    And a raw payload {"k": "v"} under subclaim 42
    When it is prepared for issuance
    Then it fails with UnknownSubclaim(42)
    When the host registers subclaim 42 as "Local payload"
    Then the raw payload issues under it

  @req:stt-sel-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SelectPayloadTest.kt::SelectPayloadTest::STT-SEL-003_a_development-range_subclaim_needs_the_explicit_opt-in
  Scenario: A development-range subclaim needs the explicit opt-in (Kotlin)
    Given a newborn's DVCMin issuance request that does not allow development subclaims
    When it is prepared with the default registry
    Then it fails with DevelopmentSubclaimNotAllowed(-6)

  @req:stt-sel-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SelectPayloadTest.kt::SelectPayloadTest::STT-SEL-003_DVC_moves_to_an_assigned_subclaim_without_an_API_change
  Scenario: DVC moves to an assigned subclaim without an API change (Kotlin)
    Given a registry where subclaim 6 is registered as DVCMin, with the DVCMin profile, and DVCMin is set to subclaim 6
    When a newborn's DVCMin is issued with ES256, development subclaims not allowed
    Then it verifies with that registry, its one entry a DVCMin under subclaim 6
    When the same is issued with PS256
    Then it fails verification at step KEY_USAGE with reason KEY_USAGE_MISMATCH, its DSC's EKU allowing test certificates only

  @req:stt-sel-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SelectPayloadTest.kt::SelectPayloadTest::STT-SEL-004_an_issued_HCERT_carries_each_payload_under_its_own_subclaim,_in_key_order
  Scenario: An issued HCERT carries each payload under its own subclaim, in key order (Kotlin)
    Given a newborn's DVCMin and a live VHL issued together
    When the -260 claim of its COSE payload is read
    Then its keys are 5 then -6, deterministic CBOR ordering 0x05 before 0x25
    And a certificate with the DVCMin alone has the one key -6

  @req:stt-sel-004 @req:stt-iss-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SelectPayloadTest.kt::SelectPayloadTest::STT-SEL-004_STT-ISS-004_a_certificate_with_a_DVC_and_a_VHL_verifies_with_both_entries
  Scenario: A certificate with a DVC and a VHL verifies with both entries (Kotlin)
    Given a newborn's DVCMin and a live VHL issued together with ES256
    When the COSE_Sign1 is verified
    Then its entries are subclaim 5 then -6, in wire order
    And entry 5 is the VHL and entry -6 the newborn's DVCMin, extensions aside
    And every entry has key usage authorised
    And the only diagnostic is "no certificate type is known for subclaim 5"
    And read-unverified on the HC1 string gives entries 5 then -6, each with its payload

  @req:stt-sel-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SelectPayloadTest.kt::SelectPayloadTest::STT-SEL-004_maxPayloads_refuses_more_entries_than_the_profile_allows
  Scenario: maxPayloads refuses more entries than the profile allows (Kotlin)
    Given a certificate with a newborn's DVCMin and a live VHL
    When it is verified with maxPayloads 1
    Then it fails at step HCERT with reason MULTIPLE_SUBCLAIMS and detail "hcert has 2 entries"
    And verified with maxPayloads 2 it gives 2 entries
    Given a signed claim set whose hcert holds the DVCMin under -6 and an empty map under -7
    When it is verified
    Then its entries are -6 then -7, the second a raw payload whose CBOR is the empty map
    And verified with maxPayloads 1 it fails at step HCERT with reason MULTIPLE_SUBCLAIMS

  @req:stt-sel-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SelectPayloadTest.kt::SelectPayloadTest::STT-SEL-004_an_invalid_entry_is_left_out_and_reported
  Scenario: An invalid entry is left out and reported (Kotlin)
    Given a signed claim set whose hcert holds, under -6, a DVCMin whose nt is "Laos" and, under 5, a live VHL
    When it is verified
    Then its entries are only subclaim 5
    And one diagnostic starts "subclaim -6: ", at step PAYLOAD with severity WARNING
    And read-unverified gives entries 5 with its payload and -6 without one, with a PAYLOAD diagnostic starting "subclaim -6: "
    And a claim set with only the invalid DVCMin fails at step PAYLOAD with reason PAYLOAD_INVALID
    And a claim set with a valid DVCMin and a VHL that expired an hour ago verifies with only entry -6, and a TIME diagnostic starting "subclaim 5: "

  @req:stt-ver-004 @req:stt-sel-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SelectPayloadTest.kt::SelectPayloadTest::STT-VER-004_STT-SEL-004_key_usage_is_checked_per_entry
  Scenario: Key usage is checked per entry (Kotlin)
    Given a newborn's DVCMin and a live VHL issued together with PS256, whose DSC's EKU allows test certificates only
    When the COSE_Sign1 is verified against the PS256 DSC
    Then entry 5 has key usage authorised and entry -6 does not
    And a KEY_USAGE diagnostic says "the DSC's extended key usage does not allow subclaim -6's certificate type"
    And a KEY_USAGE diagnostic says "no certificate type is known for subclaim 5"
    And the DVCMin issued alone with PS256 fails at step KEY_USAGE with reason KEY_USAGE_MISMATCH

  @req:stt-sel-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/SelectPayloadTest.kt::SelectPayloadTest::STT-SEL-004_issuance_refuses_no_payload_and_a_duplicate_subclaim
  Scenario: Issuance refuses no payload and a duplicate subclaim (Kotlin)
    When an issuance request with no payloads is prepared
    Then it fails with NoPayload
    When a request with a DVCMin and a raw payload also under -6 is prepared
    Then it fails with DuplicateSubclaim(-6)
    And a VHL then a DVCMin without the development opt-in fails with DevelopmentSubclaimNotAllowed(-6), the first failure winning
    And a VHL then a DVCMin whose nt is "Laos" fails with PayloadInvalid

  @req:stt-sel-001 @req:stt-sel-002
  @test:tools/conformance-ts/suite.ts::STT-SEL-001_STT-SEL-002_the_registry_starts_with_the_guide's_subclaims,_and_is_configuration
  Scenario: The registry starts with the guide's subclaims, and is configuration (TypeScript, either package)
    Given a new registry
    Then its keys are 1, 3, 4, 5, -6 and -7, and dvc-min maps to -6 and vhl to 5
    When dvc-min is set to subclaim -99 and -99 is registered as "DVCMin moved"
    Then dvc-min maps to -99 and looking up -99 gives "DVCMin moved"

  @req:stt-sel-006
  @test:tools/conformance-ts/suite.ts::STT-SEL-006_trust_domains_come_from_the_GDHCN_code_system
  Scenario: Trust domains come from the GDHCN code system (TypeScript, either package)
    Given a trust store loaded with the GDHCN trust-domain code system
    Then it loaded 4 domains: DDCC, ICVP, IPS-PILGRIMAGE and PH4H
    And a DID document under the trust domain FUTURE throws "unknown-trust-domain"
    And a DID document under DDCC holding the testkit DSC adds 1 key, whose candidate by kid has domain DDCC

  @req:stt-sel-003 @req:stt-cwt-004
  @test:tools/conformance-ts/suite.ts::STT-SEL-003_STT-CWT-004_development_subclaims_need_opting_in;_validity_must_sit_inside_the_DSC
  Scenario: Development subclaims need opting in, and validity must sit inside the DSC (TypeScript, either package)
    Given a newborn's DVCMin issuance request, valid for one day, that does not allow development subclaims
    When it is prepared
    Then it throws "development-subclaim-not-allowed"
    And with the opt-in but an exp 20 years after iat it throws "validity-outside-dsc"
