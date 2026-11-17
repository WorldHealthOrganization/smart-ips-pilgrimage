// One conformance suite for both HCERT libraries (STT-TST-007): the Kotlin/JS
// package and the jco-transpiled Rust component. It is type-checked against
// api/generated/ts, the TypeScript that jco derives from the WIT contract, so
// a call or a result that differs from the contract fails tsc before it runs.
// The data comes from the shared vectors (STT-TST-005), passed in by run.mjs.
// Verifies STT-TST-007 and STT-GEN-011: tsc type-checks it against api/generated/ts
// for both packages before it runs.

import type * as codecT from "../../api/generated/ts/interfaces/who-smart-trust-codec.js";
import type * as coseT from "../../api/generated/ts/interfaces/who-smart-trust-cose.js";
import type * as subclaimsT from "../../api/generated/ts/interfaces/who-smart-trust-subclaims.js";
import type * as dvcT from "../../api/generated/ts/interfaces/who-smart-trust-dvc.js";
import type * as vhlT from "../../api/generated/ts/interfaces/who-smart-trust-vhl.js";
import type * as trustT from "../../api/generated/ts/interfaces/who-smart-trust-trust.js";
import type * as verifierT from "../../api/generated/ts/interfaces/who-smart-trust-verifier.js";
import type * as issuerT from "../../api/generated/ts/interfaces/who-smart-trust-issuer.js";
import type { DecodeLimits } from "../../api/generated/ts/interfaces/who-smart-trust-types.js";
import type { DvcMin } from "../../api/generated/ts/interfaces/who-smart-trust-dvc.js";
import type { VhlPayload } from "../../api/generated/ts/interfaces/who-smart-trust-vhl.js";
import type { VerificationResult, VerifierOptions } from "../../api/generated/ts/interfaces/who-smart-trust-verifier.js";

/** The `hcert` world: what each implementation's loader returns. */
export interface Hcert {
  codec: typeof codecT;
  cose: typeof coseT;
  subclaims: Pick<typeof subclaimsT, "Registry">;
  dvc: typeof dvcT;
  vhl: typeof vhlT;
  trust: Pick<typeof trustT, "TrustStore" | "verifyDidProof">;
  verifier: typeof verifierT;
  issuer: typeof issuerT;
}

export interface NegativeCase {
  id: string;
  hc1?: string;
  coseHex?: string;
  trust?: string[];
  now?: number;
  expect: { step: string; reason: string };
}

/** The shared vectors, and a signer standing in for the host's key holder. */
export interface Fixtures {
  pr129: { certificates: Record<string, { hc1: string; payload: { n: string } }> };
  pr129Pem: string;
  /** The merged guide's example (WHO af75be2), GDHCN DEV participant XXR: decodes, but its DSC is on the DEV trust list only. */
  /** XXR's DSC DID document from the GDHCN DEV trust list. */
  xxrDscDid: string;
  /** GDHCN DEV trust list DID documents and WHO's signing DID (vectors/gdhcn-dev-trustlist). */
  devTrustList: { signer: string; documents: Record<string, string> };
  xxr: { kid_hex: string; certificates: Record<string, { hc1: string; iss: string; iat: number; cwt_cbor_bytes: number; cose_sign1_bytes: number; deflated_bytes: number; hc1_chars: number; payload: { n: string; vx: { vp: string; bo: string } } }> };
  negative: { defaults: { trust: string[]; now: number; clockSkewSeconds: number }; cases: NegativeCase[] };
  pem: Record<string, string>;
  trustDomains: string;
  manifestCaseB: string;
  jwe: { key: string; plaintext: string; jwe: string; jweZipDef: string };
  testkitDsc: Uint8Array;
  /** ES256 over `data` with the testkit key, as DER (as JCA and OpenSSL give it). */
  signEs256Der(data: Uint8Array): Uint8Array;
  /** ES256 (DER) by a fresh P-256 key that no DSC holds: for the wrong-key refusal. */
  signEs256DerOtherKey(data: Uint8Array): Uint8Array;
  /** Verifies a 64-byte r||s ES256 signature with the testkit key. */
  verifyEs256Raw(data: Uint8Array, raw: Uint8Array): boolean;
  /** The PS256 testkit DSC, whose EKU allows test certificates only. */
  testkitPsDsc: Uint8Array;
  /** PS256 over `data` with the testkit RSA key. */
  signPs256(data: Uint8Array): Uint8Array;
}

export interface Outcome {
  name: string;
  ok: boolean;
  detail?: string;
}

export const L: DecodeLimits = { maxInputChars: 8192, maxInflatedBytes: 65536, maxDepth: 16, maxItems: 4096, maxStringBytes: 16384 };
export const OPTIONS: VerifierOptions = { limits: L, clockSkewSeconds: 300 };
const NOW = 1792454400n; // 2026-10-20T00:00:00Z
export const TESTKIT_NOW = 1792520192n + 3600n;

export const hex = (b: Uint8Array) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
const fromHex = (h: string) => new Uint8Array(h.match(/../g)?.map((x) => parseInt(x, 16)) ?? []);
const text = (b: Uint8Array) => new TextDecoder().decode(b);

/** The error variant a call threw, as both libraries throw it: `{ payload: { tag, val } }`. */
function thrownTag(f: () => unknown): string | undefined {
  try {
    f();
    return undefined;
  } catch (e) {
    return (e as { payload?: { tag?: string } }).payload?.tag;
  }
}

