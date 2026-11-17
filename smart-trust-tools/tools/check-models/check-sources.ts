/**
 * Every set of test vectors says where it came from.
 *
 * @module smart-trust-tools/tools/check-models/check-sources
 * @covers hcert-test-vectors
 *
 * The vectors are verbatim upstream material and carry no `$schema`; what
 * makes a file a usable vector is its provenance. Each directory under
 * vectors/ is one set, and:
 *
 * - a set with a SOURCE.yaml that lists `files:` holds exactly those files
 *   besides SOURCE.yaml, no more and no fewer;
 * - a set with a SOURCE.yaml and no `files:` names its `generator:`, a file
 *   of this repository, and holds one file besides SOURCE.yaml;
 * - a set with no SOURCE.yaml is the test PKI: a README.md titled TEST ONLY
 *   that names each of its files.
 *
 * check_models.py and the library suites judge what the vectors contain;
 * this judges that each one is accounted for.
 *
 *   bun tools/check-models/check-sources.ts
 */
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const ROOT = join(import.meta.dir, "..", "..");
const VECTORS = join(ROOT, "vectors");
const problems: string[] = [];
let sets = 0;

for (const set of readdirSync(VECTORS).sort()) {
  const dir = join(VECTORS, set);
  if (!statSync(dir).isDirectory()) {
    problems.push(`vectors/${set}: a file outside any set`);
    continue;
  }
  sets++;
  const held = readdirSync(dir).filter((n) => n !== "SOURCE.yaml" && n !== "README.md").sort();
  const source = join(dir, "SOURCE.yaml");
  if (existsSync(source)) {
    const text = readFileSync(source, "utf-8");
    const block = /^files:\n((?:(?: {2}.*)?\n)*)/m.exec(text)?.[1];
    if (block !== undefined) {
      const listed = [...block.matchAll(/^ {2}([^\s:][^:]*):/gm)].map((m) => m[1]!).sort();
      for (const f of listed) if (!held.includes(f)) problems.push(`vectors/${set}/SOURCE.yaml lists ${f}, which is not in the set`);
      for (const f of held) if (!listed.includes(f)) problems.push(`vectors/${set}/${f}: not listed in its SOURCE.yaml`);
    } else {
      const generator = /^generator: (\S+)$/m.exec(text)?.[1];
      if (!generator) problems.push(`vectors/${set}/SOURCE.yaml lists no files and names no generator`);
      else if (!existsSync(join(ROOT, generator))) problems.push(`vectors/${set}/SOURCE.yaml: generator ${generator} does not exist`);
      if (held.length !== 1) problems.push(`vectors/${set}: a generated set holds one file besides SOURCE.yaml, not ${held.length}`);
    }
  } else {
    const readme = join(dir, "README.md");
    const text = existsSync(readme) ? readFileSync(readme, "utf-8") : "";
    if (!/^# .*TEST ONLY/m.test(text)) problems.push(`vectors/${set}: no SOURCE.yaml, and no README.md titled TEST ONLY`);
    for (const f of held) if (!text.includes("`" + f + "`")) problems.push(`vectors/${set}/${f}: not named in the set's README.md`);
  }
}

for (const p of problems) console.error(p);
console.log(`${sets} vector set(s); ${problems.length} problem(s)`);
process.exit(problems.length === 0 && sets > 0 ? 0 : 1);
