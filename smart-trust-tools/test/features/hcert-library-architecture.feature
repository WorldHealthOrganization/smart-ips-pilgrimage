# Test-plan case hcert-library-architecture (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-library-architecture
Feature: The rules every implementation follows
  Kotlin first, Rust second, one contract, a synchronous core with no I/O,
  open standards, no payload in logs.

  # --- Every step is its own call ------------------------------------------------

  @req:stt-gen-002
  @test:tools/hcert-rust/tests/api.rs::stt_gen_002_every_step_is_its_own_call_and_they_compose_to_a_verifiable_hc1
  Scenario: Every step is its own call through the JSON surface, and they compose to a verifiable HC1 (Rust)
    Given a newborn's DVCMin ("Test CHILD") as JSON
    When "assemblePayload" is called with it
    Then it reports no issues
    And "buildCwt" with that payload, iss "XX", a one-day validity from the testkit clock and subclaim -6 gives a CWT whose diagnostic contains "-260: {"
    And "cborDeterministic" on that CWT gives back the same CWT
    And "prepare" with the same DVC, iss, validity, ES256 and the ES256 testkit DSC builds the same CWT as the separate steps
    And "finish" with the testkit key's signature over its toBeSigned gives a COSE_Sign1 and an HC1 string
    And "compress", "base45Encode" and "prefix" in turn on that COSE_Sign1 give the same HC1 string
    And "decodeLayers" on the HC1 string gives back the same COSE_Sign1
    And "verify" with the testkit DSC's PEM at the testkit clock gives status "verified", with one entry under subclaim -6, key-usage authorised, whose payload's n is "Test CHILD"
    And "verify" two days later fails at step "TIME" with reason "EXPIRED"

  @req:stt-gen-002
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ArchitectureTest.kt::ArchitectureTest::STT-GEN-002_every_step_is_callable_on_its_own,_and_the_steps_compose_to_the_pipeline
  Scenario: Every step is callable on its own, and the steps compose to the pipeline (Kotlin)
    Given a newborn's DVCMin issued by the testkit
    When its COSE_Sign1 is compressed with ZLIB at level 9, Base45-encoded and prefixed with "HC1:"
    Then the text is the issued HC1 string
    And detecting the context, Base45-decoding the rest and inflating it with a limit of 65536 bytes gives back the issued COSE_Sign1
    And that COSE_Sign1 parses, and its signature verifies against the testkit's ES256 DSC
    And re-encoding its payload deterministically gives back the same bytes

  @req:stt-gen-002
  @test:tools/conformance-ts/suite.ts::STT-GEN-002_every_step_is_callable_on_its_own,_and_the_steps_compose_to_the_issued_HC1
  Scenario: Every step is callable on its own, and the steps compose to the issued HC1 (TypeScript, either package)
    Given a newborn's DVCMin issued with iss "XX" and the ES256 testkit DSC
    When its COSE_Sign1 is compressed with ZLIB at level 9, Base45-encoded and prefixed with "HC1:"
    And the context is detected, the rest Base45-decoded and inflated with a limit of 65536 bytes
    Then the bytes are the issued COSE_Sign1
    And the composed HC1 text verifies against a store holding the testkit DSC

  # --- The JSON surface the WebAssembly demo calls ---------------------------------

  @req:stt-tst-011 @req:stt-tru-001
  @test:tools/hcert-rust/tests/api.rs::stt_tst_011_stt_tru_001_the_xxr_certificates_verify_through_the_json_surface_against_a_did_document
  Scenario: The XXR certificates verify through the JSON surface against a DID document (Rust)
    Given the XXR vector's "hepb1" HC1 string and XXR's DSC DID document
    When "verify" is called with the HC1 string, the DID document as trustDid, and a clock one hour after its iat
    Then the status is "verified", the iss "XR" and the kid 916ffa567c0f44a2

  @req:stt-tru-006
  @test:tools/hcert-rust/tests/api.rs::stt_tru_006_verify_trusts_a_did_document_only_once_its_proof_verifies_against_the_signer
  Scenario: Verify trusts a DID document only once its proof verifies against the signer (Rust)
    Given the XXR vector's "hepb1" HC1 string, a clock one hour after its iat, and WHO's signing DID as trustDidSigner
    When "verify" is called with XXR's DSC DID document, and again with the 2026-10-23 DEV trust list copy of it, each as trustDid
    Then each gives status "verified", kid 916ffa567c0f44a2 and trustDidProofVerified true
    And without a trustDidSigner the call verifies with trustDidProofVerified false
    And with one member added to the DID document the call fails with an error starting "DID document proof invalid", and no status
    And with XXR's own trust-list document as the signer the call fails
    And a trustDidSigner without a trustDid fails with the error "trustDidSigner needs trustDid"

  @req:stt-tst-001
  @test:tools/hcert-rust/tests/api.rs::stt_tst_001_the_pr129_vector_verifies_through_the_json_surface
  Scenario: The PR 129 vector verifies through the JSON surface (Rust)
    Given the PR 129 "bcg" HC1 string and the PR 129 DSC's PEM
    When "verify" is called with them at 1792454400
    Then the status is "verified" and the kid 58733e058aaa6621
    And "verify" of "HC1:abc" fails with reason "BASE45_INVALID"
    And an unknown op "nope" gives ok false

  @req:stt-qr-001
  @test:tools/hcert-rust/tests/api.rs::stt_qr_001_the_pr129_hc1_string_renders_as_the_version_16_q_symbol_the_page_states
  Scenario: The PR 129 HC1 string renders as the version 16 Q symbol the page states (Rust)
    # Runs only when the crate is built with the "qr" feature.
    Given the PR 129 "hepb1" HC1 string
    When "qrSvg" is called with it
    Then the symbol is version 16, of 81 modules
    And the SVG starts with "<?xml" or "<svg"

  # --- The core's sources ------------------------------------------------------------

  @req:stt-gen-012 @req:stt-vhl-010 @req:stt-ver-009
  @test:tools/hcert-rust/tests/architecture.rs::stt_gen_012_stt_vhl_010_stt_ver_009_the_core_does_no_network_file_clock_or_asynchronous_io
  Scenario: The core does no network, file, clock or asynchronous I/O (Rust)
    Given the library's sources, tools/hcert-rust/src/*.rs, more than 10 files
    When their code outside comments is searched
    Then no line uses std::net, std::fs, std::io::, std::env, std::process, SystemTime, Instant::, async fn, .await, tokio, reqwest or hyper

  @req:stt-gen-012 @req:stt-vhl-010 @req:stt-ver-009
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ArchitectureTest.kt::ArchitectureTest::STT-GEN-012_STT-VHL-010_STT-VER-009_the_core_does_no_network,_file_or_asynchronous_I-O
  Scenario: The core does no network, file or asynchronous I/O (Kotlin)
    Given the core's commonMain, jvmMain and jsMain sources
    When they are searched
    Then no line names java.net, java.nio.file, java.io.File, node:fs, node:http, node:net, fetch(, suspend fun, kotlinx.coroutines or System.getenv

  @req:stt-sec-001
  @test:tools/hcert-rust/tests/architecture.rs::stt_sec_001_the_core_writes_nothing_to_a_log_or_console
  Scenario: The core writes nothing to a log or console (Rust)
    Given the library's sources, tools/hcert-rust/src/*.rs
    When their code outside comments is searched
    Then no line uses println!, eprintln!, print!(, eprint!(, dbg!, log::, tracing::, console_log or web_sys::console

  @req:stt-sec-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ArchitectureTest.kt::ArchitectureTest::STT-SEC-001_the_core_writes_nothing_to_a_log_or_console
  Scenario: The core writes nothing to a log or console (Kotlin)
    Given the core's commonMain, jvmMain and jsMain sources
    When they are searched
    Then no line names println(, print(, console., Logger, System.err or System.out

  @req:stt-sec-002
  @test:tools/hcert-rust/tests/architecture.rs::stt_sec_002_cryptography_comes_from_rustcrypto_with_no_primitive_of_our_own
  Scenario: Cryptography comes from RustCrypto, with no primitive of our own (Rust)
    Given the [dependencies] of tools/hcert-rust/Cargo.toml
    Then each is one of p256, rsa, sha2 and aes-gcm, or one of x509-cert, getrandom, miniz_oxide, unicode-normalization, qrcode and wit-bindgen
    And p256, rsa, sha2 and aes-gcm are all among them
    And no source line outside comments holds a SHA-256 round constant, an AES S-box, or a fn aes, gcm, ghash, mod_pow, modpow, point_add or scalar_mul, or a struct BigUint

  @req:stt-sec-002 @req:stt-gen-004
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ArchitectureTest.kt::ArchitectureTest::STT-SEC-002_STT-GEN-004_cryptography_comes_from_the_platform,_with_no_third-party_runtime_dependency
  Scenario: Cryptography comes from the platform, with no third-party runtime dependency (Kotlin)
    Given hcert-core's build.gradle.kts
    Then its commonMain dependencies are exactly api(project(":hcert-api"))
    And the only JavaScript modules the core's sources import are node:crypto, node:zlib and node:buffer

  @req:stt-iss-003
  @test:tools/hcert-rust/tests/architecture.rs::stt_iss_003_no_private_key_and_no_test_key_is_in_the_librarys_sources
  Scenario: No private key, and no test key, is in the library's sources (Rust)
    Given the library's sources, tools/hcert-rust/src/*.rs
    When their code outside comments is searched
    Then no line holds "PRIVATE KEY", "vectors/testkit", include_bytes! or include_str!

  @req:stt-iss-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/ArchitectureTest.kt::ArchitectureTest::STT-ISS-003_no_private_key,_and_no_test_key,_is_in_the_library's_sources
  Scenario: No private key, and no test key, is in the library's sources (Kotlin)
    Given the core's commonMain, jvmMain and jsMain sources
    When they are searched
    Then no line holds "PRIVATE KEY" or "vectors/testkit"

  @req:stt-iss-003
  @test:tools/hcert-rust/tests/build_cwt_sign_cose.rs::stt_iss_003_a_test_dsc_around_a_host_key_issues_and_verifies
  Scenario: A test DSC around a host key issues and verifies (Rust)
    Given a P-256 key the host holds
    And a test DSC built around its public key: ES256, country "XX", common name "TEST ONLY demo DSC", valid from a minute before the clock for a year, serial 42, extended key usage "vaccinations", its TBSCertificate signed by the same key
    When a newborn's DVCMin is prepared with that DSC, valid for one day from the clock, and finished with the host key's signature over the bytes to be signed
    Then the HC1 string verifies against a store holding that DSC
    And the DSC's country is "XX" and its extended key usages are exactly 1.3.6.1.4.1.1847.2021.1.2
