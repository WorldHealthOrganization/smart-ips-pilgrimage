@file:OptIn(ExperimentalJsExport::class)
@file:Suppress("unused", "UNUSED_PARAMETER")

package who.smart.trust.core

import who.smart.trust.HcertResult
import who.smart.trust.cose.Base64Alphabet
import who.smart.trust.cose.CoseError
import who.smart.trust.cose.Sign1
import who.smart.trust.codec.CodecError
import who.smart.trust.dvc.DvcMin
import who.smart.trust.dvc.DvcMinVaccineDetails
import who.smart.trust.issuer.IssueError
import who.smart.trust.issuer.IssueRequest
import who.smart.trust.issuer.PendingSignature
import who.smart.trust.issuer.Validity
import who.smart.trust.payloads.Payload
import who.smart.trust.payloads.RawPayload
import who.smart.trust.subclaims.PayloadKind
import who.smart.trust.trust.TrustError
import who.smart.trust.trust.TrustedDsc
import who.smart.trust.types.CoseAlgorithm
import who.smart.trust.types.DecodeLimits
import who.smart.trust.types.Diagnostic
import who.smart.trust.types.Subclaim
import who.smart.trust.types.ValidationIssue
import who.smart.trust.verifier.VerificationFailure
import who.smart.trust.verifier.VerificationResult
import who.smart.trust.verifier.VerifierOptions
import who.smart.trust.vhl.SignatureRequest
import who.smart.trust.vhl.VhlError
import who.smart.trust.vhl.VhlPayload

/*
 * The `hcert` world of api/wit, in the shape jco gives a component's
 * exports (STT-GEN-011, STT-TST-007): one object per interface, records as
 * plain objects with camelCase fields, enums as kebab-case strings,
 * variants as { tag, val }, list<u8> as Uint8Array, s64 as bigint, option
 * as undefined, resources as classes, and a result's error thrown as an
 * Error whose `payload` is the error variant. The TypeScript in
 * api/generated/ts describes it; the same test suite drives this and the
 * jco-transpiled Rust component. Only conversions are here: every call
 * goes to the Kotlin library.
 */

// ---- conversions -------------------------------------------------------

private fun obj(vararg fields: Pair<String, Any?>): dynamic {
    val o: dynamic = js("({})")
    for ((k, v) in fields) if (v != null) o[k] = v
    return o
}

private val toUint8: (ByteArray) -> dynamic = js("(function (a) { return new Uint8Array(a.buffer, a.byteOffset, a.length).slice(); })")
private val toInt8: (dynamic) -> ByteArray = js("(function (u) { return new Int8Array(u.buffer, u.byteOffset, u.length).slice(); })")
private val bigint: (String) -> dynamic = js("(function (s) { return BigInt(s); })")
private val componentError: (dynamic) -> Throwable = js(
    "(function (p) { var e = new Error(typeof p.val === 'string' ? p.tag + ': ' + p.val : p.tag); e.name = 'ComponentError'; e.payload = p; return e; })",
)

private fun bytesOut(b: ByteArray): dynamic = toUint8(b)
private fun bytesIn(u: dynamic): ByteArray = toInt8(u)
private fun s64Out(v: Long): dynamic = bigint(v.toString())
private fun s64In(v: dynamic): Long = (v.toString() as String).toLong()
private fun kebab(name: String) = name.lowercase().replace('_', '-')
private fun variant(tag: String, value: Any? = null): dynamic = if (value == null) obj("tag" to tag) else obj("tag" to tag, "val" to value)
private fun fail(payload: dynamic): Nothing = throw componentError(payload)
private fun <T> array(items: List<T>, f: (T) -> Any?): dynamic {
    val a: dynamic = js("[]")
    for (i in items) a.push(f(i))
    return a
}
private fun <T> listIn(a: dynamic, f: (dynamic) -> T): List<T> = (0 until (a.length as Int)).map { f(a[it]) }
private fun optStr(v: dynamic): String? = if (v == null || v == undefined) null else v as String

private fun limitsIn(l: dynamic) = DecodeLimits(l.maxInputChars as Int, l.maxInflatedBytes as Int, l.maxDepth as Int, l.maxItems as Int, l.maxStringBytes as Int)
private fun algOut(a: CoseAlgorithm) = kebab(a.name)
private fun algIn(a: dynamic) = CoseAlgorithm.valueOf((a as String).uppercase())
private fun issueOut(i: ValidationIssue) = obj("path" to i.path, "code" to i.code, "message" to i.message, "severity" to kebab(i.severity.name))
private fun issuesOut(v: List<ValidationIssue>) = array(v) { issueOut(it) }
private fun diagOut(d: Diagnostic) = obj("step" to kebab(d.step.name), "severity" to kebab(d.severity.name), "message" to d.message)
private fun subclaimOut(s: Subclaim) = obj("key" to s.key, "title" to s.title, "logicalModel" to s.logicalModel)
private fun kindIn(k: dynamic) = PayloadKind.valueOf((k as String).uppercase().replace('-', '_'))

