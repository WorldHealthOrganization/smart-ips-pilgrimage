package who.smart.trust.core

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue
import who.smart.trust.issuer.IssueError
import who.smart.trust.payloads.Payload
import who.smart.trust.payloads.RawPayload
import who.smart.trust.types.CoseAlgorithm
import who.smart.trust.verifier.VerificationResult

/** Skill `hcert-assemble-payload`: QR Code Generation step 2. */
class AssemblePayloadTest {
    private val reg = SubclaimRegistry()
    private fun roundTrip(p: Payload): Payload {
        val issued = Testkit.issue(p)
        val store = Testkit.store(Testkit.esPem)
        return assertIs<VerificationResult.Verified>(HcertVerifier.verify(issued.hc1, store, reg, Testkit.now, OPTIONS)).value.entries.single().payload
    }

    @Test fun `STT-PAY-001 STT-PAY-002 STT-PAY-005 a newborn's DVCMin, with no identity document, round-trips as typed fields`() {
        assertEquals(emptyList(), HcertDvc.validate(NEWBORN).filter { it.severity == who.smart.trust.types.Severity.BLOCKING })
        val got = assertIs<Payload.DvcMin>(roundTrip(Payload.DvcMin(NEWBORN))).value
        assertEquals(NEWBORN.copy(extensions = emptyList()), got.copy(extensions = emptyList()))
        assertEquals("XM9V38", got.vx.vp)
    }

    @Test fun `STT-PAY-003 one immunization event per DVC`() {
        val vx = (cborDecode(HcertDvc.toCbor(NEWBORN), DEFAULT_LIMITS) as CborItem.Map)["vx"]
        assertIs<CborItem.Map>(vx, "vx is one event, not an array")
    }

    @Test fun `STT-PAY-004 STT-PAY-007 an invalid payload is refused, naming each rule`() {
        val bad = NEWBORN.copy(nt = "LA", vx = NEWBORN.vx.copy(`is` = null, cn = null))
        val e = assertIs<IssueError.PayloadInvalid>(HcertIssuer.prepare(Testkit.request(Payload.DvcMin(bad)), reg).err())
        assertEquals(setOf("not-alpha3", "must-have-issuer-or-clinician-name"), e.value.map { it.code }.toSet())
    }

    @Test fun `STT-PAY-008 unknown payload elements are kept`() {
        val got = assertIs<Payload.DvcMin>(roundTrip(Payload.DvcMin(NEWBORN))).value
        assertEquals(listOf("zz"), got.extensions.map { it.first })
        assertContentEquals(NEWBORN.extensions.single().second, got.extensions.single().second)
    }

    @Test fun `STT-PAY-009 STT-GEN-003 another payload passes through the core untouched`() {
        val body = CborEncoder.encode(CborItem.Map(listOf(CborItem.Text("t") to CborItem.Text("x"))))
        val issued = Testkit.issue(Payload.Raw(RawPayload(4, body)), CoseAlgorithm.PS256)
        val store = Testkit.store(Testkit.psPem)
        val v = assertIs<VerificationResult.Verified>(HcertVerifier.verify(issued.hc1, store, reg, Testkit.now, OPTIONS)).value
        assertContentEquals(body, assertIs<Payload.Raw>(v.entries.single().payload).value.cbor)
        assertTrue(v.diagnostics.isEmpty())
    }
}
