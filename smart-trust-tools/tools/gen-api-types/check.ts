/**
 * The TypeScript view in api/generated/ts has the shape of the WIT contract
 * it is generated from, without running the generator.
 *
 * @module smart-trust-tools/tools/gen-api-types/check
 * @covers hcert-generated-contract
 *
 * Regenerating the view needs jco from the pinned Node toolchain, which the
 * CI job of this repository installs and a downstream's gates do not. This
 * asks what can be answered from the files alone:
 *
 * - every `interface` the `who:smart-trust` package declares in api/wit has
 *   its `interfaces/who-smart-trust-<name>.d.ts`, and every such file names a
 *   declared interface;
 * - hcert.d.ts is the world `who:smart-trust/hcert` at the package's version,
 *   and every module it re-exports is a file of the view.
 *
 * Whether the bytes are current is the CI job's `gen_api_types.sh` and
 * `git diff --exit-code`.
 *
 *   bun tools/gen-api-types/check.ts
 */
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const ROOT = join(import.meta.dir, "..", "..");
const WIT = join(ROOT, "api", "wit");
const OUT = join(ROOT, "api", "generated", "ts");
const problems: string[] = [];

const versions = new Set<string>();
const declared = new Set<string>();
for (const f of readdirSync(WIT).filter((n) => n.endsWith(".wit")).sort()) {
  const text = readFileSync(join(WIT, f), "utf-8");
  const pkg = /^package who:smart-trust@([0-9][^;]*);/m.exec(text);
  if (!pkg) {
    problems.push(`api/wit/${f}: declares no who:smart-trust package`);
    continue;
  }
  versions.add(pkg[1]!);
  for (const m of text.matchAll(/^interface ([a-z][a-z0-9-]*) \{/gm)) declared.add(m[1]!);
}
if (versions.size !== 1) problems.push(`api/wit: ${versions.size} package versions (${[...versions].join(", ")}), expected one`);
const version = [...versions][0];

const prefix = "who-smart-trust-";
const files = existsSync(join(OUT, "interfaces")) ? readdirSync(join(OUT, "interfaces")).filter((n) => n.endsWith(".d.ts")) : [];
const generated = new Set(files.filter((n) => n.startsWith(prefix)).map((n) => n.slice(prefix.length, -".d.ts".length)));
for (const i of [...declared].sort()) if (!generated.has(i)) problems.push(`api/generated/ts/interfaces: no ${prefix}${i}.d.ts for interface ${i}`);
for (const i of [...generated].sort()) if (!declared.has(i)) problems.push(`api/generated/ts/interfaces/${prefix}${i}.d.ts: names no interface of api/wit`);

const world = existsSync(join(OUT, "hcert.d.ts")) ? readFileSync(join(OUT, "hcert.d.ts"), "utf-8") : undefined;
if (world === undefined) problems.push("api/generated/ts/hcert.d.ts is missing");
else {
  if (version && !world.startsWith(`// world who:smart-trust/hcert@${version}\n`)) problems.push(`api/generated/ts/hcert.d.ts: not the world who:smart-trust/hcert@${version}`);
  for (const m of world.matchAll(/from '\.\/(interfaces\/[^']+)\.js'/g)) {
    if (!files.includes(m[1]!.slice("interfaces/".length) + ".d.ts")) problems.push(`api/generated/ts/hcert.d.ts: re-exports ${m[1]}, which is not in the view`);
  }
}

for (const p of problems) console.error(p);
console.log(`${declared.size} WIT interface(s), ${generated.size} generated; ${problems.length} problem(s)`);
process.exit(problems.length === 0 ? 0 : 1);
