// Runs the compiled Kotlin/JS library on Node against the PR 129 vector:
// the same checks as the JVM tests' ConformanceVectorsTest, without a test framework.
// Verifies STT-GEN-004 (the library runs on Node) and STT-GEN-011 (the Kotlin/JS surface).
//   gradle -p tools/hcert-kotlin :hcert-core:compileProductionLibraryKotlinJs && node tools/hcert-kotlin/hcert-core/node-smoke.mjs
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, "..", "..", "..");
const HcertNode = (await import(join(here, "build/compileSync/js/main/productionLibrary/kotlin/smart-trust-kotlin-hcert-core.mjs"))).HcertNode.getInstance();

const vector = JSON.parse(readFileSync(join(repo, "vectors/smart-trust-pr129/dvc-qr-example-XXA.json"), "utf8"));
const pem = readFileSync(join(repo, "vectors/smart-trust-pr129/dvc-qr-example-XXA-dsc.pem"), "utf8");
const NOW = 1792454400; // 2026-10-20T00:00:00Z

let failures = 0;
function expect(name, got, want) {
  const ok = Object.entries(want).every(([k, v]) => JSON.stringify(got[k]) === JSON.stringify(v));
  console.log(`${ok ? "ok  " : "FAIL"} ${name}: ${JSON.stringify(got)}`);
  if (!ok) failures++;
}
for (const name of ["hepb1", "bcg"]) {
  const hc1 = vector.certificates[name].hc1;
  expect(`${name} verifies`, JSON.parse(HcertNode.verifySummary(hc1, pem, NOW)),
    { status: "verified", entries: [{ subclaim: -6, payload: "dvc-min", keyUsageAuthorised: true }], iss: "XX", kid: "58733e058aaa6621" });
  expect(`${name} expired`, JSON.parse(HcertNode.verifySummary(hc1, pem, 1822206600 + 301)), { status: "failed", reason: "EXPIRED" });
  expect(`${name} unknown kid`, JSON.parse(HcertNode.verifySummary(hc1, "", NOW)), { status: "failed", reason: "KID_NOT_FOUND" });
}
expect("bad prefix", JSON.parse(HcertNode.verifySummary("HC2:00", pem, NOW)), { status: "failed", reason: "UNSUPPORTED_CONTEXT_VERSION" });
// The shared negative vectors (STT-TST-005): the same file the JVM suite loads.
const negative = JSON.parse(readFileSync(join(repo, "vectors/negative/negative-vectors.json"), "utf8"));
for (const c of negative.cases) {
  const trust = (c.trust ?? negative.defaults.trust).map((p) => readFileSync(join(repo, p), "utf8")).join("\n");
  const now = c.now ?? negative.defaults.now;
  const got = c.coseHex ? HcertNode.verifyCoseSummary(c.coseHex, trust, now) : HcertNode.verifySummary(c.hc1, trust, now);
  expect(`negative ${c.id}`, JSON.parse(got), { status: "failed", step: c.expect.step, reason: c.expect.reason });
}
// VHL document decryption on Node, against a JWE made by node:crypto alone.
const jwe = JSON.parse(readFileSync(join(repo, "vectors/ihe-vhl/jwe-dir-a256gcm.json"), "utf8"));
for (const k of ["jwe", "jweZipDef"]) {
  const got = HcertNode.decryptText(jwe[k], jwe.key);
  const ok = got === jwe.plaintext;
  console.log(`${ok ? "ok  " : "FAIL"} ${k} decrypts`);
  if (!ok) failures++;
}
process.exit(failures ? 1 : 0);
