package who.smart.trust.core

import kotlin.math.abs
import kotlin.math.floor
import kotlin.math.pow
import who.smart.trust.types.DecodeLimits

/**
 * A decoded CBOR data item (RFC 8949). Integers are held as [Long]; a value
 * outside the Long range is refused rather than silently truncated.
 */
sealed interface CborItem {
    data class Int(val value: Long) : CborItem
    class Bytes(val value: ByteArray) : CborItem {
        override fun equals(other: Any?) = other is Bytes && value.contentEquals(other.value)
        override fun hashCode() = value.contentHashCode()
        override fun toString() = "Bytes(${value.size})"
    }
    data class Text(val value: String) : CborItem
    data class Array(val items: List<CborItem>) : CborItem
    /** Entries in wire order; [get] looks a key up. */
    data class Map(val entries: List<Pair<CborItem, CborItem>>) : CborItem {
        operator fun get(key: CborItem): CborItem? = entries.firstOrNull { it.first == key }?.second
        operator fun get(key: Long): CborItem? = get(Int(key))
        operator fun get(key: String): CborItem? = get(Text(key))
    }
    data class Tag(val tag: Long, val item: CborItem) : CborItem
    data class Bool(val value: Boolean) : CborItem
    data object Null : CborItem
    data object Undefined : CborItem
    data class Simple(val value: kotlin.Int) : CborItem
    data class Float(val value: Double) : CborItem
}

class CborException(message: String, val limit: Boolean = false) : Exception(message)

/**
 * Bounded CBOR decoder: every length is checked against the remaining input
 * and against [DecodeLimits] before anything is allocated. [STT-CBR-003]
 */
class CborDecoder(private val data: ByteArray, private val limits: DecodeLimits) {
    private var pos = 0
    private var items = 0

    fun decodeSingle(): CborItem {
        val item = read(0)
        if (pos != data.size) throw CborException("${data.size - pos} trailing byte(s) after the data item")
        return item
    }

    private fun byte(): kotlin.Int {
        if (pos >= data.size) throw CborException("unexpected end of input")
        return data[pos++].toInt() and 0xff
    }

    private fun argument(info: kotlin.Int): Long = when {
        info < 24 -> info.toLong()
        info == 24 -> byte().toLong()
        info == 25 -> (byte().toLong() shl 8) or byte().toLong()
        info == 26 -> (0 until 4).fold(0L) { acc, _ -> (acc shl 8) or byte().toLong() }
        info == 27 -> {
            var v = 0L
            repeat(8) { v = (v shl 8) or byte().toLong() }
            if (v < 0) throw CborException("integer argument exceeds 2^63-1")
            v
        }
        else -> throw CborException("reserved additional information $info")
    }

    private fun count() {
        if (++items > limits.maxItems) throw CborException("more than ${limits.maxItems} data items", limit = true)
    }

    private fun length(n: Long, perUnit: kotlin.Int = 1): kotlin.Int {
        if (n > Int.MAX_VALUE.toLong() || n * perUnit > (data.size - pos).toLong()) {
            throw CborException("length $n exceeds the remaining input")
        }
        return n.toInt()
    }

    private fun bytesOf(n: kotlin.Int): ByteArray {
        if (n > limits.maxStringBytes) throw CborException("string of $n bytes exceeds ${limits.maxStringBytes}", limit = true)
        val out = data.copyOfRange(pos, pos + n)
        pos += n
        return out
    }

    private fun chunks(major: kotlin.Int): ByteArray {
        val parts = mutableListOf<ByteArray>()
        var total = 0
        while (true) {
            if (pos >= data.size) throw CborException("unterminated indefinite-length string")
            if ((data[pos].toInt() and 0xff) == 0xff) { pos++; break }
            val ib = byte()
            if (ib shr 5 != major || (ib and 0x1f) == 31) throw CborException("bad chunk in an indefinite-length string")
            val chunk = bytesOf(length(argument(ib and 0x1f)))
            total += chunk.size
            if (total > limits.maxStringBytes) throw CborException("string exceeds ${limits.maxStringBytes} bytes", limit = true)
            parts += chunk
        }
        val out = ByteArray(total)
        var o = 0
        for (p in parts) { p.copyInto(out, o); o += p.size }
        return out
    }

