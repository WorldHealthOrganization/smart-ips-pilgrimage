package who.smart.trust.core

import java.math.BigInteger
import java.security.cert.CertificateFactory
import java.security.interfaces.ECPublicKey
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue
import who.smart.trust.trust.TrustError
import who.smart.trust.types.CoseAlgorithm

/** Skill `hcert-trust-list`: the trust store the host fills. */
class TrustListTest {
    @Test fun `STT-TRU-001 STT-KID-001 a DSC is found by its kid, the first 8 bytes of its SHA-256`() {
        val store = Testkit.store(Testkit.esPem)
        val kid = Platform.sha256(Testkit.esDer).copyOf(8)
        assertEquals(1, store.candidates(kid).size)
        assertEquals(0, store.candidates(ByteArray(8)).size)
    }

    @Test fun `STT-KID-003 a kid reads and writes as standard and URL-safe base64`() {
        val kid = HcertCose.kidFromDsc(Testkit.esDer)
        for (alphabet in who.smart.trust.cose.Base64Alphabet.entries) {
            assertEquals(kid.toHex(), HcertCose.kidFromBase64(HcertCose.kidToBase64(kid, alphabet)).ok().toHex())
        }
    }

    @Test fun `STT-TRU-002 a GDHCN DID trustlist v2 document loads its DSCs`() {
        val did = """{"id":"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXA:DSC","verificationMethod":[
          {"id":"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXA:DSC#k1","type":"JsonWebKey2020",
           "publicKeyJwk":{"kty":"EC","crv":"P-256","x5c":["${Base64Std.encode(Testkit.esDer)}"]}},
          "did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXB:DSC"]}"""
        val store = HcertTrustStore()
        assertEquals(1, store.addDidDocument(did).ok())
        val d = store.candidates(HcertCose.kidFromDsc(Testkit.esDer)).single()
        assertEquals(null to "XXA", d.domain to d.participant)
        assertEquals("XX", d.country)
    }

    @Test fun `STT-TRU-005 a static list of PEM certificates loads`() {
        val store = HcertTrustStore()
        assertEquals(2, store.addPem(Testkit.esPem + "\n" + Testkit.psPem).ok())
        assertEquals(2, store.size())
    }

    private fun did(domain: String) = """{"id":"did:web:tng-cdn.who.int:v2:trustlist:$domain:XXA:DSC","verificationMethod":[
      {"id":"did:web:tng-cdn.who.int:v2:trustlist:$domain:XXA:DSC#k1","type":"JsonWebKey2020",
       "publicKeyJwk":{"kty":"EC","crv":"P-256","x5c":["${Base64Std.encode(Testkit.esDer)}"]}}]}"""

    @Test fun `STT-SEL-006 trust domains are read from the GDHCN code system, not a closed list`() {
        val store = HcertTrustStore()
        assertEquals(emptyList(), store.trustDomains())
        assertEquals(1, store.addDidDocument(did("FUTURE")).ok()) // nothing loaded: kept as given
        assertEquals("FUTURE", store.candidates(HcertCose.kidFromDsc(Testkit.esDer)).single().domain)

        store.clear()
        val production = readRepo("vectors/gdhcn-trust-domains/CodeSystem-Domains.json")
        assertEquals(4, store.loadTrustDomains(production).ok())
        assertEquals(listOf("DDCC", "ICVP", "IPS-PILGRIMAGE", "PH4H"), store.trustDomains())
        assertEquals(1, store.addDidDocument(did("DDCC")).ok())
        assertEquals(TrustError.UnknownTrustDomain("FUTURE"), store.addDidDocument(did("FUTURE")).err())
        assertEquals(1, store.size()) // refused whole, nothing added
        store.clear()
        assertEquals(1, store.addDidDocument(did("-")).ok()) // the wildcard names no domain

        // A domain registered later is a new code in the data, not a new library release.
        val withFuture = production.replace("\"concept\" : [", "\"concept\" : [{\"code\":\"FUTURE\"},")
        assertEquals(5, store.loadTrustDomains(withFuture).ok())
        assertEquals(1, HcertTrustStore().apply { loadTrustDomains(withFuture).ok() }.addDidDocument(did("FUTURE")).ok())
        for (env in listOf("UAT", "DEV")) assertEquals(4, HcertTrustStore().loadTrustDomains(readRepo("vectors/gdhcn-trust-domains/CodeSystem-Domains-$env.json")).ok())
        assertIs<TrustError.Parse>(store.loadTrustDomains("""{"resourceType":"ValueSet"}""").err())
    }

