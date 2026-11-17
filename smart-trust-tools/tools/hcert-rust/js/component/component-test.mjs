// Drives the jco-transpiled component through every interface of the
// `hcert` world, against the shared vectors (STT-GEN-005, STT-TST-005).
// Verifies STT-GEN-005 and STT-TST-005.
//
//   tools/hcert-rust/build-component.sh <dir> && node tools/hcert-rust/js/component/component-test.mjs <dir>
import { readFileSync } from "node:fs";
import { createPrivateKey, sign as nodeSign, createVerify } from "node:crypto";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const dir = resolve(process.argv[2] ?? "");
const { codec, cose, subclaims, dvc, vhl, trust, verifier, issuer } = await import(join(dir, "js", "hcert.js"));
const repo = fileURLToPath(new URL("../../../../", import.meta.url));
const read = (p) => readFileSync(join(repo, p), "utf8");
const hex = (b) => Buffer.from(b).toString("hex");
const L = { maxInputChars: 8192, maxInflatedBytes: 65536, maxDepth: 16, maxItems: 4096, maxStringBytes: 16384 };
const OPTIONS = { limits: L, clockSkewSeconds: 300 };
const NOW = 1792454400n; // 2026-10-20T00:00:00Z
const TESTKIT_NOW = 1792520192n + 3600n;

let failures = 0;
function check(name, ok, detail = "") {
  console.log(`${ok ? "ok  " : "FAIL"} ${name}${detail ? ": " + detail : ""}`);
  if (!ok) failures++;
}
function throws(fn, tag) {
  try { fn(); return false; } catch (e) { return e.payload?.tag === tag; }
}

// codec and cose
const vector = JSON.parse(read("vectors/smart-trust-pr129/dvc-qr-example-XXA.json"));
const hepb1 = vector.certificates.hepb1.hc1;
const bytes = codec.fromHc1(hepb1, L);
const s1 = cose.parseSign1(bytes, L);
check("codec, cose: the PR 129 HC1 decodes to a tagged ES256 COSE_Sign1 with the vector's kid", bytes.length === 295 && s1.tagged && s1.alg === "es256" && hex(s1.kid) === "58733e058aaa6621");
check("codec: deterministic re-encoding reproduces the CWT", hex(codec.cborDeterministic(s1.payload, L)) === hex(s1.payload));
check("codec: to-hc1 inverts from-hc1", hex(codec.fromHc1(codec.toHc1(bytes), L)) === hex(bytes));
check("codec: Base45 errors are typed", throws(() => codec.base45Decode("abc"), "base45-invalid"));
check("cose: kid base64 both ways", cose.kidToBase64(s1.kid, "standard") === "WHM+BYqqZiE=" && hex(cose.kidFromBase64("WHM-BYqqZiE")) === hex(s1.kid));

// trust store, registry, verifier
const store = new trust.TrustStore();
const added = store.addPem(read("vectors/smart-trust-pr129/dvc-qr-example-XXA-dsc.pem"));
check("trust: the PR 129 PEM loads its two certificates", added === 2 && store.size() === 2);
check("trust: candidates by kid", store.candidates(s1.kid).length === 1);
check("trust: trust domains from the GDHCN code system", store.loadTrustDomains(read("vectors/gdhcn-trust-domains/CodeSystem-Domains.json")) === 4 && store.trustDomains().join() === "DDCC,ICVP,IPS-PILGRIMAGE,PH4H");
const reg = new subclaims.Registry();
check("subclaims: the guide's defaults, DVC at -6 and VHL at 5", reg.all().map((s) => s.key).join() === "1,3,4,5,-6,-7" && reg.subclaimFor("dvc-min") === -6 && reg.subclaimFor("vhl") === 5);
for (const name of ["hepb1", "bcg"]) {
  const r = verifier.verify(vector.certificates[name].hc1, store, reg, NOW, OPTIONS);
  check(`verifier: ${name} verifies as published`, r.tag === "verified" && r.val.iss === "XX" && r.val.entries.length === 1 && r.val.entries[0].subclaim === -6 && r.val.entries[0].payload.tag === "dvc-min" && r.val.entries[0].payload.val.n === vector.certificates[name].payload.n);
}
const u = verifier.readUnverified(hepb1, reg, L);
check("verifier: read-unverified says so", u.diagnostics[0].message.startsWith("NOT VERIFIED") && u.entries[0]?.subclaim === -6);

// the shared negative vectors
const negative = JSON.parse(read("vectors/negative/negative-vectors.json"));
let agreed = 0;
for (const c of negative.cases) {
  const st = new trust.TrustStore();
  for (const p of c.trust ?? negative.defaults.trust) st.addPem(read(p));
  const now = BigInt(c.now ?? negative.defaults.now);
  const r = c.coseHex ? verifier.verifyCose(Buffer.from(c.coseHex, "hex"), st, reg, now, OPTIONS) : verifier.verify(c.hc1, st, reg, now, OPTIONS);
  const want = [c.expect.step.toLowerCase().replace(/_/g, "-"), c.expect.reason.toLowerCase().replace(/_/g, "-")];
  if (r.tag === "failed" && r.val.step === want[0] && r.val.reason === want[1]) agreed++;
  else console.log(`     ${c.id}: ${JSON.stringify(r.val?.step)} ${JSON.stringify(r.val?.reason)} wanted ${want}`);
}
check(`verifier: all ${negative.cases.length} shared negative vectors stop at the named step with the named reason`, agreed === negative.cases.length, `${agreed}/${negative.cases.length}`);

