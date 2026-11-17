package who.smart.trust.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue
import who.smart.trust.HcertResult
import who.smart.trust.payloads.Payload
import who.smart.trust.payloads.RawPayload
import who.smart.trust.types.CoseAlgorithm
import who.smart.trust.types.FailureReason
import who.smart.trust.types.Step
import who.smart.trust.verifier.VerificationResult

/** Skill `hcert-verify`: QR Code Generation section 11, the steps upwards. */
class VerifyTest {
    private val reg = SubclaimRegistry()
    private val store = Testkit.store(Testkit.esPem)

    @Test fun `STT-VER-001 STT-VER-002 a tampered payload fails at the signature, before any payload is read`() {
        val cose = signClaims(cwt()).let { cborDecode(it, DEFAULT_LIMITS) as CborItem.Tag }
        val items = (cose.item as CborItem.Array).items.toMutableList()
        val payload = (items[2] as CborItem.Bytes).value.copyOf().also { it[it.size - 1] = (it[it.size - 1].toInt() xor 1).toByte() }
        items[2] = CborItem.Bytes(payload)
        val tampered = CborEncoder.encode(CborItem.Tag(18, CborItem.Array(items)))
        val f = assertIs<VerificationResult.Failed>(HcertVerifier.verifyCose(tampered, store, reg, Testkit.now, OPTIONS)).value
        assertEquals(Step.SIGNATURE to FailureReason.SIGNATURE_INVALID, f.step to f.reason) // a failure carries no payload
    }

    @Test fun `STT-VER-004 a DSC whose key usage allows test certificates only cannot sign a vaccination`() {
        val issued = Testkit.issue(Payload.DvcMin(NEWBORN), CoseAlgorithm.PS256)
        val f = assertIs<VerificationResult.Failed>(HcertVerifier.verify(issued.hc1, Testkit.store(Testkit.psPem), reg, Testkit.now, OPTIONS)).value
        assertEquals(Step.KEY_USAGE to FailureReason.KEY_USAGE_MISMATCH, f.step to f.reason)
    }

    @Test fun `STT-VER-004 a DCC is a test, vaccination or recovery certificate by its own entry`() {
        fun dcc(entry: String) = CborEncoder.encode(CborItem.Map(listOf(CborItem.Text(entry) to CborItem.Array(listOf(CborItem.Map(emptyList()))))))
        val psStore = Testkit.store(Testkit.psPem)
        val test = Testkit.issue(Payload.Raw(RawPayload(1, dcc("t"))), CoseAlgorithm.PS256)
        assertIs<VerificationResult.Verified>(HcertVerifier.verify(test.hc1, psStore, reg, Testkit.now, OPTIONS))
        val vacc = Testkit.issue(Payload.Raw(RawPayload(1, dcc("v"))), CoseAlgorithm.PS256)
        assertEquals(FailureReason.KEY_USAGE_MISMATCH, assertIs<VerificationResult.Failed>(HcertVerifier.verify(vacc.hc1, psStore, reg, Testkit.now, OPTIONS)).value.reason)
    }

    @Test fun `STT-VER-005 time is the clock the caller passes, with the skew it allows`() {
        val hc1 = Testkit.issue(Payload.DvcMin(NEWBORN)).hc1
        val exp = Testkit.now + 86400
        assertIs<VerificationResult.Verified>(HcertVerifier.verify(hc1, store, reg, exp + 299, OPTIONS))
        assertEquals(FailureReason.EXPIRED, assertIs<VerificationResult.Failed>(HcertVerifier.verify(hc1, store, reg, exp + 301, OPTIONS)).value.reason)
        assertEquals(FailureReason.NOT_YET_VALID, assertIs<VerificationResult.Failed>(HcertVerifier.verify(hc1, store, reg, Testkit.now - 301, OPTIONS)).value.reason)
    }

    @Test fun `STT-VER-006 STT-KID-002 a kid nobody trusts fails the trust lookup`() {
        val hc1 = Testkit.issue(Payload.DvcMin(NEWBORN)).hc1
        val f = assertIs<VerificationResult.Failed>(HcertVerifier.verify(hc1, HcertTrustStore(), reg, Testkit.now, OPTIONS)).value
        assertEquals(Step.TRUST_LOOKUP to FailureReason.KID_NOT_FOUND, f.step to f.reason)
    }

    @Test fun `STT-VER-007 the payload is dispatched to its logical model by subclaim`() {
        val v = assertIs<VerificationResult.Verified>(HcertVerifier.verify(Testkit.issue(Payload.DvcMin(NEWBORN)).hc1, store, reg, Testkit.now, OPTIONS)).value
        assertEquals(-6, v.entries.single().subclaim)
        assertIs<Payload.DvcMin>(v.entries.single().payload)
    }

    @Test fun `STT-VER-008 STT-VER-009 every failure is a value naming its step and reason, offline`() {
        val failures = listOf("NCFOXN", "HC2:NCFOXN", "HC1:abc", "HC1:" + "0".repeat(9000)).map {
            assertIs<VerificationResult.Failed>(HcertVerifier.verify(it, store, reg, Testkit.now, OPTIONS)).value
        }
        assertEquals(listOf(FailureReason.BAD_PREFIX, FailureReason.UNSUPPORTED_CONTEXT_VERSION, FailureReason.BASE45_INVALID, FailureReason.LIMIT_EXCEEDED), failures.map { it.reason })
        assertTrue(failures.all { it.detail.isNotEmpty() })
    }

    @Test fun `STT-VER-011 an unverified read for triage is marked so`() {
        val hc1 = Testkit.issue(Payload.DvcMin(NEWBORN)).hc1
        val u = HcertVerifier.readUnverified(hc1, reg, DEFAULT_LIMITS).ok()
        assertEquals(-6, u.entries.single().subclaim)
        assertEquals("XM9V38", (u.entries.single().payload as Payload.DvcMin).value.vx.vp)
        assertTrue(u.diagnostics.first().message.startsWith("NOT VERIFIED"))
        assertEquals(FailureReason.BASE45_INVALID, (HcertVerifier.readUnverified("HC1:abc", reg, DEFAULT_LIMITS) as HcertResult.Err).error.reason)
    }

    @Test fun `STT-SEC-001 a failure's message does not carry the payload`() {
        val hc1 = Testkit.issue(Payload.DvcMin(NEWBORN)).hc1
        val f = assertIs<VerificationResult.Failed>(HcertVerifier.verify(hc1, HcertTrustStore(), reg, Testkit.now, OPTIONS)).value
        assertTrue(listOf("Test CHILD", "Test MOTHER", "XM9V38").none { it in f.detail || f.diagnostics.any { d -> it in d.message } }, f.detail)
    }
}
