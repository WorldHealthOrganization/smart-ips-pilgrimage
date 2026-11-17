@file:OptIn(ExperimentalJsExport::class)

package who.smart.trust.core

import who.smart.trust.payloads.Payload
import who.smart.trust.verifier.VerificationResult
import who.smart.trust.verifier.VerifierOptions

/**
 * A minimal JavaScript entry point to the verifier, for Node. The full
 * JavaScript surface comes with the hcert-js facade. [STT-GEN-011]
 */
@JsExport
object HcertNode {
    /** Verifies [hc1] against the PEM DSCs in [trustPem] at [now] (Unix seconds); returns a JSON summary without payload content. */
    fun verifySummary(hc1: String, trustPem: String, now: Double): String =
        summary(HcertVerifier.verify(hc1, store(trustPem), SubclaimRegistry(), now.toLong(), VerifierOptions(DEFAULT_LIMITS, 300)))

    /** As [verifySummary], for raw COSE_Sign1 bytes given as hex, without the QR layers. [STT-TST-005] */
    fun verifyCoseSummary(coseHex: String, trustPem: String, now: Double): String =
        summary(HcertVerifier.verifyCose(coseHex.chunked(2).map { it.toInt(16).toByte() }.toByteArray(), store(trustPem), SubclaimRegistry(), now.toLong(), VerifierOptions(DEFAULT_LIMITS, 300)))

    private fun store(trustPem: String) = HcertTrustStore().apply { if (trustPem.isNotBlank()) addPem(trustPem) }

    private fun summary(r: VerificationResult): String =
        when (r) {
            is VerificationResult.Verified -> {
                val v = r.value
                val entries = v.entries.joinToString(",") { e ->
                    val kind = when (e.payload) {
                        is Payload.DvcMin -> "dvc-min"
                        is Payload.Vhl -> "vhl"
                        is Payload.Raw -> "raw"
                    }
                    """{"subclaim":${e.subclaim},"payload":"$kind","keyUsageAuthorised":${e.keyUsageAuthorised}}"""
                }
                """{"status":"verified","entries":[$entries],"iss":${v.iss?.let { "\"$it\"" } ?: "null"},"kid":"${v.dsc.kid.toHex()}"}"""
            }
            is VerificationResult.Failed -> """{"status":"failed","step":"${r.value.step}","reason":"${r.value.reason}"}"""
        }

    /** Decrypts a VHL document (JWE dir / A256GCM) and returns its text, or "error: ...". */
    fun decryptText(jwe: String, key: String): String = when (val r = HcertVhl.decrypt(jwe, key)) {
        is who.smart.trust.HcertResult.Ok -> r.value.content.decodeToString()
        is who.smart.trust.HcertResult.Err -> "error: ${r.error}"
    }
}