    @Test fun `STT-TRU-001 bad trust material is refused with a typed error and nothing is added`() {
        val store = HcertTrustStore()
        val pem = readRepo("vectors/smart-trust-pr129/dvc-qr-example-XXA-dsc.pem")
        assertEquals(2, store.addPem(pem).ok()) // the DSC and its CSCA
        assertEquals(0, store.addPem(pem).ok(), "a certificate given twice is held once")
        val dsc = store.candidates(Base64Std.decode("WHM+BYqqZiE=")).single()
        assertEquals(0, store.addDer(dsc.der).ok())
        for (bad in listOf(
            "no certificate here",
            "-----BEGIN CERTIFICATE-----\n!!!!\n-----END CERTIFICATE-----",
            "-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----",
        )) assertIs<TrustError.Parse>(HcertTrustStore().addPem(bad).err(), bad)
        assertIs<TrustError.Parse>(HcertTrustStore().addDer(byteArrayOf(0x30, 0x03, 0x02, 0x01, 0x01)).err())
        for (bad in listOf("{", "[]", "{}", """{"verificationMethod": [{"id": "did:web:x:v2:trustlist:DDCC:XX:DSC#k", "publicKeyJwk": {"x5c": [7]}}]}""",
                """{"verificationMethod": [{"id": "did:web:x:v2:trustlist:DDCC:XX:DSC#k", "publicKeyJwk": {"x5c": ["!!"]}}]}"""))
            assertIs<TrustError.Parse>(HcertTrustStore().addDidDocument(bad).err(), bad)
        for (bad in listOf("{", "[]", """{"resourceType": "CodeSystem", "concept": []}"""))
            assertIs<TrustError.Parse>(HcertTrustStore().loadTrustDomains(bad).err(), bad)
        assertEquals(1, store.candidates(dsc.kid).size)
    }

    // ---- STT-TRU-006: the trust list DID documents' proofs ----------------------

    private val dev = "vectors/gdhcn-dev-trustlist"
    private val signer = readRepo("$dev/WHO-signing-did.json")
    private val xxrDsc = readRepo("vectors/smart-trust-af75be2/XXR-DSC-did.json")
    private val documents = listOf(
        "vectors/smart-trust-af75be2/XXR-DSC-did.json", "$dev/XXR-DSC-did-2026-10-23.json",
        "$dev/XXR-did.json", "$dev/XXA-did.json", "$dev/root-did.json",
    )
    private val signerId = "did:web:raw.githubusercontent.com:WorldHealthOrganization:tng-participants-dev:main:WHO:signing:DID"

    private fun proofInvalid(document: String, signerDoc: String = signer): String {
        val e = HcertTrust.verifyDidProof(document, signerDoc).err()
        assertIs<TrustError.ProofInvalid>(e)
        return e.value
    }

    private fun b64u(b: ByteArray) = Base64Std.encodeUrl(b)
    /** [s] with a non-zero pad bit in its last character: the same bytes, written non-canonically. */
    private fun padBitsSet(s: String): String {
        val alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        return s.dropLast(1) + alphabet[alphabet.indexOf(s.last()) xor 1]
    }
    private fun jwsOf(doc: String) = Regex("\"jws\":\"([^\"]+)\"").find(doc)!!.groupValues[1]
    private fun withJws(doc: String, jws: String) = doc.replace(jwsOf(doc), jws)
    private fun signerWith(x: String, y: String, id: String = signerId) =
        """{"id":"$id","verificationMethod":[{"id":"$id","type":"JsonWebKey2020","publicKeyJwk":{"kty":"EC","crv":"P-256","x":"$x","y":"$y"}}]}"""

