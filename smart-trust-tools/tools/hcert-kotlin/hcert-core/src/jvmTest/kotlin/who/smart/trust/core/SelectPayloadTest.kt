package who.smart.trust.core

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue
import who.smart.trust.issuer.IssueError
import who.smart.trust.payloads.Payload
import who.smart.trust.payloads.RawPayload
import who.smart.trust.subclaims.PayloadKind
import who.smart.trust.types.CoseAlgorithm
import who.smart.trust.types.FailureReason
import who.smart.trust.types.Severity
import who.smart.trust.types.Step
import who.smart.trust.types.Subclaim
import who.smart.trust.verifier.VerificationResult
import who.smart.trust.verifier.VerifierOptions

/** Skill `hcert-select-payload`: QR Code Generation step 1. */
class SelectPayloadTest {
    private val reg = SubclaimRegistry()
    private val vhl = Payload.Vhl(IHE_VHL.copy(exp = Testkit.now + 86400))

    private fun verified(cose: ByteArray, store: HcertTrustStore = Testkit.store(Testkit.esPem), options: VerifierOptions = OPTIONS) =
        assertIs<VerificationResult.Verified>(HcertVerifier.verifyCose(cose, store, reg, Testkit.now, options)).value

    @Test fun `STT-SEL-001 the registry holds the subclaims the guide defines`() {
        val reg = SubclaimRegistry()
        assertEquals(setOf(1, 3, 4, 5, -6, -7), reg.all().map { it.key }.toSet())
        assertEquals("http://smart.who.int/trust-phw/StructureDefinition/DVCMin", reg.lookup(-6)?.logicalModel)
        assertEquals(-6, reg.subclaimFor(PayloadKind.DVC_MIN))
        assertEquals(5, reg.subclaimFor(PayloadKind.VHL))
    }

    @Test fun `STT-SEL-002 a host registers its own subclaim and issues under it`() {
        val reg = SubclaimRegistry()
        assertNull(reg.lookup(42))
        val body = CborEncoder.encode(CborItem.Map(listOf(CborItem.Text("k") to CborItem.Text("v"))))
        assertEquals(IssueError.UnknownSubclaim(42), HcertIssuer.prepare(Testkit.request(Payload.Raw(RawPayload(42, body))), reg).err())
        reg.register(Subclaim(42, "Local payload"))
        Testkit.issue(Testkit.request(Payload.Raw(RawPayload(42, body))), reg)
    }

    @Test fun `STT-SEL-003 a development-range subclaim needs the explicit opt-in`() {
        val r = HcertIssuer.prepare(Testkit.request(Payload.DvcMin(NEWBORN), dev = false), SubclaimRegistry())
        assertEquals(IssueError.DevelopmentSubclaimNotAllowed(-6), r.err())
    }

    @Test fun `STT-SEL-003 DVC moves to an assigned subclaim without an API change`() {
        // WHO assigns DVC a production number (6 here): registry configuration only.
        val assigned = SubclaimRegistry()
        assigned.register(Subclaim(6, "DVCMin", "http://smart.who.int/trust-phw/StructureDefinition/DVCMin"))
        assigned.setSubclaimFor(PayloadKind.DVC_MIN, 6)
        // A production number needs no development opt-in.
        val es = Testkit.issue(Testkit.request(Payload.DvcMin(NEWBORN), dev = false), assigned)
        val v = assertIs<VerificationResult.Verified>(HcertVerifier.verify(es.hc1, Testkit.store(Testkit.esPem), assigned, Testkit.now, OPTIONS)).value
        assertEquals(listOf(6), v.entries.map { it.subclaim })
        assertIs<Payload.DvcMin>(v.entries.single().payload)
        // The key-usage check follows the number too: the PS256 DSC's EKU is
        // test certificates only, so a DVC under 6 is refused, as under -6.
        val ps = Testkit.issue(Testkit.request(Payload.DvcMin(NEWBORN), CoseAlgorithm.PS256, dev = false), assigned)
        val f = assertIs<VerificationResult.Failed>(HcertVerifier.verify(ps.hc1, Testkit.store(Testkit.psPem), assigned, Testkit.now, OPTIONS)).value
        assertEquals(Step.KEY_USAGE to FailureReason.KEY_USAGE_MISMATCH, f.step to f.reason)
    }

