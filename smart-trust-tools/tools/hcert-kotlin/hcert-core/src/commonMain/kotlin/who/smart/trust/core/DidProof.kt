package who.smart.trust.core

import who.smart.trust.HcertResult
import who.smart.trust.trust.TrustError

/**
 * The JsonWebSignature2020 proof of a GDHCN trust list DID document, as
 * WorldHealthOrganization/tng-key-distribution makes it (ld-signatures-java
 * 1.11.0, URDNA2015 by titanium). [STT-TRU-006]
 *
 * Not a JSON-LD processor: the document shapes that service emits are mapped
 * to RDF here directly, with the IRIs of the pinned contexts it signs with
 * (did/v1, jws-2020/v1, the tng-context for production, UAT or DEV, and
 * security v3 for the proof options). Neither graph has more than one blank
 * node, so URDNA2015 reduces to serialising, de-duplicating and sorting the
 * quads. Anything outside those shapes (another key, another type, another
 * context, a number in a JWK, a relative IRI) is refused, never dropped: a
 * term that a processor would map and this code would not must not be able
 * to change the signed bytes unnoticed.
 *
 * The profile is the one the Rust library implements too, so both give the
 * same verdict on any input [STT-GEN-006]: every document key, VM controller
 * and publicKeyJwk required; JWK values strings or arrays of strings; IRIs
 * printable-ASCII DIDs; no code point above U+FFFF; proofValue and
 * signatureValue refused; strict DER; duplicate members refused.
 *
 * The signature is over ASCII(header) || "." || SHA-256(options N-Quads) ||
 * SHA-256(document N-Quads), a detached b64:false ES256 JWS; the service
 * writes it DER-encoded rather than as RFC 7518's r||s, so both are taken.
 */
internal object DidProof {
    private class Invalid(message: String) : Exception(message)

    private fun fail(message: String): Nothing = throw Invalid(message)

    private const val SEC = "https://w3id.org/security#"
    private const val RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    private const val RDF_JSON = "http://www.w3.org/1999/02/22-rdf-syntax-ns#JSON"
    private const val XSD_DATETIME = "http://www.w3.org/2001/XMLSchema#dateTime"
    private const val DC_CREATED = "http://purl.org/dc/terms/created"

    private const val DID_V1 = "https://www.w3.org/ns/did/v1"
    private const val JWS_2020_V1 = "https://w3id.org/security/suites/jws-2020/v1"
    private const val TNG_CONTEXT = "https://smart.who.int/trust/tng-context/"

    /** The tng-context per environment: its URL's file name and the suffix of its value set IRIs. */
    private val TNG_ENVIRONMENTS = mapOf("v1.jsonld" to "", "v1-UAT.jsonld" to "-UAT", "v1-DEV.jsonld" to "-DEV")

    /** tng-context term to value set name; the IRI is https://smart.who.int/trust/ValueSet-<name><env>.jsonld. */
    private val VALUE_SETS = linkedMapOf("domain" to "Domains", "participant" to "Participants", "keyusage" to "KeyUsage")

    private val DOC_KEYS = setOf("@context", "id", "controller", "verificationMethod")
    private val VM_KEYS = setOf("id", "type", "controller", "publicKeyJwk") + VALUE_SETS.keys
    private val PROOF_KEYS = setOf("type", "created", "nonce", "proofPurpose", "verificationMethod", "domain", "challenge", "jws")

    /** The only protected header the profile uses. */
    private val JWS_HEADER = mapOf("b64" to false, "crit" to listOf("b64"), "alg" to "ES256")

    fun verify(document: String, signer: String): HcertResult<Map<*, *>, TrustError> = try {
        val doc = parseObject(document, "DID document")
        verifyParsed(doc, parseObject(signer, "signer DID document"))
        HcertResult.Ok(doc)
    } catch (e: Invalid) {
        HcertResult.Err(TrustError.ProofInvalid(e.message ?: "proof invalid"))
    }

    private fun parseObject(json: String, what: String): Map<*, *> = try {
        parseJson(json, rejectDuplicates = true) as? Map<*, *>
    } catch (e: IllegalArgumentException) {
        fail("$what: ${e.message}")
    } ?: fail("$what is not a JSON object")

