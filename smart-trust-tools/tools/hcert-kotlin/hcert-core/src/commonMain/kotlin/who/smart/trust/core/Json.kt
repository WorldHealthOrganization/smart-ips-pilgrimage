package who.smart.trust.core

/**
 * A small RFC 8259 JSON reader, enough for DID documents: objects, arrays,
 * strings, numbers (as Double), booleans and null. Depth and size are bounded.
 * With [rejectDuplicates], an object naming a member twice is an error rather
 * than the last value winning, as signed data needs. [STT-TRU-006]
 */
internal class JsonReader(private val s: String, private val maxDepth: Int = 64, private val rejectDuplicates: Boolean = false) {
    private var p = 0

    fun parse(): Any? {
        val v = value(0)
        ws()
        if (p != s.length) fail("trailing characters")
        return v
    }

    private fun fail(msg: String): Nothing = throw IllegalArgumentException("JSON: $msg at $p")
    private fun ws() { while (p < s.length && s[p] in " \t\r\n") p++ }

    private fun value(depth: Int): Any? {
        if (depth > maxDepth) fail("nesting deeper than $maxDepth")
        ws()
        if (p >= s.length) fail("unexpected end")
        return when (s[p]) {
            '{' -> obj(depth)
            '[' -> arr(depth)
            '"' -> str()
            't' -> lit("true", true)
            'f' -> lit("false", false)
            'n' -> lit("null", null)
            else -> num()
        }
    }

    private fun lit(word: String, v: Any?): Any? {
        if (!s.startsWith(word, p)) fail("bad literal")
        p += word.length
        return v
    }

    private fun obj(depth: Int): Map<String, Any?> {
        val m = LinkedHashMap<String, Any?>()
        p++
        ws()
        if (p < s.length && s[p] == '}') { p++; return m }
        while (true) {
            ws()
            if (p >= s.length || s[p] != '"') fail("expected a member name")
            val k = str()
            ws()
            if (p >= s.length || s[p] != ':') fail("expected ':'")
            p++
            if (rejectDuplicates && k in m) fail("member \"$k\" given twice")
            m[k] = value(depth + 1)
            ws()
            if (p >= s.length) fail("unterminated object")
            when (s[p++]) {
                ',' -> continue
                '}' -> return m
                else -> fail("expected ',' or '}'")
            }
        }
    }

    private fun arr(depth: Int): List<Any?> {
        val l = mutableListOf<Any?>()
        p++
        ws()
        if (p < s.length && s[p] == ']') { p++; return l }
        while (true) {
            l += value(depth + 1)
            ws()
            if (p >= s.length) fail("unterminated array")
            when (s[p++]) {
                ',' -> continue
                ']' -> return l
                else -> fail("expected ',' or ']'")
            }
        }
    }

    private fun str(): String {
        p++
        val sb = StringBuilder()
        while (true) {
            if (p >= s.length) fail("unterminated string")
            val c = s[p++]
            when {
                c == '"' -> return sb.toString()
                c == '\\' -> {
                    if (p >= s.length) fail("bad escape")
                    when (val e = s[p++]) {
                        '"', '\\', '/' -> sb.append(e)
                        'b' -> sb.append('\b')
                        'f' -> sb.append('\u000c')
                        'n' -> sb.append('\n')
                        'r' -> sb.append('\r')
                        't' -> sb.append('\t')
                        'u' -> {
                            val hex = if (p + 4 <= s.length) s.substring(p, p + 4) else ""
                            if (hex.length != 4 || !hex.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }) fail("bad \\u escape")
                            sb.append(hex.toInt(16).toChar())
                            p += 4
                        }
                        else -> fail("bad escape")
                    }
                }
                c < ' ' -> fail("control character in string")
                else -> sb.append(c)
            }
        }
    }

    private fun num(): Double {
        val m = Regex("-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?").matchAt(s, p) ?: fail("bad value")
        p += m.value.length
        return m.value.toDouble()
    }
}

internal fun parseJson(s: String, rejectDuplicates: Boolean = false): Any? = JsonReader(s, rejectDuplicates = rejectDuplicates).parse()
