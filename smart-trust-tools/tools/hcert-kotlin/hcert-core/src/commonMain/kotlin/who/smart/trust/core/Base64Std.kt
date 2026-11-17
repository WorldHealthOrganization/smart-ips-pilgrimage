package who.smart.trust.core

import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi

/** Standard and URL-safe base64 from the Kotlin standard library. [STT-KID-003] */
@OptIn(ExperimentalEncodingApi::class)
object Base64Std {
    fun encode(b: ByteArray): String = Base64.Default.encode(b)
    fun encodeUrl(b: ByteArray): String = Base64.UrlSafe.encode(b).trimEnd('=')
    /** Accepts either alphabet, padded or not. */
    fun decode(s: String): ByteArray {
        val std = s.replace('-', '+').replace('_', '/')
        val padded = std + "=".repeat((4 - std.length % 4) % 4)
        return Base64.Default.decode(padded)
    }
}

fun ByteArray.toHex(): String = joinToString("") { (it.toInt() and 0xff).toString(16).padStart(2, '0') }
