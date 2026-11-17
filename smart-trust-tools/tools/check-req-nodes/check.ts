#!/usr/bin/env bun
/**
 * The requirement graph of this instance resolves: no edge points at nothing.
 *
 * cat-harness's own `check:skills` and `check:requirements` walk the
 * cat-harness instance only, so this downstream checks its nodes itself,
 * against the same bootstrap `RequirementSchema`, and checks every edge the
 * viewers draw:
 *
 * - a requirement's id is `req:<file name>`;
 * - each `derivedFrom` names a requirement here (the harness's meaning: the
 *   broader requirement this one specialises);
 * - each `reference` names a node that exists: a library entry or section, an
 *   external schema, a reference, a memory directive, a test vector, or a
 *   smart-trust FHIR Requirements canonical (an instance in the ingested
 *   Requirements.fsh, with its statement key if one is given). The field is
 *   FHIR R5 `Requirements.reference`, the artefacts a requirement was drawn
 *   from;
 * - every statement carries at least one success criterion;
 * - each skill's `satisfies` names a requirement and one of its statements;
 * - each file a skill's `tested-by` names exists, and every requirement id a
 *   test in it is named after (`STT-XXX-nnn …`) names a requirement;
 * - each bean's "Requirements affected" and "Sources" resolve likewise;
 * - each external schema (external-schemas/*.json) parses as
 *   `folio-external-schema/v1` and each reference (references/*.json) as
 *   `folio-reference/v1`, the schemas their typologies name, and its id is its
 *   file name: the nodes a `reference` lands on are well formed; a
 *   reference's `heldAt`, when it names a library entry, names one that exists;
 * - each code list (code-lists/*.json) parses as `folio-code-list/v1`, and
 *   every requirement's area (the AREA of STT-AREA-nnn) is an active code of
 *   the requirement-area list, which the viewers read the areas from;
 * - the shared negative vectors (vectors/negative/negative-vectors.json) parse
 *   against the negative-vectors Tool's Zod schema, each case's expected step
 *   and reason a case of the WIT failure taxonomy (api/wit/types.wit) and each
 *   trust path a file; the file carries no `$schema`, as its typology says;
 * - each test plan in test/plans/ parses as `test-plan/v1`, its requirements
 *   name requirements, each assertion id is a success criterion
 *   (`req:<id>#<statement>/<criterion>`), each fixed data path and generated
 *   template exists, and each predecessor names a plan here.
 *
 *   bun tools/check-req-nodes/check.ts
 */
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, join } from "node:path";

import { RequirementSchema } from "@litlfred/bootstrap-tools/schemas/requirement.ts";

import { TestPlanSchema } from "@litlfred/cat-harness-tools/schemas/sdlc/test-plan.ts";

const ROOT = join(import.meta.dir, "..", "..");
const REQ_DIR = join(ROOT, "skills", "requirements");
const UPSTREAM = "http://smart.who.int/trust/Requirements/";
const problems: string[] = [];

const files = readdirSync(REQ_DIR).filter((n) => n.endsWith(".json")).sort();
const nodes = new Map<string, { file: string; node: Record<string, any> }>();
for (const file of files) {
  const node = JSON.parse(readFileSync(join(REQ_DIR, file), "utf-8"));
  const r = RequirementSchema.safeParse(node);
  if (!r.success) for (const i of r.error.issues) problems.push(`${file}: ${i.path.join(".") || "(root)"}: ${i.message}`);
  if (node.id !== `req:${basename(file, ".json")}`) problems.push(`${file}: id ${node.id} is not req:${basename(file, ".json")}`);
  nodes.set(node.id, { file, node });
}

// The smart-trust FHIR Requirements, read from the ingested Requirements.fsh.
const upstream = new Map<string, Set<string>>();
const fshDir = join(ROOT, "library", "who-smart-trust-requirements-fsh", "sections");
for (const f of existsSync(fshDir) ? readdirSync(fshDir).filter((n) => n.endsWith(".md")) : []) {
  let current: Set<string> | undefined;
  for (const line of readFileSync(join(fshDir, f), "utf-8").split("\n")) {
    const inst = /^Instance:\s+(\S+)/.exec(line);
    if (inst) upstream.set(inst[1]!, (current = new Set()));
    const key = /^\* statement\[\+\]\.key = "([^"]+)"/.exec(line);
    if (key && current) current.add(key[1]!);
  }
}

/** Whether a reference names a node of this graph. */
function resolves(ref: string): boolean {
  if (ref.startsWith("req:")) return nodes.has(ref.split("#")[0]!);
  if (ref.startsWith(UPSTREAM)) {
    const [inst, key] = ref.slice(UPSTREAM.length).split("#");
    const stmts = upstream.get(inst!);
    return stmts !== undefined && (key === undefined || stmts.has(key));
  }
  const m = /^library\/([^/]+)(?:\/sections\/([^/]+))?$/.exec(ref);
  if (m) return existsSync(join(ROOT, "library", m[1]!, m[2] ? `sections/${m[2]}.md` : "manifest.jsonld"));
  for (const [dir, ext] of [["external-schemas", ".json"], ["references", ".json"], ["memory", ".md"]] as const) {
    if (ref.startsWith(`${dir}/`)) return existsSync(join(ROOT, `${ref}${ext}`));
  }
  if (ref.startsWith("vectors/")) return existsSync(join(ROOT, ref));
  return false;
}

