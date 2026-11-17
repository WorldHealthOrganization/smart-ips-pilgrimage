/**
 * Every upstream patch is a well-formed git format-patch file.
 *
 * @module smart-trust-tools/tools/check-upstream-patches/check
 * @covers upstream-patches
 *
 * upstream/ is kept on the state branch cat/smart-trust-tools/upstream-patches
 * (`bun run cat state:mount` puts it on disk). Each file is
 * upstream/<target>/NNNN-<subject>.patch, and holds what `git am` reads: the
 * mbox `From <sha> Mon Sep 17 00:00:00 2001` line, `From:`, `Date:`, a
 * `Subject: [PATCH...]`, the `---` separator and at least one `diff --git`.
 * Whether a patch APPLIES needs the upstream tree at the commit it was made
 * against, which this repository does not hold. An absent upstream/ is
 * "not mounted", never a pass.
 *
 *   bun tools/check-upstream-patches/check.ts
 */
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const ROOT = join(import.meta.dir, "..", "..");
const UPSTREAM = join(ROOT, "upstream");
if (!existsSync(UPSTREAM)) {
  console.error("upstream/ is not on disk: it is kept on cat/smart-trust-tools/upstream-patches; run `bun run cat state:mount`. Not a pass.");
  process.exit(1);
}
const problems: string[] = [];
let patches = 0;
for (const target of readdirSync(UPSTREAM).sort()) {
  const dir = join(UPSTREAM, target);
  if (!statSync(dir).isDirectory()) {
    problems.push(`upstream/${target}: not in a target directory`);
    continue;
  }
  for (const f of readdirSync(dir).sort()) {
    const where = `upstream/${target}/${f}`;
    if (!/^\d{4}-[A-Za-z0-9._-]+\.patch$/.test(f)) {
      problems.push(`${where}: not a numbered NNNN-<subject>.patch`);
      continue;
    }
    patches++;
    const text = readFileSync(join(dir, f), "utf-8");
    const head = text.split("\n---\n")[0] ?? "";
    if (!/^From [0-9a-f]{40} Mon Sep 17 00:00:00 2001$/m.test(text.split("\n")[0] ?? "")) problems.push(`${where}: no mbox From line`);
    if (!/^From: .+$/m.test(head)) problems.push(`${where}: no From: header`);
    if (!/^Date: .+$/m.test(head)) problems.push(`${where}: no Date: header`);
    if (!/^Subject: \[PATCH[^\]]*\] .+$/m.test(head)) problems.push(`${where}: no [PATCH] Subject: header`);
    if (!text.includes("\n---\n")) problems.push(`${where}: no --- separator`);
    if (!/^diff --git a\/\S+ b\/\S+$/m.test(text)) problems.push(`${where}: no diff --git hunk`);
  }
}
for (const p of problems) console.error(p);
console.log(`${patches} patch(es); ${problems.length} problem(s)`);
process.exit(problems.length === 0 && patches > 0 ? 0 : 1);
