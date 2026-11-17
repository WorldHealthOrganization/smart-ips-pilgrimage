// What run.mjs and cross.mjs share: a loader per implementation, which only
// regroups that package's exports under the `hcert` world's interface names,
// and the fixtures built from vectors/ (signing with node:crypto and the
// testkit keys, so the suites themselves need no Node types).
import { readFileSync } from "node:fs";
import { constants, createPrivateKey, sign, createVerify, generateKeyPairSync } from "node:crypto";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repo = fileURLToPath(new URL("../../", import.meta.url));
const read = (p) => readFileSync(join(repo, p), "utf8");

export const loaders = {
  // jco gives one namespace per WIT interface already.
  rust: async (dir) => import(join(resolve(dir), "js", "hcert.js")),
  // Kotlin/JS exports each interface as an object behind getInstance(), and
  // the resources as classes; this regroups them under the interface names.
  kotlin: async (dir) => {
    const m = await import(join(resolve(dir), "smart-trust-kotlin-hcert-core.mjs"));
    const ns = (o) => {
      const i = o.getInstance();
      const out = {};
      for (const k of Object.getOwnPropertyNames(Object.getPrototypeOf(i))) if (k !== "constructor" && typeof i[k] === "function") out[k] = i[k].bind(i);
      return out;
    };
    return {
      codec: ns(m.WitCodec), cose: ns(m.WitCose), dvc: ns(m.WitDvc), vhl: ns(m.WitVhl), verifier: ns(m.WitVerifier),
      issuer: { ...ns(m.WitIssuer), PendingSignature: m.WitPendingSignature },
      subclaims: { Registry: m.WitRegistry }, trust: { ...ns(m.WitTrust), TrustStore: m.WitTrustStore },
    };
  },
};

const negative = JSON.parse(read("vectors/negative/negative-vectors.json"));
const pemPaths = new Set([...negative.defaults.trust, ...negative.cases.flatMap((c) => c.trust ?? [])]);
const pemDer = (pem) => new Uint8Array(Buffer.from(pem.split("-----BEGIN CERTIFICATE-----")[1].split("-----END CERTIFICATE-----")[0].replace(/\s/g, ""), "base64"));
const key = createPrivateKey(read("vectors/testkit/es256-key.pem"));
const psKey = createPrivateKey(read("vectors/testkit/ps256-key.pem"));
// A P-256 key no DSC holds, made fresh each run: a signature by it must be refused (STT-COS-006).
const otherKey = generateKeyPairSync("ec", { namedCurve: "P-256" }).privateKey;
export const fixtures = {
  pr129: JSON.parse(read("vectors/smart-trust-pr129/dvc-qr-example-XXA.json")),
  pr129Pem: read("vectors/smart-trust-pr129/dvc-qr-example-XXA-dsc.pem"),
  xxr: JSON.parse(read("vectors/smart-trust-af75be2/dvc-qr-example-XXR.json")),
  xxrDscDid: read("vectors/smart-trust-af75be2/XXR-DSC-did.json"),
  devTrustList: {
    signer: read("vectors/gdhcn-dev-trustlist/WHO-signing-did.json"),
    documents: Object.fromEntries(["XXR-DSC-did-2026-10-23.json", "XXR-did.json", "XXA-did.json", "root-did.json"].map((f) => [f, read(`vectors/gdhcn-dev-trustlist/${f}`)])),
  },
  negative,
  pem: Object.fromEntries([...pemPaths].map((p) => [p, read(p)])),
  trustDomains: read("vectors/gdhcn-trust-domains/CodeSystem-Domains.json"),
  manifestCaseB: read("vectors/ihe-vhl/iti-yy5-manifest-case-b.json"),
  jwe: JSON.parse(read("vectors/ihe-vhl/jwe-dir-a256gcm.json")),
  testkitDsc: pemDer(read("vectors/testkit/es256-dsc.pem")),
  signEs256Der: (data) => new Uint8Array(sign("sha256", data, key)),
  signEs256DerOtherKey: (data) => new Uint8Array(sign("sha256", data, otherKey)),
  verifyEs256Raw: (data, raw) => createVerify("sha256").update(data).verify({ key, dsaEncoding: "ieee-p1363" }, raw),
  testkitPsDsc: pemDer(read("vectors/testkit/ps256-dsc-test-eku.pem")),
  // COSE PS256 (RFC 8230): RSASSA-PSS, SHA-256, MGF1 with SHA-256, salt length 32.
  signPs256: (data) => new Uint8Array(sign("sha256", data, { key: psKey, padding: constants.RSA_PKCS1_PSS_PADDING, saltLength: 32 })),
};

