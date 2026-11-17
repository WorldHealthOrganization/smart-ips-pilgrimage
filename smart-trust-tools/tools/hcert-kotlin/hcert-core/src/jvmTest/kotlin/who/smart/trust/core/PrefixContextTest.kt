package who.smart.trust.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue
import who.smart.trust.payloads.Payload
import who.smart.trust.types.FailureReason
import who.smart.trust.verifier.VerificationResult

/** Skill `hcert-prefix-context`: QR Code Generation steps 8 and 9. */
class PrefixContextTest {
    private fun fail(hc1: String) = assertIs<VerificationResult.Failed>(HcertVerifier.verify(hc1, HcertTrustStore(), SubclaimRegistry(), NOW, OPTIONS)).value.reason

    @Test fun `STT-HC1-001 HC1 is the only context, version 1 the only version`() {
        assertEquals(FailureReason.BAD_PREFIX, fail("NCFOXN"))
        assertEquals(FailureReason.UNSUPPORTED_CONTEXT_VERSION, fail("HC2:NCFOXN"))
        assertEquals("1" to "NCFOXN", HcertCodec.detectContext("HC1:NCFOXN").ok()) // version, then the rest
    }

    @Test fun `STT-QR-001 the output is a QR-ready string in the Alphanumeric alphabet`() {
        val hc1 = Testkit.issue(Payload.DvcMin(NEWBORN)).hc1
        assertTrue(hc1.startsWith("HC1:"))
        assertTrue(hc1.all { it in Base45.ALPHABET || it == ':' }, "QR Alphanumeric only")
    }

    @Test fun `STT-GEN-009 the COSE bytes travel without the QR layers too`() {
        val issued = Testkit.issue(Payload.DvcMin(NEWBORN))
        val v = HcertVerifier.verifyCose(issued.cose, Testkit.store(Testkit.esPem), SubclaimRegistry(), Testkit.now, OPTIONS)
        assertIs<VerificationResult.Verified>(v)
    }
}
