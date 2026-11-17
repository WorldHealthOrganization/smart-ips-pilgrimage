package who.smart.trust.core

import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue
import who.smart.trust.payloads.Payload
import who.smart.trust.types.FailureReason
import who.smart.trust.types.Step
import who.smart.trust.verifier.VerificationResult

/** Skill `hcert-conformance-testing`: the shared vectors (QR Code Generation 12). */
class ConformanceVectorsTest {
    private val vector = parseJson(readRepo("vectors/smart-trust-pr129/dvc-qr-example-XXA.json")) as Map<*, *>
    private val certs = vector["certificates"] as Map<*, *>
    private val store = HcertTrustStore().apply { addPem(readRepo("vectors/smart-trust-pr129/dvc-qr-example-XXA-dsc.pem")).ok() }
    private val reg = SubclaimRegistry()
    private fun hc1(name: String) = (certs[name] as Map<*, *>)["hc1"] as String

    @Test fun `STT-TST-001 STT-KID-001 the vector's kid is the DSC's`() {
        assertEquals("58733e058aaa6621", store.candidates(Base64Std.decode("WHM+BYqqZiE=")).single().kid.toHex())
    }

    @Test fun `STT-TST-001 STT-PAY-001 both PR 129 certificates verify and decode as published`() {
        for (name in listOf("hepb1", "bcg")) {
            val v = assertIs<VerificationResult.Verified>(HcertVerifier.verify(hc1(name), store, reg, NOW, OPTIONS), name).value
            assertEquals("XX", v.iss)
            assertEquals(-6, v.entries.single().subclaim)
            val p = assertIs<Payload.DvcMin>(v.entries.single().payload).value
            val expected = (certs[name] as Map<*, *>)["payload"] as Map<*, *>
            assertEquals(expected["n"], p.n)
            assertEquals(expected["nt"], p.nt)
            assertEquals((expected["vx"] as Map<*, *>)["vp"], p.vx.vp)
            assertEquals((expected["vx"] as Map<*, *>)["bo"], p.vx.bo)
            assertTrue(v.diagnostics.isEmpty(), v.diagnostics.toString())
        }
    }

    @Test fun `STT-TST-002 STT-CBR-001 deterministic re-encoding reproduces the issued CWT byte for byte`() {
        val cose = HcertCodec.fromHc1(hc1("hepb1"), DEFAULT_LIMITS).ok()
        val s = HcertCose.parseSign1(cose, DEFAULT_LIMITS).ok()
        assertContentEquals(s.payload, HcertCodec.cborDeterministic(s.payload, DEFAULT_LIMITS).ok())
        assertEquals(210, s.payload.size)
        assertEquals(295, cose.size)
    }

    @Test fun `STT-TST-011 STT-TST-002 the merged guide's XXR certificates decode as published`() {
        val xxr = (parseJson(readRepo("vectors/smart-trust-af75be2/dvc-qr-example-XXR.json")) as Map<*, *>)["certificates"] as Map<*, *>
        for (name in listOf("hepb1", "bcg")) {
            val c = xxr[name] as Map<*, *>
            val hc1 = c["hc1"] as String
            val num = { k: String -> (c[k] as Number).toInt() }
            val u = HcertVerifier.readUnverified(hc1, reg, DEFAULT_LIMITS).ok()
            assertEquals("916ffa567c0f44a2", u.kid!!.toHex())
            assertEquals("XR", u.iss)
            assertEquals(1792657800L to 1824193800L, u.iat to u.exp)
            assertEquals(-6L, u.entries.single().subclaim.toLong())
            val p = assertIs<Payload.DvcMin>(u.entries.single().payload).value
            val expected = c["payload"] as Map<*, *>
            val vx = expected["vx"] as Map<*, *>
            assertEquals(expected["n"], p.n)
            assertEquals(expected["dob"], p.dob)
            assertEquals(vx["vp"], p.vx.vp)
            assertEquals(vx["is"], p.vx.`is`)
            assertEquals(vx["bo"], p.vx.bo)
            // 12.5 Size at each stage, exactly: these are the published strings.
            val cose = HcertCodec.fromHc1(hc1, DEFAULT_LIMITS).ok()
            val s = HcertCose.parseSign1(cose, DEFAULT_LIMITS).ok()
            assertContentEquals(s.payload, HcertCodec.cborDeterministic(s.payload, DEFAULT_LIMITS).ok())
            assertEquals(num("cwt_cbor_bytes"), s.payload.size)
            assertEquals(num("cose_sign1_bytes"), cose.size)
            assertEquals(num("deflated_bytes"), HcertCodec.base45Decode(hc1.substring(4)).ok().size)
            assertEquals(num("hc1_chars"), hc1.length)
            // Without the DEV trust list's DSC, verification stops at the trust lookup.
            val f = assertIs<VerificationResult.Failed>(HcertVerifier.verify(hc1, store, reg, NOW, OPTIONS), name).value
            assertEquals(Step.TRUST_LOOKUP to FailureReason.KID_NOT_FOUND, f.step to f.reason, name)
        }
        val h = xxr["hepb1"] as Map<*, *>
        assertEquals(listOf(222, 307, 293, 444), listOf("cwt_cbor_bytes", "cose_sign1_bytes", "deflated_bytes", "hc1_chars").map { (h[it] as Number).toInt() })
    }