    private fun verifyParsed(doc: Map<*, *>, signer: Map<*, *>) {
        // Every key the document must have, the proof among them, before anything else.
        exactKeys(doc, DOC_KEYS + "proof", DOC_KEYS + "proof", "DID document")
        val proof = doc["proof"] as? Map<*, *> ?: fail("proof is not an object")
        val jws = proof["jws"] as? String ?: fail("proof has no jws string")
        val parts = jws.split('.')
        if (parts.size != 3 || parts[1].isNotEmpty()) fail("jws is not a detached JWS (header..signature)")
        val header = parts[0]
        val headerJson = try {
            parseJson(b64url(header, "JWS header").decodeToString(throwOnInvalidSequence = true), rejectDuplicates = true)
        } catch (e: IllegalArgumentException) {
            fail("JWS header: ${e.message}")
        } catch (e: CharacterCodingException) {
            fail("JWS header is not UTF-8")
        }
        if (headerJson != JWS_HEADER) fail("JWS header is not {\"b64\":false,\"crit\":[\"b64\"],\"alg\":\"ES256\"}")

        val docHash = Platform.sha256(documentNQuads(doc.filterKeys { it != "proof" }).encodeToByteArray())
        val optsHash = Platform.sha256(proofOptionsNQuads(proof.filterKeys { it != "jws" }).encodeToByteArray())
        val signingInput = header.encodeToByteArray() + '.'.code.toByte() + optsHash + docHash

        val (x, y) = signerKey(signer, proof["verificationMethod"] as String)
        val sig = b64url(parts[2], "JWS signature")
        // 64 bytes is tried as r||s; anything starting 0x30 as strict DER. Either verifying is enough.
        val asRaw = sig.size == 64 && Platform.verifyEs256Point(x, y, signingInput, sig)
        val der = if (!asRaw && sig[0] == 0x30.toByte()) strictDer(sig) else null
        if (!asRaw && der == null && sig.size != 64) fail("signature is neither DER nor 64-byte r||s")
        if (!asRaw && (der == null || !Platform.verifyEs256Point(x, y, signingInput, der)))
            fail("the signature does not verify with the signer's key")
    }

    /**
     * ECDSA-Sig-Value in strict DER (short-form lengths, minimal positive
     * INTEGERs of at most 32 significant bytes) as 64-byte r||s; null otherwise.
     */
    private fun strictDer(b: ByteArray): ByteArray? {
        fun u(i: Int) = b[i].toInt() and 0xff
        if (b.size < 8 || u(0) != 0x30 || u(1) != b.size - 2) return null
        val out = ByteArray(64)
        var p = 2
        for (k in 0..1) {
            if (p + 2 > b.size || u(p) != 0x02) return null
            val len = u(p + 1)
            p += 2
            if (len == 0 || len > 33 || p + len > b.size) return null
            if (u(p) and 0x80 != 0) return null // negative
            if (len > 1 && u(p) == 0 && u(p + 1) and 0x80 == 0) return null // not minimal
            val v = b.copyOfRange(p, p + len).let { if (it.size == 33) it.copyOfRange(1, 33) else it }
            v.copyInto(out, k * 32 + 32 - v.size)
            p += len
        }
        return if (p == b.size) out else null
    }

    /** The P-256 point of the signer's verification method whose id is exactly [vmId]. */
    private fun signerKey(signer: Map<*, *>, vmId: String): Pair<ByteArray, ByteArray> {
        if (signer["id"] != vmId.substringBefore('#')) fail("the signer document is not $vmId's DID")
        val methods = (signer["verificationMethod"] as? List<*> ?: fail("signer has no verificationMethod array"))
            .filter { (it as? Map<*, *>)?.get("id") == vmId }
        val vm = methods.singleOrNull() as? Map<*, *> ?: fail("signer has ${methods.size} verification methods with id $vmId")
        if (vm["type"] != "JsonWebKey2020") fail("signer key is not a JsonWebKey2020")
        if ("controller" in vm && vm["controller"] != signer["id"]) fail("signer key's controller is not the signer")
        val jwk = vm["publicKeyJwk"] as? Map<*, *> ?: fail("signer key has no publicKeyJwk")
        if (jwk["kty"] != "EC" || jwk["crv"] != "P-256") fail("signer key is not an EC P-256 JWK")
        if ("alg" in jwk && jwk["alg"] != "ES256") fail("signer key is not for ES256")
        fun coordinate(name: String): ByteArray {
            val b = b64url(jwk[name] as? String ?: fail("signer JWK has no $name"), "signer JWK $name")
            return when {
                b.size == 32 -> b
                b.size == 33 && b[0] == 0.toByte() -> b.copyOfRange(1, 33)
                else -> fail("signer JWK $name is ${b.size} bytes, not 32")
            }
        }
        return coordinate("x") to coordinate("y")
    }