    /** The testkit DSC's P-256 public key, as fixed-width x and y. */
    private val testkitPoint: Pair<ByteArray, ByteArray> by lazy {
        val w = (CertificateFactory.getInstance("X.509").generateCertificate(Testkit.esDer.inputStream()).publicKey as ECPublicKey).w
        fun fixed(i: BigInteger) = i.toByteArray().let { b -> ByteArray(32).also { b.takeLast(32).toByteArray().copyInto(it, 32 - minOf(32, b.size)) } }
        fixed(w.affineX) to fixed(w.affineY)
    }

    /** [doc]'s proof re-made with the testkit key, the signature DER as the GDHCN signer writes it. */
    private fun resignWithTestkit(doc: String): String {
        val m = parseJson(doc) as Map<*, *>
        val header = jwsOf(doc).substringBefore('.')
        val input = header.encodeToByteArray() + '.'.code.toByte() +
            Platform.sha256(DidProof.proofOptionsNQuads((m["proof"] as Map<*, *>).filterKeys { it != "jws" }).encodeToByteArray()) +
            Platform.sha256(DidProof.documentNQuads(m.filterKeys { it != "proof" }).encodeToByteArray())
        return withJws(doc, header + ".." + b64u(TestSigner(readRepo("vectors/testkit/es256-key.pem"), CoseAlgorithm.ES256).sign(input)))
    }

    @Test fun `STT-TRU-006 the XXR DSC document's canonical N-Quads equal the golden files byte for byte`() {
        val m = parseJson(xxrDsc) as Map<*, *>
        assertEquals(readRepo("$dev/XXR-DSC-did.doc.nq"), DidProof.documentNQuads(m.filterKeys { it != "proof" }))
        assertEquals(readRepo("$dev/XXR-DSC-did.proof-options.nq"), DidProof.proofOptionsNQuads((m["proof"] as Map<*, *>).filterKeys { it != "jws" }))
        assertEquals("68d4f58e", Platform.sha256(readRepo("$dev/XXR-DSC-did.doc.nq").encodeToByteArray()).toHex().take(8))
    }

    @Test fun `STT-TRU-006 the DEV trust list documents, the 234-key root among them, verify against WHO's signing DID`() {
        for (path in documents) {
            val doc = readRepo(path)
            val t0 = System.nanoTime()
            HcertTrust.verifyDidProof(doc, signer).ok()
            val ms = (System.nanoTime() - t0) / 1_000_000.0
            System.out.println("STT-TRU-006 verified $path (${doc.length} chars) in $ms ms")
        }
        // Warm: the root document again, after the JIT has seen the code.
        val root = readRepo("$dev/root-did.json")
        val t0 = System.nanoTime()
        repeat(5) { HcertTrust.verifyDidProof(root, signer).ok() }
        System.out.println("STT-TRU-006 root-did.json warm: ${(System.nanoTime() - t0) / 5_000_000.0} ms per verification")
    }

