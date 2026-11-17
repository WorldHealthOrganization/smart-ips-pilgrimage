---
doc_id: who-smart-trust-qr-code-generation
doc_title: "QR Code Generation"
section_id: s012-11-verifying-the-same-steps-upwards
section_title: "11. Verifying: the same steps upwards"
file: "input/pagecontent/qr_code_generation.md"
lines: 175-198
source_sha256: 03253100cd38b5c6
granularity: heading
---
#### 11. Verifying: the same steps upwards

1. Confirm the `HC1:` prefix and strip it.
2. Base45-decode, then ZLIB-decompress.
3. Parse the COSE_Sign1 and read `alg` and `kid` from the protected header.
4. **Validate the input before trusting it.** Parsing the protected header
   necessarily happens before signature verification, which makes it an attack
   surface; check types and lengths defensively. See
   [section 6.3](hcert_spec.html#63-input-data-validation).
5. Look the `kid` up on the trust list, retrieving every DSC that matches.
6. Rebuild the `Sig_structure` and verify the signature against each candidate
   DSC until one succeeds. **Verify the signature before processing the
   payload.**
7. Decode the CBOR payload and check `exp` and `iat` against the current time.
8. Read the `hcert` claim, dispatch on the subclaim to the right logical model,
   and only then apply business rules.

The Extended Key Usage identifiers in
[Appendix A.2](hcert_spec.html#a2-extended-key-usage-identifiers) are inherited
from the EU DCC and cover test, vaccination and recovery. They have not been
applied to the payload types introduced since, and there is no mapping from the
newer subclaims to a key usage, so a verifier has nothing to check them against
for a DVC.