    private fun b64url(s: String, what: String): ByteArray {
        if (s.isEmpty() || !s.all { it in 'A'..'Z' || it in 'a'..'z' || it in '0'..'9' || it == '-' || it == '_' } || s.length % 4 == 1)
            fail("$what is not unpadded base64url")
        return try {
            Base64Std.decode(s)
        } catch (e: IllegalArgumentException) {
            fail("$what is not canonical base64url: ${e.message}") // e.g. non-zero pad bits
        }
    }

    // ---- canonical N-Quads --------------------------------------------------

    /** URDNA2015 N-Quads of a trust list DID document without its proof. */
    fun documentNQuads(doc: Map<*, *>): String {
        exactKeys(doc, DOC_KEYS, DOC_KEYS, "DID document")
        val ctx = doc["@context"] as? List<*> ?: fail("@context is not an array")
        val tng = (ctx.getOrNull(2) as? String)?.takeIf { it.startsWith(TNG_CONTEXT) }?.removePrefix(TNG_CONTEXT)
        val env = TNG_ENVIRONMENTS[tng]
        if (ctx.size != 3 || ctx[0] != DID_V1 || ctx[1] != JWS_2020_V1 || env == null)
            fail("@context is not [did/v1, jws-2020/v1, tng-context v1, v1-UAT or v1-DEV]")
        val q = mutableListOf<String>()
        val id = did(doc["id"], "id")
        q += quad(id, SEC + "controller", did(doc["controller"], "controller"))
        val methods = doc["verificationMethod"] as? List<*> ?: fail("verificationMethod is not an array")
        for (m in methods) {
            if (m is String) {
                q += quad(id, SEC + "verificationMethod", did(m, "verificationMethod"))
                continue
            }
            val vm = m as? Map<*, *> ?: fail("verificationMethod entry is neither a DID URL nor an object")
            exactKeys(vm, VM_KEYS, setOf("id", "type", "controller", "publicKeyJwk"), "verificationMethod")
            if (vm["type"] != "JsonWebKey2020") fail("verificationMethod type is not JsonWebKey2020")
            val v = did(vm["id"], "verificationMethod id")
            q += quad(id, SEC + "verificationMethod", v)
            q += quad(v, RDF_TYPE, iri(SEC + "JsonWebKey2020"))
            q += quad(v, SEC + "controller", did(vm["controller"], "verificationMethod controller"))
            val jwk = vm["publicKeyJwk"] as? Map<*, *> ?: fail("publicKeyJwk is not an object")
            q += quad(v, SEC + "publicKeyJwk", literal(jcs(jwk)) + "^^" + iri(RDF_JSON))
            for ((term, name) in VALUE_SETS) {
                if (term !in vm) continue
                val set = vm[term] as? Map<*, *> ?: fail("$term is not an object")
                exactKeys(set, setOf("code"), setOf("code"), term)
                val code = set["code"] as? String ?: fail("$term code is not a string")
                // "#CODE" resolved against the scoped @base ".../ValueSet-<name><env>.jsonld#".
                if (!code.startsWith("#") || code.length < 2 || code.indexOf('#', 1) >= 0) fail("$term code is not a #fragment")
                val base = "https://smart.who.int/trust/ValueSet-$name$env.jsonld"
                q += quad(v, base, iri(base + code))
            }
        }
        return canonical(q)
    }