private fun codecErr(e: CodecError): dynamic = when (e) {
    is CodecError.Base45Invalid -> variant("base45-invalid", e.value)
    is CodecError.InflateFailed -> variant("inflate-failed", e.value)
    is CodecError.LimitExceeded -> variant("limit-exceeded", e.value)
    is CodecError.CborMalformed -> variant("cbor-malformed", e.value)
    CodecError.BadPrefix -> variant("bad-prefix")
    is CodecError.UnsupportedContextVersion -> variant("unsupported-context-version", e.value)
}
private fun coseErr(e: CoseError): dynamic = when (e) {
    is CoseError.Malformed -> variant("malformed", e.value)
    is CoseError.HeaderInvalid -> variant("header-invalid", e.value)
    is CoseError.UnsupportedAlgorithm -> variant("unsupported-algorithm", e.value)
    is CoseError.BadSignatureFormat -> variant("bad-signature-format", e.value)
    CoseError.SignatureInvalid -> variant("signature-invalid")
    is CoseError.BadCertificate -> variant("bad-certificate", e.value)
}
private fun trustErr(e: TrustError): dynamic = when (e) {
    is TrustError.Parse -> variant("parse", e.value)
    is TrustError.UnknownTrustDomain -> variant("unknown-trust-domain", e.value)
    is TrustError.ProofInvalid -> variant("proof-invalid", e.value)
}
private fun issueErr(e: IssueError): dynamic = when (e) {
    is IssueError.PayloadInvalid -> variant("payload-invalid", issuesOut(e.value))
    IssueError.NoPayload -> variant("no-payload")
    is IssueError.DuplicateSubclaim -> variant("duplicate-subclaim", e.value)
    is IssueError.DevelopmentSubclaimNotAllowed -> variant("development-subclaim-not-allowed", e.value)
    is IssueError.UnknownSubclaim -> variant("unknown-subclaim", e.value)
    IssueError.ValidityOutsideDsc -> variant("validity-outside-dsc")
    is IssueError.BadCertificate -> variant("bad-certificate", e.value)
    is IssueError.BadSignatureFormat -> variant("bad-signature-format", e.value)
}
private fun vhlErr(e: VhlError): dynamic = when (e) {
    is VhlError.Invalid -> variant("invalid", issuesOut(e.value))
    is VhlError.NotAVhlink -> variant("not-a-vhlink", e.value)
    is VhlError.Manifest -> variant("manifest", e.value)
    is VhlError.DecryptFailed -> variant("decrypt-failed", e.value)
    is VhlError.Unsupported -> variant("unsupported", e.value)
}

private inline fun <T, E> HcertResult<T, E>.orThrow(err: (E) -> dynamic): T = when (this) {
    is HcertResult.Ok -> value
    is HcertResult.Err -> fail(err(error))
}

