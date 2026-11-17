# Test-plan case hcert-trust-list (test/plans/hcert-library-conformance.test-plan.json).
# One Scenario per executable test; the @test: tag names the test that runs it.
@case:hcert-trust-list
Feature: Hold the trusted DSCs the host obtained, and find every candidate for a kid
  The host obtains the trust material (PEM, DER, GDHCN DID trustlist v2) and
  the library holds the DSCs, finding every candidate for a kid. A trust list
  DID document's proof is verified against WHO's signing DID before its keys
  are trusted.

  @test:tools/hcert-rust/src/didproof.rs::tests::base64url_is_strict
  Scenario: The proof's base64url is read strictly (Rust)
    When "AQ" is read as base64url
    Then it gives the single byte 1
    And "AR", whose trailing bits are not zero, is refused
    And "AQ==", which is padded, is refused
    And "A", a dangling character, is refused
    And "+/", from the standard alphabet, is refused

  @test:tools/hcert-rust/src/didproof.rs::tests::jcs_sorts_by_utf16_and_escapes
  Scenario: The JWK's JCS sorts members by UTF-16 code unit, and escapes (Rust)
    Given the JWK {"😀":"a","｡":"b","x":["\"\\"]}
    When it is written as JCS
    Then the members come in the order "x", U+1F600, U+FF61, by UTF-16 code unit rather than by code point
    And the quote and backslash in "x" are escaped
    And a JWK holding DEL in a string is refused
    And a JWK holding a newline in an array string is refused
    And a JWK holding a number, an array of objects, or a duplicate member name is refused
    And a JWK that is an array, or no JWK at all, is refused
    And an N-Quads literal escapes backslash, quote, newline and carriage return
    And a JCS string escapes backspace, form feed, tab and carriage return as \b, \f, \t and \r

  @req:stt-tru-005 @req:stt-kid-002
  @test:tools/hcert-rust/tests/trust_list.rs::stt_tru_005_stt_kid_002_pem_loads_once_and_candidates_are_found_by_kid
  Scenario: PEM loads once, and bad material is refused (Rust)
    Given an empty trust store
    When the PR 129 XXA DSC PEM file is added
    Then 2 certificates are added
    And adding the same PEM again adds 0
    And adding the PEM text "nothing" fails with Parse
    And adding the DER bytes 30 03 02 01 01 fails with Parse

  @req:stt-tru-002 @req:stt-sel-006
  @test:tools/hcert-rust/tests/trust_list.rs::stt_tru_002_stt_sel_006_did_documents_load_and_trust_domains_come_from_the_code_system
  Scenario: DID documents load, and trust domains come from the code system (Rust)
    Given an empty trust store with no trust domains loaded
    When a DID trustlist v2 document for domain "FUTURE" holding the testkit ES256 DSC is added
    Then 1 DSC is added, and its candidate's trust domain is "FUTURE"
    When a new store loads the GDHCN Domains code system
    Then 4 domains are loaded: DDCC, ICVP, IPS-PILGRIMAGE and PH4H
    And adding the "FUTURE" document fails with UnknownTrustDomain "FUTURE"
    And adding the same DSC under domain "DDCC" adds 1
    And adding the testkit PS256 DSC under the wildcard domain "-" adds 1
    And loading a ValueSet as the trust domains fails with Parse

  @req:stt-tru-006
  @test:tools/hcert-rust/tests/trust_list.rs::stt_tru_006_canonical_n_quads_equal_the_golden_files
  Scenario: The XXR DSC document's canonical N-Quads equal the golden files (Rust)
    Given the XXR DSC DID document from the merged guide
    When its document and its proof options are canonicalised
    Then the document's N-Quads equal XXR-DSC-did.doc.nq byte for byte
    And the proof options' N-Quads equal XXR-DSC-did.proof-options.nq byte for byte

  @req:stt-tru-006
  @test:tools/hcert-rust/tests/trust_list.rs::stt_tru_006_dev_trust_list_documents_verify_against_who_signing_did
  Scenario Outline: The DEV trust list documents verify against WHO's signing DID (Rust)
    Given WHO's DEV signing DID document
    When the proof of <document> is verified
    Then it verifies

    Examples:
      | document                          |
      | XXR-DSC-did.json (merged guide)   |
      | XXR-DSC-did-2026-10-23.json       |
      | XXR-did.json                      |
      | XXA-did.json                      |
      | root-did.json                     |

  @req:stt-tru-006
  @test:tools/hcert-rust/tests/trust_list.rs::stt_tru_006_a_changed_byte_the_wrong_signer_an_unmodelled_term_or_header_is_proof_invalid
  Scenario: A changed byte, the wrong signer, an unmodelled term or header is proof-invalid (Rust)
    Given the XXR DSC DID document, whose proof verifies against WHO's signing DID
    Then each of these fails with ProofInvalid, its message containing:
      | change                                                              | message             |
      | one byte changed in the x5c certificate                             | does not verify     |
      | a signer with another P-256 key under the same DID                  | does not verify     |
      | that signer under another DID                                       | not the DID         |
      | a signer document with no verification method                       | not exactly one     |
      | an "alsoKnownAs" key on the document                                | alsoKnownAs         |
      | a "service" key on the verification method                          | service             |
      | an "expires" key on the proof                                       | expires             |
      | an "ext" member in the JWK                                          | ext                 |
      | a "display" key beside a domain code                                | display             |
      | the v2.jsonld context in place of v1-DEV.jsonld                     | @context            |
      | a JWS header with b64 true                                          | JWS header          |
      | a JWS header with alg ES384                                         | JWS header          |
      | a JWS header without crit                                           | JWS header          |
      | a JWS header with an extra kid                                      | JWS header          |
      | a JWS with an attached payload                                      | detached            |
      | "[]" as the document                                                | not a JSON object   |

  @req:stt-tru-006
  @test:tools/hcert-rust/tests/trust_list.rs::stt_tru_006_a_64_byte_r_s_signature_also_verifies
  Scenario: A 64-byte r||s signature also verifies (Rust)
    Given the XXR DSC DID document
    When its DER proof signature is re-encoded as 64-byte r||s
    Then the proof verifies against WHO's signing DID
    And with the DER signature's last byte cut off it fails with ProofInvalid

  @req:stt-tru-006
  @test:tools/hcert-rust/tests/trust_list.rs::stt_tru_006_add_verified_did_document_adds_only_verified_documents
  Scenario: Adding a verified DID document adds only verified documents (Rust)
    Given an empty trust store and WHO's DEV signing DID document
    When XXR-did.json with an "ext" member added to a JWK is added as verified
    Then it fails with ProofInvalid and the store stays empty
    When XXR-did.json itself is added as verified
    Then 2 DSCs are added and the store holds 2
    And adding the XXR DSC document as verified adds 0, its DSC already held through XXR

  @req:stt-tru-006
  @test:tools/hcert-rust/tests/trust_list.rs::stt_tru_006_signer_coordinates_and_profile_variants
  Scenario: Signer coordinates, and the profile's variants (Rust)
    Given the XXR DSC DID document and WHO's signing DID document
    Then the proof verifies when the signer's x has a leading 00 byte, as a Java BigInteger writes it
    And with two leading 00 bytes it fails with ProofInvalid mentioning "32 bytes"
    And with the signer's curve P-384 it fails with ProofInvalid mentioning "P-256"
    And a reference document whose verification methods are two equal DID URLs canonicalises to one controller quad and one verificationMethod quad
    And with the UAT tng-context the PH4H domain is read under ValueSet-Domains-UAT.jsonld
    And with the production tng-context the DSC key usage is read under ValueSet-KeyUsage.jsonld
    And a relative id, a domain code that is not a fragment, a key usage of "#", a non-JsonWebKey2020 type, and a numeric kty are each proof-invalid
    And proof options with a control character in the nonce, proofPurpose "authentication", type "Ed25519Signature2020", or a verification method that is not a DID are each refused
    And proof options with a domain "tng" and a challenge "c" canonicalise with a domain and a challenge quad, but the proof no longer verifies
    And the reference document, which has no proof, has its proof options refused
    And a verificationMethod that is an object is proof-invalid

  @req:stt-tru-006
  @test:tools/hcert-rust/tests/trust_list.rs::stt_tru_006_unified_profile_rows_give_the_same_verdict
  Scenario: The unified profile's rows give the same verdict (Rust)
    Given the XXR DSC DID document and WHO's signing DID document
    Then each of these edits fails with ProofInvalid, its message containing:
      | profile row               | edit                                                            | message                    |
      | 1. document keys          | the controller removed                                          | has no controller          |
      | 1. document keys          | the controller an array                                         | controller is not a string |
      | 1. document keys          | a number in verificationMethod                                  | not an object              |
      | 1. document keys          | the proof removed                                               | no proof                   |
      | 2. verification method    | the method's controller removed                                 | has no controller          |
      | 2. verification method    | a "system" key beside the participant code                      | system                     |
      | 2. verification method    | the participant code "XXR", "#XXR#1" or "#X R"                  | not a fragment             |
      | 3. proof keys             | proofValue, signatureValue, expires or creator added            | that key's name            |
      | 3. proof keys             | "type" misspelt "typo"                                          | typo                       |
      | 4. JWK values             | the kid an object, or null                                      | neither a string           |
      | 4. JWK values             | the kid an array holding a number                               | not a string               |
      | 5. IRIs                   | an https: id, a urn: controller, a space, "<" or "é" in an id   | not an absolute IRI        |
      | 5. IRIs                   | an http: proof verification method                              | not an absolute IRI        |
      | 5. IRIs                   | a referenced verification method that is not a DID URL          | reference                  |
      | 6. literals               | DEL in created, U+001F in the nonce, a tab in a domain          | control character          |
      | 6. literals               | DEL in a challenge                                              | control character          |
      | 6. literals               | DEL in the JWK kid, a newline in an x5c                         | control character          |
      | 6. literals               | a lone high or low surrogate in the nonce                       | surrogate                  |
      | 7. code points            | U+1F600 in the nonce or the kid                                 | above U+FFFF               |
      | 8. signer                 | the signer key's alg ES384                                      | ES256                      |
      | 8. signer                 | the signer key's controller another DID                         | another controller         |
      | 8. signer                 | the signer's method given twice                                 | not exactly one            |
      | 9. signatures             | a DER signature whose INTEGERs are padded                       | does not verify            |
      | 11. duplicate members     | a duplicate id                                                  | duplicate key: id          |
      | 11. duplicate members     | a duplicate participant code                                    | duplicate key: code        |
      | 11. duplicate members     | a duplicate nonce                                               | duplicate key: nonce       |
      | 11. duplicate members     | a duplicate kty in the JWK, or in the signer's JWK              | duplicate key: kty         |
      | 11. duplicate members     | a duplicate alg in the JWS header                               | duplicate key: alg         |
    And proof options without a nonce canonicalise to 4 lines
    And a nonce starting "é" and U+FFFF canonicalises with those characters kept
    And the signer key with alg ES256, or with no controller, verifies

  @req:stt-kid-003
  @test:tools/hcert-rust/tests/trust_list.rs::stt_kid_003_a_kid_reads_and_writes_as_hex_standard_and_url_safe_base64
  Scenario: A kid reads and writes as hex, standard and URL-safe base64 (Rust)
    Given the PR 129 example's kid "WHM+BYqqZiE=", which holds a "+"
    Then it writes as standard base64 "WHM+BYqqZiE=" and URL-safe base64 "WHM-BYqqZiE="
    And "WHM-BYqqZiE", unpadded and URL-safe, reads as the same kid
    And its hex is "58733e058aaa6621"
    And the testkit ES256 and PS256 DSCs' kids round-trip through standard and URL-safe base64, and through 16-character hex
    And "WHM BYqqZiE=" is refused as base64, and "5873z" as hex
    And a store holding the testkit ES256 DSC finds 1 candidate for its kid read from either base64 form

  @req:stt-tru-001 @req:stt-kid-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-TRU-001_STT-KID-001_a_DSC_is_found_by_its_kid,_the_first_8_bytes_of_its_SHA-256
  Scenario: A DSC is found by its kid, the first 8 bytes of its SHA-256 (Kotlin)
    Given a trust store holding the testkit ES256 DSC
    When candidates are looked up for the first 8 bytes of the DSC's SHA-256
    Then 1 candidate is found
    And 8 zero bytes find no candidate

  @req:stt-kid-003
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-KID-003_a_kid_reads_and_writes_as_standard_and_URL-safe_base64
  Scenario: A kid reads and writes as standard and URL-safe base64 (Kotlin)
    Given the testkit ES256 DSC's kid
    When it is written in each base64 alphabet, standard and URL-safe, and read back
    Then the same kid comes back

  @req:stt-tru-002
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-TRU-002_a_GDHCN_DID_trustlist_v2_document_loads_its_DSCs
  Scenario: A GDHCN DID trustlist v2 document loads its DSCs (Kotlin)
    Given a DID document "did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXA:DSC" with one embedded JsonWebKey2020 holding the testkit ES256 DSC, and one reference to the XXB document
    When it is added to an empty trust store
    Then 1 DSC is added
    And the DSC's candidate has no trust domain, participant "XXA" and country "XX"

  @req:stt-tru-005
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-TRU-005_a_static_list_of_PEM_certificates_loads
  Scenario: A static list of PEM certificates loads (Kotlin)
    Given an empty trust store
    When the testkit ES256 and PS256 DSC PEMs, concatenated, are added
    Then 2 certificates are added and the store holds 2

  @req:stt-sel-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-SEL-006_trust_domains_are_read_from_the_GDHCN_code_system,_not_a_closed_list
  Scenario: Trust domains are read from the GDHCN code system, not a closed list (Kotlin)
    Given an empty trust store, which has no trust domains
    When a DID document for domain "FUTURE" holding the testkit ES256 DSC is added
    Then 1 DSC is added, kept with domain "FUTURE"
    When the store is cleared and the production GDHCN Domains code system loaded
    Then 4 domains are loaded: DDCC, ICVP, IPS-PILGRIMAGE and PH4H
    And the "DDCC" document adds 1
    And the "FUTURE" document fails with UnknownTrustDomain "FUTURE", and the store still holds 1
    And after clearing, the wildcard "-" document adds 1
    And the code system with a "FUTURE" concept added loads 5 domains, after which a new store adds the "FUTURE" document
    And the UAT and DEV code systems each load 4 domains
    And loading a ValueSet fails with Parse

  @req:stt-tru-001
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-TRU-001_bad_trust_material_is_refused_with_a_typed_error_and_nothing_is_added
  Scenario: Bad trust material is refused with a typed error, and nothing is added (Kotlin)
    Given a trust store with the PR 129 XXA PEM added, 2 certificates: the DSC and its CSCA
    Then adding the PEM again adds 0
    And adding the DSC found by kid "WHM+BYqqZiE=" as DER adds 0
    And adding to a new store each of these fails with Parse:
      | call             | material                                                         |
      | addPem           | no certificate here                                              |
      | addPem           | a CERTIFICATE block whose body is "!!!!"                         |
      | addPem           | a CERTIFICATE block whose body is "AAAA"                         |
      | addDer           | the bytes 30 03 02 01 01                                         |
      | addDidDocument   | "{", "[]", "{}"                                                  |
      | addDidDocument   | a verification method whose x5c holds the number 7               |
      | addDidDocument   | a verification method whose x5c holds "!!"                       |
      | loadTrustDomains | "{", "[]", a CodeSystem with no concept                          |
    And the first store still finds 1 candidate for the DSC's kid

  @req:stt-tru-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-TRU-006_the_XXR_DSC_document's_canonical_N-Quads_equal_the_golden_files_byte_for_byte
  Scenario: The XXR DSC document's canonical N-Quads equal the golden files byte for byte (Kotlin)
    Given the XXR DSC DID document from the merged guide
    When the document without its proof, and the proof without its jws, are canonicalised
    Then they equal XXR-DSC-did.doc.nq and XXR-DSC-did.proof-options.nq byte for byte
    And the SHA-256 of XXR-DSC-did.doc.nq starts "68d4f58e"

  @req:stt-tru-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-TRU-006_the_DEV_trust_list_documents,_the_234-key_root_among_them,_verify_against_WHO's_signing_DID
  Scenario: The DEV trust list documents, the 234-key root among them, verify against WHO's signing DID (Kotlin)
    Given WHO's DEV signing DID document
    When the proofs of the merged guide's XXR-DSC-did.json, XXR-DSC-did-2026-10-23.json, XXR-did.json, XXA-did.json and root-did.json are verified
    Then each verifies
    And root-did.json verifies 5 more times, its time reported

  @req:stt-tru-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-TRU-006_a_changed_byte_in_an_x5c,_the_wrong_signer,_an_unmodelled_term_and_a_wrong_JWS_header_fail_proof-invalid
  Scenario: A changed byte in an x5c, the wrong signer, an unmodelled term and a wrong JWS header fail proof-invalid (Kotlin)
    Given the XXR DSC DID document and WHO's signing DID document
    Then each of these fails with ProofInvalid, its message containing:
      | change                                                         | message          |
      | "MIICmDCCAj+g" in the x5c changed to "MIICmDCCAj+h"            | does not verify  |
      | created written "2026-10-22T12:00:16.000Z", never normalised    | does not verify  |
      | a signer with the testkit's P-256 key under the same id        | does not verify  |
      | an "alsoKnownAs" key on the document                           | does not model   |
      | a "service" key on the verification method                     | does not model   |
      | an "expires" key on the proof                                  | does not model   |
      | a "display" key beside the PH4H domain code                    | does not model   |
      | a JWS header with alg ES384                                    | JWS header       |
      | a JWS header with an extra kid                                 | JWS header       |
      | a JWS header of only alg ES256                                 | JWS header       |
      | a JWS with the payload "e30" attached                          | detached         |

  @req:stt-tru-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-TRU-006_the_trust_store_adds_a_document_whose_proof_verifies,_and_nothing_when_it_does_not
  Scenario: The trust store adds a document whose proof verifies, and nothing when it does not (Kotlin)
    Given WHO's DEV signing DID document
    When each of the five DEV trust list documents is added as verified to a new store
    Then each adds more than 0 DSCs, as many as adding it unverified does, and the store holds that many
    And a store refuses with ProofInvalid the XXR DSC document with a changed x5c byte, and the document against a signer with the testkit's key
    And that store stays empty
    And a document re-signed with the testkit key, whose proof verifies, but with a second method whose x5c is "AAAA", fails with Parse
    And the store still holds 0

  @req:stt-tru-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-TRU-006_a_64-byte_r-s_signature_verifies_as_the_DER_one_does,_and_so_do_00-padded_coordinates
  Scenario: A 64-byte r||s signature verifies as the DER one does, and so do 00-padded coordinates (Kotlin)
    Given the XXR DSC DID document and WHO's signing DID document
    When its DER proof signature is re-encoded as 64-byte r||s
    Then the proof verifies
    And with one bit of byte 5 of r||s flipped it fails with ProofInvalid "does not verify"
    And the document re-signed with the testkit key verifies against a signer holding the testkit key's x and y
    And it verifies too with 33-byte x and y, each led by 00
    And it is proof-invalid against WHO's signing DID

  @req:stt-tru-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-TRU-006_the_signer_document_and_the_signature_are_checked_before_any_key_is_trusted
  Scenario: The signer document and the signature are checked before any key is trusted (Kotlin)
    Given the XXR DSC DID document re-signed with the testkit key
    Then against each of these signer documents it fails with ProofInvalid, its message containing:
      | signer document                                         | message                |
      | the testkit key under "did:web:other"                   | not                    |
      | WHO's id with no verificationMethod                     | verificationMethod     |
      | WHO's id with an empty verificationMethod               | 0 verification methods |
      | type Ed25519VerificationKey2020                         | JsonWebKey2020         |
      | alg ES384 in the JWK                                    | ES256                  |
      | curve P-384                                             | P-256                  |
      | no publicKeyJwk                                         | publicKeyJwk           |
      | no y                                                    | no y                   |
      | a 31-byte x                                             | 31 bytes               |
      | a 33-byte x led by 01                                   | 33 bytes               |
      | x padded with "="                                       | base64url              |
      | x with a non-zero pad bit                               | canonical base64url    |
      | "[]"                                                    | not a JSON object      |
      | {"id":1,"id":2}                                         | twice                  |
    And a signer point off the curve, and one with x all FF bytes, fail with "does not verify"
    And on the original document these proof signatures fail with ProofInvalid:
      | signature                                       | message          |
      | 70 bytes of 0x30                                | neither DER      |
      | 64 bytes of 0x30                                | does not verify  |
      | 64 bytes of 0x31                                | does not verify  |
      | empty                                           | base64url        |
      | a JWS of "!!..AAAA"                             | base64url        |
      | a header of "{"                                 | JWS header       |
      | a header of the bytes FF FE                     | UTF-8            |
      | a 64-byte DER signature with short r and s      | does not verify  |
    And the documents "{", "[]", "{}", {"proof":{}}, a jws of four parts, and the document with a second id are each proof-invalid

  @req:stt-tru-006 @req:stt-gen-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::TrustListTest::STT-TRU-006_STT-GEN-006_the_unified_profile's_document_shapes,_and_what_it_refuses
  Scenario: The unified profile's document shapes, and what it refuses (Kotlin)
    Given a production-context document "did:web:a" whose verificationMethod holds the reference "did:web:b#k" and the same JsonWebKey2020 method twice
    When it is canonicalised
    Then it gives the 7 expected N-Quads, in order, the duplicate quads collapsed
    And with the UAT context the domain is read under ValueSet-Domains-UAT.jsonld
    And JCS orders members by UTF-16 code unit and escapes quote and backslash
    And a JWK value holding a quote is written escaped in its JSON literal
    And each of these edits to the XXR DSC document fails with ProofInvalid from the profile, not "does not verify":
      | profile row             | edit                                                                         |
      | 1. document keys        | no proof; no controller; a controller array; no verificationMethod          |
      | 1. document keys        | a number in verificationMethod; a proof that is a string                     |
      | 2. verification method  | no controller; no publicKeyJwk; a string publicKeyJwk; an Ed25519 type        |
      | 2. verification method  | a domain that is a string, {"code":7}, "PH4H", "#", "#a#b", or {}            |
      | 4. JWK values           | a boolean, null, number, object, or array holding a number                   |
      | 5. IRIs                 | an https: id, a space, "é" or braces in the id                               |
      | 6. literals             | a tab, DEL, lone low surrogate, newline in an array, U+0001 in a member name |
      | 7. code points          | U+1F600 in a JWK string                                                      |
      | 11. duplicate members   | a duplicate kty in the JWK, a duplicate nonce in the proof                   |
    And U+1F600 in the nonce fails with ProofInvalid mentioning "U+FFFF"
    And proof options with domain "d\"x" and challenge "c" canonicalise with an escaped domain quad and a challenge quad
    And proofValue, signatureValue, expires or creator in the proof each fail with "does not model"
    And proof options without created, with an Ed25519Signature2020 type, an authentication purpose, a numeric nonce, a newline in the nonce, or an https: verification method cannot be canonicalised
    And a JWS header with alg twice fails with ProofInvalid mentioning "twice"
    And the JSON reader keeps the last duplicate member unless asked to refuse duplicates, and refuses the escapes "\u+123", "\u12" and "\u-001"

  @req:stt-tru-006 @req:stt-gen-006
  @test:tools/hcert-kotlin/hcert-core/src/jvmTest/kotlin/who/smart/trust/core/TrustListTest.kt::STT-TRU-006_STT-GEN-006_the_signer's_key_controller,_and_DER_signatures,_are_held_to_the_unified_profile
  Scenario: The signer's key controller, and DER signatures, are held to the unified profile (Kotlin)
    Given the XXR DSC DID document and WHO's signing DID document
    Then the proof verifies, the signing key's controller naming the DID itself
    And with the signing key's controller "did:web:other" it fails with ProofInvalid mentioning "controller"
    And a DER signature whose r INTEGER is padded with a 00, which the lenient COSE parser accepts, fails with "neither DER"
    And a DER signature with a long-form length fails with "neither DER"
    And a DER signature whose r is negative fails with "neither DER"
    And the DER signature cut to 7 bytes, missing its last byte, or with a 00 appended each fail with "neither DER"

  @req:stt-tru-006
  @test:tools/conformance-ts/suite.ts::STT-TRU-006_the_DEV_trust_list_documents,_the_234-key_root_among_them,_verify_against_WHO's_signing_DID
  Scenario: The DEV trust list documents, the 234-key root among them, verify against WHO's signing DID (TypeScript, either package)
    Given WHO's DEV signing DID document
    When the proofs of the XXR DSC document and every DEV trust list document are verified
    Then each verifies

  @req:stt-tru-006
  @test:tools/conformance-ts/suite.ts::STT-TRU-006_a_DER_signature_re-encoded_as_64-byte_r||s_verifies_too
  Scenario: A DER signature re-encoded as 64-byte r||s verifies too (TypeScript, either package)
    Given the XXR DSC DID document
    When its DER proof signature is re-encoded as 64-byte r||s with ecdsa-der-to-raw
    Then the proof verifies against WHO's signing DID

  @req:stt-tru-006
  @test:tools/conformance-ts/suite.ts::STT-TRU-006_the_shared_profile_refuses_each_unmodelled_or_altered_shape_with_proof-invalid
  Scenario Outline: The shared profile refuses each unmodelled or altered shape with proof-invalid (TypeScript, either package)
    Given the XXR DSC DID document and WHO's signing DID document
    When <edit>
    Then verifying the proof throws "proof-invalid"

    Examples:
      | edit                                                  |
      | a byte of the x5c is changed                          |
      | an extra top-level key "service" is added             |
      | the controller is an array                            |
      | the controller is removed                             |
      | a proofValue is added beside the jws                  |
      | a boolean member is added to the JWK                  |
      | the controller is an https: URL                       |
      | DEL is put in the nonce                               |
      | a code point above U+FFFF is put in the JWK kid       |
      | the created lexical form changes "Z" to "+00:00"      |
      | an extra key is added to a domain value set           |
      | the JWS header's alg is ES384                         |
      | the controller member name is duplicated              |
      | the signer key's alg is ES384                         |
      | the signer document's id is another DID               |

  @req:stt-tru-006
  @test:tools/conformance-ts/suite.ts::STT-TRU-006_the_trust_store_adds_a_verified_document,_and_nothing_when_the_proof_fails
  Scenario: The trust store adds a verified document, and nothing when the proof fails (TypeScript, either package)
    Given an empty trust store and WHO's DEV signing DID document
    When the XXR DSC document with its nonce changed is added as verified
    Then it throws "proof-invalid" and the store stays empty
    When the XXR DSC document itself is added as verified
    Then 1 DSC is added and the store holds 1

  @req:stt-kid-003
  @test:tools/conformance-ts/suite.ts::STT-KID-003_kid_base64,_standard_and_URL-safe
  Scenario: A kid in base64, standard and URL-safe (TypeScript, either package)
    Given the kid 58733e058aaa6621
    Then its standard base64 is "WHM+BYqqZiE="
    And its URL-safe base64 starts "WHM-BYqqZiE"
    And "WHM-BYqqZiE" reads back as the same kid

  @req:stt-tru-005 @req:stt-kid-002
  @test:tools/conformance-ts/suite.ts::STT-TRU-005_STT-KID-002_PEM_loads_once;_candidates_by_kid
  Scenario: PEM loads once, and candidates are found by kid (TypeScript, either package)
    Given an empty trust store
    When the PR 129 XXA PEM is added
    Then 2 certificates are added
    And adding it again adds 0, the store still holding 2
    And the kid 58733e058aaa6621 finds 1 candidate
    And adding the PEM "nothing" throws "parse"

  @req:stt-tru-001 @req:stt-tru-002
  @test:tools/conformance-ts/suite.ts::STT-TRU-001_STT-TRU-002_a_DID_trustlist_v2_document's_DSCs_are_held_by_the_store_and_found_by_kid
  Scenario: A DID trustlist v2 document's DSCs are held by the store and found by kid (TypeScript, either package)
    Given a DID document "did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXA:DSC" with one embedded key holding the testkit DSC, and one reference to the XXB document
    When it is added to an empty trust store
    Then 1 DSC is added and the store holds 1
    And the testkit DSC's kid finds exactly that DSC
    And 8 zero bytes find no candidate
    And an HC1 string issued with the testkit key verifies against the store

  @req:stt-ver-006
  @test:tools/conformance-ts/suite.ts::STT-VER-006_trust-list_presence_is_the_validity_check;_a_DSC_outside_its_X.509_period_is_reported
  Scenario: Trust-list presence is the validity check; a DSC outside its X.509 period is reported (TypeScript, either package)
    Given an HC1 string issued with the testkit key
    When it is verified against an empty trust store
    Then it fails with reason "kid-not-found"
    When it is verified against a store holding the testkit DSC, 11 years later, with a clock skew of 20 years
    Then it is verified
    And a trust-lookup diagnostic mentions "X.509 validity"
