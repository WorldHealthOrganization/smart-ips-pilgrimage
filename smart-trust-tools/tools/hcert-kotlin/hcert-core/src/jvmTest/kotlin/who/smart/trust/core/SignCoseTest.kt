package who.smart.trust.core

import java.security.Signature
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue
import who.smart.trust.issuer.IssueError
import who.smart.trust.payloads.Payload
import who.smart.trust.types.CoseAlgorithm
import who.smart.trust.types.FailureReason
import who.smart.trust.types.Step
import who.smart.trust.verifier.VerificationResult

/** Skill `hcert-sign-cose`: QR Code Generation step 5. */
class SignCoseTest {
    private val reg = SubclaimRegistry()

    @Test fun `STT-COS-001 STT-COS-003 a tagged COSE_Sign1 with alg and kid in the protected header`() {
        val issued = Testkit.issue(Payload.DvcMin(NEWBORN))
        val tag = assertIs<CborItem.Tag>(cborDecode(issued.cose, DEFAULT_LIMITS))
        assertEquals(18L, tag.tag)
        assertEquals(4, assertIs<CborItem.Array>(tag.item).items.size)
        val s = HcertCose.parseSign1(issued.cose, DEFAULT_LIMITS).ok()
        assertTrue(s.tagged && s.kidInProtected)
        val protected = cborDecode(s.protected, DEFAULT_LIMITS) as CborItem.Map
        assertEquals(CborItem.Int(-7), protected[1L])
        assertEquals(CborItem.Bytes(HcertCose.kidFromDsc(Testkit.esDer)), protected[4L])
    }

    @Test fun `STT-COS-004 STT-ISS-004 what is signed is the Signature1 structure prepare returns`() {
        val pending = HcertIssuer.prepare(Testkit.request(Payload.DvcMin(NEWBORN)), reg).ok()
        val issued = Testkit.issue(Payload.DvcMin(NEWBORN))
        val s = HcertCose.parseSign1(issued.cose, DEFAULT_LIMITS).ok()
        val expected = CborEncoder.encode(CborItem.Array(listOf(CborItem.Text("Signature1"), CborItem.Bytes(s.protected), CborItem.Bytes(byteArrayOf()), CborItem.Bytes(s.payload))))
        assertContentEquals(expected, HcertCose.sigStructure(s.protected, s.payload))
        assertContentEquals(expected, pending.toBeSigned())
    }

    @Test fun `STT-COS-002 STT-GEN-001 both ES256 and PS256 sign and verify`() {
        val dvc = Testkit.issue(Payload.DvcMin(NEWBORN), CoseAlgorithm.ES256)
        assertIs<VerificationResult.Verified>(HcertVerifier.verify(dvc.hc1, Testkit.store(Testkit.esPem), reg, Testkit.now, OPTIONS))
        // the PS256 testkit DSC may sign test certificates only (subclaim 4)
        val body = CborEncoder.encode(CborItem.Map(listOf(CborItem.Text("t") to CborItem.Text("x"))))
        val test = Testkit.issue(Payload.Raw(who.smart.trust.payloads.RawPayload(4, body)), CoseAlgorithm.PS256)
        assertIs<VerificationResult.Verified>(HcertVerifier.verify(test.hc1, Testkit.store(Testkit.psPem), reg, Testkit.now, OPTIONS))
    }

    @Test fun `STT-COS-005 an ES256 signature is a fixed-width 64-byte r and s, whatever the signer returns`() {
        assertEquals(64, HcertCose.parseSign1(Testkit.issue(Payload.DvcMin(NEWBORN)).cose, DEFAULT_LIMITS).ok().signature.size)
        val raw = ByteArray(64) { (it * 7 + 0x80).toByte() }
        assertContentEquals(raw, EcdsaSignature.derToRaw(EcdsaSignature.rawToDer(raw)))
        val small = ByteArray(64).also { it[31] = 1; it[63] = 2 } // leading zeros in r and s
        assertContentEquals(small, EcdsaSignature.derToRaw(EcdsaSignature.rawToDer(small)))
    }

    @Test fun `STT-COS-006 the library holds no private key, and refuses a signature from another key`() {
        val pending = HcertIssuer.prepare(Testkit.request(Payload.DvcMin(NEWBORN)), reg).ok()
        val other = java.security.KeyPairGenerator.getInstance("EC").apply { initialize(256) }.generateKeyPair()
        val sig = Signature.getInstance("SHA256withECDSA").run { initSign(other.private); update(pending.toBeSigned()); sign() }
        assertIs<IssueError.BadSignatureFormat>(HcertIssuer.finish(pending, sig).err())
    }

    @Test fun `STT-VER-003 a protected header with an unsupported alg is refused`() {
        val protected = CborEncoder.encode(CborItem.Map(listOf(CborItem.Int(1) to CborItem.Int(-8))))
        val cose = CborEncoder.encode(CborItem.Array(listOf(CborItem.Bytes(protected), CborItem.Map(emptyList()), CborItem.Bytes(byteArrayOf()), CborItem.Bytes(byteArrayOf()))))
        val f = assertIs<VerificationResult.Failed>(HcertVerifier.verifyCose(cose, HcertTrustStore(), reg, NOW, OPTIONS)).value
        assertEquals(Step.HEADER to FailureReason.UNSUPPORTED_ALGORITHM, f.step to f.reason)
    }
}
