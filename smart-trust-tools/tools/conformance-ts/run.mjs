// Runs the conformance suite (suite.ts) against one implementation:
//   node tools/conformance-ts/run.mjs rust   <dir from tools/hcert-rust/build-component.sh>
//   node tools/conformance-ts/run.mjs kotlin <Kotlin/JS productionLibrary dir>
// The loaders only adapt how each package is laid out to the `hcert` world;
// every call the suite makes goes to the library unchanged. Node strips the
// suite's types at load (Node 22.18+); tsconfig.json type-checks it.
import { loaders, fixtures } from "./load.mjs";
import { runSuite } from "./suite.ts";

const [kind, dir] = process.argv.slice(2);
if (!loaders[kind] || !dir) {
  console.error("usage: run.mjs rust|kotlin <dir>");
  process.exit(2);
}

const outcomes = runSuite(await loaders[kind](dir), fixtures);
for (const o of outcomes) console.log(`${o.ok ? "ok  " : "FAIL"} ${o.name}${o.detail && !o.ok ? ": " + o.detail : ""}`);
const failed = outcomes.filter((o) => !o.ok).length;
console.log(`${kind}: ${outcomes.length - failed} of ${outcomes.length} passed`);
process.exit(failed ? 1 : 0);
