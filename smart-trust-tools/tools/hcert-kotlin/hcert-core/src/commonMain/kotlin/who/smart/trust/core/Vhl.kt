package who.smart.trust.core

import who.smart.trust.HcertResult
import who.smart.trust.types.NumericDate
import who.smart.trust.types.Severity
import who.smart.trust.types.ValidationIssue
import who.smart.trust.vhl.Decrypted
import who.smart.trust.vhl.ManifestDocument
import who.smart.trust.vhl.ManifestRequest
import who.smart.trust.vhl.SignatureBase
import who.smart.trust.vhl.SignatureRequest
import who.smart.trust.vhl.Vhl
import who.smart.trust.vhl.VhlError
import who.smart.trust.vhl.VhlPayload

/**
 * Verifiable Health Links as IHE ITI VHL specifies them, with the SMART Health
 * Links payload format. No I/O: the host sends what this builds and hands back
 * what it receives. [STT-VHL-001 to STT-VHL-010]
 */
object HcertVhl : Vhl {
    private const val PREFIX = "vhlink:/"
    private const val FORM = "application/x-www-form-urlencoded"
    /** Upper bound on an inflated (zip DEF) document. */
    private const val MAX_DOCUMENT_BYTES = 64 * 1024 * 1024
    private val base64url = Regex("[A-Za-z0-9_-]{43}")

    private fun issue(path: String, code: String, message: String, severity: Severity = Severity.BLOCKING) =
        ValidationIssue(path, code, message, severity)

    override fun validate(p: VhlPayload, now: NumericDate?): List<ValidationIssue> {
        val out = mutableListOf<ValidationIssue>()
        if (!p.url.startsWith("https://")) out += issue("url", "not-https", "url must be an https URL")
        val keyOk = base64url.matches(p.key) && runCatching { Base64Std.decode(p.key).size == 32 }.getOrDefault(false)
        if (!keyOk) out += issue("key", "bad-key", "key must be 43 base64url characters encoding 32 bytes")
        p.flag?.let { f ->
            if ('U' in f) out += issue("flag", "unsupported-flag-U", "the single-file U flag is not supported")
            val letters = f.filter { it != 'U' }
            if (letters.any { it !in "LP" } || letters.toSet().size != letters.length || letters.toList() != letters.toList().sorted()) {
                out += issue("flag", "bad-flag", "flag must be L and/or P, each once, in alphabetical order")
            }
        }
        p.label?.let { if (it.length > 80) out += issue("label", "label-too-long", "label must be at most 80 characters") }
        p.v?.let { if (it < 1) out += issue("v", "bad-version", "v must be a positive integer") }
        p.fhirBaseUrl?.let { if (!it.startsWith("https://")) out += issue("extension.fhirBaseUrl", "not-https", "fhirBaseUrl must be an https URL") }
        if (now != null && p.exp != null && now > p.exp!!) out += issue("exp", "expired", "the link has expired")
        return out
    }

    // ---- the payload as JSON (vhlink:/) and as a CBOR map (HCERT key 5) ----

    private fun json(p: VhlPayload): String = buildString {
        fun str(s: String) {
            append('"')
            for (c in s) when {
                c == '"' -> append("\\\"")
                c == '\\' -> append("\\\\")
                c < ' ' -> append("\\u").append(c.code.toString(16).padStart(4, '0'))
                else -> append(c)
            }
            append('"')
        }
        append("{\"url\":"); str(p.url)
        append(",\"key\":"); str(p.key)
        p.exp?.let { append(",\"exp\":").append(it) }
        p.flag?.let { append(",\"flag\":"); str(it) }
        p.label?.let { append(",\"label\":"); str(it) }
        p.v?.let { append(",\"v\":").append(it) }
        p.fhirBaseUrl?.let { append(",\"extension\":{\"fhirBaseUrl\":"); str(it); append("}") }
        append('}')
    }

    override fun toVhlink(p: VhlPayload): String = PREFIX + Base64Std.encodeUrl(json(p).encodeToByteArray())

    override fun fromVhlink(text: String): HcertResult<VhlPayload, VhlError> {
        if (!text.startsWith(PREFIX)) return HcertResult.Err(VhlError.NotAVhlink("no vhlink:/ prefix"))
        val obj = try {
            parseJson(Base64Std.decode(text.substring(PREFIX.length)).decodeToString(throwOnInvalidSequence = true)) as? Map<*, *>
        } catch (e: Exception) {
            return HcertResult.Err(VhlError.NotAVhlink("the text after vhlink:/ is not base64url JSON"))
        } ?: return HcertResult.Err(VhlError.NotAVhlink("the payload is not a JSON object"))
        return fromFields(obj.mapKeys { it.key as String }) { it as? Map<*, *> }
    }