    @Test fun `STT-TRU-006 a changed byte in an x5c, the wrong signer, an unmodelled term and a wrong JWS header fail proof-invalid`() {
        // A changed byte in a certificate: the document hash changes, the signature no longer verifies.
        assertTrue("MIICmDCCAj+g" in xxrDsc)
        assertTrue("does not verify" in proofInvalid(xxrDsc.replaceFirst("MIICmDCCAj+g", "MIICmDCCAj+h")))
        assertTrue("does not verify" in proofInvalid(xxrDsc.replace("2026-10-22T12:00:16Z", "2026-10-22T12:00:16.000Z")), "created is never normalised")
        // The wrong signer: another P-256 key under the same id.
        val (x, y) = testkitPoint
        assertTrue("does not verify" in proofInvalid(xxrDsc, signerWith(b64u(x), b64u(y))))
        // Unmodelled terms, at each level: refused, never dropped from the signed bytes.
        val head = "{\"@context\":"
        for (bad in listOf(
            xxrDsc.replaceFirst(head, "{\"alsoKnownAs\":\"did:web:example\",\"@context\":"),
            xxrDsc.replaceFirst("\"type\":\"JsonWebKey2020\"", "\"type\":\"JsonWebKey2020\",\"service\":[]"),
            xxrDsc.replaceFirst("\"type\":\"JsonWebSignature2020\"", "\"type\":\"JsonWebSignature2020\",\"expires\":\"2030-01-01T00:00:00Z\""),
            xxrDsc.replaceFirst("{\"code\":\"#PH4H\"}", "{\"code\":\"#PH4H\",\"display\":\"PH4H\"}"),
        )) assertTrue("does not model" in proofInvalid(bad), bad.take(80))
        // A wrong JWS header: another algorithm, an extra member, an attached payload.
        val sig = jwsOf(xxrDsc).substringAfter("..")
        for (h in listOf(
            """{"b64":false,"crit":["b64"],"alg":"ES384"}""",
            """{"b64":false,"crit":["b64"],"alg":"ES256","kid":"k"}""",
            """{"alg":"ES256"}""",
        )) assertTrue("JWS header" in proofInvalid(withJws(xxrDsc, b64u(h.encodeToByteArray()) + ".." + sig)), h)
        assertTrue("detached" in proofInvalid(withJws(xxrDsc, jwsOf(xxrDsc).replace("..", ".e30."))))
    }

    @Test fun `STT-TRU-006 the trust store adds a document whose proof verifies, and nothing when it does not`() {
        for (path in documents) {
            val doc = readRepo(path)
            val store = HcertTrustStore()
            val n = store.addVerifiedDidDocument(doc, signer).ok()
            assertTrue(n > 0, path)
            assertEquals(HcertTrustStore().addDidDocument(doc).ok(), n, path)
            assertEquals(n, store.size())
        }
        val store = HcertTrustStore()
        assertIs<TrustError.ProofInvalid>(store.addVerifiedDidDocument(xxrDsc.replaceFirst("MIICmDCCAj+g", "MIICmDCCAj+h"), signer).err())
        assertIs<TrustError.ProofInvalid>(store.addVerifiedDidDocument(xxrDsc, signerWith(b64u(testkitPoint.first), b64u(testkitPoint.second))).err())
        assertEquals(0, store.size())
        // A document that verifies but holds a bad certificate further on adds none of its certificates.
        val resigned = resignWithTestkit(
            xxrDsc.replaceFirst("}],\"proof\"", "},{\"id\":\"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXR:DSC#bad\",\"type\":\"JsonWebKey2020\",\"controller\":\"did:web:x\",\"publicKeyJwk\":{\"x5c\":[\"AAAA\"]}}],\"proof\""),
        )
        val tk = signerWith(b64u(testkitPoint.first), b64u(testkitPoint.second))
        HcertTrust.verifyDidProof(resigned, tk).ok()
        assertIs<TrustError.Parse>(store.addVerifiedDidDocument(resigned, tk).err())
        assertEquals(0, store.size())
    }

