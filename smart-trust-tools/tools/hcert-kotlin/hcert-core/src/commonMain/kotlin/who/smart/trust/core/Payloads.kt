package who.smart.trust.core

import who.smart.trust.HcertResult
import who.smart.trust.dvc.Dvc
import who.smart.trust.dvc.DvcMin
import who.smart.trust.dvc.DvcMinVaccineDetails
import who.smart.trust.subclaims.PayloadKind
import who.smart.trust.subclaims.Registry
import who.smart.trust.subclaims.Subclaims
import who.smart.trust.types.CborBytes
import who.smart.trust.types.DecodeLimits
import who.smart.trust.types.Severity
import who.smart.trust.types.Subclaim
import who.smart.trust.types.ValidationIssue

/** The subclaims QR Code Generation 2.1 lists. [STT-SEL-001] */
val DEFAULT_SUBCLAIMS = listOf(
    Subclaim(1, "HCertDCC (EU DCC core data set)"),
    Subclaim(3, "DDCCCoreDataSetVS"),
    Subclaim(4, "DDCCCoreDataSetTR"),
    Subclaim(5, "Verifiable Health Link"),
    Subclaim(-6, "DVCMin", "http://smart.who.int/trust-phw/StructureDefinition/DVCMin"),
    Subclaim(-7, "MedicationTreatmentLineMin"),
)

/** [STT-SEL-002, STT-SEL-003] */
class SubclaimRegistry : Registry {
    private val byKey = LinkedHashMap<Int, Subclaim>().apply { DEFAULT_SUBCLAIMS.forEach { put(it.key, it) } }
    private val kinds = mutableMapOf(PayloadKind.DVC_MIN to -6, PayloadKind.VHL to 5)

    override fun lookup(key: Int): Subclaim? = byKey[key]
    override fun register(s: Subclaim) { byKey[s.key] = s }
    override fun all(): List<Subclaim> = byKey.values.toList()
    override fun subclaimFor(kind: PayloadKind): Int? = kinds[kind]
    override fun setSubclaimFor(kind: PayloadKind, key: Int) { kinds[kind] = key }
    override fun close() {}
}

object HcertSubclaims : Subclaims {
    override fun newRegistry(): Registry = SubclaimRegistry()
}

/** DVCMin <-> CBOR, and its logical-model rules. [STT-PAY-001 to STT-PAY-005, STT-PAY-007, STT-PAY-008] */
object HcertDvc : Dvc {
    // FHIR R5 primitive regexes, as models/generated/trust-phw.cddl carries them.
    private val fhirString = Regex("[\\s\\S]+")
    private val fhirCode = Regex("[^\\s]+( [^\\s]+)*")
    private val fhirDate = Regex("([0-9]([0-9]([0-9][1-9]|[1-9]0)|[1-9]00)|[1-9]000)(-(0[1-9]|1[0-2])(-(0[1-9]|[1-2][0-9]|3[0-1]))?)?")
    private val fhirId = Regex("[A-Za-z0-9\\-.]{1,64}")
    private val alpha3 = Regex("[A-Z]{3}")

    private val subjectKeys = setOf("n", "dob", "s", "nt", "id", "dt", "gn", "vx", "v")
    private val vxKeys = setOf("vp", "dv", "cn", "is", "bo")

    private fun issue(path: String, code: String, message: String, severity: Severity = Severity.BLOCKING) =
        ValidationIssue(path, code, message, severity)

    override fun validate(p: DvcMin): List<ValidationIssue> {
        val out = mutableListOf<ValidationIssue>()
        fun check(path: String, value: String?, re: Regex, type: String) {
            if (value != null && !re.matches(value)) out += issue(path, "invalid-$type", "$path is not a valid FHIR $type")
        }
        check("n", p.n, fhirString, "string")
        check("dob", p.dob, fhirDate, "date")
        check("s", p.s, fhirCode, "code")
        check("nt", p.nt, fhirCode, "code")
        if (fhirCode.matches(p.nt) && !alpha3.matches(p.nt)) out += issue("nt", "not-alpha3", "nt must be an ISO 3166-1 alpha-3 code")
        check("id", p.id, fhirString, "string")
        check("dt", p.dt, fhirCode, "code")
        check("gn", p.gn, fhirString, "string")
        check("v", p.v, fhirString, "string")
        check("vx.vp", p.vx.vp, fhirCode, "code")
        check("vx.dv", p.vx.dv, fhirDate, "date")
        check("vx.cn", p.vx.cn, fhirString, "string")
        check("vx.is", p.vx.`is`, fhirId, "id")
        check("vx.bo", p.vx.bo, fhirString, "string")
        if (p.vx.cn == null && p.vx.`is` == null) {
            out += issue("vx", "must-have-issuer-or-clinician-name", "vx needs is, cn or both")
        }
        return out
    }