    /** The CBOR map written at HCERT key 5. [STT-VHL-002] */
    internal fun toItem(p: VhlPayload): CborItem = CborItem.Map(
        buildList {
            fun put(k: String, v: CborItem) = add(CborItem.Text(k) to v)
            put("url", CborItem.Text(p.url))
            put("key", CborItem.Text(p.key))
            p.exp?.let { put("exp", CborItem.Int(it)) }
            p.flag?.let { put("flag", CborItem.Text(it)) }
            p.label?.let { put("label", CborItem.Text(it)) }
            p.v?.let { put("v", CborItem.Int(it.toLong())) }
            p.fhirBaseUrl?.let { put("extension", CborItem.Map(listOf(CborItem.Text("fhirBaseUrl") to CborItem.Text(it)))) }
        },
    )

    /** Key 5 as the CBOR map, or as a vhlink:/ text string (IHE ITI-YY3). [STT-VHL-002] */
    internal fun fromItem(item: CborItem): HcertResult<VhlPayload, VhlError> = when (item) {
        is CborItem.Text -> fromVhlink(item.value)
        is CborItem.Map -> {
            val fields = item.entries.mapNotNull { (k, v) -> (k as? CborItem.Text)?.value?.let { it to cborToValue(v) } }.toMap()
            fromFields(fields) { it as? Map<*, *> }
        }
        else -> HcertResult.Err(VhlError.Invalid(listOf(issue("", "not-a-map", "key 5 is neither a CBOR map nor a vhlink:/ string"))))
    }

    private fun cborToValue(i: CborItem): Any? = when (i) {
        is CborItem.Text -> i.value
        is CborItem.Int -> i.value
        is CborItem.Map -> i.entries.mapNotNull { (k, v) -> (k as? CborItem.Text)?.value?.let { it to cborToValue(v) } }.toMap()
        else -> i
    }

    private fun fromFields(f: Map<String, Any?>, asMap: (Any?) -> Map<*, *>?): HcertResult<VhlPayload, VhlError> {
        val issues = mutableListOf<ValidationIssue>()
        fun text(k: String, required: Boolean): String? = when (val v = f[k]) {
            null -> { if (required) issues += issue(k, "required", "$k is required"); null }
            is String -> v
            else -> { issues += issue(k, "not-text", "$k must be a string"); null }
        }
        fun integer(k: String): Long? = when (val v = f[k]) {
            null -> null
            is Long -> v
            is Double -> if (v == kotlin.math.floor(v) && kotlin.math.abs(v) < 9.007199254740992E15) v.toLong() else { issues += issue(k, "not-integer", "$k must be an integer"); null }
            else -> { issues += issue(k, "not-integer", "$k must be an integer"); null }
        }
        val url = text("url", true)
        val key = text("key", true)
        val p = VhlPayload(
            url = url ?: "", key = key ?: "", exp = integer("exp"), flag = text("flag", false), label = text("label", false),
            v = integer("v")?.toInt(), fhirBaseUrl = asMap(f["extension"])?.get("fhirBaseUrl") as? String,
        )
        return if (issues.isEmpty()) HcertResult.Ok(p) else HcertResult.Err(VhlError.Invalid(issues))
    }

    override fun newKey(): String = Base64Std.encodeUrl(Platform.randomBytes(32))

    // ---- ITI-YY5 ----

    private fun formEncode(s: String): String = buildString {
        for (b in s.encodeToByteArray()) {
            val c = b.toInt() and 0xff
            when {
                c in 'A'.code..'Z'.code || c in 'a'.code..'z'.code || c in '0'.code..'9'.code || c.toChar() in "*-._" -> append(c.toChar())
                c == ' '.code -> append('+')
                else -> append('%').append(c.toString(16).uppercase().padStart(2, '0'))
            }
        }
    }

    private fun percentDecode(s: String): String {
        val out = mutableListOf<Byte>()
        var i = 0
        while (i < s.length) {
            val hex = if (s[i] == '%' && i + 3 <= s.length) s.substring(i + 1, i + 3).toIntOrNull(16) else null
            if (hex != null) {
                out += hex.toByte()
                i += 3
            } else {
                out.addAll(s[i].toString().encodeToByteArray().toList())
                i++
            }
        }
        return out.toByteArray().decodeToString()
    }

