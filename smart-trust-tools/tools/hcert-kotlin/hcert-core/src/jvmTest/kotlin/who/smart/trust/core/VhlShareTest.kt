package who.smart.trust.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue
import who.smart.trust.payloads.Payload
import who.smart.trust.payloads.RawPayload
import who.smart.trust.verifier.VerificationResult
import who.smart.trust.vhl.VhlError

/** Skill `vhl-share`: issue a Verifiable Health Link (journey J4.0). */
class VhlShareTest {
    private val reg = SubclaimRegistry()
    private val store = Testkit.store(Testkit.esPem)
    private val payload = IHE_VHL.copy(exp = Testkit.now + 86400)
    private fun key5(cose: ByteArray) = (claimsOf(cose)[-260L] as CborItem.Map)[5L]!!

    @Test fun `STT-VHL-001 the IHE ITI-YY3 example payload is valid, and each rule is enforced`() {
        assertEquals(emptyList(), HcertVhl.validate(IHE_VHL, null))
        fun codes(p: who.smart.trust.vhl.VhlPayload, now: Long? = null) = HcertVhl.validate(p, now).map { it.code }.toSet()
        // the ITI-YY4 example key: 44 characters, 33 bytes (OI-22)
        assertEquals(setOf("bad-key"), codes(IHE_VHL.copy(key = "dGhpcyBpcyBhIHNlY3JldCBrZXkgdXNlZCBmb3IgZW5j")))
        assertEquals(setOf("bad-flag"), codes(IHE_VHL.copy(flag = "PL")))
        assertEquals(setOf("unsupported-flag-U"), codes(IHE_VHL.copy(flag = "LU")))
        assertEquals(setOf("label-too-long"), codes(IHE_VHL.copy(label = "x".repeat(81))))
        assertEquals(setOf("not-https"), codes(IHE_VHL.copy(url = "http://vhl-sharer.example.org/List?_id=1")))
    }

    @Test fun `STT-VHL-002 the payload is a CBOR map at HCERT key 5, and verifies`() {
        val cose = Testkit.issue(Payload.Vhl(payload)).cose
        assertIs<CborItem.Map>(key5(cose))
        val v = assertIs<VerificationResult.Verified>(HcertVerifier.verify(HcertCodec.toHc1(cose), store, reg, Testkit.now, OPTIONS)).value
        assertEquals(5, v.entries.single().subclaim)
        assertEquals(payload, (v.entries.single().payload as Payload.Vhl).value)
    }

    @Test fun `STT-VHL-002 STT-VHL-003 a vhlink string at key 5 still verifies, and the map is smaller`() {
        val text = CborEncoder.encode(CborItem.Text(HcertVhl.toVhlink(payload)))
        val cose = Testkit.issue(Payload.Raw(RawPayload(5, text)))
            .cose
        assertIs<CborItem.Text>(key5(cose))
        val v = assertIs<VerificationResult.Verified>(HcertVerifier.verify(HcertCodec.toHc1(cose), store, reg, Testkit.now, OPTIONS)).value
        assertEquals(payload, (v.entries.single().payload as Payload.Vhl).value)
        val asMap = Testkit.issue(Payload.Vhl(payload)).hc1.length
        val asText = HcertCodec.toHc1(cose).length
        assertTrue(asMap < asText * 0.8, "map $asMap vs text $asText characters")
    }

    @Test fun `STT-VHL-003 vhlink round-trips, and reads the IHE example link`() {
        val link = HcertVhl.toVhlink(IHE_VHL)
        assertTrue(link.startsWith("vhlink:/eyJ1cmwiOi"))
        assertEquals(IHE_VHL, HcertVhl.fromVhlink(link).ok())
        val upstream = "vhlink:/eyJ1cmwiOiJodHRwczovL3ZobC1zaGFyZXIuZXhhbXBsZS5vcmcvTGlzdC9fc2VhcmNoP19pZD1hYmMxMjNkZWY0NTYmY29kZT1mb2xkZXImc3RhdHVzPWN1cnJlbnQmcGF0aWVudC5pZGVudGlmaWVyPXVybjpvaWQ6Mi4xNi44NDAuMS4xMTM4ODMuMi40LjYuM3xQQVNTUE9SVDEyMyZfaW5jbHVkZT1MaXN0Oml0ZW0iLCJrZXkiOiI4NkY4TFk1TGxXQWExLU9TX0ZnclRuWU5xRkhKUDJleTVSU0tMSkJOOWprIiwiZXhwIjoxNzM1Njg5NjAwLCJmbGFnIjoiTFAiLCJsYWJlbCI6IlBhdGllbnQgSGVhbHRoIFN1bW1hcnkiLCJ2IjoxLCJleHRlbnNpb25zIjp7ImZoaXJCYXNlVXJsIjoiaHR0cHM6Ly92aGwtc2hhcmVyLmV4YW1wbGUub3JnIn19"
        assertEquals(IHE_VHL.copy(fhirBaseUrl = null), HcertVhl.fromVhlink(upstream).ok()) // its "extensions" is not the payload's "extension"
        assertIs<VhlError.NotAVhlink>(HcertVhl.fromVhlink("shlink:/abc").err())
    }

    @Test fun `STT-VHL-004 a new key is 32 random bytes, base64url without padding`() {
        val a = HcertVhl.newKey()
        assertEquals(43, a.length)
        assertEquals(32, Base64Std.decode(a).size)
        assertTrue(a != HcertVhl.newKey())
    }

    @Test fun `STT-VHL-007 a document is encrypted as compact JWE dir A256GCM`() {
        val key = HcertVhl.newKey()
        val jwe = HcertVhl.encrypt("hello".encodeToByteArray(), "text/plain", key).ok()
        val parts = jwe.split('.')
        assertEquals(5, parts.size)
        assertEquals("", parts[1]) // dir: no encrypted key
        assertEquals("""{"alg":"dir","enc":"A256GCM","cty":"text/plain"}""", Base64Std.decode(parts[0]).decodeToString())
        assertEquals("hello", HcertVhl.decrypt(jwe, key).ok().content.decodeToString())
    }
}