    override fun toCbor(p: DvcMin): CborBytes = CborEncoder.encode(item(p))

    internal fun item(p: DvcMin): CborItem {
        val vx = buildList {
            add("vp" to p.vx.vp); add("dv" to p.vx.dv)
            p.vx.cn?.let { add("cn" to it) }; p.vx.`is`?.let { add("is" to it) }
            add("bo" to p.vx.bo)
        }.map { (k, v) -> CborItem.Text(k) to CborItem.Text(v) as CborItem }
        val subject = buildList<Pair<CborItem, CborItem>> {
            fun put(k: String, v: String?) { if (v != null) add(CborItem.Text(k) to CborItem.Text(v)) }
            put("n", p.n); put("dob", p.dob); put("s", p.s); put("nt", p.nt)
            put("id", p.id); put("dt", p.dt); put("gn", p.gn)
            add(CborItem.Text("vx") to CborItem.Map(vx))
            put("v", p.v)
            for ((k, v) in p.extensions) {
                require(k !in subjectKeys) { "extension $k collides with a DVCMin element" }
                add(CborItem.Text(k) to cborDecode(v, DEFAULT_LIMITS))
            }
        }
        return CborItem.Map(subject)
    }

    override fun fromCbor(cbor: CborBytes, limits: DecodeLimits): HcertResult<DvcMin, List<ValidationIssue>> {
        val root = try {
            cborDecode(cbor, limits)
        } catch (e: CborException) {
            return HcertResult.Err(listOf(issue("", "cbor", e.message!!)))
        }
        return fromItem(root)
    }

    internal fun fromItem(root: CborItem): HcertResult<DvcMin, List<ValidationIssue>> {
        val issues = mutableListOf<ValidationIssue>()
        val map = root as? CborItem.Map ?: return HcertResult.Err(listOf(issue("", "not-a-map", "DVCMin is not a CBOR map")))
        fun texts(m: CborItem.Map, prefix: String, known: Set<String>): kotlin.collections.Map<String, String> {
            val out = mutableMapOf<String, String>()
            for ((k, v) in m.entries) {
                val name = (k as? CborItem.Text)?.value
                if (name == null) { issues += issue(prefix, "non-text-key", "element name is not a text string"); continue }
                if (name !in known || name == "vx") continue
                val t = (v as? CborItem.Text)?.value
                if (t == null) issues += issue(prefix + name, "not-text", "$prefix$name is not a text string") else out[name] = t
            }
            return out
        }
        val s = texts(map, "", subjectKeys)
        val vxItem = map["vx"] as? CborItem.Map
        if (vxItem == null) issues += issue("vx", "required", "vx is required and must be a map")
        val vx = vxItem?.let { texts(it, "vx.", vxKeys) } ?: emptyMap()
        vxItem?.entries?.forEach { (k, _) ->
            val name = (k as? CborItem.Text)?.value
            if (name != null && name !in vxKeys) {
                issues += issue("vx.$name", "unknown-element", "vx.$name is not in this DVCMin version and is not kept", Severity.WARNING)
            }
        }
        for (r in listOf("n", "dob", "s", "nt", "v")) if (r !in s && issues.none { it.path == r }) issues += issue(r, "required", "$r is required")
        for (r in listOf("vp", "dv", "bo")) if (vxItem != null && r !in vx && issues.none { it.path == "vx.$r" }) issues += issue("vx.$r", "required", "vx.$r is required")
        if (issues.any { it.severity == Severity.BLOCKING }) return HcertResult.Err(issues)
        // Unknown elements are kept, encoded, so newer versions still decode. [STT-PAY-008]
        val extensions = map.entries.mapNotNull { (k, v) ->
            val name = (k as CborItem.Text).value
            if (name in subjectKeys) null else name to CborEncoder.encode(v)
        }
        return HcertResult.Ok(
            DvcMin(
                n = s.getValue("n"), dob = s.getValue("dob"), s = s.getValue("s"), nt = s.getValue("nt"),
                id = s["id"], dt = s["dt"], gn = s["gn"],
                vx = DvcMinVaccineDetails(vp = vx.getValue("vp"), dv = vx.getValue("dv"), cn = vx["cn"], `is` = vx["is"], bo = vx.getValue("bo")),
                v = s.getValue("v"),
                extensions = extensions,
            ),
        )
    }
}