    @Test fun `STT-TST-011 the merged guide's XXR certificates verify against the DEV trust list's DSC`() {
        val dev = HcertTrustStore().apply { assertEquals(1, addDidDocument(readRepo("vectors/smart-trust-af75be2/XXR-DSC-did.json")).ok()) }
        val xxr = (parseJson(readRepo("vectors/smart-trust-af75be2/dvc-qr-example-XXR.json")) as Map<*, *>)["certificates"] as Map<*, *>
        for (name in listOf("hepb1", "bcg")) {
            val c = xxr[name] as Map<*, *>
            val v = assertIs<VerificationResult.Verified>(HcertVerifier.verify(c["hc1"] as String, dev, reg, (c["iat"] as Number).toLong() + 3600, OPTIONS), name).value
            assertEquals("XR", v.iss)
            assertEquals("XR", v.dsc.country)
            assertEquals("916ffa567c0f44a2", v.dsc.kid.toHex())
            val e = v.entries.single()
            assertTrue(e.keyUsageAuthorised)
            assertEquals(((c["payload"] as Map<*, *>)["vx"] as Map<*, *>)["vp"], assertIs<Payload.DvcMin>(e.payload).value.vx.vp)
            assertTrue(v.diagnostics.isEmpty(), "$name: ${v.diagnostics}")
        }
    }

    @Test fun `STT-TST-004 STT-TST-005 the shared negative vectors fail at the named step with the named reason`() {
        val doc = parseJson(readRepo("vectors/negative/negative-vectors.json")) as Map<*, *>
        val defaults = doc["defaults"] as Map<*, *>
        val cases = doc["cases"] as List<*>
        assertTrue(cases.size >= 15)
        for (c in cases.map { it as Map<*, *> }) {
            val id = c["id"] as String
            val trust = HcertTrustStore().apply { for (p in (c["trust"] ?: defaults["trust"]) as List<*>) addPem(readRepo(p as String)).ok() }
            val now = ((c["now"] ?: defaults["now"]) as Number).toLong()
            val options = OPTIONS.copy(clockSkewSeconds = ((defaults["clockSkewSeconds"]) as Number).toInt())
            val r = when (val hex = c["coseHex"] as String?) {
                null -> HcertVerifier.verify(c["hc1"] as String, trust, reg, now, options)
                else -> HcertVerifier.verifyCose(hex.chunked(2).map { it.toInt(16).toByte() }.toByteArray(), trust, reg, now, options)
            }
            val f = assertIs<VerificationResult.Failed>(r, id).value
            val expect = c["expect"] as Map<*, *>
            assertEquals(expect["step"] to expect["reason"], f.step.name to f.reason.name, id)
        }
    }
}
