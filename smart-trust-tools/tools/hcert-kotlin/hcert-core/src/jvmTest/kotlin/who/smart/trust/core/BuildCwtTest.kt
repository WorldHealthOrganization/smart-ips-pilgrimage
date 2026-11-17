package who.smart.trust.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import who.smart.trust.issuer.IssueError
import who.smart.trust.issuer.Validity
import who.smart.trust.payloads.Payload
import who.smart.trust.types.FailureReason
import who.smart.trust.types.Step
import who.smart.trust.verifier.VerificationResult

/** Skill `hcert-build-cwt`: QR Code Generation step 3. */
class BuildCwtTest {
    private val reg = SubclaimRegistry()
    private val store = Testkit.store(Testkit.esPem)
    private fun verify(cose: ByteArray) = HcertVerifier.verifyCose(cose, store, reg, Testkit.now, OPTIONS)

    @Test fun `STT-CWT-001 STT-CWT-002 claim keys are integers and dates are integer NumericDates`() {
        val claims = claimsOf(Testkit.issue(Payload.DvcMin(NEWBORN)).cose)
        assertEquals(setOf(1L, 4L, 6L, -260L), claims.entries.map { assertIs<CborItem.Int>(it.first).value }.toSet())
        assertIs<CborItem.Int>(claims[4L])
        assertIs<CborItem.Int>(claims[6L])
    }

    @Test fun `STT-CWT-003 an HCERT without exp is refused on issue and on verify`() {
        val req = Testkit.request(Payload.DvcMin(NEWBORN)).copy(validity = Validity(Testkit.now, Testkit.now))
        assertEquals(listOf("exp-not-after-iat"), assertIs<IssueError.PayloadInvalid>(HcertIssuer.prepare(req, reg).err()).value.map { it.code })
        val f = assertIs<VerificationResult.Failed>(verify(signClaims(cwt(exp = null)))).value
        assertEquals(Step.CWT to FailureReason.COSE_MALFORMED, f.step to f.reason)
    }

    @Test fun `STT-CWT-004 the validity must fit inside the DSC's`() {
        val req = Testkit.request(Payload.DvcMin(NEWBORN)).copy(validity = Validity(Testkit.now, Testkit.now + 20L * 365 * 86400))
        assertEquals(IssueError.ValidityOutsideDsc, HcertIssuer.prepare(req, reg).err())
    }

    @Test fun `STT-CWT-005 iss is optional, and alpha-2 when present`() {
        for (bad in listOf("Xx", "XXX", "x")) {
            val e = assertIs<IssueError.PayloadInvalid>(HcertIssuer.prepare(Testkit.request(Payload.DvcMin(NEWBORN), iss = bad), reg).err(), bad)
            assertEquals(listOf("not-alpha2"), e.value.map { it.code }, bad)
        }
        val issued = Testkit.issue(Testkit.request(Payload.DvcMin(NEWBORN), iss = null))
        assertEquals(null, claimsOf(issued.cose)[1L])
        assertEquals(null, assertIs<VerificationResult.Verified>(verify(issued.cose)).value.iss)
        assertEquals("XX", assertIs<VerificationResult.Verified>(verify(Testkit.issue(Payload.DvcMin(NEWBORN)).cose)).value.iss)
    }

    @Test fun `STT-CWT-006 claims this version does not know are kept`() {
        val extra = CborItem.Int(-70000) to CborItem.Text("future")
        val v = assertIs<VerificationResult.Verified>(verify(signClaims(cwt(extra)))).value
        val (k, value) = v.otherClaims.single()
        assertEquals(extra.first, cborDecode(k, DEFAULT_LIMITS))
        assertEquals(extra.second, cborDecode(value, DEFAULT_LIMITS))
    }
}
