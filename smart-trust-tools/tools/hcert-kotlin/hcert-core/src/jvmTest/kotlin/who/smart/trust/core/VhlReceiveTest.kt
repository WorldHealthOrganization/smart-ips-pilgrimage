package who.smart.trust.core

import java.security.Signature
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertNull
import kotlin.test.assertTrue
import who.smart.trust.payloads.Payload
import who.smart.trust.types.FailureReason
import who.smart.trust.verifier.VerificationResult
import who.smart.trust.vhl.SignatureRequest
import who.smart.trust.vhl.VhlError

/** Skill `vhl-receive`: use a Verifiable Health Link (journey J4.1). */
class VhlReceiveTest {
    @Test fun `STT-VHL-005 the ITI-YY5 request is the exact body of the IHE example`() {
        val r = HcertVhl.buildManifestRequest(IHE_VHL, "Dr. Smith Hospital", "user-pin", 10000).ok()
        assertEquals("https://vhl-sharer.example.org/List/_search", r.url)
        assertEquals("application/x-www-form-urlencoded", r.contentType)
        assertEquals(
            "_id=abc123def456&code=folder&status=current&patient.identifier=urn%3Aoid%3A2.16.840.1.113883.2.4.6.3%7CPASSPORT123&_include=List%3Aitem&recipient=Dr.+Smith+Hospital&passcode=user-pin&embeddedLengthMax=10000",
            r.body,
        )
    }

    @Test fun `STT-VHL-005 a List URL is searched, and the passcode follows the P flag`() {
        val list = IHE_VHL.copy(url = "https://vhl-sharer.example.org/List?_id=abc&code=folder&status=current&patient.identifier=s%7Cv", flag = null)
        assertEquals("https://vhl-sharer.example.org/List/_search", HcertVhl.buildManifestRequest(list, "Clinic B", null, null).ok().url)
        assertIs<VhlError.Manifest>(HcertVhl.buildManifestRequest(IHE_VHL, "Clinic B", null, null).err()) // P without passcode
        assertIs<VhlError.Manifest>(HcertVhl.buildManifestRequest(list, "Clinic B", "1234", null).err()) // passcode without P
        val noId = list.copy(url = "https://vhl-sharer.example.org/List?code=folder&status=current&patient.identifier=s%7Cv")
        assertIs<VhlError.Manifest>(HcertVhl.buildManifestRequest(noId, "Clinic B", null, null).err())
    }

    @Test fun `STT-VHL-006 the IHE Case B manifest Bundle reads as documents`() {
        val docs = HcertVhl.parseManifest(readRepo("vectors/ihe-vhl/iti-yy5-manifest-case-b.json")).ok()
        assertEquals(4, docs.size)
        assertEquals("https://vhl-sharer.example.org/Binary/doc001-content", docs[0].url)
        assertEquals("application/pdf", docs[0].contentType)
        // the example abbreviates doc002..doc004 to bare ids: handed back as references
        assertEquals(listOf("DocumentReference/doc002", "DocumentReference/doc003", "DocumentReference/doc004"), docs.drop(1).map { it.reference })
    }

    @Test fun `STT-VHL-006 a Case A manifest without includes hands back references`() {
        val bundle = """{"resourceType":"Bundle","type":"searchset","entry":[{"resource":{"resourceType":"List","entry":[{"item":{"reference":"DocumentReference/d1"}}]},"search":{"mode":"match"}}]}"""
        val d = HcertVhl.parseManifest(bundle).ok().single()
        assertEquals("DocumentReference/d1", d.reference)
        assertNull(d.url)
        assertIs<VhlError.Manifest>(HcertVhl.parseManifest("""{"resourceType":"Bundle","type":"document"}""").err())
    }

    @Test fun `STT-VHL-007 decrypts what node crypto encrypted, with and without zip DEF`() {
        val fixture = parseJson(readRepo("vectors/ihe-vhl/jwe-dir-a256gcm.json")) as Map<*, *>
        for (k in listOf("jwe", "jweZipDef")) {
            val d = HcertVhl.decrypt(fixture[k] as String, fixture["key"] as String).ok()
            assertEquals(fixture["plaintext"], d.content.decodeToString(), k)
            assertEquals("application/fhir+json", d.contentType)
        }
    }