/** CBOR head (RFC 8949 3.1) for major type `mt` and argument `n`. */
function head(mt: number, n: number): number[] {
  const m = mt << 5;
  if (n < 24) return [m | n];
  if (n < 0x100) return [m | 24, n];
  if (n < 0x10000) return [m | 25, n >> 8, n & 0xff];
  return [m | 26, (n >>> 24) & 0xff, (n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff];
}
const cborInt = (n: number) => (n >= 0 ? head(0, n) : head(1, -1 - n));
const cborBytes = (b: Uint8Array) => [...head(2, b.length), ...b];
const cborText = (t: string) => { const b = new TextEncoder().encode(t); return [...head(3, b.length), ...b]; };

/** A minimal CBOR reader for the tests' own checks: ints, byte and text strings, arrays, maps, tags. */
type Cbor = number | Uint8Array | string | Cbor[] | Map<Cbor, Cbor> | { tag: number; item: Cbor };
function cborRead(b: Uint8Array): Cbor {
  let i = 0;
  const arg = (ai: number): number => {
    if (ai < 24) return ai;
    const n = [1, 2, 4][ai - 24]!;
    let v = 0;
    for (let k = 0; k < n; k++) v = v * 256 + b[i++]!;
    return v;
  };
  const item = (): Cbor => {
    const ib = b[i++]!;
    const mt = ib >> 5, n = arg(ib & 31);
    switch (mt) {
      case 0: return n;
      case 1: return -1 - n;
      case 2: return b.slice(i, (i += n));
      case 3: return new TextDecoder().decode(b.slice(i, (i += n)));
      case 4: return Array.from({ length: n }, item);
      case 5: { const m = new Map<Cbor, Cbor>(); for (let k = 0; k < n; k++) { const key = item(); m.set(key, item()); } return m; }
      case 6: return { tag: n, item: item() };
      default: throw new Error(`major type ${mt} not read here`);
    }
  };
  return item();
}
const mapKeys = (c: Cbor) => [...(c as Map<Cbor, Cbor>).keys()];

export const newborn: DvcMin = {
  n: "Test CHILD", dob: "2026-09-28", s: "female", nt: "LAO", gn: "Test MOTHER",
  vx: { vp: "XM9V38", dv: "2026-09-28", is: "org-test", bo: "HEPB-TEST" }, v: "1.0.0", extensions: [],
};

export const ihe: VhlPayload = {
  url: "https://vhl-sharer.example.org/List/_search?_id=abc123def456&code=folder&status=current&patient.identifier=urn:oid:2.16.840.1.113883.2.4.6.3|PASSPORT123&_include=List:item",
  key: "86F8LY5LlWAa1-OS_FgrTnYNqFHJP2ey5RSKLJBN9jk", exp: 1735689600n, flag: "LP", label: "Patient Health Summary", v: 1,
  fhirBaseUrl: "https://vhl-sharer.example.org",
};

// @test-runner run — each run("title", …) below is a test (check:test-gherkin).
export function runSuite(h: Hcert, f: Fixtures): Outcome[] {
  const out: Outcome[] = [];
  const check = (name: string, ok: boolean, detail?: string) => out.push({ name, ok, detail });
  const run = (name: string, body: () => boolean | [boolean, string]) => {
    try {
      const r = body();
      Array.isArray(r) ? check(name, r[0], r[1]) : check(name, r);
    } catch (e) {
      check(name, false, `threw ${(e as Error).message}`);
    }
  };
  const hepb1 = f.pr129.certificates.hepb1.hc1;

  // codec (steps 4, 6, 7, 8)
  run("STT-HC1-001 STT-B45-001 STT-ZIP-001 the PR 129 HC1 string decodes to the 295-byte COSE_Sign1", () => h.codec.fromHc1(hepb1, L).length === 295);
  run("STT-HC1-001 the context identifier is read and other versions refused", () => {
    const [v, rest] = h.codec.detectContext("HC1:XYZ");
    return v === "1" && rest === "XYZ" && thrownTag(() => h.codec.fromHc1("HC2:00", L)) === "unsupported-context-version" && thrownTag(() => h.codec.detectContext("XYZ")) === "bad-prefix";
  });
  run("STT-B45-001 STT-B45-002 Base45: RFC 9285 examples, and strict decoding", () =>
    h.codec.base45Encode(new TextEncoder().encode("Hello!!")) === "%69 VD92EX0" && text(h.codec.base45Decode("UJCLQE7W581")) === "base-45" && thrownTag(() => h.codec.base45Decode("abc")) === "base45-invalid");
  run("STT-ZIP-001 STT-ZIP-002 ZLIB round-trips, and inflation stops at the limit", () => {
    const z = h.codec.zlibCompress(new Uint8Array(10000).fill(7), 9);
    return h.codec.zlibInflate(z, 10000).length === 10000 && thrownTag(() => h.codec.zlibInflate(z, 9999)) === "limit-exceeded";
  });
  run("STT-QR-001 to-hc1 inverts from-hc1, in the Alphanumeric alphabet", () => {
    const c = h.codec.fromHc1(hepb1, L);
    const back = h.codec.toHc1(c);
    return /^HC1:[0-9A-Z $%*+\-./:]+$/.test(back) && hex(h.codec.fromHc1(back, L)) === hex(c);
  });
  run("STT-CBR-001 deterministic re-encoding: RFC 8949 Appendix A, and the PR 129 CWT byte for byte", () => {
    const det = (x: string) => hex(h.codec.cborDeterministic(fromHex(x), L));
    const s = h.cose.parseSign1(h.codec.fromHc1(hepb1, L), L);
    return det("fb3ff0000000000000") === "f93c00" && det("bf6346756ef563416d7421ff") === "a263416d74216346756ef5" && hex(h.codec.cborDeterministic(s.payload, L)) === hex(s.payload);
  });
  run("STT-CBR-003 nesting beyond the limit is refused", () => thrownTag(() => h.codec.cborDeterministic(new Uint8Array([...new Array(40).fill(0x81), 0]), L)) === "limit-exceeded");

  run("STT-TST-011 STT-TST-002 the merged guide's XXR certificates decode as published, at the published sizes", () => {
    const store = new h.trust.TrustStore();
    store.addPem(f.pr129Pem);
    return Object.entries(f.xxr.certificates).every(([, c]) => {
      const u = h.verifier.readUnverified(c.hc1, new h.subclaims.Registry(), L);
      const cose = h.codec.fromHc1(c.hc1, L);
      const s = h.cose.parseSign1(cose, L);
      const r = h.verifier.verify(c.hc1, store, new h.subclaims.Registry(), NOW, OPTIONS);
      return hex(u.kid ?? new Uint8Array()) === f.xxr.kid_hex && u.iss === c.iss && u.entries.length === 1 && u.entries[0]!.subclaim === -6 &&
        u.entries[0]!.payload?.tag === "dvc-min" && u.entries[0]!.payload.val.n === c.payload.n && u.entries[0]!.payload.val.vx.vp === c.payload.vx.vp && u.entries[0]!.payload.val.vx.bo === c.payload.vx.bo &&
        hex(h.codec.cborDeterministic(s.payload, L)) === hex(s.payload) && s.payload.length === c.cwt_cbor_bytes && cose.length === c.cose_sign1_bytes &&
        h.codec.base45Decode(c.hc1.slice(4)).length === c.deflated_bytes && c.hc1.length === c.hc1_chars &&
        r.tag === "failed" && r.val.step === "trust-lookup" && r.val.reason === "kid-not-found";
    });
  });

  run("STT-TST-011 the merged guide's XXR certificates verify against the DEV trust list's DSC", () => {
    const dev = new h.trust.TrustStore();
    if (dev.addDidDocument(f.xxrDscDid) !== 1) return [false, "the DID document gave no DSC"];
    return Object.entries(f.xxr.certificates).every(([, c]) => {
      const r = h.verifier.verify(c.hc1, dev, new h.subclaims.Registry(), BigInt(c.iat) + 3600n, OPTIONS);
      return r.tag === "verified" && r.val.iss === "XR" && r.val.dsc.country === "XR" && hex(r.val.dsc.kid) === f.xxr.kid_hex &&
        r.val.entries.length === 1 && r.val.entries[0]!.keyUsageAuthorised && r.val.entries[0]!.payload.tag === "dvc-min" &&
        r.val.entries[0]!.payload.val.vx.vp === c.payload.vx.vp && r.val.diagnostics.length === 0;
    });
  });

  // Trust list DID document proofs (STT-TRU-006): the DEV documents verify, and
  // each rule of the shared fail-closed profile refuses the same edits in both libraries.
  const proofOk = (doc: string, signer = f.devTrustList.signer) => {
    try {
      h.trust.verifyDidProof(doc, signer);
      return "ok";
    } catch (e) {
      return (e as { payload?: { tag?: string } }).payload?.tag ?? `threw ${(e as Error).message}`;
    }
  };
  run("STT-TRU-006 the DEV trust list documents, the 234-key root among them, verify against WHO's signing DID", () => {
    const docs = [f.xxrDscDid, ...Object.values(f.devTrustList.documents)];
    const got = docs.map((d) => proofOk(d));
    return [got.every((g) => g === "ok"), got.join(",")];
  });
  run("STT-TRU-006 a DER signature re-encoded as 64-byte r||s verifies too", () => {
    const d = JSON.parse(f.xxrDscDid);
    const [hdr, , sig] = d.proof.jws.split(".");
    const b64 = (b: Uint8Array) => btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
    const der = Uint8Array.from(atob(sig.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));
    d.proof.jws = `${hdr}..${b64(h.cose.ecdsaDerToRaw(der))}`;
    return proofOk(JSON.stringify(d)) === "ok";
  });
  run("STT-TRU-006 the shared profile refuses each unmodelled or altered shape with proof-invalid", () => {
    const base = () => JSON.parse(f.xxrDscDid);
    const signer = () => JSON.parse(f.devTrustList.signer);
    const cases: [string, string, string?][] = [];
    const add = (name: string, edit: (d: any) => void) => { const d = base(); edit(d); cases.push([name, JSON.stringify(d)]); };
    add("a changed byte in an x5c", (d) => { const x = d.verificationMethod[0].publicKeyJwk.x5c[0]; d.verificationMethod[0].publicKeyJwk.x5c[0] = (x[10] === "A" ? "B" : "A") + x.slice(1); });
    add("an extra top-level key", (d) => { d.service = []; });
    add("a controller array", (d) => { d.controller = [d.controller]; });
    add("no controller", (d) => { delete d.controller; });
    add("proofValue beside jws", (d) => { d.proof.proofValue = "z"; });
    add("a boolean JWK member", (d) => { d.verificationMethod[0].publicKeyJwk.ext = true; });
    add("an https: controller", (d) => { d.controller = "https://example.org/x"; });
    add("DEL in the nonce", (d) => { d.proof.nonce = "a\u007fb"; });
    add("a code point above U+FFFF in a JWK string", (d) => { d.verificationMethod[0].publicKeyJwk.kid = "kW/6VnwPRKI=\u{1F600}"; });
    add("a changed created lexical form", (d) => { d.proof.created = d.proof.created.replace("Z", "+00:00"); });
    add("an extra key in a value set", (d) => { d.verificationMethod[0].domain.display = "x"; });
    add("a wrong JWS header", (d) => { const [, , s] = d.proof.jws.split("."); d.proof.jws = `${btoa(JSON.stringify({ b64: false, crit: ["b64"], alg: "ES384" })).replace(/=+$/, "")}..${s}`; });
    const dup = f.xxrDscDid.replace('"controller":', '"controller":"did:x","controller":');
    cases.push(["a duplicate member name", dup]);
    const s1 = signer(); s1.verificationMethod[0].publicKeyJwk.alg = "ES384";
    cases.push(["a signer key whose alg is not ES256", f.xxrDscDid, JSON.stringify(s1)]);
    const s2 = signer(); s2.id = "did:web:example.org";
    cases.push(["a signer for another DID", f.xxrDscDid, JSON.stringify(s2)]);
    const wrong = cases.map(([n, d, s]) => [n, proofOk(d, s)] as const).filter(([, g]) => g !== "proof-invalid");
    return [wrong.length === 0, wrong.map(([n, g]) => `${n}: ${g}`).join("; ")];
  });
  run("STT-TRU-006 the trust store adds a verified document, and nothing when the proof fails", () => {
    const st = new h.trust.TrustStore();
    const tampered = f.xxrDscDid.replace('"nonce":"', '"nonce":"x');
    let refused = false;
    try { st.addVerifiedDidDocument(tampered, f.devTrustList.signer); } catch (e) { refused = (e as { payload?: { tag?: string } }).payload?.tag === "proof-invalid"; }
    const empty = st.size() === 0;
    const added = st.addVerifiedDidDocument(f.xxrDscDid, f.devTrustList.signer);
    return refused && empty && added === 1 && st.size() === 1;
  });

  // cose (step 5)
  run("STT-COS-001 STT-COS-002 STT-COS-003 STT-KID-001 the COSE_Sign1 is tagged ES256 with the vector's kid in the protected header", () => {
    const s = h.cose.parseSign1(h.codec.fromHc1(hepb1, L), L);
    return [s.tagged && s.alg === "es256" && s.kidInProtected && s.kid !== undefined && hex(s.kid) === "58733e058aaa6621", hex(s.kid ?? new Uint8Array())];
  });
  run("STT-KID-003 kid base64, standard and URL-safe", () => {
    const k = fromHex("58733e058aaa6621");
    return h.cose.kidToBase64(k, "standard") === "WHM+BYqqZiE=" && h.cose.kidToBase64(k, "url-safe").startsWith("WHM-BYqqZiE") && hex(h.cose.kidFromBase64("WHM-BYqqZiE")) === hex(k);
  });
  run("STT-COS-004 STT-COS-002 verify-sign1 checks the Sig_structure against the DSC", () => {
    const s = h.cose.parseSign1(h.codec.fromHc1(hepb1, L), L);
    const store = new h.trust.TrustStore();
    store.addPem(f.pr129Pem);
    const dsc = store.candidates(s.kid ?? new Uint8Array())[0]!.der;
    h.cose.verifySign1(s, dsc);
    const bad = { ...s, signature: s.signature.map((b, i) => (i === 0 ? b ^ 1 : b)) };
    return thrownTag(() => h.cose.verifySign1(bad, dsc)) === "signature-invalid" && h.cose.sigStructure(s.protected, s.payload)[0] === 0x84;
  });
  run("STT-COS-005 ECDSA DER and r||s convert both ways", () => {
    const der = f.signEs256Der(new Uint8Array([1, 2, 3]));
    const raw = h.cose.ecdsaDerToRaw(der);
    return raw.length === 64 && hex(h.cose.ecdsaDerToRaw(h.cose.ecdsaRawToDer(raw))) === hex(raw) && thrownTag(() => h.cose.ecdsaRawToDer(new Uint8Array(10))) === "bad-signature-format";
  });

  // subclaims
  run("STT-SEL-001 STT-SEL-002 the registry starts with the guide's subclaims, and is configuration", () => {
    const reg = new h.subclaims.Registry();
    const keys = reg.all().map((s) => s.key).join();
    const dvc = reg.subclaimFor("dvc-min");
    reg.setSubclaimFor("dvc-min", -99);
    reg.register({ key: -99, title: "DVCMin moved" });
    return [keys === "1,3,4,5,-6,-7" && dvc === -6 && reg.subclaimFor("vhl") === 5 && reg.subclaimFor("dvc-min") === -99 && reg.lookup(-99)?.title === "DVCMin moved", keys];
  });

  // dvc (step 2)
  run("STT-PAY-001 STT-PAY-008 a DVCMin round-trips through CBOR", () => h.dvc.fromCbor(h.dvc.toCbor(newborn), L).gn === "Test MOTHER" && h.dvc.validate(newborn).length === 0);
  run("STT-PAY-002 STT-PAY-007 the logical model's rules are enforced", () => {
    const codes = h.dvc.validate({ ...newborn, nt: "LA", vx: { ...newborn.vx, is: undefined } }).map((i) => i.code);
    return [codes.includes("not-alpha3") && codes.includes("must-have-issuer-or-clinician-name"), codes.join()];
  });

  // trust
  run("STT-TRU-005 STT-KID-002 PEM loads once; candidates by kid", () => {
    const st = new h.trust.TrustStore();
    const n = st.addPem(f.pr129Pem);
    return n === 2 && st.addPem(f.pr129Pem) === 0 && st.size() === 2 && st.candidates(fromHex("58733e058aaa6621")).length === 1 && thrownTag(() => st.addPem("nothing")) === "parse";
  });
  run("STT-SEL-006 trust domains come from the GDHCN code system", () => {
    const st = new h.trust.TrustStore();
    const n = st.loadTrustDomains(f.trustDomains);
    const did = (d: string) => JSON.stringify({ id: `did:web:x:v2:trustlist:${d}:XX:DSC`, verificationMethod: [{ id: `did:web:x:v2:trustlist:${d}:XX:DSC#k`, publicKeyJwk: { x5c: [btoa(String.fromCharCode(...f.testkitDsc))] } }] });
    return n === 4 && st.trustDomains().join() === "DDCC,ICVP,IPS-PILGRIMAGE,PH4H" && thrownTag(() => st.addDidDocument(did("FUTURE"))) === "unknown-trust-domain" && st.addDidDocument(did("DDCC")) === 1 && st.candidates(h.cose.kidFromDsc(f.testkitDsc))[0]?.domain === "DDCC";
  });

  // verifier (section 11)
  const reg = new h.subclaims.Registry();
  const store = new h.trust.TrustStore();
  store.addPem(f.pr129Pem);
  for (const [name, c] of Object.entries(f.pr129.certificates)) {
    run(`STT-TST-001-STT-VER-001-PR-129-certificate-verifies-as-published[${name}]`, () => {
      const r = h.verifier.verify(c.hc1, store, reg, NOW, OPTIONS);
      return r.tag === "verified" && r.val.iss === "XX" && r.val.entries.length === 1 && r.val.entries[0]!.subclaim === -6 && r.val.entries[0]!.payload.tag === "dvc-min" && r.val.entries[0]!.payload.val.n === c.payload.n && r.val.dsc.notBefore < NOW;
    });
  }
  run("STT-VER-011 read-unverified decodes and says it is not verified", () => {
    const u = h.verifier.readUnverified(hepb1, reg, L);
    return u.diagnostics[0]!.message.startsWith("NOT VERIFIED") && u.entries[0]?.subclaim === -6 && u.iss === "XX" && typeof u.iat === "bigint";
  });
  const negative = f.negative;
  for (const c of negative.cases) {
    const key = `${c.id}: ${c.expect.step} ${c.expect.reason}`;
    run(`STT-TST-004-STT-TST-005-STT-VER-008-negative-vector-stops-at-the-named-step[${key}]`, () => {
      const st = new h.trust.TrustStore();
      for (const p of c.trust ?? negative.defaults.trust) st.addPem(f.pem[p]!);
      const now = BigInt(c.now ?? negative.defaults.now);
      const options: VerifierOptions = { limits: L, clockSkewSeconds: negative.defaults.clockSkewSeconds };
      const r: VerificationResult = c.coseHex ? h.verifier.verifyCose(fromHex(c.coseHex), st, reg, now, options) : h.verifier.verify(c.hc1!, st, reg, now, options);
      const want = [c.expect.step, c.expect.reason].map((x) => x.toLowerCase().replace(/_/g, "-"));
      return r.tag === "failed" ? [r.val.step === want[0] && r.val.reason === want[1], `${r.val.step} ${r.val.reason}`] : [false, "verified"];
    });
  }

  // issuer (two-phase, the host signs)
  run("STT-ISS-004 STT-COS-005 two-phase issuance with a host DER signature verifies", () => {
    const p = h.issuer.prepare({ payloads: [{ tag: "dvc-min", val: newborn }], iss: "XX", validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n }, dscDer: f.testkitDsc, alg: "es256", allowDevelopmentSubclaims: true }, reg);
    // finish takes the pending signature by ownership (WIT `own`): read it first.
    const alg = p.algorithm();
    const kid = hex(p.kid());
    const issued = h.issuer.finish(p, f.signEs256Der(p.toBeSigned()));
    const st = new h.trust.TrustStore();
    st.addDer(f.testkitDsc);
    const r = h.verifier.verify(issued.hc1, st, reg, TESTKIT_NOW, OPTIONS);
    return alg === "es256" && kid === hex(h.cose.kidFromDsc(f.testkitDsc)) && r.tag === "verified" && r.val.entries[0]?.payload.tag === "dvc-min" && r.val.entries[0].payload.val.n === "Test CHILD";
  });
  run("STT-SEL-003 STT-CWT-004 development subclaims need opting in; validity must sit inside the DSC", () => {
    const req = { payloads: [{ tag: "dvc-min" as const, val: newborn }], validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n }, dscDer: f.testkitDsc, alg: "es256" as const, allowDevelopmentSubclaims: false };
    return thrownTag(() => h.issuer.prepare(req, reg)) === "development-subclaim-not-allowed" &&
      thrownTag(() => h.issuer.prepare({ ...req, allowDevelopmentSubclaims: true, validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n * 365n * 20n } }, reg)) === "validity-outside-dsc";
  });
  run("STT-COS-006 finish refuses a signature from another key", () => {
    const p = h.issuer.prepare({ payloads: [{ tag: "dvc-min", val: newborn }], validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n }, dscDer: f.testkitDsc, alg: "es256", allowDevelopmentSubclaims: true }, reg);
    // A well-formed signature over the right bytes, by a key that is not the DSC's.
    return thrownTag(() => h.issuer.finish(p, f.signEs256DerOtherKey(p.toBeSigned()))) === "bad-signature-format";
  });

  // OI-38: the assertions the Rust component's run left unnamed. Each one
  // runs against both packages, as every check here does.
  const esStore = () => { const st = new h.trust.TrustStore(); st.addDer(f.testkitDsc); return st; };
  const psStore = () => { const st = new h.trust.TrustStore(); st.addDer(f.testkitPsDsc); return st; };
  const validity = { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n };
  type Req = Parameters<typeof h.issuer.prepare>[0];
  const req = (over: Partial<Req> = {}): Req => ({ payloads: [{ tag: "dvc-min", val: newborn }], iss: "XX", validity, dscDer: f.testkitDsc, alg: "es256", allowDevelopmentSubclaims: true, ...over });
  const issueWith = (r: Req, registry = reg) => {
    const p = h.issuer.prepare(r, registry);
    return h.issuer.finish(p, r.alg === "ps256" ? f.signPs256(p.toBeSigned()) : f.signEs256Der(p.toBeSigned()));
  };
  /** A COSE_Sign1 over the claim set `payload` (encoded CBOR), signed by the ES256 testkit key, with the given protected header. */
  const signedCose = (payload: Uint8Array, protectedHeader?: Uint8Array) => {
    const ph = protectedHeader ?? new Uint8Array([0xa2, 0x01, 0x26, 0x04, ...cborBytes(h.cose.kidFromDsc(f.testkitDsc))]);
    const sig = h.cose.ecdsaDerToRaw(f.signEs256Der(h.cose.sigStructure(ph, payload)));
    return new Uint8Array([0xd2, 0x84, ...cborBytes(ph), 0xa0, ...cborBytes(payload), ...cborBytes(sig)]);
  };
  const dvcCbor = () => h.dvc.toCbor(newborn);
  /** {4: exp, 6: iat, -260: {-6: DVC}} plus `extra` encoded claims, exp left out when null. */
  const claims = (exp: bigint | null, extra: number[][] = []) => {
    const entries: number[][] = [];
    if (exp !== null) entries.push([...cborInt(4), ...cborInt(Number(exp))]);
    entries.push([...cborInt(6), ...cborInt(Number(TESTKIT_NOW))]);
    entries.push([...cborInt(-260), ...head(5, 1), ...cborInt(-6), ...dvcCbor()]);
    entries.push(...extra);
    return new Uint8Array([...head(5, entries.length), ...entries.flat()]);
  };

  run("STT-CWT-001 STT-CWT-002 the claim set has integer keys and integer NumericDates", () => {
    const s = h.cose.parseSign1(issueWith(req()).cose, L);
    const c = cborRead(s.payload) as Map<Cbor, Cbor>;
    const hc = c.get(-260) as Map<Cbor, Cbor>;
    return [mapKeys(c).join() === "1,4,6,-260" && c.get(4) === Number(validity.exp) && c.get(6) === Number(TESTKIT_NOW) && c.get(1) === "XX" && mapKeys(hc).join() === "-6", mapKeys(c).join()];
  });
  run("STT-CWT-003 an HCERT without exp is refused on issue and on verify", () => {
    const r = h.verifier.verifyCose(signedCose(claims(null)), esStore(), reg, TESTKIT_NOW, OPTIONS);
    return thrownTag(() => h.issuer.prepare(req({ validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW } }), reg)) === "payload-invalid" &&
      r.tag === "failed" && r.val.step === "cwt" && r.val.reason === "cose-malformed";
  });
  run("STT-CWT-005 iss is optional, and two upper-case letters when present", () => {
    const none = issueWith(req({ iss: undefined }));
    const c = cborRead(h.cose.parseSign1(none.cose, L).payload) as Map<Cbor, Cbor>;
    const r = h.verifier.verify(none.hc1, esStore(), reg, TESTKIT_NOW, OPTIONS);
    return ["Xx", "XXX"].every((iss) => thrownTag(() => h.issuer.prepare(req({ iss }), reg)) === "payload-invalid") && !c.has(1) && r.tag === "verified" && r.val.iss === undefined;
  });
  run("STT-CWT-006 claims this version does not know are kept", () => {
    const r = h.verifier.verifyCose(signedCose(claims(TESTKIT_NOW + 1000n, [[...cborInt(-70000), ...cborText("future")]])), esStore(), reg, TESTKIT_NOW, OPTIONS);
    return r.tag === "verified" && r.val.otherClaims.length === 1 && cborRead(r.val.otherClaims[0]![0]) === -70000 && cborRead(r.val.otherClaims[0]![1]) === "future";
  });
  run("STT-GEN-001 STT-GEN-009 ES256 and PS256 issue and verify, and the COSE bytes travel without the QR layers", () => {
    const dvc = issueWith(req());
    const test = issueWith(req({ alg: "ps256", dscDer: f.testkitPsDsc, payloads: [{ tag: "raw", val: { subclaim: 4, cbor: new Uint8Array([0xa1, ...cborText("t"), ...cborText("x")]) } }] }));
    const ok = (r: VerificationResult) => r.tag === "verified";
    return ok(h.verifier.verify(dvc.hc1, esStore(), reg, TESTKIT_NOW, OPTIONS)) && ok(h.verifier.verify(test.hc1, psStore(), reg, TESTKIT_NOW, OPTIONS)) &&
      hex(h.codec.fromHc1(dvc.hc1, L)) === hex(dvc.cose) && ok(h.verifier.verifyCose(dvc.cose, esStore(), reg, TESTKIT_NOW, OPTIONS)) && ok(h.verifier.verifyCose(test.cose, psStore(), reg, TESTKIT_NOW, OPTIONS));
  });
  run("STT-GEN-002 every step is callable on its own, and the steps compose to the issued HC1", () => {
    const issued = issueWith(req());
    const text = "HC1:" + h.codec.base45Encode(h.codec.zlibCompress(issued.cose, 9));
    const [, rest] = h.codec.detectContext(text);
    const back = h.codec.zlibInflate(h.codec.base45Decode(rest), 65536);
    return hex(back) === hex(issued.cose) && h.verifier.verify(text, esStore(), reg, TESTKIT_NOW, OPTIONS).tag === "verified";
  });
  run("STT-PAY-009 STT-GEN-003 payloads under 1, 3, 4 and -7 pass through the core untouched", () => {
    const body = (k: string) => new Uint8Array([0xa1, ...cborText(k), ...cborText("x")]);
    const cases: [number, string, boolean][] = [[4, "t", true], [1, "v", false], [3, "v", false], [-7, "m", false]];
    return cases.every(([subclaim, k, ps]) => {
      const issued = issueWith(req(ps ? { alg: "ps256", dscDer: f.testkitPsDsc, payloads: [{ tag: "raw", val: { subclaim, cbor: body(k) } }] } : { payloads: [{ tag: "raw", val: { subclaim, cbor: body(k) } }] }));
      const r = h.verifier.verify(issued.hc1, ps ? psStore() : esStore(), reg, TESTKIT_NOW, OPTIONS);
      const p = r.tag === "verified" ? r.val.entries[0]?.payload : undefined;
      return p?.tag === "raw" && p.val.subclaim === subclaim && hex(p.val.cbor) === hex(body(k));
    });
  });
  run("STT-PAY-003 one immunization event per DVC", () => {
    const vx = (cborRead(h.dvc.toCbor(newborn)) as Map<Cbor, Cbor>).get("vx");
    return vx instanceof Map && vx.get("vp") === "XM9V38";
  });
  run("STT-PAY-004 STT-PAY-007 an invalid payload is refused, naming each rule", () => {
    try {
      h.issuer.prepare(req({ payloads: [{ tag: "dvc-min", val: { ...newborn, nt: "LA", vx: { ...newborn.vx, is: undefined, cn: undefined } } }] }), reg);
      return [false, "issued"];
    } catch (e) {
      const err = (e as { payload?: { tag?: string; val?: { code: string }[] } }).payload;
      const codes = [...new Set((err?.val ?? []).map((i) => i.code))].sort().join();
      return [err?.tag === "payload-invalid" && codes === "must-have-issuer-or-clinician-name,not-alpha3" && h.dvc.validate({ ...newborn, nt: "XXA" }).length === 0, codes];
    }
  });
  run("STT-PAY-005 a newborn's DVCMin has no identity document and names a guardian", () => {
    const r = h.verifier.verify(issueWith(req()).hc1, esStore(), reg, TESTKIT_NOW, OPTIONS);
    const p = r.tag === "verified" ? r.val.entries[0]?.payload : undefined;
    return p?.tag === "dvc-min" && p.val.id === undefined && p.val.dt === undefined && p.val.gn === "Test MOTHER";
  });
  run("STT-SEL-004 one entry per payload, in wire order; no payload and a duplicate subclaim are refused", () => {
    const vhl = { ...ihe, exp: TESTKIT_NOW + 86400n };
    const r = h.verifier.verify(issueWith(req({ payloads: [{ tag: "dvc-min", val: newborn }, { tag: "vhl", val: vhl }] })).hc1, esStore(), reg, TESTKIT_NOW, OPTIONS);
    const subclaims = r.tag === "verified" ? r.val.entries.map((e) => e.subclaim).join() : r.val.reason;
    return [subclaims === "5,-6" && thrownTag(() => h.issuer.prepare(req({ payloads: [] }), reg)) === "no-payload" &&
      thrownTag(() => h.issuer.prepare(req({ payloads: [{ tag: "dvc-min", val: newborn }, { tag: "dvc-min", val: newborn }] }), reg)) === "duplicate-subclaim", subclaims];
  });
  run("STT-TRU-001 STT-TRU-002 a DID trustlist v2 document's DSCs are held by the store and found by kid", () => {
    const b64 = (b: Uint8Array) => btoa(String.fromCharCode(...b));
    const id = "did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXA:DSC";
    // One embedded key and one reference to another document, which the host resolves.
    const did = JSON.stringify({ id, verificationMethod: [{ id: `${id}#k1`, type: "JsonWebKey2020", publicKeyJwk: { kty: "EC", crv: "P-256", x5c: [b64(f.testkitDsc)] } }, "did:web:tng-cdn-dev.who.int:v2:trustlist:-:XXB:DSC"] });
    const st = new h.trust.TrustStore();
    const n = st.addDidDocument(did);
    const kid = h.cose.kidFromDsc(f.testkitDsc);
    const found = st.candidates(kid);
    return [n === 1 && st.size() === 1 && found.length === 1 && hex(found[0]!.der) === hex(f.testkitDsc) && st.candidates(new Uint8Array(8)).length === 0 &&
      h.verifier.verify(issueWith(req()).hc1, st, reg, TESTKIT_NOW, OPTIONS).tag === "verified", `${n} ${found.length}`];
  });
  run("STT-VER-002 a failure carries no payload, and an unverified read is its own named call", () => {
    const issued = issueWith(req());
    const r = h.verifier.verify(issued.hc1, new h.trust.TrustStore(), reg, TESTKIT_NOW, OPTIONS);
    if (r.tag !== "failed") return [false, "verified"];
    const v = r.val as unknown as Record<string, unknown>;
    const said = [r.val.detail, ...r.val.diagnostics.map((d) => d.message)].join(" ");
    return [["entries", "otherClaims", "iss", "payload"].every((k) => v[k] === undefined) && !said.includes("Test CHILD") && !said.includes("XM9V38") &&
      h.verifier.readUnverified(issued.hc1, reg, L).diagnostics[0]!.message.startsWith("NOT VERIFIED"), said];
  });
  run("STT-VER-003 a protected header with an unsupported alg, or a short kid, is refused before the signature", () => {
    const kid = h.cose.kidFromDsc(f.testkitDsc);
    const payload = claims(TESTKIT_NOW + 1000n);
    const badAlg = h.verifier.verifyCose(signedCose(payload, new Uint8Array([0xa2, 0x01, ...cborInt(-999), 0x04, ...cborBytes(kid)])), esStore(), reg, TESTKIT_NOW, OPTIONS);
    const shortKid = h.verifier.verifyCose(signedCose(payload, new Uint8Array([0xa2, 0x01, 0x26, 0x04, ...cborBytes(kid.slice(0, 2))])), esStore(), reg, TESTKIT_NOW, OPTIONS);
    const got = [badAlg, shortKid].map((r) => (r.tag === "failed" ? `${r.val.step} ${r.val.reason}` : "verified"));
    return [got[0]!.startsWith("header") && got[1] === "header header-invalid", got.join(";")];
  });
  run("STT-VER-004 key usage is checked per entry, and alone a DVC under a test-only DSC is refused", () => {
    const vhl = { ...ihe, exp: TESTKIT_NOW + 86400n };
    const both = h.verifier.verify(issueWith(req({ alg: "ps256", dscDer: f.testkitPsDsc, payloads: [{ tag: "dvc-min", val: newborn }, { tag: "vhl", val: vhl }] })).hc1, psStore(), reg, TESTKIT_NOW, OPTIONS);
    const alone = h.verifier.verify(issueWith(req({ alg: "ps256", dscDer: f.testkitPsDsc })).hc1, psStore(), reg, TESTKIT_NOW, OPTIONS);
    const marks = both.tag === "verified" ? both.val.entries.map((e) => `${e.subclaim}:${e.keyUsageAuthorised}`).join() : both.val.reason;
    return [marks === "5:true,-6:false" && alone.tag === "failed" && alone.val.step === "key-usage" && alone.val.reason === "key-usage-mismatch", marks];
  });
  run("STT-VER-005 time is the clock the caller passes, with the skew it allows", () => {
    const hc1 = issueWith(req()).hc1;
    const at = (now: bigint) => { const r = h.verifier.verify(hc1, esStore(), reg, now, OPTIONS); return r.tag === "verified" ? "ok" : r.val.reason; };
    const exp = validity.exp;
    return [at(exp + 299n), at(exp + 301n), at(TESTKIT_NOW - 299n), at(TESTKIT_NOW - 301n)].join() === "ok,expired,ok,not-yet-valid";
  });
  run("STT-VER-006 trust-list presence is the validity check; a DSC outside its X.509 period is reported", () => {
    const hc1 = issueWith(req()).hc1;
    const none = h.verifier.verify(hc1, new h.trust.TrustStore(), reg, TESTKIT_NOW, OPTIONS);
    const late = h.verifier.verify(hc1, esStore(), reg, TESTKIT_NOW + 86400n * 365n * 11n, { ...OPTIONS, clockSkewSeconds: 86400 * 365 * 20 });
    return none.tag === "failed" && none.val.reason === "kid-not-found" && late.tag === "verified" && late.val.diagnostics.some((d) => d.step === "trust-lookup" && d.message.includes("X.509 validity"));
  });
  run("STT-VER-007 each entry is decoded by its subclaim's codec, falling back to raw", () => {
    const st = esStore();
    const c = claims(TESTKIT_NOW + 1000n);
    // The same claims with a -7 entry beside the DVC: {-6: DVC, -7: {}}.
    const dvc = dvcCbor();
    const two = new Uint8Array([...c.slice(0, c.length - dvc.length - cborInt(-6).length - 1), ...head(5, 2), ...cborInt(-6), ...dvc, ...cborInt(-7), 0xa0]);
    const r = h.verifier.verifyCose(signedCose(two), st, reg, TESTKIT_NOW, OPTIONS);
    const tags = r.tag === "verified" ? r.val.entries.map((e) => `${e.subclaim}:${e.payload.tag}`).join() : r.val.reason;
    return [tags === "-6:dvc-min,-7:raw", tags];
  });
  run("STT-TST-006 seeded mutations of an HC1 string never throw out of verify", () => {
    let seed = 0x2545f491;
    const rnd = (n: number) => { seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5; return (seed >>> 0) % n; };
    const base = issueWith(req()).hc1;
    const alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";
    const st = esStore();
    for (let k = 0; k < 300; k++) {
      const chars = base.split("");
      for (let m = 1 + rnd(4); m > 0; m--) chars[4 + rnd(chars.length - 4)] = alphabet[rnd(alphabet.length)]!;
      const r = h.verifier.verify(chars.join("").slice(0, chars.length - rnd(3)), st, reg, TESTKIT_NOW, OPTIONS);
      if (r.tag !== "verified" && r.tag !== "failed") return [false, `mutation ${k}`];
    }
    return true;
  });

  // vhl
  run("STT-VHL-001 STT-VHL-003 the IHE example payload is valid and round-trips through vhlink:/", () =>
    h.vhl.validate(ihe, undefined).length === 0 && h.vhl.fromVhlink(h.vhl.toVhlink(ihe)).key === ihe.key && h.vhl.validate({ ...ihe, flag: "PL" }, undefined).map((i) => i.code).join() === "bad-flag" && thrownTag(() => h.vhl.fromVhlink("shlink:/x")) === "not-a-vhlink");
  run("STT-VHL-002 a VHL is issued as a CBOR map at key 5 and verifies", () => {
    const payload = { ...ihe, exp: TESTKIT_NOW + 86400n };
    const p = h.issuer.prepare({ payloads: [{ tag: "vhl", val: payload }], iss: "XX", validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n }, dscDer: f.testkitDsc, alg: "es256", allowDevelopmentSubclaims: true }, reg);
    const issued = h.issuer.finish(p, f.signEs256Der(p.toBeSigned()));
    const st = new h.trust.TrustStore();
    st.addDer(f.testkitDsc);
    const r = h.verifier.verify(issued.hc1, st, reg, TESTKIT_NOW, OPTIONS);
    return r.tag === "verified" && r.val.entries[0]?.subclaim === 5 && r.val.entries[0].payload.tag === "vhl" && r.val.entries[0].payload.val.exp === payload.exp;
  });
  run("STT-VHL-004 new keys are 32 random bytes, base64url", () => {
    const a = h.vhl.newKey();
    return a.length === 43 && a !== h.vhl.newKey() && /^[A-Za-z0-9_-]+$/.test(a);
  });
  run("STT-VHL-005 the ITI-YY5 request is the exact body of the IHE example", () =>
    h.vhl.buildManifestRequest(ihe, "Dr. Smith Hospital", "user-pin", 10000).body ===
      "_id=abc123def456&code=folder&status=current&patient.identifier=urn%3Aoid%3A2.16.840.1.113883.2.4.6.3%7CPASSPORT123&_include=List%3Aitem&recipient=Dr.+Smith+Hospital&passcode=user-pin&embeddedLengthMax=10000" &&
    thrownTag(() => h.vhl.buildManifestRequest(ihe, "Clinic B", undefined, undefined)) === "manifest");
  run("STT-VHL-006 the IHE Case B manifest Bundle reads as documents", () => {
    const d = h.vhl.parseManifest(f.manifestCaseB);
    return d.length === 4 && d[0]!.url === "https://vhl-sharer.example.org/Binary/doc001-content" && d[1]!.reference === "DocumentReference/doc002";
  });
  run("STT-VHL-007 JWE dir/A256GCM: the node:crypto fixture decrypts, and a round trip refuses the wrong key", () => {
    const ok = [f.jwe.jwe, f.jwe.jweZipDef].every((j) => text(h.vhl.decrypt(j, f.jwe.key).content) === f.jwe.plaintext);
    const k = h.vhl.newKey();
    const jwe = h.vhl.encrypt(new TextEncoder().encode("hello"), "text/plain", k);
    return ok && text(h.vhl.decrypt(jwe, k).content) === "hello" && h.vhl.decrypt(jwe, k).contentType === "text/plain" && thrownTag(() => h.vhl.decrypt(jwe, h.vhl.newKey())) === "decrypt-failed";
  });
  run("STT-VHL-008 RFC 9421 signature base, RFC 9530 digest, and a DER signature as the raw header value", () => {
    const b = h.vhl.buildSignatureBase({ method: "POST", authority: "vhl-sharer.example.org", path: "/List/_search", contentType: "application/x-www-form-urlencoded", body: new TextEncoder().encode('{"hello": "world"}'), keyid: "receiver-key-123", alg: "ecdsa-p256-sha256", created: 1735689600n });
    const header = h.vhl.signatureHeader(f.signEs256Der(b.base), "ecdsa-p256-sha256");
    const raw = Uint8Array.from(atob(header.slice("sig1=:".length, -1)), (c) => c.charCodeAt(0));
    return b.contentDigest === "sha-256=:X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=:" && b.signatureInput.startsWith('sig1=("@method" "@path" "@authority" "content-type" "content-digest");created=1735689600') && raw.length === 64 && f.verifyEs256Raw(b.base, raw);
  });
  run("STT-VHL-009 an expired link fails verification by its own exp", () => {
    const payload = { ...ihe, exp: TESTKIT_NOW - 1000n };
    const p = h.issuer.prepare({ payloads: [{ tag: "vhl", val: payload }], validity: { iat: TESTKIT_NOW, exp: TESTKIT_NOW + 86400n }, dscDer: f.testkitDsc, alg: "es256", allowDevelopmentSubclaims: true }, reg);
    const issued = h.issuer.finish(p, f.signEs256Der(p.toBeSigned()));
    const st = new h.trust.TrustStore();
    st.addDer(f.testkitDsc);
    const r = h.verifier.verify(issued.hc1, st, reg, TESTKIT_NOW, OPTIONS);
    return r.tag === "failed" && r.val.reason === "expired";
  });
  return out;
}
