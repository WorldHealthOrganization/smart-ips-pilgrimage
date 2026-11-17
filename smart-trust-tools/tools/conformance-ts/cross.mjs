// Each library verifies the other's certificates (cross.ts):
//   node tools/conformance-ts/cross.mjs <rust dir> <kotlin dir>
// with the same directories run.mjs takes.
import { loaders, fixtures } from "./load.mjs";
import { runCross } from "./cross.ts";

const [rustDir, kotlinDir] = process.argv.slice(2);
if (!rustDir || !kotlinDir) {
  console.error("usage: cross.mjs <rust dir> <kotlin dir>");
  process.exit(2);
}

const outcomes = runCross({ rust: await loaders.rust(rustDir), kotlin: await loaders.kotlin(kotlinDir) }, fixtures);
for (const o of outcomes) console.log(`${o.ok ? "ok  " : "FAIL"} ${o.name}${o.detail && !o.ok ? ": " + o.detail : ""}`);
const failed = outcomes.filter((o) => !o.ok).length;
console.log(`cross: ${outcomes.length - failed} of ${outcomes.length} passed`);
process.exit(failed ? 1 : 0);