    override fun buildManifestRequest(p: VhlPayload, recipient: String, passcode: String?, embeddedLengthMax: Int?): HcertResult<ManifestRequest, VhlError> {
        val blocking = validate(p, null).filter { it.severity == Severity.BLOCKING }
        if (blocking.isNotEmpty()) return HcertResult.Err(VhlError.Invalid(blocking))
        if (recipient.isBlank()) return HcertResult.Err(VhlError.Manifest("recipient is required"))
        val needsPasscode = p.flag?.contains('P') == true
        if (needsPasscode && passcode.isNullOrEmpty()) return HcertResult.Err(VhlError.Manifest("the link has the P flag: a passcode is required"))
        if (!needsPasscode && passcode != null) return HcertResult.Err(VhlError.Manifest("the link has no P flag: no passcode is sent"))
        val path = p.url.substringBefore('?').trimEnd('/')
        val base = when {
            path.endsWith("/List/_search") -> path.removeSuffix("/List/_search")
            path.endsWith("/List") -> path.removeSuffix("/List")
            else -> return HcertResult.Err(VhlError.Manifest("the manifest URL is not a List search"))
        }
        val params = p.url.substringAfter('?', "").split('&').filter { it.isNotEmpty() }.map {
            percentDecode(it.substringBefore('=').replace('+', ' ')) to percentDecode(it.substringAfter('=', "").replace('+', ' '))
        }
        val names = params.map { it.first }
        for (r in listOf("_id", "code", "status", "patient.identifier")) {
            if (names.count { it == r } != 1) return HcertResult.Err(VhlError.Manifest("the manifest URL needs exactly one $r"))
        }
        params.firstOrNull { it.first == "_include" }?.let {
            if (it.second != "List:item") return HcertResult.Err(VhlError.Manifest("_include must be List:item"))
        }
        val body = (params + listOfNotNull(
            "recipient" to recipient,
            passcode?.let { "passcode" to it },
            embeddedLengthMax?.let { "embeddedLengthMax" to it.toString() },
        )).joinToString("&") { (k, v) -> formEncode(k) + "=" + formEncode(v) }
        return HcertResult.Ok(ManifestRequest("$base/List/_search", FORM, body))
    }

    override fun parseManifest(bundleJson: String): HcertResult<List<ManifestDocument>, VhlError> {
        val bundle = try {
            parseJson(bundleJson) as? Map<*, *>
        } catch (e: IllegalArgumentException) {
            return HcertResult.Err(VhlError.Manifest(e.message ?: "invalid JSON"))
        } ?: return HcertResult.Err(VhlError.Manifest("not a JSON object"))
        if (bundle["resourceType"] != "Bundle" || bundle["type"] != "searchset") return HcertResult.Err(VhlError.Manifest("not a searchset Bundle"))
        val entries = (bundle["entry"] as? List<*>).orEmpty().mapNotNull { it as? Map<*, *> }
        fun mode(e: Map<*, *>) = (e["search"] as? Map<*, *>)?.get("mode") as? String
        val lists = entries.filter { (it["resource"] as? Map<*, *>)?.get("resourceType") == "List" && mode(it) != "include" }
        if (lists.isEmpty()) return HcertResult.Err(VhlError.Manifest("the Bundle holds no matching List"))
        val included = mutableMapOf<String, Map<*, *>>()
        for (e in entries) {
            val r = e["resource"] as? Map<*, *> ?: continue
            if (r["resourceType"] != "DocumentReference") continue
            (e["fullUrl"] as? String)?.let { included[it] = r }
            (r["id"] as? String)?.let { included["DocumentReference/$it"] = r }
        }
        val docs = mutableListOf<ManifestDocument>()
        for (l in lists) {
            val list = l["resource"] as Map<*, *>
            for (item in (list["entry"] as? List<*>).orEmpty()) {
                val ref = ((item as? Map<*, *>)?.get("item") as? Map<*, *>)?.get("reference") as? String ?: continue
                val dr = included[ref] ?: included.entries.firstOrNull { ref.endsWith("/" + it.key) || it.key.endsWith("/$ref") }?.value
                if (dr == null) {
                    docs += ManifestDocument(reference = ref)
                    continue
                }
                val contents = (dr["content"] as? List<*>).orEmpty()
                if (contents.none { ((it as? Map<*, *>)?.get("attachment") as? Map<*, *>)?.get("url") != null }) {
                    docs += ManifestDocument(reference = ref) // included without an attachment URL: the host reads it
                    continue
                }
                for (c in contents) {
                    val a = (c as? Map<*, *>)?.get("attachment") as? Map<*, *> ?: continue
                    docs += ManifestDocument(
                        url = a["url"] as? String,
                        contentType = a["contentType"] as? String,
                        title = a["title"] as? String ?: dr["description"] as? String,
                    )
                }
            }
        }
        return HcertResult.Ok(docs)
    }

    // ---- JWE Compact, dir / A256GCM (RFC 7516, RFC 7518) ----

    private fun keyBytes(key: String): ByteArray? =
        runCatching { Base64Std.decode(key) }.getOrNull()?.takeIf { base64url.matches(key) && it.size == 32 }

