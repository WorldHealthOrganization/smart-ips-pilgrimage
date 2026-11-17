package who.smart.trust.core

/** ECDSA-Sig-Value (RFC 3279) DER and the fixed-width r||s of COSE. [STT-COS-005] */
object EcdsaSignature {
    /** P-256 DER to 64-byte r||s. */
    fun derToRaw(der: ByteArray, width: Int = 32): ByteArray {
        var p = 0
        fun byte(): Int = if (p < der.size) der[p++].toInt() and 0xff else throw IllegalArgumentException("truncated DER")
        fun len(): Int {
            val b = byte()
            if (b < 0x80) return b
            val n = b and 0x7f
            if (n == 0 || n > 2) throw IllegalArgumentException("bad DER length")
            var l = 0
            repeat(n) { l = (l shl 8) or byte() }
            return l
        }
        if (byte() != 0x30) throw IllegalArgumentException("not a DER SEQUENCE")
        if (len() != der.size - p) throw IllegalArgumentException("SEQUENCE length does not match")
        val out = ByteArray(2 * width)
        for (k in 0..1) {
            if (byte() != 0x02) throw IllegalArgumentException("expected INTEGER")
            val l = len()
            if (l == 0 || p + l > der.size) throw IllegalArgumentException("bad INTEGER length")
            var v = der.copyOfRange(p, p + l)
            p += l
            if (v[0].toInt() and 0x80 != 0) throw IllegalArgumentException("negative INTEGER")
            v = v.dropWhile { it == 0.toByte() }.toByteArray()
            if (v.size > width) throw IllegalArgumentException("INTEGER wider than $width bytes")
            v.copyInto(out, k * width + width - v.size)
        }
        if (p != der.size) throw IllegalArgumentException("trailing bytes after the signature")
        return out
    }

    fun rawToDer(raw: ByteArray): ByteArray {
        if (raw.size != 64) throw IllegalArgumentException("ES256 signature must be 64 bytes, got ${raw.size}")
        fun int(b: ByteArray): ByteArray {
            var v = b.dropWhile { it == 0.toByte() }.toByteArray()
            if (v.isEmpty()) v = byteArrayOf(0)
            if (v[0].toInt() and 0x80 != 0) v = byteArrayOf(0) + v
            return byteArrayOf(0x02, v.size.toByte()) + v
        }
        val body = int(raw.copyOfRange(0, 32)) + int(raw.copyOfRange(32, 64))
        return byteArrayOf(0x30, body.size.toByte()) + body
    }
}

/** PEM blocks of one type, decoded. */
object Pem {
    fun blocks(pem: String, type: String = "CERTIFICATE"): List<ByteArray> {
        val re = Regex("-----BEGIN $type-----([A-Za-z0-9+/=\\s]+)-----END $type-----")
        return re.findAll(pem).map { Base64Std.decode(it.groupValues[1].filter { c -> !c.isWhitespace() }) }.toList()
    }
}
