package who.smart.trust.core

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertIs
import who.smart.trust.types.FailureReason
import who.smart.trust.verifier.VerificationResult

/** Skill `hcert-encode-cbor`: QR Code Generation step 4. */
class EncodeCborTest {
    @Test fun `STT-CBR-001 maps are encoded in deterministic key order, whatever order they were built in`() {
        val a = CborItem.Map(listOf(CborItem.Text("b") to CborItem.Int(2), CborItem.Int(-1) to CborItem.Int(1), CborItem.Int(10) to CborItem.Int(3)))
        val b = CborItem.Map(a.entries.reversed())
        assertContentEquals(CborEncoder.encode(a), CborEncoder.encode(b))
        // RFC 8949 4.2.1: shorter encoded keys first, then bytewise: 10, -1, "b"
        assertEquals(listOf(CborItem.Int(10), CborItem.Int(-1), CborItem.Text("b")), (cborDecode(CborEncoder.encode(a), DEFAULT_LIMITS) as CborItem.Map).entries.map { it.first })
    }

    @Test fun `STT-CBR-002 text is NFC-normalised on encode, and a non-normalised string still decodes`() {
        val decomposed = "Hoà" // a + combining grave
        val encoded = CborEncoder.encode(CborItem.Text(decomposed))
        assertEquals(CborItem.Text("Hoà"), cborDecode(encoded, DEFAULT_LIMITS))
        val utf8 = decomposed.encodeToByteArray()
        val raw = byteArrayOf((0x60 + utf8.size).toByte()) + utf8 // as another encoder may send it
        assertEquals(CborItem.Text(decomposed), cborDecode(raw, DEFAULT_LIMITS))
    }

    @Test fun `STT-CBR-003 nesting beyond the limit is refused`() {
        val nested = ByteArray(40) { 0x81.toByte() } + byteArrayOf(0)
        val f = assertIs<VerificationResult.Failed>(HcertVerifier.verifyCose(nested, HcertTrustStore(), SubclaimRegistry(), NOW, OPTIONS)).value
        assertEquals(FailureReason.LIMIT_EXCEEDED, f.reason)
    }

    private fun hex(s: String) = s.chunked(2).map { it.toInt(16).toByte() }.toByteArray()
    private fun deterministic(s: String) = HcertCodec.cborDeterministic(hex(s), DEFAULT_LIMITS).ok().toHex()

    @Test fun `STT-CBR-001 RFC 8949 Appendix A numbers re-encode in their shortest form`() {
        // Already preferred: unchanged.
        for (v in listOf("1b000000e8d4a51000", "3b7fffffffffffffff", "f90000", "f98000", "f93c00", "fb3ff199999999999a", "f93e00",
                "f97bff", "fa47c35000", "fa7f7fffff", "fb7e37e43c8800759c", "f90001", "f90400", "fbc010666666666666",
                "f97c00", "f97e00", "f9fc00", "f4", "f5", "f6", "f7", "f0", "f8ff", "c11a514b67b0"))
            assertEquals(v, deterministic(v), v)
        // A float sent longer than it needs is shortened (RFC 8949 4.2.1, preferred serialization).
        assertEquals("f93c00", deterministic("fa3f800000"))
        assertEquals("f93c00", deterministic("fb3ff0000000000000"))
        assertEquals("fa47c35000", deterministic("fb40f86a0000000000"))
        assertEquals("f97c00", deterministic("fa7f800000"))
        assertEquals("f97e00", deterministic("fb7ff8000000000000"))
        // An integer sent longer than it needs is shortened.
        assertEquals("1864", deterministic("190064"))
    }

    @Test fun `STT-CBR-001 indefinite lengths re-encode as definite (RFC 8949 Appendix A)`() {
        assertEquals("450102030405", deterministic("5f42010243030405ff"))
        assertEquals("6973747265616d696e67", deterministic("7f657374726561646d696e67ff"))
        assertEquals("80", deterministic("9fff"))
        assertEquals("8301820203820405", deterministic("9f018202039f0405ffff"))
        assertEquals("a26161016162820203", deterministic("bf61610161629f0203ffff"))
        // {"Fun": true, "Amt": -2}: definite, and the keys in deterministic order.
        assertEquals("a263416d74216346756ef5", deterministic("bf6346756ef563416d7421ff"))
    }

    /** -2^64 (RFC 8949 Appendix A) is refused too: integers are held as 64-bit signed values. */
    @Test fun `STT-CBR-003 malformed indefinite-length items and out-of-range integers are refused with a typed error`() {
        for (bad in listOf("5f42010243", "5f4201026103ff", "5f5f4101ffff", "9f01", "bf6161", "ff", "1c", "5a00000005", "3bffffffffffffffff"))
            assertIs<who.smart.trust.HcertResult.Err<*>>(HcertCodec.cborDeterministic(hex(bad), DEFAULT_LIMITS), bad)
    }
}