    override fun encrypt(content: ByteArray, contentType: String, key: String): HcertResult<String, VhlError> {
        val k = keyBytes(key) ?: return HcertResult.Err(VhlError.Invalid(listOf(issue("key", "bad-key", "key must be 43 base64url characters encoding 32 bytes"))))
        val header = "{\"alg\":\"dir\",\"enc\":\"A256GCM\",\"cty\":\"" + contentType.replace("\\", "\\\\").replace("\"", "\\\"") + "\"}"
        val h = Base64Std.encodeUrl(header.encodeToByteArray())
        val iv = Platform.randomBytes(12)
        val sealed = Platform.aesGcmEncrypt(k, iv, h.encodeToByteArray(), content)
        val ct = sealed.copyOfRange(0, sealed.size - 16)
        val tag = sealed.copyOfRange(sealed.size - 16, sealed.size)
        return HcertResult.Ok("$h..${Base64Std.encodeUrl(iv)}.${Base64Std.encodeUrl(ct)}.${Base64Std.encodeUrl(tag)}")
    }

    override fun decrypt(jwe: String, key: String): HcertResult<Decrypted, VhlError> {
        val k = keyBytes(key) ?: return HcertResult.Err(VhlError.Invalid(listOf(issue("key", "bad-key", "key must be 43 base64url characters encoding 32 bytes"))))
        val parts = jwe.trim().split('.')
        if (parts.size != 5) return HcertResult.Err(VhlError.DecryptFailed("JWE Compact has 5 parts, found ${parts.size}"))
        if (parts[1].isNotEmpty()) return HcertResult.Err(VhlError.Unsupported("an encrypted key is present: alg is not dir"))
        val header = try {
            parseJson(Base64Std.decode(parts[0]).decodeToString()) as? Map<*, *>
        } catch (e: Exception) {
            null
        } ?: return HcertResult.Err(VhlError.DecryptFailed("the protected header is not base64url JSON"))
        if (header["alg"] != "dir" || header["enc"] != "A256GCM") {
            return HcertResult.Err(VhlError.Unsupported("alg ${header["alg"]} / enc ${header["enc"]}; only dir / A256GCM"))
        }
        val zip = header["zip"]
        if (zip != null && zip != "DEF") return HcertResult.Err(VhlError.Unsupported("zip $zip"))
        val (iv, ct, tag) = try {
            Triple(Base64Std.decode(parts[2]), Base64Std.decode(parts[3]), Base64Std.decode(parts[4]))
        } catch (e: IllegalArgumentException) {
            return HcertResult.Err(VhlError.DecryptFailed("a JWE part is not base64url"))
        }
        if (iv.size != 12 || tag.size != 16) return HcertResult.Err(VhlError.DecryptFailed("A256GCM needs a 96-bit IV and a 128-bit tag"))
        val plain = try {
            Platform.aesGcmDecrypt(k, iv, parts[0].encodeToByteArray(), ct + tag)
        } catch (e: IllegalArgumentException) {
            return HcertResult.Err(VhlError.DecryptFailed("the tag does not verify: wrong key or altered content"))
        }
        val content = if (zip == "DEF") try {
            Platform.inflateRaw(plain, MAX_DOCUMENT_BYTES)
        } catch (e: Exception) {
            return HcertResult.Err(VhlError.DecryptFailed("zip DEF content does not inflate: ${e.message}"))
        } else plain
        return HcertResult.Ok(Decrypted(header["cty"] as? String, content))
    }

    // ---- HTTP Message Signatures (RFC 9421) and Content-Digest (RFC 9530) ----

    override fun buildSignatureBase(r: SignatureRequest): SignatureBase {
        val digest = r.body?.let { "sha-256=:" + Base64Std.encode(Platform.sha256(it)) + ":" }
        val components = buildList {
            add("@method" to r.method.uppercase())
            add("@path" to r.path)
            add("@authority" to r.authority.lowercase())
            r.contentType?.let { add("content-type" to it.trim()) }
            digest?.let { add("content-digest" to it) }
        }
        val params = components.joinToString(" ", "(", ")") { "\"${it.first}\"" } +
            ";created=${r.created};keyid=\"${r.keyid}\";alg=\"${r.alg}\""
        val base = (components.map { "\"${it.first}\": ${it.second}" } + "\"@signature-params\": $params").joinToString("\n")
        return SignatureBase(digest, "sig1=$params", base.encodeToByteArray())
    }

    override fun signatureHeader(signature: ByteArray, alg: String): HcertResult<String, VhlError> {
        val sig = if (alg == "ecdsa-p256-sha256" && signature.size != 64) try {
            EcdsaSignature.derToRaw(signature)
        } catch (e: IllegalArgumentException) {
            return HcertResult.Err(VhlError.Unsupported("ecdsa-p256-sha256 signature is neither r||s nor DER"))
        } else signature
        return HcertResult.Ok("sig1=:" + Base64Std.encode(sig) + ":")
    }
}