    private fun text(b: ByteArray): String = b.decodeToString(throwOnInvalidSequence = true)

    private fun read(depth: kotlin.Int): CborItem {
        if (depth > limits.maxDepth) throw CborException("nesting deeper than ${limits.maxDepth}", limit = true)
        count()
        val ib = byte()
        val major = ib shr 5
        val info = ib and 0x1f
        return when (major) {
            0 -> CborItem.Int(argument(info))
            1 -> CborItem.Int(-1 - argument(info))
            2 -> CborItem.Bytes(if (info == 31) chunks(2) else bytesOf(length(argument(info))))
            3 -> try {
                CborItem.Text(text(if (info == 31) chunks(3) else bytesOf(length(argument(info)))))
            } catch (e: CharacterCodingException) {
                throw CborException("text string is not valid UTF-8")
            }
            4 -> if (info == 31) {
                val list = mutableListOf<CborItem>()
                while (peekBreak().not()) list += read(depth + 1)
                CborItem.Array(list)
            } else {
                val n = length(argument(info))
                CborItem.Array(List(n) { read(depth + 1) })
            }
            5 -> if (info == 31) {
                val list = mutableListOf<Pair<CborItem, CborItem>>()
                while (peekBreak().not()) list += read(depth + 1) to read(depth + 1)
                CborItem.Map(list)
            } else {
                val n = length(argument(info), 2)
                CborItem.Map(List(n) { read(depth + 1) to read(depth + 1) })
            }
            6 -> CborItem.Tag(argument(info), read(depth + 1))
            else -> when (info) {
                20 -> CborItem.Bool(false)
                21 -> CborItem.Bool(true)
                22 -> CborItem.Null
                23 -> CborItem.Undefined
                24 -> CborItem.Simple(byte()).also { if (it.value < 32) throw CborException("non-canonical simple value") }
                25 -> CborItem.Float(halfToDouble(argument(25).toInt()))
                26 -> CborItem.Float(Float.fromBits(argument(26).toInt()).toDouble())
                27 -> {
                    var v = 0L
                    repeat(8) { v = (v shl 8) or byte().toLong() }
                    CborItem.Float(Double.fromBits(v))
                }
                31 -> throw CborException("unexpected break")
                in 0..19 -> CborItem.Simple(info)
                else -> throw CborException("reserved simple value $info")
            }
        }
    }

    private fun peekBreak(): Boolean {
        if (pos >= data.size) throw CborException("unterminated indefinite-length item")
        if ((data[pos].toInt() and 0xff) == 0xff) { pos++; return true }
        return false
    }
}

fun cborDecode(data: ByteArray, limits: DecodeLimits): CborItem = CborDecoder(data, limits).decodeSingle()

/**
 * RFC 8949 section 4.2.1 core deterministic encoding: shortest arguments,
 * definite lengths, map keys sorted by their encoded bytes, floats in the
 * shortest form that keeps the value. [STT-CBR-001]
 */
object CborEncoder {
    fun encode(item: CborItem): ByteArray = Buf().also { write(it, item) }.toByteArray()

    private fun head(b: Buf, major: kotlin.Int, n: Long) {
        val m = major shl 5
        when {
            n < 24 -> b.add(m or n.toInt())
            n < 0x100 -> { b.add(m or 24); b.add(n.toInt()) }
            n < 0x10000 -> { b.add(m or 25); b.addBE(n, 2) }
            n < 0x100000000L -> { b.add(m or 26); b.addBE(n, 4) }
            else -> { b.add(m or 27); b.addBE(n, 8) }
        }
    }