    @Test fun `STT-SEL-004 an issued HCERT carries each payload under its own subclaim, in key order`() {
        val hcert = claimsOf(Testkit.issue(Testkit.request(listOf(Payload.DvcMin(NEWBORN), vhl))).cose)[-260L] as CborItem.Map
        // deterministic CBOR orders the keys by their encoding: 5 (0x05) before -6 (0x25)
        assertEquals(listOf(CborItem.Int(5), CborItem.Int(-6)), hcert.entries.map { it.first })
        val one = claimsOf(Testkit.issue(Payload.DvcMin(NEWBORN)).cose)[-260L] as CborItem.Map
        assertEquals(listOf(CborItem.Int(-6)), one.entries.map { it.first })
    }

    @Test fun `STT-SEL-004 STT-ISS-004 a certificate with a DVC and a VHL verifies with both entries`() {
        val issued = Testkit.issue(Testkit.request(listOf(Payload.DvcMin(NEWBORN), vhl)))
        val v = verified(issued.cose)
        assertEquals(listOf(5, -6), v.entries.map { it.subclaim }) // wire order
        assertEquals(vhl, v.entries[0].payload)
        assertEquals(NEWBORN.copy(extensions = emptyList()), assertIs<Payload.DvcMin>(v.entries[1].payload).value.copy(extensions = emptyList()))
        assertTrue(v.entries.all { it.keyUsageAuthorised })
        // the DSC carries HCERT EKUs, and a VHL has no certificate type: noted, and authorised
        assertEquals(listOf("no certificate type is known for subclaim 5"), v.diagnostics.map { it.message })
        val u = HcertVerifier.readUnverified(issued.hc1, reg, DEFAULT_LIMITS).ok()
        assertEquals(listOf(5, -6), u.entries.map { it.subclaim })
        assertTrue(u.entries.all { it.payload != null })
    }

    @Test fun `STT-SEL-004 maxPayloads refuses more entries than the profile allows`() {
        val cose = Testkit.issue(Testkit.request(listOf(Payload.DvcMin(NEWBORN), vhl))).cose
        val f = assertIs<VerificationResult.Failed>(
            HcertVerifier.verifyCose(cose, Testkit.store(Testkit.esPem), reg, Testkit.now, OPTIONS.copy(maxPayloads = 1)),
        ).value
        assertEquals(Step.HCERT to FailureReason.MULTIPLE_SUBCLAIMS, f.step to f.reason)
        assertEquals("hcert has 2 entries", f.detail)
        assertEquals(2, verified(cose, options = OPTIONS.copy(maxPayloads = 2)).entries.size)
        // a DVC beside a subclaim no payload kind maps to (-7): two entries, the second raw
        val withRaw = signClaims(
            CborItem.Map(
                listOf(
                    CborItem.Int(4) to CborItem.Int(Testkit.now + 86400),
                    CborItem.Int(6) to CborItem.Int(Testkit.now),
                    CborItem.Int(-260) to CborItem.Map(listOf(CborItem.Int(-6) to HcertDvc.item(NEWBORN), CborItem.Int(-7) to CborItem.Map(emptyList()))),
                ),
            ),
        )
        val v = verified(withRaw)
        assertEquals(listOf(-6, -7), v.entries.map { it.subclaim })
        assertContentEquals(CborEncoder.encode(CborItem.Map(emptyList())), assertIs<Payload.Raw>(v.entries[1].payload).value.cbor)
        val f1 = assertIs<VerificationResult.Failed>(
            HcertVerifier.verifyCose(withRaw, Testkit.store(Testkit.esPem), reg, Testkit.now, OPTIONS.copy(maxPayloads = 1)),
        ).value
        assertEquals(Step.HCERT to FailureReason.MULTIPLE_SUBCLAIMS, f1.step to f1.reason)
    }