    @Test fun `STT-TRU-006 a 64-byte r-s signature verifies as the DER one does, and so do 00-padded coordinates`() {
        val (header, der) = jwsOf(xxrDsc).split("..")
        val raw = EcdsaSignature.derToRaw(Base64Std.decode(der))
        HcertTrust.verifyDidProof(withJws(xxrDsc, header + ".." + b64u(raw)), signer).ok()
        raw[5] = (raw[5].toInt() xor 1).toByte()
        assertTrue("does not verify" in proofInvalid(withJws(xxrDsc, header + ".." + b64u(raw))))
        // Re-signed by the testkit key: verifies only against that key, also with a 33-byte, 00-led x and y.
        val resigned = resignWithTestkit(xxrDsc)
        val (x, y) = testkitPoint
        HcertTrust.verifyDidProof(resigned, signerWith(b64u(x), b64u(y))).ok()
        HcertTrust.verifyDidProof(resigned, signerWith(b64u(byteArrayOf(0) + x), b64u(byteArrayOf(0) + y))).ok()
        proofInvalid(resigned)
    }

    @Test fun `STT-TRU-006 the signer document and the signature are checked before any key is trusted`() {
        val (x, y) = testkitPoint
        val bad = mapOf(
            signerWith(b64u(x), b64u(y), id = "did:web:other") to "not",
            """{"id":"$signerId"}""" to "verificationMethod",
            """{"id":"$signerId","verificationMethod":[]}""" to "0 verification methods",
            signerWith(b64u(x), b64u(y)).replace("JsonWebKey2020", "Ed25519VerificationKey2020") to "JsonWebKey2020",
            signerWith(b64u(x), b64u(y)).replace("\"kty\":\"EC\",", "\"kty\":\"EC\",\"alg\":\"ES384\",") to "ES256",
            signerWith(b64u(x), b64u(y)).replace("P-256", "P-384") to "P-256",
            signerWith(b64u(x), b64u(y)).replace(",\"publicKeyJwk\":{\"kty\":\"EC\",\"crv\":\"P-256\",\"x\":\"${b64u(x)}\",\"y\":\"${b64u(y)}\"}", "") to "publicKeyJwk",
            signerWith(b64u(x), b64u(y)).replace(",\"y\":\"${b64u(y)}\"", "") to "no y",
            signerWith(b64u(x.copyOf(31)), b64u(y)) to "31 bytes",
            signerWith(b64u(byteArrayOf(1) + x), b64u(y)) to "33 bytes",
            signerWith(b64u(x) + "=", b64u(y)) to "base64url",
            signerWith(padBitsSet(b64u(x)), b64u(y)) to "canonical base64url",
            "[]" to "not a JSON object",
            "{\"id\":1,\"id\":2}" to "twice",
        )
        val resigned = resignWithTestkit(xxrDsc)
        for ((s, why) in bad) assertTrue(why in proofInvalid(resigned, s), "$why: ${proofInvalid(resigned, s)}")
        // A point off the curve, and one outside the field: refused by the platform check, not trusted.
        assertTrue("does not verify" in proofInvalid(resigned, signerWith(b64u(x), b64u(y.copyOf().also { it[31] = (it[31] + 1).toByte() }))))
        assertTrue("does not verify" in proofInvalid(resigned, signerWith(b64u(ByteArray(32) { -1 }), b64u(y))))
        // Signatures that are neither DER nor r||s, or DER whose r||s does not verify.
        val header = jwsOf(xxrDsc).substringBefore("..")
        assertTrue("neither DER" in proofInvalid(withJws(xxrDsc, "$header..${b64u(ByteArray(70) { 0x30 })}")))
        assertTrue("does not verify" in proofInvalid(withJws(xxrDsc, "$header..${b64u(ByteArray(64) { 0x30 })}")))
        assertTrue("does not verify" in proofInvalid(withJws(xxrDsc, "$header..${b64u(ByteArray(64) { 0x31 })}")))
        assertTrue("base64url" in proofInvalid(withJws(xxrDsc, "$header..")))
        assertTrue("base64url" in proofInvalid(withJws(xxrDsc, "!!..AAAA")))
        assertTrue("JWS header" in proofInvalid(withJws(xxrDsc, b64u("{".encodeToByteArray()) + "..AAAA")))
        assertTrue("UTF-8" in proofInvalid(withJws(xxrDsc, b64u(byteArrayOf(-1, -2)) + "..AAAA")))
        // A 64-byte DER signature (short r and s) is tried as DER once r||s fails.
        val short = byteArrayOf(0x30, 62, 0x02, 30) + ByteArray(30) { 1 } + byteArrayOf(0x02, 28) + ByteArray(28) { 1 }
        assertEquals(64, short.size)
        assertTrue("does not verify" in proofInvalid(withJws(xxrDsc, "$header..${b64u(short)}")))
        for (doc in listOf("{", "[]", "{}", """{"proof":{}}""", """{"proof":{"jws":"a.b.c.d"}}""", xxrDsc.replaceFirst("{", "{\"id\":\"did:x\","))) proofInvalid(doc)
    }

