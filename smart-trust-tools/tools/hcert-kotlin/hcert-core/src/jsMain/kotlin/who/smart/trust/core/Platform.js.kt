package who.smart.trust.core

import org.khronos.webgl.Int8Array
import who.smart.trust.types.CoseAlgorithm

@JsModule("node:crypto")
private external object NodeCrypto {
    val X509Certificate: dynamic
    val constants: dynamic
    fun createHash(algorithm: String): dynamic
    fun createPublicKey(key: dynamic): dynamic
    fun verify(algorithm: String, data: dynamic, key: dynamic, signature: dynamic): Boolean
    fun randomBytes(n: Int): dynamic
    fun createCipheriv(algorithm: String, key: dynamic, iv: dynamic, options: dynamic): dynamic
    fun createDecipheriv(algorithm: String, key: dynamic, iv: dynamic, options: dynamic): dynamic
}

@JsModule("node:zlib")
private external object NodeZlib {
    fun deflateSync(data: dynamic, options: dynamic): dynamic
    fun inflateSync(data: dynamic, options: dynamic): dynamic
    fun inflateRawSync(data: dynamic, options: dynamic): dynamic
}

@JsModule("node:buffer")
private external object NodeBuffer {
    val Buffer: dynamic
}

private val crypto: dynamic get() = NodeCrypto
private val zlib: dynamic get() = NodeZlib
private val BufferClass: dynamic get() = NodeBuffer.Buffer

private fun ByteArray.toBuffer(): dynamic {
    val a = this.unsafeCast<Int8Array>()
    return BufferClass.from(a.buffer, a.byteOffset, a.length)
}

private fun bytesOf(buf: dynamic): ByteArray {
    val view = Int8Array(buf.buffer.unsafeCast<org.khronos.webgl.ArrayBuffer>(), buf.byteOffset as Int, buf.length as Int)
    return ByteArray(view.length) { view.asDynamic()[it] as Byte }
}

@Suppress("UNUSED_PARAMETER")
private fun construct(ctor: dynamic, arg: dynamic): dynamic = js("new ctor(arg)")

private fun epochSeconds(dateText: dynamic): Long =
    (js("Date").parse(dateText) as Double / 1000).toLong()

internal actual object Platform {
    actual fun sha256(data: ByteArray): ByteArray =
        bytesOf(crypto.createHash("sha256").update(data.toBuffer()).digest())

    actual fun deflate(data: ByteArray, level: Int): ByteArray {
        val opts: dynamic = js("({})")
        opts.level = level
        return bytesOf(zlib.deflateSync(data.toBuffer(), opts))
    }

    actual fun inflate(data: ByteArray, maxOut: Int): ByteArray = inflateWith(data, maxOut, raw = false)

    actual fun inflateRaw(data: ByteArray, maxOut: Int): ByteArray = inflateWith(data, maxOut, raw = true)

    actual fun randomBytes(n: Int): ByteArray = bytesOf(crypto.randomBytes(n))

    private fun gcmOptions(): dynamic {
        val o: dynamic = js("({})")
        o.authTagLength = 16
        return o
    }

    actual fun aesGcmEncrypt(key: ByteArray, iv: ByteArray, aad: ByteArray, plaintext: ByteArray): ByteArray {
        val c = crypto.createCipheriv("aes-256-gcm", key.toBuffer(), iv.toBuffer(), gcmOptions())
        c.setAAD(aad.toBuffer())
        val head = bytesOf(c.update(plaintext.toBuffer()))
        val tail = bytesOf(c.final())
        return head + tail + bytesOf(c.getAuthTag())
    }

    actual fun aesGcmDecrypt(key: ByteArray, iv: ByteArray, aad: ByteArray, ciphertextAndTag: ByteArray): ByteArray {
        if (ciphertextAndTag.size < 16) throw IllegalArgumentException("ciphertext shorter than the tag")
        return try {
            val d = crypto.createDecipheriv("aes-256-gcm", key.toBuffer(), iv.toBuffer(), gcmOptions())
            d.setAAD(aad.toBuffer())
            d.setAuthTag(ciphertextAndTag.copyOfRange(ciphertextAndTag.size - 16, ciphertextAndTag.size).toBuffer())
            bytesOf(d.update(ciphertextAndTag.copyOfRange(0, ciphertextAndTag.size - 16).toBuffer())) + bytesOf(d.final())
        } catch (e: Throwable) {
            throw IllegalArgumentException("AES-GCM decryption failed: ${e.message}")
        }
    }

    private fun inflateWith(data: ByteArray, maxOut: Int, raw: Boolean): ByteArray {
        val opts: dynamic = js("({})")
        opts.maxOutputLength = maxOut
        return try {
            bytesOf(if (raw) zlib.inflateRawSync(data.toBuffer(), opts) else zlib.inflateSync(data.toBuffer(), opts))
        } catch (e: Throwable) {
            val code = e.asDynamic().code as? String
            if (code == "ERR_BUFFER_TOO_LARGE") throw LimitException("inflated data exceeds $maxOut bytes")
            throw IllegalArgumentException("invalid ZLIB data: ${e.message}")
        }
    }

    private fun x509(der: ByteArray): dynamic = construct(crypto.X509Certificate, der.toBuffer())

    actual fun certificate(der: ByteArray): CertificateInfo {
        val c = x509(der)
        val subject = c.subject as String
        val country = Regex("(?:^|\\n)C=([^\\n]+)").find(subject)?.groupValues?.get(1)
        val eku = c.keyUsage
        val ekus = if (eku == null || eku == undefined) emptyList() else (eku as Array<String>).toList()
        return CertificateInfo(epochSeconds(c.validFrom), epochSeconds(c.validTo), country, ekus)
    }

    actual fun verify(alg: CoseAlgorithm, dscDer: ByteArray, data: ByteArray, signature: ByteArray): Boolean {
        val key = x509(dscDer).publicKey
        val opts: dynamic = js("({})")
        opts.key = key
        when (alg) {
            CoseAlgorithm.ES256 -> {
                if (key.asymmetricKeyType != "ec" || signature.size != 64) return false
                opts.dsaEncoding = "ieee-p1363"
            }
            CoseAlgorithm.PS256 -> {
                if (key.asymmetricKeyType != "rsa") return false
                opts.padding = crypto.constants.RSA_PKCS1_PSS_PADDING
                opts.saltLength = 32
            }
        }
        return try {
            crypto.verify("sha256", data.toBuffer(), opts, signature.toBuffer()) as Boolean
        } catch (e: Throwable) {
            false
        }
    }

    actual fun verifyEs256Point(x: ByteArray, y: ByteArray, data: ByteArray, signature: ByteArray): Boolean {
        if (x.size != 32 || y.size != 32 || signature.size != 64) return false
        return try {
            val spec: dynamic = js("({})")
            spec.key = (P256_SPKI_PREFIX + x + y).toBuffer()
            spec.format = "der"
            spec.type = "spki"
            val opts: dynamic = js("({})")
            opts.key = crypto.createPublicKey(spec) // OpenSSL refuses a point off the curve
            opts.dsaEncoding = "ieee-p1363"
            crypto.verify("sha256", data.toBuffer(), opts, signature.toBuffer()) as Boolean
        } catch (e: Throwable) {
            false
        }
    }

    actual fun nfc(text: String): String = text.asDynamic().normalize("NFC") as String
}