// dvc
const newborn = { n: "Test CHILD", dob: "2026-09-28", s: "female", nt: "LAO", gn: "Test MOTHER", vx: { vp: "XM9V38", dv: "2026-09-28", is: "org-test", bo: "HEPB-TEST" }, v: "1.0.0", extensions: [] };
check("dvc: a valid DVCMin has no issues, and round-trips through CBOR", dvc.validate(newborn).length === 0 && dvc.fromCbor(dvc.toCbor(newborn), L).n === "Test CHILD");
check("dvc: the rules are enforced", dvc.validate({ ...newborn, nt: "LA" }).some((i) => i.code === "not-alpha3"));

// issuer: two-phase, signed by the host (node:crypto) with the testkit key
const pemDer = (pem, kind) => Buffer.from(pem.split(`-----BEGIN ${kind}-----`)[1].split(`-----END ${kind}-----`)[0].replace(/\s/g, ""), "base64");
const esDsc = pemDer(read("vectors/testkit/es256-dsc.pem"), "CERTIFICATE");
const esKey = createPrivateKey(read("vectors/testkit/es256-key.pem"));
const pending = issuer.prepare({ payloads: [{ tag: "dvc-min", val: newborn }], iss: "XX", validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n }, dscDer: esDsc, alg: "es256", allowDevelopmentSubclaims: true }, reg);
check("issuer: prepare returns the Sig_structure and the kid", pending.algorithm() === "es256" && hex(pending.kid()) === hex(cose.kidFromDsc(esDsc)));
const der = nodeSign("sha256", pending.toBeSigned(), esKey); // DER, as JCA and OpenSSL give it
const issued = issuer.finish(pending, der);
const es = new trust.TrustStore();
es.addDer(esDsc);
const v = verifier.verify(issued.hc1, es, reg, TESTKIT_NOW, OPTIONS);
check("issuer: a DER signature is accepted, and the HC1 verifies", v.tag === "verified" && v.val.entries[0].payload.val.n === "Test CHILD");
check("issuer: a development subclaim needs opting in", throws(() => issuer.prepare({ payloads: [{ tag: "dvc-min", val: newborn }], validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n }, dscDer: esDsc, alg: "es256", allowDevelopmentSubclaims: false }, reg), "development-subclaim-not-allowed"));

// vhl, randomness from the host (wasi:random)
const ihe = { url: "https://vhl-sharer.example.org/List/_search?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item", key: "86F8LY5LlWAa1-OS_FgrTnYNqFHJP2ey5RSKLJBN9jk", exp: 1735689600n, flag: "LP", label: "Patient Health Summary", v: 1, fhirBaseUrl: "https://vhl-sharer.example.org" };
check("vhl: the IHE example payload is valid and round-trips through vhlink:/", vhl.validate(ihe).length === 0 && vhl.fromVhlink(vhl.toVhlink(ihe)).key === ihe.key);
const req = vhl.buildManifestRequest(ihe, "Dr. Smith Hospital", "user-pin", 10000);
check("vhl: the ITI-YY5 request is the IHE example's body", req.body === "_id=abc123def456&code=folder&status=current&patient.identifier=urn%3Aoid%3A2.16.840.1.113883.2.4.6.3%7CPASSPORT123&_include=List%3Aitem&recipient=Dr.+Smith+Hospital&passcode=user-pin&embeddedLengthMax=10000");
check("vhl: the IHE Case B manifest reads as 4 documents", vhl.parseManifest(read("vectors/ihe-vhl/iti-yy5-manifest-case-b.json")).length === 4);
const fixture = JSON.parse(read("vectors/ihe-vhl/jwe-dir-a256gcm.json"));
check("vhl: decrypts the node:crypto JWE, with and without zip DEF", ["jwe", "jweZipDef"].every((k) => new TextDecoder().decode(vhl.decrypt(fixture[k], fixture.key).content) === fixture.plaintext));
const k1 = vhl.newKey(), k2 = vhl.newKey();
check("vhl: new keys come from the host's random source", k1.length === 43 && k1 !== k2);
const jwe = vhl.encrypt(new TextEncoder().encode("hello"), "text/plain", k1);
check("vhl: encrypt then decrypt", new TextDecoder().decode(vhl.decrypt(jwe, k1).content) === "hello" && throws(() => vhl.decrypt(jwe, k2), "decrypt-failed"));
const base = vhl.buildSignatureBase({ method: "POST", authority: "vhl-sharer.example.org", path: "/List/_search", contentType: "application/x-www-form-urlencoded", body: new TextEncoder().encode('{"hello": "world"}'), keyid: "receiver-key-123", alg: "ecdsa-p256-sha256", created: 1735689600n });
check("vhl: the RFC 9530 Content-Digest", base.contentDigest === "sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:");
const sigDer = nodeSign("sha256", base.base, esKey);
const header = vhl.signatureHeader(sigDer, "ecdsa-p256-sha256");
const raw = Buffer.from(header.slice("sig1=:".length, -1), "base64");
check("vhl: a DER signature becomes the 64-byte header value", raw.length === 64 && createVerify("sha256").update(base.base).verify({ key: esKey, dsaEncoding: "ieee-p1363" }, raw));

process.exit(failures ? 1 : 0);