private fun extensionsOut(x: List<Pair<String, ByteArray>>) = array(x) { (k, v) -> arrayOf<Any?>(k, bytesOut(v)) }
private fun dvcOut(p: DvcMin): dynamic = obj(
    "n" to p.n, "dob" to p.dob, "s" to p.s, "nt" to p.nt, "id" to p.id, "dt" to p.dt, "gn" to p.gn,
    "vx" to obj("vp" to p.vx.vp, "dv" to p.vx.dv, "cn" to p.vx.cn, "is" to p.vx.`is`, "bo" to p.vx.bo),
    "v" to p.v, "extensions" to extensionsOut(p.extensions),
)
private fun dvcIn(p: dynamic) = DvcMin(
    n = p.n as String, dob = p.dob as String, s = p.s as String, nt = p.nt as String,
    id = optStr(p.id), dt = optStr(p.dt), gn = optStr(p.gn),
    vx = DvcMinVaccineDetails(p.vx.vp as String, p.vx.dv as String, optStr(p.vx.cn), optStr(p.vx["is"]), p.vx.bo as String),
    v = p.v as String,
    extensions = if (p.extensions == null || p.extensions == undefined) emptyList() else listIn(p.extensions) { e -> (e[0] as String) to bytesIn(e[1]) },
)
private fun vhlOut(p: VhlPayload): dynamic = obj(
    "url" to p.url, "key" to p.key, "exp" to p.exp?.let { s64Out(it) }, "flag" to p.flag, "label" to p.label, "v" to p.v, "fhirBaseUrl" to p.fhirBaseUrl,
)
private fun vhlIn(p: dynamic) = VhlPayload(
    url = p.url as String, key = p.key as String,
    exp = if (p.exp == null || p.exp == undefined) null else s64In(p.exp),
    flag = optStr(p.flag), label = optStr(p.label),
    v = if (p.v == null || p.v == undefined) null else p.v as Int,
    fhirBaseUrl = optStr(p.fhirBaseUrl),
)
private fun payloadOut(p: Payload): dynamic = when (p) {
    is Payload.DvcMin -> variant("dvc-min", dvcOut(p.value))
    is Payload.Vhl -> variant("vhl", vhlOut(p.value))
    is Payload.Raw -> variant("raw", obj("subclaim" to p.value.subclaim, "cbor" to bytesOut(p.value.cbor)))
}
private fun payloadIn(p: dynamic): Payload = when (p.tag as String) {
    "dvc-min" -> Payload.DvcMin(dvcIn(p["val"]))
    "vhl" -> Payload.Vhl(vhlIn(p["val"]))
    else -> Payload.Raw(RawPayload(p["val"].subclaim as Int, bytesIn(p["val"].cbor)))
}
private fun dscOut(d: TrustedDsc): dynamic = obj(
    "der" to bytesOut(d.der), "kid" to bytesOut(d.kid), "country" to d.country,
    "notBefore" to s64Out(d.notBefore), "notAfter" to s64Out(d.notAfter),
    "extendedKeyUsages" to array(d.extendedKeyUsages) { it }, "domain" to d.domain, "participant" to d.participant,
)
private fun failureOut(f: VerificationFailure): dynamic =
    obj("step" to kebab(f.step.name), "reason" to kebab(f.reason.name), "detail" to f.detail, "diagnostics" to array(f.diagnostics) { diagOut(it) })
private fun optionsIn(o: dynamic) = VerifierOptions(
    limitsIn(o.limits), o.clockSkewSeconds as Int,
    if (o.maxPayloads == null || o.maxPayloads == undefined) null else o.maxPayloads as Int,
)
private fun resultOut(r: VerificationResult): dynamic = when (r) {
    is VerificationResult.Verified -> r.value.let { v ->
        variant(
            "verified",
            obj(
                "iss" to v.iss, "iat" to s64Out(v.iat), "exp" to s64Out(v.exp),
                "entries" to array(v.entries) { obj("subclaim" to it.subclaim, "payload" to payloadOut(it.payload), "keyUsageAuthorised" to it.keyUsageAuthorised) },
                "dsc" to dscOut(v.dsc),
                "otherClaims" to array(v.otherClaims) { (k, x) -> arrayOf<Any?>(bytesOut(k), bytesOut(x)) },
                "diagnostics" to array(v.diagnostics) { diagOut(it) },
            ),
        )
    }
    is VerificationResult.Failed -> variant("failed", failureOut(r.value))
}

// ---- interfaces --------------------------------------------------------

@JsExport
@JsName("WitCodec")
object WitCodec {
    fun base45Encode(data: dynamic): String = HcertCodec.base45Encode(bytesIn(data))
    fun base45Decode(text: String): dynamic = bytesOut(HcertCodec.base45Decode(text).orThrow(::codecErr))
    fun zlibCompress(data: dynamic, level: Int): dynamic = bytesOut(HcertCodec.zlibCompress(bytesIn(data), level))
    fun zlibInflate(data: dynamic, maxOut: Int): dynamic = bytesOut(HcertCodec.zlibInflate(bytesIn(data), maxOut).orThrow(::codecErr))
    fun detectContext(text: String): dynamic = HcertCodec.detectContext(text).orThrow(::codecErr).let { arrayOf<Any?>(it.first, it.second) }
    fun toHc1(cose: dynamic): String = HcertCodec.toHc1(bytesIn(cose))
    fun fromHc1(text: String, limits: dynamic): dynamic = bytesOut(HcertCodec.fromHc1(text, limitsIn(limits)).orThrow(::codecErr))
    fun cborDeterministic(cbor: dynamic, limits: dynamic): dynamic = bytesOut(HcertCodec.cborDeterministic(bytesIn(cbor), limitsIn(limits)).orThrow(::codecErr))
}