    /** URDNA2015 N-Quads of the proof options: the proof without jws, in the security v3 context. */
    fun proofOptionsNQuads(proof: Map<*, *>): String {
        exactKeys(proof, PROOF_KEYS - "jws", setOf("type", "created", "proofPurpose", "verificationMethod"), "proof")
        if (proof["type"] != "JsonWebSignature2020") fail("proof type is not JsonWebSignature2020")
        if (proof["proofPurpose"] != "assertionMethod") fail("proofPurpose is not assertionMethod")
        val b = "_:c14n0"
        val q = mutableListOf(
            "$b ${iri(RDF_TYPE)} ${iri(SEC + "JsonWebSignature2020")}",
            // The lexical form as given: a processor does not normalise a typed literal.
            "$b ${iri(DC_CREATED)} ${literal(string(proof["created"], "created"))}^^${iri(XSD_DATETIME)}",
            "$b ${iri(SEC + "proofPurpose")} ${iri(SEC + "assertionMethod")}",
            "$b ${iri(SEC + "verificationMethod")} ${did(proof["verificationMethod"], "proof verificationMethod")}",
        )
        for (term in listOf("nonce", "domain", "challenge")) {
            if (term in proof) q += "$b ${iri(SEC + term)} ${literal(string(proof[term], term))}"
        }
        return canonical(q)
    }

    private fun exactKeys(m: Map<*, *>, allowed: Set<String>, required: Set<String>, what: String) {
        val extra = m.keys.filter { it !in allowed }
        if (extra.isNotEmpty()) fail("$what has a member the profile does not model: ${extra.joinToString()}")
        val missing = required.filter { it !in m }
        if (missing.isNotEmpty()) fail("$what lacks ${missing.joinToString()}")
    }

    private fun string(v: Any?, what: String): String = v as? String ?: fail("$what is not a string")

    private fun quad(s: String, p: String, o: String) = "$s ${iri(p)} $o"

    /**
     * Sorted by code point, de-duplicated, each line ending " .\n". A line
     * with a code point above U+FFFF is refused: there, code point order (the
     * standard's) and UTF-16 order (Java's and JavaScript's processors') can
     * differ, so both libraries refuse rather than pick one. Below it, the
     * two orders are the same, and that is Kotlin's String order.
     */
    private fun canonical(quads: List<String>): String {
        val lines = quads.map { "$it .\n" }.distinct()
        if (lines.any { l -> l.any { it.isSurrogate() } }) fail("N-Quads with a code point above U+FFFF")
        return lines.sorted().joinToString("")
    }

    /** An absolute DID or DID URL as an N-Quads IRI; anything else is refused, never resolved. */
    private fun did(v: Any?, what: String): String {
        val s = v as? String ?: fail("$what is not a string")
        if (!s.startsWith("did:")) fail("$what is not a DID")
        return iri(s)
    }

    private fun iri(s: String): String {
        if (s.any { it <= ' ' || it >= '\u007f' || it in "<>\"{}|^`\\" }) fail("not a printable ASCII IRI: $s")
        return "<$s>"
    }

    /** An N-Quads string literal; control characters are refused, as processors escape them differently. */
    private fun literal(s: String): String {
        checkLiteral(s)
        return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
    }

    private fun checkLiteral(s: String) {
        if (s.any { it < ' ' || it == '\u007f' } || hasLoneSurrogate(s)) fail("literal with a control character, DEL or lone surrogate")
    }

    private fun hasLoneSurrogate(s: String): Boolean {
        var i = 0
        while (i < s.length) {
            val c = s[i]
            if (c.isHighSurrogate() && i + 1 < s.length && s[i + 1].isLowSurrogate()) i += 2
            else if (c.isSurrogate()) return true
            else i++
        }
        return false
    }

    // ---- RFC 8785 ------------------------------------------------------------

    /**
     * JSON Canonicalization Scheme for a JWK whose members are strings or
     * arrays of strings, the only values the profile models. Every string,
     * member names included, is checked as a literal first, so only '"' and
     * '\\' need escaping. Members sort by UTF-16 code unit (Kotlin's String
     * order), as RFC 8785 says.
     */
    fun jcs(jwk: Map<*, *>): String = jwk.keys.map { it as String }.sorted().joinToString(",", "{", "}") { k ->
        jcsString(k) + ":" + when (val v = jwk[k]) {
            is String -> jcsString(v)
            is List<*> -> v.joinToString(",", "[", "]") { jcsString(it as? String ?: fail("publicKeyJwk $k holds a non-string")) }
            else -> fail("publicKeyJwk $k is neither a string nor an array of strings")
        }
    }

    private fun jcsString(s: String): String {
        checkLiteral(s)
        return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
    }
}
