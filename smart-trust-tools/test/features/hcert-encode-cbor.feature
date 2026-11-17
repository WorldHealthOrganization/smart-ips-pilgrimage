# Test-plan case hcert-encode-cbor (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-encode-cbor
Feature: Serialise as deterministic CBOR, and decode untrusted CBOR within limits
  Step 4 of issuance: the claims are serialised as RFC 8949 deterministic
  CBOR. Untrusted CBOR is decoded within limits, and refused with a typed error.

  @req:stt-cbr-001
  @test:tools/hcert-rust/tests/encode_cbor.rs::stt_cbr_001_maps_are_encoded_in_deterministic_key_order
  Scenario: Maps are encoded in deterministic key order (Rust)
    Given the map {"b": 2, -1: 1, 10: 3}
    And the same map with its entries built in reverse order
    When both are encoded as CBOR
    Then the two encodings are identical
    And the encoding is the hex a30a032001616202, with the keys in the order 10, -1, "b"

  @req:stt-cbr-001
  @test:tools/hcert-rust/tests/encode_cbor.rs::stt_cbr_001_rfc_8949_appendix_a_numbers_re_encode_in_their_shortest_form
  Scenario: RFC 8949 Appendix A numbers re-encode in their shortest form (Rust)
    Given these RFC 8949 Appendix A items, already in preferred serialisation:
      | 1b000000e8d4a51000 | 3b7fffffffffffffff | f90000             | f98000 |
      | f93c00             | fb3ff199999999999a | f93e00             | f97bff |
      | fa47c35000         | fa7f7fffff         | fb7e37e43c8800759c | f90001 |
      | f90400             | fbc010666666666666 | f97c00             | f97e00 |
      | f9fc00             | f4                 | f5                 | f6     |
      | f7                 | f0                 | f8ff               | c11a514b67b0 |
    When each is re-encoded deterministically
    Then each comes back unchanged
    And items sent longer than they need are shortened:
      | input              | re-encoded |
      | fa3f800000         | f93c00     |
      | fb3ff0000000000000 | f93c00     |
      | fb40f86a0000000000 | fa47c35000 |
      | fa7f800000         | f97c00     |
      | fb7ff8000000000000 | f97e00     |
      | 190064             | 1864       |

  @req:stt-cbr-001
  @test:tools/hcert-rust/tests/encode_cbor.rs::stt_cbr_001_indefinite_lengths_re_encode_as_definite
  Scenario: Indefinite lengths re-encode as definite (Rust)
    When these indefinite-length items are re-encoded deterministically
    Then each comes back definite-length, with map keys in deterministic order:
      | input                      | re-encoded             |
      | 5f42010243030405ff         | 450102030405           |
      | 7f657374726561646d696e67ff | 6973747265616d696e67   |
      | 9fff                       | 80                     |
      | 9f018202039f0405ffff       | 8301820203820405       |
      | bf61610161629f0203ffff     | a26161016162820203     |
      | bf6346756ef563416d7421ff   | a263416d74216346756ef5 |

  @req:stt-cbr-002
  @test:tools/hcert-rust/tests/encode_cbor.rs::stt_cbr_002_text_is_nfc_normalised_on_encode
  Scenario: Text is NFC-normalised on encode (Rust)
    Given the text "Hoa" followed by a combining grave accent (U+0300)
    When it is encoded as CBOR and decoded again
    Then the text is "Hoà" with the precomposed U+00E0

  @req:stt-cbr-003
  @test:tools/hcert-rust/tests/encode_cbor.rs::stt_cbr_003_malformed_or_oversized_input_is_refused_with_a_typed_error
  Scenario: Malformed or oversized input is refused with a typed error (Rust)
    When each of these malformed items is re-encoded deterministically with the default limits
      | 5f42010243         |
      | 5f4201026103ff     |
      | 5f5f4101ffff       |
      | 9f01               |
      | bf6161             |
      | ff                 |
      | 1c                 |
      | 5a00000005         |
      | 3bffffffffffffffff |
    Then each is refused with an error
    And 40 nested one-element arrays around a 0 are refused with LimitExceeded
    And a byte string of 0x5000 bytes is refused with LimitExceeded

  @req:stt-cbr-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/EncodeCborTest.kt::EncodeCborTest::STT-CBR-001_maps_are_encoded_in_deterministic_key_order,_whatever_order_they_were_built_in
  Scenario: Maps are encoded in deterministic key order, whatever order they were built in (Kotlin)
    Given the map {"b": 2, -1: 1, 10: 3}
    And the same map with its entries built in reverse order
    When both are encoded as CBOR
    Then the two encodings are identical
    And decoding the encoding gives the keys in the order 10, -1, "b"

  @req:stt-cbr-002
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/EncodeCborTest.kt::EncodeCborTest::STT-CBR-002_text_is_NFC-normalised_on_encode,_and_a_non-normalised_string_still_decodes
  Scenario: Text is NFC-normalised on encode, and a non-normalised string still decodes (Kotlin)
    Given the text "Hoa" followed by a combining grave accent (U+0300)
    When it is encoded as CBOR and decoded again
    Then the text is "Hoà" with the precomposed U+00E0
    And a CBOR text string holding the decomposed UTF-8 bytes, as another encoder may send it, decodes to the decomposed text unchanged

  @req:stt-cbr-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/EncodeCborTest.kt::EncodeCborTest::STT-CBR-003_nesting_beyond_the_limit_is_refused
  Scenario: Nesting beyond the limit is refused (Kotlin)
    Given 40 nested one-element arrays around a 0
    When they are verified as a COSE_Sign1
    Then verification fails with reason LIMIT_EXCEEDED

  @req:stt-cbr-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/EncodeCborTest.kt::EncodeCborTest::STT-CBR-001_RFC_8949_Appendix_A_numbers_re-encode_in_their_shortest_form
  Scenario: RFC 8949 Appendix A numbers re-encode in their shortest form (Kotlin)
    Given these RFC 8949 Appendix A items, already in preferred serialisation:
      | 1b000000e8d4a51000 | 3b7fffffffffffffff | f90000             | f98000 |
      | f93c00             | fb3ff199999999999a | f93e00             | f97bff |
      | fa47c35000         | fa7f7fffff         | fb7e37e43c8800759c | f90001 |
      | f90400             | fbc010666666666666 | f97c00             | f97e00 |
      | f9fc00             | f4                 | f5                 | f6     |
      | f7                 | f0                 | f8ff               | c11a514b67b0 |
    When each is re-encoded deterministically
    Then each comes back unchanged
    And a float or an integer sent longer than it needs is shortened:
      | input              | re-encoded |
      | fa3f800000         | f93c00     |
      | fb3ff0000000000000 | f93c00     |
      | fb40f86a0000000000 | fa47c35000 |
      | fa7f800000         | f97c00     |
      | fb7ff8000000000000 | f97e00     |
      | 190064             | 1864       |

  @req:stt-cbr-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/EncodeCborTest.kt::EncodeCborTest::STT-CBR-001_indefinite_lengths_re-encode_as_definite_(RFC_8949_Appendix_A)
  Scenario: Indefinite lengths re-encode as definite (Kotlin)
    When these indefinite-length items are re-encoded deterministically
    Then each comes back definite-length, with map keys in deterministic order:
      | input                      | re-encoded             |
      | 5f42010243030405ff         | 450102030405           |
      | 7f657374726561646d696e67ff | 6973747265616d696e67   |
      | 9fff                       | 80                     |
      | 9f018202039f0405ffff       | 8301820203820405       |
      | bf61610161629f0203ffff     | a26161016162820203     |
      | bf6346756ef563416d7421ff   | a263416d74216346756ef5 |

  @req:stt-cbr-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/EncodeCborTest.kt::EncodeCborTest::STT-CBR-003_malformed_indefinite-length_items_and_out-of-range_integers_are_refused_with_a_typed_error
  Scenario: Malformed indefinite-length items and out-of-range integers are refused with a typed error (Kotlin)
    When each of these items is re-encoded deterministically with the default limits
      | 5f42010243         |
      | 5f4201026103ff     |
      | 5f5f4101ffff       |
      | 9f01               |
      | bf6161             |
      | ff                 |
      | 1c                 |
      | 5a00000005         |
      | 3bffffffffffffffff |
    Then each gives an Err result

  @req:stt-cbr-001
  @test:tools/conformance-ts/suite.ts::STT-CBR-001_deterministic_re-encoding:_RFC_8949_Appendix_A,_and_the_PR_129_CWT_byte_for_byte
  Scenario: Deterministic re-encoding of Appendix A items, and of the PR 129 CWT byte for byte (TypeScript, either package)
    Given the PR 129 hepb1 HC1 string, decoded and parsed as a COSE_Sign1
    When its payload is re-encoded deterministically
    Then the bytes are identical to the payload
    And fb3ff0000000000000 re-encodes as f93c00
    And bf6346756ef563416d7421ff re-encodes as a263416d74216346756ef5

  @req:stt-cbr-003
  @test:tools/conformance-ts/suite.ts::STT-CBR-003_nesting_beyond_the_limit_is_refused
  Scenario: Nesting beyond the limit is refused (TypeScript, either package)
    Given 40 nested one-element arrays around a 0
    When they are re-encoded deterministically
    Then it throws "limit-exceeded"
