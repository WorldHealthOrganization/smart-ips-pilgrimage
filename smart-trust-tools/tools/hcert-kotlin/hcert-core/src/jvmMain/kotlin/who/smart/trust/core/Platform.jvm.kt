package who.smart.trust.core

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.security.MessageDigest
import java.security.Signature
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.security.interfaces.ECPublicKey
import java.security.interfaces.RSAPublicKey
import java.security.spec.MGF1ParameterSpec
import java.security.spec.PSSParameterSpec
import java.util.zip.Deflater
import java.util.zip.Inflater
import who.smart.trust.types.CoseAlgorithm

internal actual object Platform {
    actual fun sha256(data: ByteArray): ByteArray = MessageDigest.getInstance("SHA-256").digest(data)

    actual fun deflate(data: ByteArray, level: Int): ByteArray {
        val d = Deflater(level)
        try {
            d.setInput(data)
            d.finish()
            val out = ByteArrayOutputStream(data.size / 2 + 64)
            val buf = ByteArray(4096)
            while (!d.finished()) out.write(buf, 0, d.deflate(buf))
            return out.toByteArray()
        } finally {
            d.end()
        }
    }

    actual fun inflate(data: ByteArray, maxOut: Int): ByteArray = inflateWith(Inflater(), data, maxOut)

    actual fun inflateRaw(data: ByteArray, maxOut: Int): ByteArray = inflateWith(Inflater(true), data, maxOut)

    private fun inflateWith(inf: Inflater, data: ByteArray, maxOut: Int): ByteArray {
        try {
            inf.setInput(data)
            val out = ByteArrayOutputStream()
            val buf = ByteArray(4096)
            while (!inf.finished()) {
                val n = inf.inflate(buf)
                if (n == 0 && (inf.needsInput() || inf.needsDictionary())) throw IllegalArgumentException("truncated ZLIB stream")
                if (out.size() + n > maxOut) throw LimitException("inflated data exceeds $maxOut bytes")
                out.write(buf, 0, n)
            }
            if (inf.remaining != 0) throw IllegalArgumentException("${inf.remaining} byte(s) after the ZLIB stream")
            return out.toByteArray()
        } catch (e: java.util.zip.DataFormatException) {
            throw IllegalArgumentException("invalid ZLIB data: ${e.message}")
        } finally {
            inf.end()
        }
    }

    private val random by lazy { java.security.SecureRandom() }

    actual fun randomBytes(n: Int): ByteArray = ByteArray(n).also { random.nextBytes(it) }

    private fun gcm(mode: Int, key: ByteArray, iv: ByteArray, aad: ByteArray) =
        javax.crypto.Cipher.getInstance("AES/GCM/NoPadding").apply {
            init(mode, javax.crypto.spec.SecretKeySpec(key, "AES"), javax.crypto.spec.GCMParameterSpec(128, iv))
            updateAAD(aad)
        }

    actual fun aesGcmEncrypt(key: ByteArray, iv: ByteArray, aad: ByteArray, plaintext: ByteArray): ByteArray =
        gcm(javax.crypto.Cipher.ENCRYPT_MODE, key, iv, aad).doFinal(plaintext)

    actual fun aesGcmDecrypt(key: ByteArray, iv: ByteArray, aad: ByteArray, ciphertextAndTag: ByteArray): ByteArray = try {
        gcm(javax.crypto.Cipher.DECRYPT_MODE, key, iv, aad).doFinal(ciphertextAndTag)
    } catch (e: java.security.GeneralSecurityException) {
        throw IllegalArgumentException("AES-GCM decryption failed: ${e.message}")
    }

    private fun x509(der: ByteArray): X509Certificate =
        CertificateFactory.getInstance("X.509").generateCertificate(ByteArrayInputStream(der)) as X509Certificate

    actual fun certificate(der: ByteArray): CertificateInfo {
        val c = x509(der)
        val country = Regex("(?:^|,)C=([^,]+)").find(c.subjectX500Principal.getName("RFC2253"))?.groupValues?.get(1)
        return CertificateInfo(c.notBefore.time / 1000, c.notAfter.time / 1000, country, c.extendedKeyUsage ?: emptyList())
    }

    actual fun verify(alg: CoseAlgorithm, dscDer: ByteArray, data: ByteArray, signature: ByteArray): Boolean {
        val key = x509(dscDer).publicKey
        return try {
            when (alg) {
                CoseAlgorithm.ES256 -> {
                    if (key !is ECPublicKey || signature.size != 64) return false
                    Signature.getInstance("SHA256withECDSA").run {
                        initVerify(key); update(data); verify(EcdsaSignature.rawToDer(signature))
                    }
                }
                CoseAlgorithm.PS256 -> {
                    if (key !is RSAPublicKey) return false
                    pss().run { initVerify(key); update(data); verify(signature) }
                }
            }
        } catch (e: java.security.GeneralSecurityException) {
            false
        }
    }

    actual fun verifyEs256Point(x: ByteArray, y: ByteArray, data: ByteArray, signature: ByteArray): Boolean {
        if (x.size != 32 || y.size != 32 || signature.size != 64 || !P256.onCurve(x, y)) return false
        return try {
            val key = java.security.KeyFactory.getInstance("EC").generatePublic(java.security.spec.X509EncodedKeySpec(P256.spki(x, y)))
            Signature.getInstance("SHA256withECDSA").run {
                initVerify(key); update(data); verify(EcdsaSignature.rawToDer(signature))
            }
        } catch (e: java.security.GeneralSecurityException) {
            false
        }
    }

    /** RSASSA-PSS, SHA-256, MGF1-SHA-256, salt 32 (RFC 8230). Android names it SHA256withRSA/PSS. */
    private fun pss(): Signature = try {
        Signature.getInstance("RSASSA-PSS").apply {
            setParameter(PSSParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA256, 32, 1))
        }
    } catch (e: java.security.NoSuchAlgorithmException) {
        Signature.getInstance("SHA256withRSA/PSS")
    }

    /** y^2 = x^3 - 3x + b over the P-256 field (FIPS 186-5, SEC 2). */
    private object P256 {
        private val p = java.math.BigInteger("ffffffff00000001000000000000000000000000ffffffffffffffffffffffff", 16)
        private val b = java.math.BigInteger("5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b", 16)
        fun onCurve(xb: ByteArray, yb: ByteArray): Boolean {
            val x = java.math.BigInteger(1, xb)
            val y = java.math.BigInteger(1, yb)
            if (x >= p || y >= p) return false
            return y.multiply(y).subtract(x.pow(3).subtract(x.multiply(java.math.BigInteger.valueOf(3))).add(b)).mod(p).signum() == 0
        }
        fun spki(x: ByteArray, y: ByteArray): ByteArray = P256_SPKI_PREFIX + x + y
    }

    actual fun nfc(text: String): String = java.text.Normalizer.normalize(text, java.text.Normalizer.Form.NFC)
}