for (const { file, node } of nodes.values()) {
  for (const d of node.derivedFrom ?? []) {
    if (!d.startsWith("req:") || !nodes.has(d)) problems.push(`${file}: derivedFrom ${d} names no requirement`);
  }
  for (const d of node.reference ?? []) {
    if (d.startsWith("req:") || !resolves(d)) problems.push(`${file}: reference ${d} names no source node`);
  }
  for (const s of node.statements ?? []) {
    if (!s.successCriteria?.length) problems.push(`${file}: statement ${s.key} has no success criterion`);
  }
}

/** `req:<id>#<statement key>`, checked against the node's own statements. */
function statementResolves(ref: string): boolean {
  const [id, key] = ref.split("#");
  const n = nodes.get(id!);
  return n !== undefined && (key === undefined || (n.node.statements ?? []).some((s: { key: string }) => s.key === key));
}

let skills = 0;
let tests = 0;
for (const pkg of readdirSync(join(ROOT, "skills"), { withFileTypes: true })) {
  if (!pkg.isDirectory() || pkg.name === "requirements") continue;
  for (const f of readdirSync(join(ROOT, "skills", pkg.name)).filter((n) => n.endsWith(".md"))) {
    skills++;
    const front = /^---\n([\s\S]*?)\n---/.exec(readFileSync(join(ROOT, "skills", pkg.name, f), "utf-8"))?.[1] ?? "";
    for (const m of front.matchAll(/^\s+- "(req:[^"]+)"/gm)) {
      if (!statementResolves(m[1]!)) problems.push(`skills/${pkg.name}/${f}: satisfies ${m[1]} names no requirement statement`);
    }
    const testedBy = /^tested-by:\n((?:\s+- .*\n?)+)/m.exec(front)?.[1] ?? "";
    for (const m of testedBy.matchAll(/^\s+- (\S+)/gm)) {
      const path = join(ROOT, m[1]!);
      if (!existsSync(path)) {
        problems.push(`skills/${pkg.name}/${f}: tested-by ${m[1]} does not exist`);
        continue;
      }
      const text = readFileSync(path, "utf-8");
      // Kotlin names a test `STT-XXX-nnn …`; Rust `stt_xxx_nnn_…`.
      const names = path.endsWith(".kt")
        ? [...text.matchAll(/@Test\s+fun\s+`([^`]+)`/g)].map((t) => [t[1]!, t[1]!.match(/STT-[A-Z0-9]+-\d{3}/g) ?? []] as const)
        : path.endsWith(".rs")
          ? [...text.matchAll(/#\[test\]\s*fn\s+(stt_[a-z0-9_]+)\s*\(/g)].map((t) => [t[1]!, [...t[1]!.matchAll(/(?:^|_)stt_([a-z0-9]+)_(\d{3})(?=_)/g)].map((m) => `STT-${m[1]!.toUpperCase()}-${m[2]}`)] as const)
          : [];
      for (const [name, ids] of names) {
        tests++;
        for (const id of ids) {
          if (!nodes.has(`req:${id.toLowerCase()}`)) problems.push(`${m[1]}: test "${name}" names ${id}, which is no requirement`);
        }
      }
    }
  }
}

const beanDir = join(ROOT, "beans", "defs");
const beans = existsSync(beanDir) ? readdirSync(beanDir).filter((n) => n.endsWith(".md")) : [];
for (const f of beans) {
  const text = readFileSync(join(beanDir, f), "utf-8");
  for (const section of ["Requirements affected", "Sources"]) {
    const body = new RegExp(`^## ${section}\\n\\n((?:- .*\\n?)+)`, "m").exec(text)?.[1] ?? "";
    for (const m of body.matchAll(/^- (\S+)/gm)) {
      if (!resolves(m[1]!)) problems.push(`beans/defs/${f}: ${section} ${m[1]} names no node`);
    }
  }
}