@JsExport
object WitCose {
    fun kidFromDsc(dscDer: dynamic): dynamic = bytesOut(HcertCose.kidFromDsc(bytesIn(dscDer)))
    fun kidToBase64(k: dynamic, alphabet: String): String =
        HcertCose.kidToBase64(bytesIn(k), if (alphabet == "url-safe") Base64Alphabet.URL_SAFE else Base64Alphabet.STANDARD)
    fun kidFromBase64(text: String): dynamic = bytesOut(HcertCose.kidFromBase64(text).orThrow(::coseErr))
    fun parseSign1(bytes: dynamic, limits: dynamic): dynamic {
        val s = HcertCose.parseSign1(bytesIn(bytes), limitsIn(limits)).orThrow(::coseErr)
        return obj(
            "protected" to bytesOut(s.protected), "payload" to bytesOut(s.payload), "signature" to bytesOut(s.signature),
            "alg" to s.alg?.let { algOut(it) }, "kid" to s.kid?.let { bytesOut(it) },
            "kidInProtected" to s.kidInProtected, "tagged" to s.tagged,
        )
    }
    fun sigStructure(protected: dynamic, payload: dynamic): dynamic = bytesOut(HcertCose.sigStructure(bytesIn(protected), bytesIn(payload)))
    fun verifySign1(s: dynamic, dscDer: dynamic) {
        val sign1 = Sign1(
            bytesIn(s.protected), bytesIn(s.payload), bytesIn(s.signature),
            if (s.alg == null || s.alg == undefined) null else algIn(s.alg),
            if (s.kid == null || s.kid == undefined) null else bytesIn(s.kid),
            s.kidInProtected as Boolean, s.tagged as Boolean,
        )
        HcertCose.verifySign1(sign1, bytesIn(dscDer)).orThrow(::coseErr)
    }
    fun ecdsaDerToRaw(der: dynamic): dynamic = bytesOut(HcertCose.ecdsaDerToRaw(bytesIn(der)).orThrow(::coseErr))
    fun ecdsaRawToDer(raw: dynamic): dynamic = bytesOut(HcertCose.ecdsaRawToDer(bytesIn(raw)).orThrow(::coseErr))
}

/** subclaims.registry */
@JsExport
class WitRegistry {
    internal val reg = SubclaimRegistry()
    fun lookup(key: Int): dynamic = reg.lookup(key)?.let { subclaimOut(it) }
    fun register(s: dynamic) = reg.register(Subclaim(s.key as Int, s.title as String, optStr(s.logicalModel)))
    fun all(): dynamic = array(reg.all()) { subclaimOut(it) }
    fun subclaimFor(kind: String): dynamic = reg.subclaimFor(kindIn(kind))
    fun setSubclaimFor(kind: String, key: Int) = reg.setSubclaimFor(kindIn(kind), key)
}

@JsExport
object WitDvc {
    fun validate(p: dynamic): dynamic = issuesOut(HcertDvc.validate(dvcIn(p)))
    fun toCbor(p: dynamic): dynamic = bytesOut(HcertDvc.toCbor(dvcIn(p)))
    fun fromCbor(cbor: dynamic, limits: dynamic): dynamic = dvcOut(HcertDvc.fromCbor(bytesIn(cbor), limitsIn(limits)).orThrow { issuesOut(it) })
}

@JsExport
object WitVhl {
    fun validate(p: dynamic, now: dynamic): dynamic = issuesOut(HcertVhl.validate(vhlIn(p), if (now == null || now == undefined) null else s64In(now)))
    fun toVhlink(p: dynamic): String = HcertVhl.toVhlink(vhlIn(p))
    fun fromVhlink(text: String): dynamic = vhlOut(HcertVhl.fromVhlink(text).orThrow(::vhlErr))
    fun newKey(): String = HcertVhl.newKey()
    fun buildManifestRequest(p: dynamic, recipient: String, passcode: dynamic, embeddedLengthMax: dynamic): dynamic {
        val r = HcertVhl.buildManifestRequest(vhlIn(p), recipient, optStr(passcode), if (embeddedLengthMax == null || embeddedLengthMax == undefined) null else embeddedLengthMax as Int)
            .orThrow(::vhlErr)
        return obj("url" to r.url, "contentType" to r.contentType, "body" to r.body)
    }
    fun parseManifest(bundleJson: String): dynamic =
        array(HcertVhl.parseManifest(bundleJson).orThrow(::vhlErr)) { obj("url" to it.url, "reference" to it.reference, "contentType" to it.contentType, "title" to it.title) }
    fun encrypt(content: dynamic, contentType: String, key: String): String = HcertVhl.encrypt(bytesIn(content), contentType, key).orThrow(::vhlErr)
    fun decrypt(jwe: String, key: String): dynamic = HcertVhl.decrypt(jwe, key).orThrow(::vhlErr).let { obj("contentType" to it.contentType, "content" to bytesOut(it.content)) }
    fun buildSignatureBase(r: dynamic): dynamic {
        val b = HcertVhl.buildSignatureBase(
            SignatureRequest(
                r.method as String, r.authority as String, r.path as String, optStr(r.contentType),
                if (r.body == null || r.body == undefined) null else bytesIn(r.body),
                r.keyid as String, r.alg as String, s64In(r.created),
            ),
        )
        return obj("contentDigest" to b.contentDigest, "signatureInput" to b.signatureInput, "base" to bytesOut(b.base))
    }
    fun signatureHeader(signature: dynamic, alg: String): String = HcertVhl.signatureHeader(bytesIn(signature), alg).orThrow(::vhlErr)
}

