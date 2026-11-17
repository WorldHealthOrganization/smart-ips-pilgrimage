#!/usr/bin/env bun
/**
 * `translations/<locale>/navbar.pot`: the words of this site's navbar (the
 * rail), so translated pages show it in their language (owner, 2026-11-12:
 * "translate all the stuff on the LHS navbar").
 *
 * The rail is drawn from shared data in the site's source language; on a page
 * whose `<html lang>` is a locale with a translated `navbar.po`, `navbar.js`
 * swaps every label it finds there, by exact match
 * (cat-harness-tools `scripts/lib/navbar-strings.ts`). So this template holds:
 * - the guide's title and every group and entry of `sushi-config.yaml`
 *   `menu:`, which are the rail's page labels;
 * - "Table of Contents" and "Releases", the entries the IG build adds;
 * - the rail's own words ("Pages", "Folders", …), from the platform's one list
 *   (`railChromePotEntries`), never typed here.
 *
 * Usage:
 *   bun input/scripts/navbar-pot.ts           # write the templates
 *   bun input/scripts/navbar-pot.ts --check   # exit 1 if one is missing or stale
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { formatPot, potWithoutTimestamp, type PotEntry } from "../../cat-harness-tools/pipeline/pot-extract.ts";
import { railChromePotEntries } from "../../cat-harness-tools/scripts/lib/navbar-strings.ts";

const ROOT = resolve(import.meta.dir, "..", "..");
const LOCALES = ["ar", "es", "fr", "ru", "zh"];
const SUSHI = "sushi-config.yaml";

/** The title and menu labels of `sushi-config.yaml`, read line by line (no YAML dependency). */
export function menuEntries(text: string): PotEntry[] {
  const out: PotEntry[] = [];
  const lines = text.split("\n");
  let inMenu = false;
  lines.forEach((raw, i) => {
    const title = /^title:\s*(.+?)\s*$/.exec(raw);
    if (title) out.push({ source: SUSHI, line: i + 1, msgid: title[1]!.replace(/^["']|["']$/g, ""), kind: "ui-string", comment: "The guide's title, at the top of the navbar." });
    if (/^menu:\s*$/.test(raw)) return void (inMenu = true);
    if (inMenu && /^\S/.test(raw)) inMenu = false;
    if (!inMenu) return;
    const m = /^(\s+)([^:#][^:]*?)\s*:\s*(\S.*)?$/.exec(raw);
    if (!m) return;
    const group = m[3] === undefined;
    out.push({
      source: SUSHI,
      line: i + 1,
      msgid: m[2]!.replace(/^["']|["']$/g, ""),
      kind: "ui-string",
      comment: group ? "Navbar group (sushi-config.yaml menu)." : `Navbar entry for ${m[3]} (sushi-config.yaml menu).`,
    });
  });
  return out;
}

export function entries(): PotEntry[] {
  return [
    ...menuEntries(readFileSync(join(ROOT, SUSHI), "utf8")),
    { source: "IG build", line: 1, msgid: "Table of Contents", kind: "ui-string", comment: "Navbar entry for toc.html, which the IG build adds." },
    { source: "IG build", line: 2, msgid: "Releases", kind: "ui-string", comment: "Navbar entry for the guide's release history, which the IG build adds." },
    ...railChromePotEntries(),
  ];
}

if (import.meta.main) {
  const check = process.argv.includes("--check");
  let stale = 0;
  for (const locale of LOCALES) {
    const pot = formatPot(entries(), { projectName: "smart-ips-pilgrimage", locale });
    const path = join(ROOT, "translations", locale, "navbar.pot");
    const current = existsSync(path) && potWithoutTimestamp(readFileSync(path, "utf8")) === potWithoutTimestamp(pot);
    if (current) continue;
    stale++;
    if (check) console.error(`✗ translations/${locale}/navbar.pot is stale — run bun input/scripts/navbar-pot.ts`);
    else {
      mkdirSync(join(ROOT, "translations", locale), { recursive: true });
      writeFileSync(path, pot);
    }
  }
  if (check && stale) process.exit(1);
  console.log(`✓ navbar templates ${check ? "current" : "written"} for ${LOCALES.join(", ")}.`);
}