// The source nodes a `reference` names, against the schemas their typologies
// (external-schema, references) declare. Loaded here rather than at the top so
// the module's static imports stay those the Tool loader shares.
const { ExternalSchemaSchema } = await import("@litlfred/cat-harness-tools/schemas/kg/external-schema.ts");
const { ReferenceNodeSchema } = await import("@litlfred/folio-assistant-core/schemas/reference.ts");
const { STRUCTURE_FILENAME } = await import("@litlfred/cat-harness-tools/schemas/content/document-structure.ts");
let sourceNodes = 0;
for (const [dir, schema, idOf] of [
  ["external-schemas", ExternalSchemaSchema, (n: Record<string, any>) => n.id],
  ["references", ReferenceNodeSchema, (n: Record<string, any>) => n.id],
] as const) {
  for (const f of readdirSync(join(ROOT, dir)).filter((n) => n.endsWith(".json")).sort()) {
    sourceNodes++;
    const node = JSON.parse(readFileSync(join(ROOT, dir, f), "utf-8"));
    const r = schema.safeParse(node);
    if (!r.success) for (const i of r.error.issues) problems.push(`${dir}/${f}: ${i.path.join(".") || "(root)"}: ${i.message}`);
    if (idOf(node) !== basename(f, ".json")) problems.push(`${dir}/${f}: id ${idOf(node)} is not its file name`);
    const held = typeof node.heldAt === "string" ? /^library\/([^/]+)$/.exec(node.heldAt) : null;
    if (held && !existsSync(join(ROOT, "library", held[1]!, STRUCTURE_FILENAME))) problems.push(`${dir}/${f}: heldAt ${node.heldAt} names no library entry`);
  }
}

// The code lists, against the harness's schema; the requirement areas resolve in theirs.
const { parseCodeList, activeCodes } = await import("@litlfred/cat-harness-tools/schemas/library/code-list.ts");
const codeListDir = join(ROOT, "code-lists");
const codeLists = new Map<string, string[]>();
for (const f of existsSync(codeListDir) ? readdirSync(codeListDir).filter((n) => n.endsWith(".json")).sort() : []) {
  try {
    const list = parseCodeList(join(codeListDir, f));
    if (list.id !== basename(f, ".json")) problems.push(`code-lists/${f}: id ${list.id} is not its file name`);
    codeLists.set(list.id, activeCodes(list));
  } catch (e) {
    problems.push((e as Error).message);
  }
}
const areas = codeLists.get("requirement-area");
if (!areas) problems.push("code-lists/requirement-area.json: missing; the viewers read the requirement areas from it");
else {
  for (const id of nodes.keys()) {
    const area = /^req:stt-([a-z0-9]+)-\d{3}$/.exec(id)?.[1];
    if (!area || !areas.includes(area)) problems.push(`${nodes.get(id)!.file}: area ${area ?? "(none)"} is no code of requirement-area`);
  }
}

// The negative vectors, against their schema and the WIT failure taxonomy.
const { checkNegativeVectors } = await import("../negative-vectors/negative-vectors.schema.ts");
const negative = checkNegativeVectors(ROOT);
problems.push(...negative.problems);

/** `req:<id>#<statement key>/<criterion key>`, checked against the statement's criteria. */
function criterionResolves(ref: string): boolean {
  const m = /^(req:[^#]+)#([^/]+)\/(.+)$/.exec(ref);
  const s = m && (nodes.get(m[1]!)?.node.statements ?? []).find((x: { key: string }) => x.key === m[2]);
  return !!s && (s.successCriteria ?? []).some((c: { key: string }) => c.key === m![3]);
}

const planDir = join(ROOT, "test", "plans");
const plans = existsSync(planDir) ? readdirSync(planDir).filter((n) => n.endsWith(".test-plan.json")).sort() : [];
const planIds = new Set(plans.map((f) => JSON.parse(readFileSync(join(planDir, f), "utf-8")).id));
for (const f of plans) {
  const where = `test/plans/${f}`;
  const r = TestPlanSchema.safeParse(JSON.parse(readFileSync(join(planDir, f), "utf-8")));
  if (!r.success) {
    for (const i of r.error.issues) problems.push(`${where}: ${i.path.join(".") || "(root)"}: ${i.message}`);
    continue;
  }
  const plan = r.data;
  for (const q of plan.requirements) if (!statementResolves(q)) problems.push(`${where}: requirement ${q} names no requirement`);
  for (const c of plan.testCases) {
    for (const a of c.assertions) if (!criterionResolves(a.id)) problems.push(`${where}: case ${c.id}: assertion ${a.id} names no success criterion`);
    for (const d of c.testData) {
      const path = d.kind === "fixed" ? d.path : d.template;
      if (!existsSync(join(ROOT, path))) problems.push(`${where}: case ${c.id}: test data ${path} does not exist`);
    }
  }
  for (const d of plan.dependencies) {
    if (d.predecessor && !planIds.has(d.predecessor)) problems.push(`${where}: predecessor ${d.predecessor} names no plan`);
  }
}

for (const p of problems) console.error(`  ✗ ${p}`);
console.log(`${files.length} requirement(s), ${skills} skill(s), ${tests} test(s), ${beans.length} bean(s), ${plans.length} test plan(s), ${upstream.size} smart-trust Requirements, ${sourceNodes} external schema(s) and reference(s), ${codeLists.size} code list(s), ${negative.cases} negative vector(s); ${problems.length} problem(s)`);
process.exit(problems.length ? 1 : 0);
