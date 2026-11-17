package who.smart.trust.core

import who.smart.trust.HcertResult
import who.smart.trust.trust.Trust
import who.smart.trust.trust.TrustError
import who.smart.trust.trust.TrustStore
import who.smart.trust.trust.TrustedDsc
import who.smart.trust.types.Kid

/**
 * DSCs the host has loaded. No I/O. Lookup returns every DSC with the kid;
 * kids are computed from the DER, never taken from a list's labels.
 * A DID document is added whole or not at all, and only after its proof
 * verifies when added with [addVerifiedDidDocument].
 * [STT-TRU-001, STT-TRU-002, STT-TRU-005, STT-TRU-006, STT-KID-002, STT-GEN-012]
 */
class HcertTrustStore : TrustStore {
    private val dscs = mutableListOf<TrustedDsc>()

    /** Loaded from the GDHCN Trust Domain code system; null until loaded. [STT-SEL-006] */
    private var domains: Set<String>? = null

    /**
     * Reads the codes of a FHIR CodeSystem, as the GDHCN Trust Domain code
     * systems (production, UAT, DEV) publish them. Nested concepts count too.
     */
    override fun loadTrustDomains(codesystemJson: String): HcertResult<Int, TrustError> {
        val doc = try {
            parseJson(codesystemJson) as? Map<*, *>
        } catch (e: IllegalArgumentException) {
            return HcertResult.Err(TrustError.Parse(e.message ?: "invalid JSON"))
        } ?: return HcertResult.Err(TrustError.Parse("CodeSystem is not a JSON object"))
        if (doc["resourceType"] != "CodeSystem") return HcertResult.Err(TrustError.Parse("not a FHIR CodeSystem"))
        val codes = mutableSetOf<String>()
        fun walk(concepts: Any?) {
            for (c in concepts as? List<*> ?: return) {
                val m = c as? Map<*, *> ?: continue
                (m["code"] as? String)?.let { codes += it }
                walk(m["concept"])
            }
        }
        walk(doc["concept"])
        if (codes.isEmpty()) return HcertResult.Err(TrustError.Parse("CodeSystem has no concepts"))
        domains = codes
        return HcertResult.Ok(codes.size)
    }

    override fun trustDomains(): List<String> = domains?.sorted() ?: emptyList()

    private fun add(der: ByteArray, domain: String? = null, participant: String? = null): HcertResult<Int, TrustError> {
        if (dscs.any { it.der.contentEquals(der) }) return HcertResult.Ok(0)
        val info = try {
            Platform.certificate(der)
        } catch (e: Exception) {
            return HcertResult.Err(TrustError.Parse("not an X.509 certificate: ${e.message}"))
        }
        dscs += TrustedDsc(der, HcertCose.kidFromDsc(der), info.country, info.notBefore, info.notAfter, info.extendedKeyUsages, domain, participant)
        return HcertResult.Ok(1)
    }

    override fun addDer(der: ByteArray): HcertResult<Int, TrustError> = add(der)

    override fun addPem(pem: String): HcertResult<Int, TrustError> {
        val blocks = try {
            Pem.blocks(pem)
        } catch (e: IllegalArgumentException) {
            return HcertResult.Err(TrustError.Parse("bad base64 in a PEM block"))
        }
        if (blocks.isEmpty()) return HcertResult.Err(TrustError.Parse("no CERTIFICATE block"))
        var n = 0
        for (b in blocks) when (val r = add(b)) {
            is HcertResult.Ok -> n += r.value
            is HcertResult.Err -> return r
        }
        return HcertResult.Ok(n)
    }

    /**
     * GDHCN DID trustlist v2 (embedded or reference variant): each
     * verificationMethod object with publicKeyJwk.x5c contributes its first
     * certificate. DID URL references, as the reference variant lists, are
     * the host's to fetch and load. Trust domain and participant come from
     * the `trustlist:<domain>:<participant>:<usage>` DID path; "-" is the
     * wildcard. Once trust domains are loaded, a named domain must be one of
     * them.
     */
    override fun addDidDocument(json: String): HcertResult<Int, TrustError> {
        val doc = try {
            parseJson(json) as? Map<*, *>
        } catch (e: IllegalArgumentException) {
            return HcertResult.Err(TrustError.Parse(e.message ?: "invalid JSON"))
        } ?: return HcertResult.Err(TrustError.Parse("DID document is not a JSON object"))
        return addDid(doc)
    }

    /** [addDidDocument] once [DidProof] has verified the document against [signer]. [STT-TRU-006] */
    override fun addVerifiedDidDocument(json: String, signer: String): HcertResult<Int, TrustError> =
        when (val v = DidProof.verify(json, signer)) {
            is HcertResult.Ok -> addDid(v.value)
            is HcertResult.Err -> v
        }

    /** All of the document's DSCs or, on any error, none of them. */
    private fun addDid(doc: Map<*, *>): HcertResult<Int, TrustError> {
        val before = dscs.size
        val r = addDidMethods(doc)
        if (r is HcertResult.Err) while (dscs.size > before) dscs.removeAt(dscs.size - 1)
        return r
    }

    private fun addDidMethods(doc: Map<*, *>): HcertResult<Int, TrustError> {
        val methods = doc["verificationMethod"] as? List<*> ?: return HcertResult.Err(TrustError.Parse("no verificationMethod array"))
        // A domain the loaded code system does not hold refuses the whole
        // document before anything is added. [STT-SEL-006]
        domains?.let { known ->
            val named = methods.mapNotNull { m -> pathOf((m as? Map<*, *>)?.get("id") as? String ?: doc["id"] as? String).first }
            named.firstOrNull { it !in known }?.let { return HcertResult.Err(TrustError.UnknownTrustDomain(it)) }
        }
        var n = 0
        for (m in methods) {
            val vm = m as? Map<*, *> ?: continue
            val x5c = (vm["publicKeyJwk"] as? Map<*, *>)?.get("x5c") as? List<*> ?: continue
            val first = x5c.firstOrNull() as? String ?: return HcertResult.Err(TrustError.Parse("x5c entry is not a string"))
            val der = try {
                Base64Std.decode(first)
            } catch (e: IllegalArgumentException) {
                return HcertResult.Err(TrustError.Parse("x5c entry is not base64"))
            }
            val (domain, participant) = pathOf(vm["id"] as? String ?: doc["id"] as? String)
            when (val r = add(der, domain, participant)) {
                is HcertResult.Ok -> n += r.value
                is HcertResult.Err -> return r
            }
        }
        return HcertResult.Ok(n)
    }

    private fun pathOf(did: String?): Pair<String?, String?> {
        val parts = did?.substringBefore('#')?.split(':') ?: return null to null
        val at = parts.indexOf("trustlist")
        fun level(i: Int) = parts.getOrNull(at + i)?.takeIf { it != "-" && it.isNotEmpty() }
        return if (at < 0) null to null else level(1) to level(2)
    }

    override fun candidates(k: Kid): List<TrustedDsc> = dscs.filter { it.kid.contentEquals(k) }
    override fun size(): Int = dscs.size
    override fun clear() = dscs.clear()
    override fun close() {}
}

object HcertTrust : Trust {
    override fun verifyDidProof(document: String, signer: String): HcertResult<Unit, TrustError> =
        when (val v = DidProof.verify(document, signer)) {
            is HcertResult.Ok -> HcertResult.Ok(Unit)
            is HcertResult.Err -> v
        }

    override fun newTrustStore(): TrustStore = HcertTrustStore()
}