    /** [xxrDsc] with [from] replaced by [to] (which must occur), as JSON text. */
    private fun edit(from: String, to: String): String {
        assertTrue(from in xxrDsc, from)
        return xxrDsc.replaceFirst(from, to)
    }

    private val vmHead = """{"id":"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXR:DSC#kW/6VnwPRKI=","type":"JsonWebKey2020","controller":"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXR","""
    private val jwkHead = """"publicKeyJwk":{"""

    @Test fun `STT-TRU-006 STT-GEN-006 the unified profile's document shapes, and what it refuses`() {
        fun nq(doc: String) = DidProof.documentNQuads((parseJson(doc) as Map<*, *>).filterKeys { it != "proof" })
        val ctx = """"@context":["https://www.w3.org/ns/did/v1","https://w3id.org/security/suites/jws-2020/v1","https://smart.who.int/trust/tng-context/v1"""
        val vm = """{"id":"did:web:a#k","type":"JsonWebKey2020","controller":"did:web:c","publicKeyJwk":{"kty":"EC"},"domain":{"code":"#DDCC"}}"""
        // Production and UAT contexts; plain DID URL references; duplicate quads collapse.
        assertEquals(
            listOf(
                "<did:web:a#k> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <https://w3id.org/security#JsonWebKey2020> .",
                "<did:web:a#k> <https://smart.who.int/trust/ValueSet-Domains.jsonld> <https://smart.who.int/trust/ValueSet-Domains.jsonld#DDCC> .",
                "<did:web:a#k> <https://w3id.org/security#controller> <did:web:c> .",
                "<did:web:a#k> <https://w3id.org/security#publicKeyJwk> \"{\\\"kty\\\":\\\"EC\\\"}\"^^<http://www.w3.org/1999/02/22-rdf-syntax-ns#JSON> .",
                "<did:web:a> <https://w3id.org/security#controller> <did:web:c> .",
                "<did:web:a> <https://w3id.org/security#verificationMethod> <did:web:a#k> .",
                "<did:web:a> <https://w3id.org/security#verificationMethod> <did:web:b#k> .",
                "",
            ).joinToString("\n"),
            nq("""{$ctx.jsonld"],"id":"did:web:a","controller":"did:web:c","verificationMethod":["did:web:b#k",$vm,$vm]}"""),
        )
        assertTrue("ValueSet-Domains-UAT.jsonld#DDCC" in nq("""{$ctx-UAT.jsonld"],"id":"did:web:a","controller":"did:web:c","verificationMethod":[$vm]}"""))
        // JCS: members by UTF-16 code unit; '"' and '\' escaped; arrays of strings.
        assertEquals("""{"":"","a":["x","y"],"b":"\"\\é","é":"x"}""", DidProof.jcs(parseJson("""{"é":"x","b":"\"\\é","a":["x","y"],"":""}""") as Map<*, *>))
        assertTrue(""""{\"k\":\"a\\\"b\"}"^^""" in nq(xxrDsc.replace(Regex(""""publicKeyJwk":\{[^}]*\}"""), """"publicKeyJwk":{"k":"a\\"b"}""")))

        val proofLess = xxrDsc.replace(Regex(""","proof":\{.*\}\}$"""), "}")
        val refused = listOf(
            // 1. Document keys: all required; controller a single string; verificationMethod an array.
            proofLess,
            edit(""","controller":"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXR","verificationMethod"""", ""","verificationMethod""""),
            edit(""""controller":"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXR","verificationMethod"""", """"controller":["did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXR"],"verificationMethod""""),
            xxrDsc.replace(Regex(""","verificationMethod":\[.*\],"proof""""), ""","proof""""),
            edit(""""verificationMethod":[""", """"verificationMethod":[7,"""),
            xxrDsc.replace(Regex(""""proof":\{.*\}\}$"""), """"proof":"x"}"""),
            // 2. Verification method objects: controller and publicKeyJwk required, type JsonWebKey2020, value sets {code: #fragment}.
            edit(vmHead, vmHead.replace(""""controller":"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXR",""", "")),
            xxrDsc.replace(Regex(""""publicKeyJwk":\{[^}]*\},"""), ""),
            xxrDsc.replace(Regex(""""publicKeyJwk":\{[^}]*\}"""), """"publicKeyJwk":"x""""),
            edit(""""type":"JsonWebKey2020"""", """"type":"Ed25519VerificationKey2020""""),
            edit("""{"code":"#PH4H"}""", """"#PH4H""""),
            edit("""{"code":"#PH4H"}""", """{"code":7}"""),
            edit("""{"code":"#PH4H"}""", """{"code":"PH4H"}"""),
            edit("""{"code":"#PH4H"}""", """{"code":"#"}"""),
            edit("""{"code":"#PH4H"}""", """{"code":"#a#b"}"""),
            edit("""{"code":"#PH4H"}""", """{}"""),
            // 4. JWK values: strings or arrays of strings only.
            edit(jwkHead, jwkHead + """"ext":true,"""),
            edit(jwkHead, jwkHead + """"ext":null,"""),
            edit(jwkHead, jwkHead + """"e":65537,"""),
            edit(jwkHead, jwkHead + """"o":{"a":"b"},"""),
            edit(jwkHead, jwkHead + """"key_ops":["verify",1],"""),
            // 5. IRIs: did:, printable ASCII, no forbidden characters.
            edit(""""id":"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXR:DSC",""", """"id":"https://tng-cdn-dev.who.int/XXR",""""),
            edit(""""id":"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXR:DSC",""", """"id":"did:web:a b",""""),
            edit(""""id":"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXR:DSC",""", """"id":"did:web:é",""""),
            edit(""""id":"did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXR:DSC",""", """"id":"did:web:a{b}",""""),
            // 6. Literals, every string of the JWK included (member names too): no control character, DEL or lone surrogate.
            edit(jwkHead, jwkHead + """"k":"a\tb","""),
            edit(jwkHead, jwkHead + """"k":"a${'\u007f'}b","""),
            edit(jwkHead, jwkHead + """"k":"\udc00","""),
            edit(jwkHead, jwkHead + """"k":["a\nb"],"""),
            edit(jwkHead, jwkHead + """"a\u0001":"b","""),
            // 7. A code point above U+FFFF anywhere in a line.
            edit(jwkHead, jwkHead + """"k":"\ud83d\ude00","""),
            // 11. Duplicate member names, at any depth.
            edit(jwkHead, jwkHead + """"kty":"EC","""),
            edit(""""proof":{""", """"proof":{"nonce":"a","""),
        )
        for (bad in refused) {
            val e = HcertTrust.verifyDidProof(bad, signer).err()
            assertIs<TrustError.ProofInvalid>(e, bad.take(120))
            assertTrue("does not verify" !in e.value, "refused by the profile, not the signature: ${e.value}")
        }
        // A code point above U+FFFF is refused even where both orders would agree.
        assertTrue("U+FFFF" in proofInvalid(edit(""""nonce":"z9n9""", """"nonce":"😀z9n9""")))

