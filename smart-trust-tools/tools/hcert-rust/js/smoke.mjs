// Runs the WebAssembly build on Node against the shared vectors and with a
// key pair WebCrypto generates, as the browser demo does. STT-GEN-005.
//   cargo build --release --locked --target wasm32-unknown-unknown && node tools/hcert-rust/js/smoke.mjs
import { readFileSync } from "node:fs";
import { loadHcert, generateKeyPair, makeTestDsc, issue } from "./hcert.mjs";

const repo = new URL("../../../", import.meta.url);
const hcert = await loadHcert(new URL("tools/hcert-rust/target/wasm32-unknown-unknown/release/hcert.wasm", repo));
const read = (p) => readFileSync(new URL(p, repo), "utf8");
let failures = 0;
const expect = (name, got, want) => {
  const ok = Object.entries(want).every(([k, v]) => got[k] === v);
  console.log(`${ok ? "ok  " : "FAIL"} ${name}: ${JSON.stringify(Object.fromEntries(Object.keys(want).map((k) => [k, got[k]])))}`);
  if (!ok) failures++;
};

const vector = JSON.parse(read("vectors/smart-trust-pr129/dvc-qr-example-XXA.json"));
const pem = read("vectors/smart-trust-pr129/dvc-qr-example-XXA-dsc.pem");
for (const name of ["hepb1", "bcg"]) {
  const r = hcert.call("verify", { hc1: vector.certificates[name].hc1, trustPem: pem, now: 1792454400 });
  expect(`${name} verifies`, { ...r, entrySubclaims: r.entries?.map((e) => e.subclaim).join() }, { status: "verified", entrySubclaims: "-6", iss: "XX", kid: "58733e058aaa6621" });
}
// The live demo's published example: XXR's DSC DID document, trusted only once its proof verifies against WHO's signing DID (STT-TRU-006).
const xxr = JSON.parse(read("vectors/smart-trust-af75be2/dvc-qr-example-XXR.json"));
const xxrDid = read("vectors/smart-trust-af75be2/XXR-DSC-did.json");
const whoSigner = read("vectors/gdhcn-dev-trustlist/WHO-signing-did.json");
for (const [name, c] of Object.entries(xxr.certificates)) {
  const r = hcert.call("verify", { hc1: c.hc1, trustDid: xxrDid, trustDidSigner: whoSigner, now: c.iat + 3600 });
  expect(`XXR ${name} verifies once the DSC document's proof does`, r, { status: "verified", kid: "916ffa567c0f44a2", trustDidProofVerified: true });
}
const tampered = hcert.call("verify", { hc1: xxr.certificates.hepb1.hc1, trustDid: xxrDid.replace('"kty"', '"ext":"1","kty"'), trustDidSigner: whoSigner, now: xxr.certificates.hepb1.iat + 3600 });
expect("a changed DSC document fails its proof and nothing is verified", { ...tampered, proof: tampered.error?.startsWith("DID document proof invalid") }, { ok: false, proof: true, status: undefined });
const negative = JSON.parse(read("vectors/negative/negative-vectors.json"));
for (const c of negative.cases) {
  const trustPem = (c.trust ?? negative.defaults.trust).map(read).join("\n");
  const r = hcert.call("verify", { hc1: c.hc1, coseHex: c.coseHex, trustPem, now: c.now ?? negative.defaults.now });
  expect(`negative ${c.id}`, r, { status: "failed", step: c.expect.step, reason: c.expect.reason });
}
const now = Math.floor(Date.now() / 1000);
const dvc = { n: "Test CHILD", dob: "2026-09-28", s: "female", nt: "LAO", vx: { vp: "XM9V38", dv: "2026-09-28", is: "org-test", bo: "HEPB-TEST" }, v: "1.0.0" };
for (const alg of ["ES256", "PS256"]) {
  const keys = await generateKeyPair(alg);
  const dsc = await makeTestDsc(hcert, keys);
  const issued = await issue(hcert, keys, dsc, { dvc, iat: now, exp: now + 86400 });
  expect(`${alg} own key issues and verifies`, hcert.call("verify", { hc1: issued.hc1, trustPem: dsc.pem, now }), { status: "verified", kid: dsc.kid });
  const other = await makeTestDsc(hcert, await generateKeyPair(alg));
  expect(`${alg} another key's DSC is not trusted`, hcert.call("verify", { hc1: issued.hc1, trustPem: other.pem, now }), { status: "failed", reason: "KID_NOT_FOUND" });
}
process.exit(failures ? 1 : 0);
