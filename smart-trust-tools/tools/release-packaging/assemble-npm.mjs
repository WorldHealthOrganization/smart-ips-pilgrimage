// Assemble the two npm packages of STT-NFR-002 into a dist directory, from
// build outputs already on disk. Writes files only: it installs, resolves and
// publishes nothing (docs/RELEASING.md says who publishes, and how).
//
//   node tools/release-packaging/assemble-npm.mjs --out <dist> \
//     [--component <dir>]    build-component.sh's output: hcert.component.wasm, js/
//     [--kotlin-js <dir>]    hcert-core's build/compileSync/js/main/productionLibrary/kotlin
//
// Each package gets a package.json with the version from VERSION, no
// dependencies and no scripts, and a README. The layouts are those the
// conformance suite loads (tools/conformance-ts/load.mjs), so
// `node tools/conformance-ts/run.mjs rust <dist>/hcert-component` and
// `... kotlin <dist>/hcert-kotlin-js` test the very files that would ship.
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { parseArgs } from "node:util";
import { homepage, mavenGroup, npmScope, repoRoot as repo, repoUrl } from "./coordinates.mjs";

const version = readFileSync(join(repo, "VERSION"), "utf8").trim();

const { values } = parseArgs({ options: { out: { type: "string" }, component: { type: "string" }, "kotlin-js": { type: "string" } } });
if (!values.out || (!values.component && !values["kotlin-js"])) {
  console.error("usage: assemble-npm.mjs --out <dist> [--component <dir>] [--kotlin-js <dir>]");
  process.exit(2);
}

const common = {
  license: "Apache-2.0",
  author: "Carl Leitner (https://github.com/litlfred)",
  homepage,
  repository: { type: "git", url: `git+${repoUrl}.git` },
  bugs: { url: `${repoUrl}/issues` },
  type: "module",
  sideEffects: false,
};

// Every regular file under dir, as sorted paths relative to it.
function walk(dir, base = dir) {
  return readdirSync(dir).sort().flatMap((n) => {
    const p = join(dir, n);
    return statSync(p).isDirectory() ? walk(p, base) : [relative(base, p).split("\\").join("/")];
  });
}

function assemble(name, from, keep, pkg, readme) {
  if (!existsSync(from)) throw new Error(`${from}: no such directory (build it first)`);
  const to = resolve(values.out, name.split("/")[1]);
  rmSync(to, { recursive: true, force: true });
  mkdirSync(to, { recursive: true });
  const files = walk(from).filter(keep);
  if (files.length === 0) throw new Error(`${from}: nothing to package`);
  for (const f of files) cpSync(join(from, f), join(to, f));
  const { description, keywords, ...entry } = pkg;
  writeFileSync(join(to, "package.json"), JSON.stringify({ name, version, description, keywords, ...common, ...entry }, null, 2) + "\n");
  writeFileSync(join(to, "README.md"), readme);
  cpSync(join(repo, "LICENSE"), join(to, "LICENSE"));
  console.log(`${name}@${version}: ${to} (${files.length} files)`);
}

if (values.component) {
  assemble(
    `${npmScope}/hcert-component`,
    resolve(values.component),
    (f) => f === "hcert.component.wasm" || (f.startsWith("js/") && /\.(js|wasm|d\.ts)$/.test(f)),
    {
      description: "SMART Trust HCERT: the Rust library as a WebAssembly component (the hcert world of the WIT contract), transpiled with jco to an ES module for browsers and Node.",
      keywords: ["hcert", "gdhcn", "health-certificate", "cose", "webassembly", "wasm-component"],
      main: "./js/hcert.js",
      types: "./js/hcert.d.ts",
      exports: {
        ".": { types: "./js/hcert.d.ts", default: "./js/hcert.js" },
        "./hcert.component.wasm": "./hcert.component.wasm",
        "./package.json": "./package.json",
      },
      files: ["hcert.component.wasm", "js/"],
    },
    `# ${npmScope}/hcert-component

SMART Trust HCERT: issue and verify WHO GDHCN health certificates (HC1) and
Verifiable Health Links, in browsers and Node. This is the Rust library
(crate \`hcert\`) built as the WebAssembly component of the \`hcert\` world of
the WIT contract and transpiled with jco to an ES module: one namespace per
interface (\`codec\`, \`cose\`, \`dvc\`, \`issuer\`, \`verifier\`, \`trust\`, \`vhl\`, ...),
resources as classes, \`s64\` as \`bigint\`.

\`\`\`js
import { verifier, trust } from "${npmScope}/hcert-component";
\`\`\`

\`hcert.component.wasm\` is the component itself, for any component host. The
only import, \`wasi:random\`, maps to \`crypto.getRandomValues\`
(\`js/wasi-random.js\`). No dependencies.

Source, requirements and changelog: ${repoUrl}
`,
  );
}

if (values["kotlin-js"]) {
  assemble(
    `${npmScope}/hcert-kotlin-js`,
    resolve(values["kotlin-js"]),
    (f) => !f.includes("/") && /\.(mjs|mjs\.map|d\.ts)$/.test(f),
    {
      description: "SMART Trust HCERT: the Kotlin Multiplatform library compiled to an ES module for Node (Kotlin/JS IR), with TypeScript declarations.",
      keywords: ["hcert", "gdhcn", "health-certificate", "cose", "kotlin"],
      main: "./smart-trust-kotlin-hcert-core.mjs",
      types: "./smart-trust-kotlin-hcert-core.d.ts",
      exports: {
        ".": { types: "./smart-trust-kotlin-hcert-core.d.ts", default: "./smart-trust-kotlin-hcert-core.mjs" },
        "./package.json": "./package.json",
      },
      files: ["*.mjs", "*.mjs.map", "*.d.ts"],
    },
    `# ${npmScope}/hcert-kotlin-js

SMART Trust HCERT: issue and verify WHO GDHCN health certificates (HC1) and
Verifiable Health Links on Node. This is the Kotlin Multiplatform library
(Maven \`${mavenGroup}:hcert-core\`) compiled with Kotlin/JS IR to an ES
module, with TypeScript declarations. Each interface of the contract is an
object behind \`getInstance()\` (\`WitCodec\`, \`WitVerifier\`, \`WitIssuer\`, ...).
It uses \`node:crypto\`, \`node:zlib\` and \`node:buffer\`; the Kotlin standard
library is bundled, so there are no dependencies.

\`\`\`js
import { WitVerifier } from "${npmScope}/hcert-kotlin-js";
\`\`\`

Source, requirements and changelog: ${repoUrl}
`,
  );
}