        // 3. Proof: domain and challenge optional; proofValue, signatureValue, expires, creator refused.
        val p = parseJson(xxrDsc).let { (it as Map<*, *>)["proof"] as Map<*, *> }.filterKeys { it != "jws" }
        val withDomain = DidProof.proofOptionsNQuads(p + mapOf("domain" to "d\"x", "challenge" to "c"))
        assertTrue("<https://w3id.org/security#domain> \"d\\\"x\" ." in withDomain && "<https://w3id.org/security#challenge> \"c\" ." in withDomain, withDomain)
        for (extra in listOf("proofValue", "signatureValue", "expires", "creator"))
            assertTrue("does not model" in proofInvalid(xxrDsc.replace("\"jws\":", "\"$extra\":\"z\",\"jws\":")), extra)
        for (bad in listOf(p - "created", p + ("type" to "Ed25519Signature2020"), p + ("proofPurpose" to "authentication"),
                p + ("nonce" to 7), p + ("nonce" to "a\nb"), p + ("verificationMethod" to "https://example.org/k")))
            assertTrue(runCatching { DidProof.proofOptionsNQuads(bad) }.isFailure, bad.toString())
        // 11. In the JWS header too.
        val sig = jwsOf(xxrDsc).substringAfter("..")
        assertTrue("twice" in proofInvalid(withJws(xxrDsc, b64u("""{"b64":false,"crit":["b64"],"alg":"ES256","alg":"ES256"}""".encodeToByteArray()) + ".." + sig)))
        // The reader refuses duplicate members and bad escapes when asked to.
        assertEquals(mapOf("a" to 2.0), parseJson("""{"a":1,"a":2}"""))
        assertTrue(runCatching { parseJson("""{"a":1,"a":2}""", rejectDuplicates = true) }.isFailure)
        for (bad in listOf("\"\\u+123\"", "\"\\u12\"", "\"\\u-001\"")) assertTrue(runCatching { parseJson(bad) }.isFailure, bad)
    }

    @Test fun `STT-TRU-006 STT-GEN-006 the signer's key controller, and DER signatures, are held to the unified profile`() {
        // 8. A signer key's controller, when given, is the signer.
        HcertTrust.verifyDidProof(xxrDsc, signer).ok() // WHO's signing DID key names the DID itself
        assertTrue("controller" in proofInvalid(xxrDsc, signer.replace(
            "\"controller\": \"$signerId\",\n            \"publicKeyJwk\"", "\"controller\": \"did:web:other\",\n            \"publicKeyJwk\"")))
        // 9. DER is strict: a non-minimal INTEGER or a long-form length is not DER.
        val (header, derB64) = jwsOf(xxrDsc).split("..")
        val der = Base64Std.decode(derB64)
        val rLen = der[3].toInt()
        val nonMinimal = byteArrayOf(0x30, (der[1] + 1).toByte(), 0x02, (rLen + 1).toByte(), 0) + der.copyOfRange(4, der.size)
        EcdsaSignature.derToRaw(nonMinimal) // the lenient COSE parser would take it
        assertTrue("neither DER" in proofInvalid(withJws(xxrDsc, "$header..${b64u(nonMinimal)}")))
        val longForm = byteArrayOf(0x30, 0x81.toByte(), der[1]) + der.copyOfRange(2, der.size)
        assertTrue("neither DER" in proofInvalid(withJws(xxrDsc, "$header..${b64u(longForm)}")))
        val negative = der.copyOf().also { it[4] = (it[4].toInt() or 0x80).toByte() }
        assertTrue("neither DER" in proofInvalid(withJws(xxrDsc, "$header..${b64u(negative)}")))
        for (cut in listOf(der.copyOf(7), der.copyOf(der.size - 1), der + byteArrayOf(0)))
            assertTrue("neither DER" in proofInvalid(withJws(xxrDsc, "$header..${b64u(cut)}")))
    }
}
