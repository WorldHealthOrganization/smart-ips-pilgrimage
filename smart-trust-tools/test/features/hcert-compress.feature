# Test-plan case hcert-compress (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-compress
Feature: Compress the signed COSE_Sign1 with ZLIB, and inflate it within a limit
  Step 6 of issuance: ZLIB/DEFLATE after signing. On the way back, inflation
  is bounded so that a small input cannot expand without limit.

  @req:stt-zip-001 @req:stt-zip-002
  @test:tools/hcert-rust/tests/compress.rs::stt_zip_001_stt_zip_002_zlib_round_trips_and_inflation_is_bounded
  Scenario: ZLIB round-trips, and inflation is bounded and strict (Rust)
    Given 10000 bytes, each 7
    When they are compressed with ZLIB at level 9
    Then the stream is shorter than 100 bytes
    And inflating it with a limit of 10000 bytes gives back the 10000 bytes
    And inflating it with a limit of 9999 bytes fails with LimitExceeded
    And inflating it with one trailing byte appended fails with InflateFailed
    And inflating it with its last 3 bytes cut off fails with InflateFailed

  @req:stt-zip-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/CompressTest.kt::CompressTest::STT-ZIP-001_what_is_compressed_is_the_signed_COSE_Sign1,_as_a_ZLIB_stream
  Scenario: What is compressed is the signed COSE_Sign1, as a ZLIB stream (Kotlin)
    Given a newborn's DVCMin issued by the testkit
    When the HC1 string's "HC1:" prefix is removed and the rest Base45-decoded
    Then the first byte is 0x78, a ZLIB header (RFC 1950)
    And inflating it gives exactly the issued COSE_Sign1 bytes

  @req:stt-zip-002
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/CompressTest.kt::CompressTest::STT-ZIP-002_a_decompression_bomb_stops_at_the_limit
  Scenario: A decompression bomb stops at the limit (Kotlin)
    Given an HC1 string made from 1000000 zero bytes
    When it is decoded
    Then it fails at step INFLATE with reason LIMIT_EXCEEDED
    And an HC1 string whose Base45 decodes to the bytes 1, 2, 3 fails with reason INFLATE_FAILED

  @req:stt-zip-001 @req:stt-zip-002
  @test:tools/conformance-ts/suite.ts::STT-ZIP-001_STT-ZIP-002_ZLIB_round-trips,_and_inflation_stops_at_the_limit
  Scenario: ZLIB round-trips, and inflation stops at the limit (TypeScript, either package)
    Given 10000 bytes, each 7, compressed with ZLIB at level 9
    When the stream is inflated with a limit of 10000 bytes
    Then 10000 bytes come back
    And inflating it with a limit of 9999 bytes throws "limit-exceeded"