    @Test fun `STT-VHL-007 a wrong key, a changed byte and another enc are refused`() {
        val key = HcertVhl.newKey()
        val jwe = HcertVhl.encrypt("hello".encodeToByteArray(), "text/plain", key).ok()
        assertIs<VhlError.DecryptFailed>(HcertVhl.decrypt(jwe, HcertVhl.newKey()).err())
        val parts = jwe.split('.').toMutableList()
        parts[3] = Base64Std.encodeUrl(Base64Std.decode(parts[3]).also { it[0] = (it[0].toInt() xor 1).toByte() })
        assertIs<VhlError.DecryptFailed>(HcertVhl.decrypt(parts.joinToString("."), key).err())
        val a128 = Base64Std.encodeUrl("""{"alg":"dir","enc":"A128GCM"}""".encodeToByteArray()) + ".." + jwe.substringAfter("..")
        assertIs<VhlError.Unsupported>(HcertVhl.decrypt(a128, key).err())
    }

    private val body = """{"hello": "world"}""".encodeToByteArray()
    private val request = SignatureRequest("POST", "vhl-sharer.example.org", "/List/_search", "application/x-www-form-urlencoded", body, "receiver-key-123", "ecdsa-p256-sha256", 1735689600)

    /** RFC 9530 appendix B.1's sha-256 of {"hello": "world"}: the value IHE's example shows without the colons (OI-26). */
    @Test fun `STT-VHL-008 the Content-Digest is RFC 9530`() {
        assertEquals("sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:", HcertVhl.buildSignatureBase(request).contentDigest)
    }

    @Test fun `STT-VHL-008 the RFC 9421 signature base has the IHE shape`() {
        val b = HcertVhl.buildSignatureBase(request)
        val params = """("@method" "@path" "@authority" "content-type" "content-digest");created=1735689600;keyid="receiver-key-123";alg="ecdsa-p256-sha256""""
        assertEquals("sig1=$params", b.signatureInput)
        assertEquals(
            listOf(
                "\"@method\": POST",
                "\"@path\": /List/_search",
                "\"@authority\": vhl-sharer.example.org",
                "\"content-type\": application/x-www-form-urlencoded",
                "\"content-digest\": sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:",
                "\"@signature-params\": $params",
            ).joinToString("\n"),
            b.base.decodeToString(),
        )
    }

    @Test fun `STT-VHL-008 a DER signature becomes the raw header value and verifies`() {
        val b = HcertVhl.buildSignatureBase(request)
        val kp = java.security.KeyPairGenerator.getInstance("EC").apply { initialize(256) }.generateKeyPair()
        val der = Signature.getInstance("SHA256withECDSA").run { initSign(kp.private); update(b.base); sign() }
        val header = HcertVhl.signatureHeader(der, "ecdsa-p256-sha256").ok()
        val raw = Base64Std.decode(header.removePrefix("sig1=:").removeSuffix(":"))
        assertEquals(64, raw.size)
        assertTrue(Signature.getInstance("SHA256withECDSA").run { initVerify(kp.public); update(b.base); verify(EcdsaSignature.rawToDer(raw)) })
    }

    @Test fun `STT-VHL-009 an expired link fails verification, by its own exp`() {
        assertEquals(setOf("expired"), HcertVhl.validate(IHE_VHL, 1735689601).map { it.code }.toSet())
        val cose = Testkit.issue(Payload.Vhl(IHE_VHL.copy(exp = Testkit.now - 1000))).cose
        val f = assertIs<VerificationResult.Failed>(HcertVerifier.verify(HcertCodec.toHc1(cose), Testkit.store(Testkit.esPem), SubclaimRegistry(), Testkit.now, OPTIONS)).value
        assertEquals(FailureReason.EXPIRED, f.reason)
    }
}
