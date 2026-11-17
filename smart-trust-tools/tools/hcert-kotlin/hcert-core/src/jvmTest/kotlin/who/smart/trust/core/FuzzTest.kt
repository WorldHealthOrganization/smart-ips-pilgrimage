package who.smart.trust.core

import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.test.fail
import who.smart.trust.HcertResult

/**
 * Skill `hcert-conformance-testing`: a seeded mutation fuzzer over the
 * decoders' public entry points (HCERT 6.3). It needs no dependency. Each
 * run is reproducible from its seed. STT_FUZZ_ITERATIONS raises the count
 * for a longer local run.
 */
class FuzzTest {
    private val vector = parseJson(readRepo("vectors/smart-trust-pr129/dvc-qr-example-XXA.json")) as Map<*, *>
    private val hc1s = (vector["certificates"] as Map<*, *>).values.map { (it as Map<*, *>)["hc1"] as String }
    private val coses = hc1s.map { HcertCodec.fromHc1(it, DEFAULT_LIMITS).ok() }
    private val payloads = coses.map { HcertCose.parseSign1(it, DEFAULT_LIMITS).ok().payload }
    private val deflated = hc1s.map { HcertCodec.base45Decode(it.substring(4)).ok() }
    private val store = HcertTrustStore().apply { addPem(readRepo("vectors/smart-trust-pr129/dvc-qr-example-XXA-dsc.pem")).ok() }
    private val reg = SubclaimRegistry()
    private val iterations = System.getenv("STT_FUZZ_ITERATIONS")?.toInt() ?: 1500
    private val base45Alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"

    private fun mutate(r: Random, seed: ByteArray): ByteArray {
        val b = seed.toMutableList()
        repeat(1 + r.nextInt(4)) {
            when (r.nextInt(6)) {
                0 -> if (b.isNotEmpty()) { val i = r.nextInt(b.size); b[i] = (b[i].toInt() xor (1 shl r.nextInt(8))).toByte() }
                1 -> b.add(r.nextInt(b.size + 1), r.nextInt(256).toByte())
                2 -> if (b.isNotEmpty()) b.removeAt(r.nextInt(b.size))
                3 -> if (b.isNotEmpty()) repeat(b.size - r.nextInt(b.size)) { b.removeAt(b.size - 1) }
                4 -> if (b.isNotEmpty()) b[r.nextInt(b.size)] = listOf(0x00, 0x7f, 0x80, 0xff, 0x9f, 0xbf, 0xd8, 0x1b)[r.nextInt(8)].toByte()
                else -> if (b.isNotEmpty()) { val i = r.nextInt(b.size); val n = minOf(b.size - i, 1 + r.nextInt(16)); b.addAll(r.nextInt(b.size + 1), b.subList(i, i + n).toList()) }
            }
        }
        return b.toByteArray()
    }

    private fun mutate(r: Random, seed: String): String {
        val s = StringBuilder(seed)
        repeat(1 + r.nextInt(4)) {
            when (r.nextInt(5)) {
                0 -> if (s.isNotEmpty()) s.setCharAt(r.nextInt(s.length), base45Alphabet[r.nextInt(base45Alphabet.length)])
                1 -> s.insert(r.nextInt(s.length + 1), if (r.nextBoolean()) base45Alphabet[r.nextInt(base45Alphabet.length)] else r.nextInt(0x20, 0x3000).toChar())
                2 -> if (s.isNotEmpty()) s.deleteCharAt(r.nextInt(s.length))
                3 -> if (s.isNotEmpty()) s.setLength(r.nextInt(s.length))
                else -> if (s.isNotEmpty()) { val i = r.nextInt(s.length); s.insert(r.nextInt(s.length + 1), s.substring(i, minOf(s.length, i + 1 + r.nextInt(32)))) }
            }
        }
        return s.toString()
    }

    /** Runs [call] [iterations] times on mutated inputs: nothing may throw or take more than a second. */
    private fun <T> fuzz(target: String, seeds: List<T>, mutator: (Random, T) -> T, call: (T) -> Unit) {
        val r = Random(target.hashCode())
        var slowest = 0L
        repeat(iterations) { n ->
            val input = mutator(r, seeds[n % seeds.size])
            val start = System.nanoTime()
            try { call(input) } catch (t: Throwable) { fail("$target #$n threw ${t::class.simpleName}: ${t.message} on ${describe(input)}") }
            slowest = maxOf(slowest, System.nanoTime() - start)
        }
        assertTrue(slowest < 1_000_000_000L, "$target: slowest call took ${slowest / 1_000_000} ms")
    }

    private fun describe(input: Any?) = when (input) {
        is ByteArray -> input.toHex()
        else -> input.toString()
    }

    private fun <T> bounded(r: HcertResult<T, *>, size: (T) -> Int, max: Int, what: String) {
        if (r is HcertResult.Ok) assertTrue(size(r.value) <= max, "$what: ${size(r.value)} > $max")
    }

    @Test fun `STT-TST-006 fuzzed Base45 never throws and never decodes more than its input`() =
        fuzz("base45Decode", hc1s.map { it.substring(4) }, ::mutate) { bounded(HcertCodec.base45Decode(it), ByteArray::size, it.length, "base45Decode") }

    @Test fun `STT-TST-006 fuzzed ZLIB never throws and never inflates past the limit`() =
        fuzz("zlibInflate", deflated, ::mutate) { bounded(HcertCodec.zlibInflate(it, DEFAULT_LIMITS.maxInflatedBytes), ByteArray::size, DEFAULT_LIMITS.maxInflatedBytes, "zlibInflate") }

    @Test fun `STT-TST-006 fuzzed CBOR never throws in the deterministic re-encoder`() =
        fuzz("cborDeterministic", payloads, ::mutate) { HcertCodec.cborDeterministic(it, DEFAULT_LIMITS) }

    @Test fun `STT-TST-006 fuzzed COSE never throws in the Sign1 parser`() =
        fuzz("parseSign1", coses, ::mutate) { HcertCose.parseSign1(it, DEFAULT_LIMITS) }

    @Test fun `STT-TST-006 fuzzed HC1 strings never throw in the QR layers or the verifier`() =
        fuzz("verify", hc1s, ::mutate) {
            bounded(HcertCodec.fromHc1(it, DEFAULT_LIMITS), ByteArray::size, DEFAULT_LIMITS.maxInflatedBytes, "fromHc1")
            HcertVerifier.verify(it, store, reg, NOW, OPTIONS)
            HcertVerifier.readUnverified(it, reg, DEFAULT_LIMITS)
        }

    @Test fun `STT-TST-006 fuzzed COSE bytes never throw in the verifier`() =
        fuzz("verifyCose", coses, ::mutate) { HcertVerifier.verifyCose(it, store, reg, NOW, OPTIONS) }
}