    private fun write(b: Buf, item: CborItem) {
        when (item) {
            is CborItem.Int -> if (item.value >= 0) head(b, 0, item.value) else head(b, 1, -1 - item.value)
            is CborItem.Bytes -> { head(b, 2, item.value.size.toLong()); b.addAll(item.value) }
            // NFC on encode [STT-CBR-002]
            is CborItem.Text -> Platform.nfc(item.value).encodeToByteArray().let { head(b, 3, it.size.toLong()); b.addAll(it) }
            is CborItem.Array -> { head(b, 4, item.items.size.toLong()); item.items.forEach { write(b, it) } }
            is CborItem.Map -> {
                val encoded = item.entries.map { encode(it.first) to it.second }.sortedWith { x, y -> compareBytes(x.first, y.first) }
                for (i in 1 until encoded.size) {
                    if (encoded[i - 1].first.contentEquals(encoded[i].first)) throw CborException("duplicate map key")
                }
                head(b, 5, encoded.size.toLong())
                encoded.forEach { (k, v) -> b.addAll(k); write(b, v) }
            }
            is CborItem.Tag -> { head(b, 6, item.tag); write(b, item.item) }
            is CborItem.Bool -> b.add(if (item.value) 0xf5 else 0xf4)
            CborItem.Null -> b.add(0xf6)
            CborItem.Undefined -> b.add(0xf7)
            is CborItem.Simple -> if (item.value < 24) b.add(0xe0 or item.value) else { b.add(0xf8); b.add(item.value) }
            is CborItem.Float -> writeFloat(b, item.value)
        }
    }

    private fun writeFloat(b: Buf, d: Double) {
        val f = d.toFloat()
        val half = if (f.toDouble() == d || d.isNaN()) doubleToHalf(d) else null
        when {
            half != null -> { b.add(0xf9); b.addBE(half.toLong(), 2) }
            f.toDouble() == d -> { b.add(0xfa); b.addBE(f.toRawBits().toLong() and 0xffffffffL, 4) }
            else -> { b.add(0xfb); b.addBE(d.toRawBits(), 8) }
        }
    }

    private fun compareBytes(x: ByteArray, y: ByteArray): kotlin.Int {
        for (i in 0 until minOf(x.size, y.size)) {
            val c = (x[i].toInt() and 0xff) - (y[i].toInt() and 0xff)
            if (c != 0) return c
        }
        return x.size - y.size
    }
}

internal fun halfToDouble(h: kotlin.Int): Double {
    val exp = (h shr 10) and 0x1f
    val mant = h and 0x3ff
    val v = when (exp) {
        0 -> mant * 2.0.pow(-24)
        31 -> if (mant == 0) Double.POSITIVE_INFINITY else Double.NaN
        else -> (mant + 1024) * 2.0.pow(exp - 25)
    }
    return if (h and 0x8000 != 0) -v else v
}

/** The binary16 bits for [d] when it is exactly representable, else null. */
internal fun doubleToHalf(d: Double): kotlin.Int? {
    if (d.isNaN()) return 0x7e00
    val sign = if (d < 0 || (d == 0.0 && 1.0 / d < 0)) 0x8000 else 0
    val a = abs(d)
    if (a == 0.0) return sign
    if (a.isInfinite()) return sign or 0x7c00
    for (exp in 1..30) {
        val mant = a / 2.0.pow(exp - 25) - 1024
        if (mant >= 0 && mant < 1024 && mant == floor(mant)) return sign or (exp shl 10) or mant.toInt()
    }
    val sub = a / 2.0.pow(-24)
    if (sub < 1024 && sub == floor(sub)) return sign or sub.toInt()
    return null
}

internal class Buf {
    private var a = ByteArray(64)
    private var n = 0
    fun add(v: kotlin.Int) { if (n == a.size) a = a.copyOf(a.size * 2); a[n++] = v.toByte() }
    fun addAll(b: ByteArray) { for (x in b) add(x.toInt()) }
    fun addBE(v: Long, bytes: kotlin.Int) { for (i in bytes - 1 downTo 0) add(((v ushr (8 * i)) and 0xff).toInt()) }
    fun toByteArray() = a.copyOf(n)
}
