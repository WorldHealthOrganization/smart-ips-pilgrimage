// Cross-implementation checks (STT-TST-003, STT-GEN-006): each library issues
// certificates, ES256 and PS256, and the other library verifies them. The two
// must also build the same bytes from the same request: the Sig_structure to
// sign, and the COSE_Sign1 once the same signature is attached. Type-checked
// with suite.ts; cross.mjs passes in both implementations.

import type { Hcert, Outcome } from "./suite.ts";
import { L, OPTIONS, TESTKIT_NOW, hex, ihe, newborn } from "./suite.ts";
import type { CoseAlgorithm } from "../../api/generated/ts/interfaces/who-smart-trust-types.js";
import type { IssueRequest } from "../../api/generated/ts/interfaces/who-smart-trust-issuer.js";
import type { Payload } from "../../api/generated/ts/interfaces/who-smart-trust-payloads.js";

export interface CrossFixtures {
  testkitDsc: Uint8Array;
  testkitPsDsc: Uint8Array;
  signEs256Der(data: Uint8Array): Uint8Array;
  /** RSASSA-PSS with SHA-256 and a 32-byte salt over `data`, with the testkit RSA key. */
  signPs256(data: Uint8Array): Uint8Array;
}

/** JSON with bigints, so payloads read back from either library compare as values. */
const canon = (x: unknown) => JSON.stringify(x, (_, v) => (typeof v === "bigint" ? v.toString() : v));

// @test-runner run — each run("title", …) below is a test (check:test-gherkin).
export function runCross(impls: Record<string, Hcert>, f: CrossFixtures): Outcome[] {
  const out: Outcome[] = [];
  const [[aName, a], [bName, b]] = Object.entries(impls) as [[string, Hcert], [string, Hcert]];
  const run = (name: string, body: () => boolean | [boolean, string]) => {
    try {
      const r = body();
      const [ok, detail] = Array.isArray(r) ? r : [r, undefined];
      out.push({ name, ok, ...(detail !== undefined ? { detail } : {}) });
    } catch (e) {
      out.push({ name, ok: false, detail: `threw ${(e as Error).message}` });
    }
  };

  const algs: [CoseAlgorithm, Uint8Array, (d: Uint8Array) => Uint8Array][] = [
    ["es256", f.testkitDsc, f.signEs256Der],
    ["ps256", f.testkitPsDsc, f.signPs256],
  ];
  const dvc: Payload = { tag: "dvc-min", val: newborn };
  // The IHE example link expired in 2025; a live link, or VHL-009 stops it first.
  const vhl: Payload = { tag: "vhl", val: { ...ihe, exp: TESTKIT_NOW + 86400n } };
  // Several payloads in one certificate, too (STT-SEL-004); the wire puts 5 before -6.
  const payloads: [string, Payload[]][] = [["DVC", [dvc]], ["VHL", [vhl]], ["DVC+VHL", [dvc, vhl]]];

  for (const [alg, dsc, signer] of algs) {
    for (const [label, list] of payloads) {
      const req: IssueRequest = { payloads: list, iss: "XX", validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n }, dscDer: dsc, alg, allowDevelopmentSubclaims: true };
      for (const [iName, issuer, vName, verifier] of [[aName, a, bName, b], [bName, b, aName, a]] as const) {
        // One test per case, named by the looped-id convention id[${key}].
        const key = `${alg.toUpperCase()} ${label} ${iName}->${vName}`;
        run(`STT-TST-003-STT-GEN-006-issued-verifies-across-from-the-same-bytes[${key}]`, () => {
          const regI = new issuer.subclaims.Registry();
          const regV = new verifier.subclaims.Registry();
          const pI = issuer.issuer.prepare(req, regI);
          const pV = verifier.issuer.prepare(req, regV);
          const tbs = pI.toBeSigned();
          // The same request gives the same Sig_structure in both libraries (deterministic CBOR, STT-CBR-001).
          if (hex(tbs) !== hex(pV.toBeSigned())) return [false, "the libraries build different Sig_structures"];
          const sig = signer(tbs);
          const issued = issuer.issuer.finish(pI, sig);
          const twin = verifier.issuer.finish(pV, sig);
          // ...and, with the same signature, the same COSE_Sign1. The HC1 text may differ: each deflates on its own.
          const cose = verifier.codec.fromHc1(issued.hc1, L);
          if (hex(cose) !== hex(issuer.codec.fromHc1(twin.hc1, L))) return [false, "the libraries assemble different COSE_Sign1 bytes"];
          verifier.cose.verifySign1(verifier.cose.parseSign1(cose, L), dsc);
          const store = new verifier.trust.TrustStore();
          store.addDer(dsc);
          const r = verifier.verifier.verify(issued.hc1, store, regV, TESTKIT_NOW, OPTIONS);
          // The PS256 testkit DSC's EKU is test certificates only: the signature
          // verified (above, and the pipeline passed SIGNATURE), then key usage
          // stops a vaccination certificate on its own, and marks it beside a
          // payload it does permit (STT-VER-004). A VHL has no EKU rule.
          const vaccinationOnly = list.every((p) => p.tag === "dvc-min");
          if (alg === "ps256" && vaccinationOnly) {
            return r.tag === "failed" ? [r.val.step === "key-usage" && r.val.reason === "key-usage-mismatch", `${r.val.step} ${r.val.reason}`] : [false, "verified despite the test-only EKU"];
          }
          if (r.tag !== "verified") return [false, `${r.val.step} ${r.val.reason}`];
          const want = [...list].sort((x, y) => (x.tag === "vhl" ? -1 : 1) - (y.tag === "vhl" ? -1 : 1))
            .map((p) => ({ subclaim: p.tag === "vhl" ? 5 : -6, payload: p, keyUsageAuthorised: !(alg === "ps256" && p.tag === "dvc-min") }));
          return [canon(r.val.entries) === canon(want), canon(r.val.entries)];
        });
      }
    }
  }

  const pair = `${aName}->${bName}`;
  run(`STT-TST-003-signature-over-other-bytes-refused[${pair}]`, () => {
    const reg = new a.subclaims.Registry();
    const pA = a.issuer.prepare({ payloads: [{ tag: "dvc-min", val: newborn }], iss: "XX", validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n }, dscDer: f.testkitDsc, alg: "es256", allowDevelopmentSubclaims: true }, reg);
    const sig = f.signEs256Der(pA.toBeSigned());
    const regB = new b.subclaims.Registry();
    const pB = b.issuer.prepare({ payloads: [{ tag: "dvc-min", val: { ...newborn, n: "Other CHILD" } }], iss: "XX", validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n }, dscDer: f.testkitDsc, alg: "es256", allowDevelopmentSubclaims: true }, regB);
    // finish checks the signature against the DSC (STT-COS-006), so the forgery never leaves the issuer.
    try {
      b.issuer.finish(pB, sig);
      return [false, "finish accepted a signature over other bytes"];
    } catch (e) {
      return [(e as { payload?: { tag?: string } }).payload?.tag === "bad-signature-format", String((e as { payload?: { tag?: string } }).payload?.tag)];
    }
  });
  return out;
}