/** trust: the interface's free functions. */
@JsExport
object WitTrust {
    fun verifyDidProof(document: String, signer: String) = HcertTrust.verifyDidProof(document, signer).orThrow(::trustErr)
}

/** trust.trust-store */
@JsExport
class WitTrustStore {
    internal val store = HcertTrustStore()
    fun addPem(pem: String): Int = store.addPem(pem).orThrow(::trustErr)
    fun addDer(der: dynamic): Int = store.addDer(bytesIn(der)).orThrow(::trustErr)
    fun addDidDocument(json: String): Int = store.addDidDocument(json).orThrow(::trustErr)
    fun addVerifiedDidDocument(json: String, signer: String): Int = store.addVerifiedDidDocument(json, signer).orThrow(::trustErr)
    fun loadTrustDomains(codesystemJson: String): Int = store.loadTrustDomains(codesystemJson).orThrow(::trustErr)
    fun trustDomains(): dynamic = array(store.trustDomains()) { it }
    fun candidates(k: dynamic): dynamic = array(store.candidates(bytesIn(k))) { dscOut(it) }
    fun size(): Int = store.size()
    fun clear() = store.clear()
}

@JsExport
object WitVerifier {
    fun verify(hc1: String, store: WitTrustStore, reg: WitRegistry, now: dynamic, options: dynamic): dynamic =
        resultOut(HcertVerifier.verify(hc1, store.store, reg.reg, s64In(now), optionsIn(options)))
    fun verifyCose(cose: dynamic, store: WitTrustStore, reg: WitRegistry, now: dynamic, options: dynamic): dynamic =
        resultOut(HcertVerifier.verifyCose(bytesIn(cose), store.store, reg.reg, s64In(now), optionsIn(options)))
    fun readUnverified(hc1: String, reg: WitRegistry, limits: dynamic): dynamic {
        val u = HcertVerifier.readUnverified(hc1, reg.reg, limitsIn(limits)).orThrow(::failureOut)
        return obj(
            "kid" to u.kid?.let { bytesOut(it) }, "iss" to u.iss, "iat" to u.iat?.let { s64Out(it) }, "exp" to u.exp?.let { s64Out(it) },
            "entries" to array(u.entries) { e -> obj("subclaim" to e.subclaim, "payload" to e.payload?.let { payloadOut(it) }) },
            "diagnostics" to array(u.diagnostics) { diagOut(it) },
        )
    }
}

/** issuer.pending-signature */
@JsExport
class WitPendingSignature internal constructor(internal val pending: PendingSignature) {
    fun toBeSigned(): dynamic = bytesOut(pending.toBeSigned())
    fun algorithm(): String = algOut(pending.algorithm())
    fun kid(): dynamic = bytesOut(pending.kid())
}

@JsExport
object WitIssuer {
    fun prepare(req: dynamic, reg: WitRegistry): WitPendingSignature {
        val r = IssueRequest(
            payloads = listIn(req.payloads) { payloadIn(it) },
            iss = optStr(req.iss),
            validity = Validity(s64In(req.validity.iat), s64In(req.validity.exp)),
            dscDer = bytesIn(req.dscDer),
            alg = algIn(req.alg),
            allowDevelopmentSubclaims = req.allowDevelopmentSubclaims as Boolean,
        )
        return WitPendingSignature(HcertIssuer.prepare(r, reg.reg).orThrow(::issueErr))
    }
    fun finish(pending: WitPendingSignature, signature: dynamic): dynamic =
        HcertIssuer.finish(pending.pending, bytesIn(signature)).orThrow(::issueErr).let { obj("hc1" to it.hc1, "cose" to bytesOut(it.cose)) }
}
