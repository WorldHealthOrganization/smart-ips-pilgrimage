package who.smart.trust.core

import who.smart.trust.HcertResult
import who.smart.trust.codec.Codec
import who.smart.trust.codec.CodecError
import who.smart.trust.cose.Base64Alphabet
import who.smart.trust.cose.Cose
import who.smart.trust.cose.CoseError
import who.smart.trust.cose.Sign1
import who.smart.trust.types.CborBytes
import who.smart.trust.types.CoseAlgorithm
import who.smart.trust.types.DecodeLimits
import who.smart.trust.types.Kid

/** A decode bound was hit. */
class LimitException(message: String) : Exception(message)

/** Bounds for untrusted input. An HC1 string in a version 40 QR symbol is at most 4296 characters. */
val DEFAULT_LIMITS = DecodeLimits(
    maxInputChars = 8192,
    maxInflatedBytes = 65536,
    maxDepth = 16,
    maxItems = 4096,
    maxStringBytes = 16384,
)

internal const val COSE_SIGN1_TAG = 18L

internal fun CoseAlgorithm.label(): Long = when (this) {
    CoseAlgorithm.ES256 -> -7
    CoseAlgorithm.PS256 -> -37
}

internal fun algorithmOf(label: Long): CoseAlgorithm? = when (label) {
    -7L -> CoseAlgorithm.ES256
    -37L -> CoseAlgorithm.PS256
    else -> null
}

/** Steps 4, 6, 7, 8. [STT-GEN-002] */
object HcertCodec : Codec {
    private val context = Regex("^HC([1-9A-Z]):")

    override fun base45Encode(data: ByteArray): String = Base45.encode(data)

    override fun base45Decode(text: String): HcertResult<ByteArray, CodecError> = try {
        HcertResult.Ok(Base45.decode(text))
    } catch (e: IllegalArgumentException) {
        HcertResult.Err(CodecError.Base45Invalid(e.message ?: "invalid Base45"))
    }

    override fun zlibCompress(data: ByteArray, level: Int): ByteArray = Platform.deflate(data, level)

    override fun zlibInflate(data: ByteArray, maxOut: Int): HcertResult<ByteArray, CodecError> = try {
        HcertResult.Ok(Platform.inflate(data, maxOut))
    } catch (e: LimitException) {
        HcertResult.Err(CodecError.LimitExceeded(e.message ?: "inflate limit"))
    } catch (e: IllegalArgumentException) {
        HcertResult.Err(CodecError.InflateFailed(e.message ?: "invalid ZLIB data"))
    }

    override fun detectContext(text: String): HcertResult<Pair<String, String>, CodecError> {
        val m = context.find(text) ?: return HcertResult.Err(CodecError.BadPrefix)
        return HcertResult.Ok(m.groupValues[1] to text.substring(m.range.last + 1))
    }

    override fun toHc1(cose: ByteArray): String = "HC1:" + Base45.encode(Platform.deflate(cose, 9))

    override fun fromHc1(text: String, limits: DecodeLimits): HcertResult<ByteArray, CodecError> {
        if (text.length > limits.maxInputChars) {
            return HcertResult.Err(CodecError.LimitExceeded("input of ${text.length} characters exceeds ${limits.maxInputChars}"))
        }
        val (version, rest) = when (val c = detectContext(text)) {
            is HcertResult.Ok -> c.value
            is HcertResult.Err -> return c
        }
        if (version != "1") return HcertResult.Err(CodecError.UnsupportedContextVersion("HC$version"))
        val deflated = when (val b = base45Decode(rest)) {
            is HcertResult.Ok -> b.value
            is HcertResult.Err -> return b
        }
        return zlibInflate(deflated, limits.maxInflatedBytes)
    }

    override fun cborDeterministic(cbor: CborBytes, limits: DecodeLimits): HcertResult<CborBytes, CodecError> = try {
        HcertResult.Ok(CborEncoder.encode(cborDecode(cbor, limits)))
    } catch (e: CborException) {
        HcertResult.Err(if (e.limit) CodecError.LimitExceeded(e.message!!) else CodecError.CborMalformed(e.message!!))
    }
}

/** Step 5. [STT-COS-001 to STT-COS-005, STT-KID-001, STT-KID-003, STT-VER-003] */
object HcertCose : Cose {
    override fun kidFromDsc(dscDer: ByteArray): Kid = Platform.sha256(dscDer).copyOf(8)

    override fun kidToBase64(k: Kid, alphabet: Base64Alphabet): String = when (alphabet) {
        Base64Alphabet.STANDARD -> Base64Std.encode(k)
        Base64Alphabet.URL_SAFE -> Base64Std.encodeUrl(k)
    }

    override fun kidFromBase64(text: String): HcertResult<Kid, CoseError> = try {
        HcertResult.Ok(Base64Std.decode(text))
    } catch (e: IllegalArgumentException) {
        HcertResult.Err(CoseError.Malformed("kid is not base64"))
    }