    @Test fun `STT-SEL-004 an invalid entry is left out and reported`() {
        val badDvc = HcertDvc.item(NEWBORN.copy(nt = "Laos")) // nt is not alpha-3
        fun claims(hcert: List<Pair<CborItem, CborItem>>) = CborItem.Map(
            listOf(
                CborItem.Int(4) to CborItem.Int(Testkit.now + 86400),
                CborItem.Int(6) to CborItem.Int(Testkit.now),
                CborItem.Int(-260) to CborItem.Map(hcert),
            ),
        )
        val mixed = signClaims(claims(listOf(CborItem.Int(-6) to badDvc, CborItem.Int(5) to HcertVhl.toItem(vhl.value))))
        val v = verified(mixed)
        assertEquals(listOf(5), v.entries.map { it.subclaim })
        val d = v.diagnostics.single { it.message.startsWith("subclaim -6: ") }
        assertEquals(Step.PAYLOAD to Severity.WARNING, d.step to d.severity)
        // unverified: every entry, the invalid one without its payload
        val u = HcertVerifier.readUnverified(HcertCodec.toHc1(mixed), reg, DEFAULT_LIMITS).ok()
        assertEquals(listOf(5 to true, -6 to false), u.entries.map { it.subclaim to (it.payload != null) })
        assertTrue(u.diagnostics.any { it.step == Step.PAYLOAD && it.message.startsWith("subclaim -6: ") })
        // with no valid entry left, the first entry's failure stands, as for a single payload
        val onlyBad = signClaims(claims(listOf(CborItem.Int(-6) to badDvc)))
        val f = assertIs<VerificationResult.Failed>(HcertVerifier.verifyCose(onlyBad, Testkit.store(Testkit.esPem), reg, Testkit.now, OPTIONS)).value
        assertEquals(Step.PAYLOAD to FailureReason.PAYLOAD_INVALID, f.step to f.reason)
        // an expired link is left out at TIME, beside a valid DVC
        val expired = HcertVhl.toItem(vhl.value.copy(exp = Testkit.now - 3600))
        val withExpired = verified(signClaims(claims(listOf(CborItem.Int(-6) to HcertDvc.item(NEWBORN), CborItem.Int(5) to expired))))
        assertEquals(listOf(-6), withExpired.entries.map { it.subclaim })
        assertTrue(withExpired.diagnostics.any { it.step == Step.TIME && it.message.startsWith("subclaim 5: ") })
    }

    @Test fun `STT-VER-004 STT-SEL-004 key usage is checked per entry`() {
        val psStore = Testkit.store(Testkit.psPem) // EKU: test certificates only
        val both = Testkit.issue(Testkit.request(listOf(Payload.DvcMin(NEWBORN), vhl), CoseAlgorithm.PS256))
        val v = verified(both.cose, psStore)
        assertEquals(listOf(5 to true, -6 to false), v.entries.map { it.subclaim to it.keyUsageAuthorised })
        assertTrue(v.diagnostics.any { it.step == Step.KEY_USAGE && it.message == "the DSC's extended key usage does not allow subclaim -6's certificate type" })
        assertTrue(v.diagnostics.any { it.step == Step.KEY_USAGE && it.message == "no certificate type is known for subclaim 5" })
        val alone = Testkit.issue(Payload.DvcMin(NEWBORN), CoseAlgorithm.PS256)
        val f = assertIs<VerificationResult.Failed>(HcertVerifier.verifyCose(alone.cose, psStore, reg, Testkit.now, OPTIONS)).value
        assertEquals(Step.KEY_USAGE to FailureReason.KEY_USAGE_MISMATCH, f.step to f.reason)
    }

    @Test fun `STT-SEL-004 issuance refuses no payload and a duplicate subclaim`() {
        assertEquals(IssueError.NoPayload, HcertIssuer.prepare(Testkit.request(emptyList()), reg).err())
        val raw = Payload.Raw(RawPayload(-6, HcertDvc.toCbor(NEWBORN)))
        assertEquals(IssueError.DuplicateSubclaim(-6), HcertIssuer.prepare(Testkit.request(listOf(Payload.DvcMin(NEWBORN), raw)), reg).err())
        // each payload is checked as a single one would be; the first failure wins
        assertEquals(IssueError.DevelopmentSubclaimNotAllowed(-6), HcertIssuer.prepare(Testkit.request(listOf(vhl, Payload.DvcMin(NEWBORN)), dev = false), reg).err())
        assertIs<IssueError.PayloadInvalid>(HcertIssuer.prepare(Testkit.request(listOf(vhl, Payload.DvcMin(NEWBORN.copy(nt = "Laos")))), reg).err())
    }
}
