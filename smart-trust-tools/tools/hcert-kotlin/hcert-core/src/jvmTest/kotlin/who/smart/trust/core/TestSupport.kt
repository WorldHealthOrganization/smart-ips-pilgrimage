package who.smart.trust.core

import java.io.File
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.MGF1ParameterSpec
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.PSSParameterSpec
import who.smart.trust.HcertResult
import who.smart.trust.dvc.DvcMin
import who.smart.trust.dvc.DvcMinVaccineDetails
import who.smart.trust.issuer.IssueRequest
import who.smart.trust.issuer.IssuedHcert
import who.smart.trust.issuer.Validity
import who.smart.trust.payloads.Payload
import who.smart.trust.types.CoseAlgorithm
import who.smart.trust.verifier.VerifierOptions
import who.smart.trust.vhl.VhlPayload

/*
 * What the tests share. Each test is named after the requirements it verifies
 * (`STT-XXX-nnn …`), and each file after the skill whose requirements it
 * holds: the skill names the file in its `tested-by:`, and the requirement
 * graph reads the names (tools/build-site/kg_nodes.py).
 */

internal val repoRoot = File(System.getProperty("repo.root"))
internal fun readRepo(path: String) = File(repoRoot, path).readText()

internal val OPTIONS = VerifierOptions(DEFAULT_LIMITS, clockSkewSeconds = 300)

/** 2026-10-20T00:00:00Z, inside the PR 129 vector's validity. */
internal const val NOW = 1792454400L

internal fun <T, E> HcertResult<T, E>.ok(): T = when (this) {
    is HcertResult.Ok -> value
    is HcertResult.Err -> throw AssertionError("expected Ok, got $error")
}

internal fun <T, E> HcertResult<T, E>.err(): E = when (this) {
    is HcertResult.Ok -> throw AssertionError("expected Err, got $value")
    is HcertResult.Err -> error
}

/** A software signer, for tests only: the library never holds a private key. [STT-COS-006, STT-ISS-003] */
internal class TestSigner(keyPem: String, private val alg: CoseAlgorithm) {
    private val key = KeyFactory.getInstance(if (alg == CoseAlgorithm.ES256) "EC" else "RSA")
        .generatePrivate(PKCS8EncodedKeySpec(Pem.blocks(keyPem, "PRIVATE KEY").single()))

    fun sign(tbs: ByteArray): ByteArray = when (alg) {
        CoseAlgorithm.ES256 -> Signature.getInstance("SHA256withECDSA").run { initSign(key); update(tbs); sign() } // DER
        CoseAlgorithm.PS256 -> Signature.getInstance("RSASSA-PSS").run {
            setParameter(PSSParameterSpec("SHA-256", "MGF1", MGF1ParameterSpec.SHA256, 32, 1))
            initSign(key); update(tbs); sign()
        }
    }
}

/** The TEST-ONLY keys in vectors/testkit/, and issuing with them. */
internal object Testkit {
    val esPem = readRepo("vectors/testkit/es256-dsc.pem")
    val psPem = readRepo("vectors/testkit/ps256-dsc-test-eku.pem") // EKU: test certificates only
    val esDer = Pem.blocks(esPem).single()
    val psDer = Pem.blocks(psPem).single()
    val now = Platform.certificate(esDer).notBefore + 3600

    fun request(payload: Payload, alg: CoseAlgorithm = CoseAlgorithm.ES256, dev: Boolean = true, iss: String? = "XX") =
        request(listOf(payload), alg, dev, iss)

    fun request(payloads: List<Payload>, alg: CoseAlgorithm = CoseAlgorithm.ES256, dev: Boolean = true, iss: String? = "XX") =
        IssueRequest(payloads, iss, Validity(now, now + 86400), if (alg == CoseAlgorithm.ES256) esDer else psDer, alg, allowDevelopmentSubclaims = dev)

    fun issue(req: IssueRequest, reg: SubclaimRegistry = SubclaimRegistry()): IssuedHcert {
        val pending = HcertIssuer.prepare(req, reg).ok()
        val keyFile = if (req.alg == CoseAlgorithm.ES256) "vectors/testkit/es256-key.pem" else "vectors/testkit/ps256-key.pem"
        return HcertIssuer.finish(pending, TestSigner(readRepo(keyFile), req.alg).sign(pending.toBeSigned())).ok()
    }

    fun issue(payload: Payload, alg: CoseAlgorithm = CoseAlgorithm.ES256) = issue(request(payload, alg))

    fun store(vararg pems: String) = HcertTrustStore().apply { pems.forEach { addPem(it).ok() } }
}

/** A DVCMin for a newborn: no identity document, the guardian named. */
internal val NEWBORN = DvcMin(
    n = "Test CHILD", dob = "2026-09-28", s = "female", nt = "LAO", gn = "Test MOTHER",
    vx = DvcMinVaccineDetails(vp = "XM9V38", dv = "2026-09-28", `is` = "org-test", bo = "HEPB-TEST"),
    v = "1.0.0", extensions = listOf("zz" to CborEncoder.encode(CborItem.Text("kept"))),
)

/** The IHE ITI-YY3 example payload. */
internal val IHE_VHL = VhlPayload(
    url = "https://vhl-sharer.example.org/List/_search?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item",
    key = "86F8LY5LlWAa1-OS_FgrTnYNqFHJP2ey5RSKLJBN9jk",
    exp = 1735689600, flag = "LP", label = "Patient Health Summary", v = 1,
    fhirBaseUrl = "https://vhl-sharer.example.org",
)

/** The claims of a COSE_Sign1's payload. */
internal fun claimsOf(cose: ByteArray): CborItem.Map =
    cborDecode(HcertCose.parseSign1(cose, DEFAULT_LIMITS).ok().payload, DEFAULT_LIMITS) as CborItem.Map

/** A COSE_Sign1 over arbitrary claims, signed with the ES256 testkit key: for claim sets the issuer would refuse. */
internal fun signClaims(claims: CborItem.Map): ByteArray {
    val protected = CborEncoder.encode(CborItem.Map(listOf(CborItem.Int(1) to CborItem.Int(-7), CborItem.Int(4) to CborItem.Bytes(HcertCose.kidFromDsc(Testkit.esDer)))))
    val payload = CborEncoder.encode(claims)
    val der = TestSigner(readRepo("vectors/testkit/es256-key.pem"), CoseAlgorithm.ES256).sign(HcertCose.sigStructure(protected, payload))
    val sign1 = CborItem.Array(listOf(CborItem.Bytes(protected), CborItem.Map(emptyList()), CborItem.Bytes(payload), CborItem.Bytes(EcdsaSignature.derToRaw(der))))
    return CborEncoder.encode(CborItem.Tag(18, sign1))
}

/** CWT claims with a DVCMin, valid at [Testkit.now], plus [extra]. */
internal fun cwt(vararg extra: Pair<CborItem, CborItem>, exp: Long? = Testkit.now + 86400): CborItem.Map = CborItem.Map(
    listOfNotNull(
        CborItem.Int(1) to CborItem.Text("XX"),
        exp?.let { CborItem.Int(4) to CborItem.Int(it) },
        CborItem.Int(6) to CborItem.Int(Testkit.now),
        CborItem.Int(-260) to CborItem.Map(listOf(CborItem.Int(-6) to HcertDvc.item(NEWBORN))),
    ) + extra,
)