    override fun parseSign1(bytes: ByteArray, limits: DecodeLimits): HcertResult<Sign1, CoseError> {
        val item = try {
            cborDecode(bytes, limits)
        } catch (e: CborException) {
            return HcertResult.Err(CoseError.Malformed(e.message!!))
        }
        val tagged = item is CborItem.Tag
        if (item is CborItem.Tag && item.tag != COSE_SIGN1_TAG) return HcertResult.Err(CoseError.Malformed("tag ${item.tag} is not COSE_Sign1 (18)"))
        val arr = (if (item is CborItem.Tag) item.item else item) as? CborItem.Array
            ?: return HcertResult.Err(CoseError.Malformed("COSE_Sign1 is not an array"))
        if (arr.items.size != 4) return HcertResult.Err(CoseError.Malformed("COSE_Sign1 has ${arr.items.size} elements, not 4"))
        val protected = (arr.items[0] as? CborItem.Bytes)?.value ?: return HcertResult.Err(CoseError.Malformed("protected header is not a byte string"))
        val unprotected = arr.items[1] as? CborItem.Map ?: return HcertResult.Err(CoseError.Malformed("unprotected header is not a map"))
        val payload = (arr.items[2] as? CborItem.Bytes)?.value ?: return HcertResult.Err(CoseError.Malformed("payload is not a byte string"))
        val signature = (arr.items[3] as? CborItem.Bytes)?.value ?: return HcertResult.Err(CoseError.Malformed("signature is not a byte string"))

        val ph = if (protected.isEmpty()) CborItem.Map(emptyList()) else try {
            cborDecode(protected, limits) as? CborItem.Map ?: return HcertResult.Err(CoseError.HeaderInvalid("protected header is not a map"))
        } catch (e: CborException) {
            return HcertResult.Err(CoseError.HeaderInvalid(e.message!!))
        }
        for (h in listOf(ph, unprotected)) {
            if (h.entries.map { it.first }.toSet().size != h.entries.size) return HcertResult.Err(CoseError.HeaderInvalid("duplicate header label"))
        }
        if (unprotected[1L] != null) return HcertResult.Err(CoseError.HeaderInvalid("alg must be in the protected header"))
        val algItem = ph[1L] ?: return HcertResult.Err(CoseError.HeaderInvalid("no alg in the protected header"))
        val algLabel = (algItem as? CborItem.Int)?.value ?: return HcertResult.Err(CoseError.HeaderInvalid("alg is not an integer"))
        val alg = algorithmOf(algLabel) ?: return HcertResult.Err(CoseError.UnsupportedAlgorithm(algLabel.toInt()))
        fun kidOf(h: CborItem.Map): HcertResult<ByteArray?, CoseError> {
            val k = h[4L] ?: return HcertResult.Ok(null)
            val b = (k as? CborItem.Bytes)?.value ?: return HcertResult.Err(CoseError.HeaderInvalid("kid is not a byte string"))
            if (b.size != 8) return HcertResult.Err(CoseError.HeaderInvalid("kid is ${b.size} bytes, not 8"))
            return HcertResult.Ok(b)
        }
        val pk = when (val r = kidOf(ph)) { is HcertResult.Ok -> r.value; is HcertResult.Err -> return r }
        val uk = when (val r = kidOf(unprotected)) { is HcertResult.Ok -> r.value; is HcertResult.Err -> return r }
        return HcertResult.Ok(Sign1(protected, payload, signature, alg, pk ?: uk, kidInProtected = pk != null, tagged = tagged))
    }

    override fun sigStructure(protected: ByteArray, payload: ByteArray): ByteArray = CborEncoder.encode(
        CborItem.Array(listOf(CborItem.Text("Signature1"), CborItem.Bytes(protected), CborItem.Bytes(ByteArray(0)), CborItem.Bytes(payload))),
    )

    override fun verifySign1(s: Sign1, dscDer: ByteArray): HcertResult<Unit, CoseError> {
        val alg = s.alg ?: return HcertResult.Err(CoseError.HeaderInvalid("no alg"))
        if (alg == CoseAlgorithm.ES256 && s.signature.size != 64) {
            return HcertResult.Err(CoseError.BadSignatureFormat("ES256 signature is ${s.signature.size} bytes, not 64"))
        }
        try {
            Platform.certificate(dscDer)
        } catch (e: Exception) {
            return HcertResult.Err(CoseError.BadCertificate(e.message ?: "unreadable certificate"))
        }
        val ok = Platform.verify(alg, dscDer, sigStructure(s.protected, s.payload), s.signature)
        return if (ok) HcertResult.Ok(Unit) else HcertResult.Err(CoseError.SignatureInvalid)
    }

    override fun ecdsaDerToRaw(der: ByteArray): HcertResult<ByteArray, CoseError> = try {
        HcertResult.Ok(EcdsaSignature.derToRaw(der))
    } catch (e: IllegalArgumentException) {
        HcertResult.Err(CoseError.BadSignatureFormat(e.message ?: "bad DER"))
    }

    override fun ecdsaRawToDer(raw: ByteArray): HcertResult<ByteArray, CoseError> = try {
        HcertResult.Ok(EcdsaSignature.rawToDer(raw))
    } catch (e: IllegalArgumentException) {
        HcertResult.Err(CoseError.BadSignatureFormat(e.message ?: "bad r||s"))
    }
}
