package who.smart.trust.core

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertIs
import who.smart.trust.payloads.Payload
import who.smart.trust.types.FailureReason
import who.smart.trust.types.Step
import who.smart.trust.verifier.VerificationResult

/** Skill `hcert-compress`: QR Code Generation step 6. */
class CompressTest {
    private fun fail(hc1: String) = assertIs<VerificationResult.Failed>(HcertVerifier.verify(hc1, HcertTrustStore(), SubclaimRegistry(), NOW, OPTIONS)).value

    @Test fun `STT-ZIP-001 what is compressed is the signed COSE_Sign1, as a ZLIB stream`() {
        val issued = Testkit.issue(Payload.DvcMin(NEWBORN))
        val zlib = Base45.decode(issued.hc1.removePrefix("HC1:"))
        assertEquals(0x78, zlib[0].toInt() and 0xff) // ZLIB header, RFC 1950
        assertContentEquals(issued.cose, Platform.inflate(zlib, 65536))
    }

    @Test fun `STT-ZIP-002 a decompression bomb stops at the limit`() {
        val f = fail(HcertCodec.toHc1(ByteArray(1_000_000)))
        assertEquals(Step.INFLATE to FailureReason.LIMIT_EXCEEDED, f.step to f.reason)
        assertEquals(FailureReason.INFLATE_FAILED, fail("HC1:" + Base45.encode(byteArrayOf(1, 2, 3))).reason)
    }
}
