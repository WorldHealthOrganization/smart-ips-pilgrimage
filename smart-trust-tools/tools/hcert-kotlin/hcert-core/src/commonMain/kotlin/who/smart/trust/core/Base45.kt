package who.smart.trust.core

/** RFC 9285 Base45. Decoding is strict. [STT-B45-001, STT-B45-002] */
object Base45 {
    const val ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
    private val index = IntArray(128) { -1 }.also { t -> ALPHABET.forEachIndexed { i, c -> t[c.code] = i } }

    fun encode(data: ByteArray): String {
        val sb = StringBuilder((data.size + 1) / 2 * 3)
        var i = 0
        while (i + 1 < data.size) {
            var n = ((data[i].toInt() and 0xff) shl 8) or (data[i + 1].toInt() and 0xff)
            repeat(3) { sb.append(ALPHABET[n % 45]); n /= 45 }
            i += 2
        }
        if (i < data.size) {
            var n = data[i].toInt() and 0xff
            repeat(2) { sb.append(ALPHABET[n % 45]); n /= 45 }
        }
        return sb.toString()
    }

    /** @throws IllegalArgumentException on a character outside the alphabet, a dangling character or an overflow. */
    fun decode(text: String): ByteArray {
        if (text.length % 3 == 1) throw IllegalArgumentException("dangling character at the end")
        val out = ByteArray(text.length / 3 * 2 + if (text.length % 3 == 2) 1 else 0)
        var o = 0
        var i = 0
        while (i < text.length) {
            val chunk = minOf(3, text.length - i)
            var n = 0
            var mul = 1
            for (j in 0 until chunk) {
                val c = text[i + j]
                val v = if (c.code < 128) index[c.code] else -1
                if (v < 0) throw IllegalArgumentException("character '${c}' at ${i + j} is not Base45")
                n += v * mul
                mul *= 45
            }
            if (chunk == 3) {
                if (n > 0xffff) throw IllegalArgumentException("triple at $i overflows 16 bits")
                out[o++] = (n shr 8).toByte(); out[o++] = n.toByte()
            } else {
                if (n > 0xff) throw IllegalArgumentException("pair at $i overflows 8 bits")
                out[o++] = n.toByte()
            }
            i += chunk
        }
        return out
    }
}
