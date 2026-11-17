package who.smart.trust.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import who.smart.trust.types.FailureReason
import who.smart.trust.verifier.VerificationResult

/** Skill `hcert-encode-base45`: QR Code Generation step 7. */
class Base45Test {
    @Test fun `STT-B45-001 the RFC 9285 section 4-3 examples`() {
        assertEquals("BB8", Base45.encode("AB".encodeToByteArray()))
        assertEquals("%69 VD92EX0", Base45.encode("Hello!!".encodeToByteArray()))
        assertEquals("UJCLQE7W581", Base45.encode("base-45".encodeToByteArray()))
        assertEquals("ietf!", Base45.decode("QED8WEX0").decodeToString())
    }

    @Test fun `STT-B45-002 lower case, a dangling character and an out-of-range triple are refused`() {
        fun fail(hc1: String) = assertIs<VerificationResult.Failed>(HcertVerifier.verify(hc1, HcertTrustStore(), SubclaimRegistry(), NOW, OPTIONS)).value.reason
        assertEquals(FailureReason.BASE45_INVALID, fail("HC1:abc"))
        assertEquals(FailureReason.BASE45_INVALID, fail("HC1:A"))
        assertEquals(FailureReason.BASE45_INVALID, fail("HC1::::"))
    }
}
