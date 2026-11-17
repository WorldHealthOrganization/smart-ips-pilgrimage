#!/usr/bin/env bun
/**
 * The overview figure (`input/includes/workflow-figure.html` and the drawing it
 * includes, `workflow-pretty.svg`) in each language (owner, 2026-11-13: "fix
 * all 3"). Both are included by pages that are translated, but an include is
 * not: a translated page showed the English figure, and its page-relative
 * links and image resolved under `<locale>/` and broke.
 *
 * Every string the figure shows (each drawn label, whose lines are joined;
 * each tooltip; the toggle labels; the image's alt and title; the caption,
 * whose links stay inline) is in `translations/<locale>/workflow-figure.pot`.
 * A locale whose `workflow-figure.po` translates any of them gets its own
 * `workflow-figure-<locale>.html` and `workflow-pretty-<locale>.svg`, which the
 * pages' `{% lang-fragment workflow-figure.html %}` picks on that locale's page
 * (fhir-harness `resolveLangFragments`), with every relative link one level up.
 * A string with no translation stays English; a drawn label keeps its number
 * of lines, re-wrapped at spaces (by characters where a language has none).
 *
 * The English files are generated elsewhere (`archimate/pretty.py`) or written
 * by hand; this reads them and never writes them.
 *
 * Usage:
 *   bun input/scripts/workflow-figure.ts           # write the templates and each translated locale's copies
 *   bun input/scripts/workflow-figure.ts --check   # fail when one is stale
 */
import { existsSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { parsePo } from "../../cat-harness-tools/pipeline/po-inject.ts";
import { formatPot, potWithoutTimestamp, type PotEntry } from "../../cat-harness-tools/pipeline/pot-extract.ts";

const ROOT = resolve(import.meta.dir, "..", "..");
const INC = join(ROOT, "input/includes");
const FIGURE = "workflow-figure.html";
const DRAWING = "workflow-pretty.svg";
const LOCALES = ["ar", "es", "fr", "ru", "zh"];
/** Languages written right to left. */
const RTL = new Set(["ar"]);

const unesc = (s: string) => s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, "&");
const esc = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const escAttr = (s: string) => esc(s).replace(/"/g, "&quot;");

/** Worth translating: has a letter run, not a lone step number or letter. */
const words = (s: string) => /\p{L}{2,}/u.test(s);

const TEXT_RE = /(<text\b[^>]*>)((?:<tspan\b[^>]*>[^<]*<\/tspan>)+)(<\/text>)/g;
/** A label drawn on one line with no <tspan> (a pictogram's caption, fitted with textLength). */
const PLAIN_TEXT_RE = /(<text\b[^>]*>)([^<]+)(<\/text>)/g;
const TSPAN_RE = /(<tspan\b[^>]*>)([^<]*)(<\/tspan>)/g;
const TITLE_RE = /(<title\b[^>]*>)([^<]+)(<\/title>)/g;
const LABEL_RE = /(<label\b[^>]*>)([^<]+)(<\/label>)/g;
const ATTR_RE = /\b(alt|title)="([^"]+)"/g;
const CAPTION_RE = /(<figcaption\b[^>]*>)([\s\S]*?)(<\/figcaption>)/;

/** A drawn label's text: its lines joined by a space. */
function labelText(tspans: string): string {
  return [...tspans.matchAll(TSPAN_RE)].map((m) => unesc(m[2]!).trim()).join(" ");
}

/** `text` in `n` lines of about equal length: at spaces, or by characters where there are none. */
export function wrap(text: string, n: number): string[] {
  if (n <= 1) return [text];
  // Chinese (and the like): any character is a break, but a Latin word or code stays whole.
  if (/[\u3000-\u9fff]/.test(text)) {
    const tokens = text.match(/[A-Za-z0-9._-]+|\s+|./gu) ?? [];
    const target = Math.ceil(text.length / n);
    const lines: string[] = [];
    let cur = "";
    for (const tok of tokens) {
      if (cur.trim() && (cur + tok).trim().length > target && lines.length < n - 1 && !/^\s+$/.test(tok)) {
        lines.push(cur.trim());
        cur = tok;
      } else cur += tok;
    }
    lines.push(cur.trim());
    return lines.filter((l) => l !== "");
  }
  const ws = text.split(/\s+/).filter(Boolean);
  if (ws.length >= n) {
    const target = text.length / n;
    const lines: string[] = [];
    let cur = "";
    for (const w of ws) {
      const next = cur ? `${cur} ${w}` : w;
      if (cur && next.length > target && lines.length < n - 1) {
        lines.push(cur);
        cur = w;
      } else cur = next;
    }
    lines.push(cur);
    return lines;
  }
  const chars = [...text];
  const per = Math.ceil(chars.length / n);
  return Array.from({ length: n }, (_, i) => chars.slice(i * per, (i + 1) * per).join("")).filter((l) => l !== "");
}

/** Every string the figure and its drawing show, in reading order, without repeats. */
export function entries(): PotEntry[] {
  const out: PotEntry[] = [];
  const seen = new Set<string>();
  const add = (source: string, msgid: string, comment: string) => {
    const m = msgid.trim();
    if (!m || !words(m) || seen.has(m)) return;
    seen.add(m);
    out.push({ source, line: out.length + 1, msgid: m, kind: "ui-string", comment });
  };
  const svg = readFileSync(join(INC, DRAWING), "utf8");
  for (const m of svg.matchAll(TITLE_RE)) add(`input/includes/${DRAWING}`, unesc(m[2]!), "A tooltip in the overview drawing.");
  for (const m of svg.matchAll(TEXT_RE)) {
    const n = [...m[2]!.matchAll(TSPAN_RE)].length;
    add(`input/includes/${DRAWING}`, labelText(m[2]!), n > 1 ? `A label drawn on ${n} lines in the overview drawing; keep it short.` : "A label in the overview drawing; keep it short.");
  }
  for (const m of svg.matchAll(PLAIN_TEXT_RE)) add(`input/includes/${DRAWING}`, unesc(m[2]!), "A small label inside a picture of the overview drawing, squeezed to its width; keep it short.");
  const fig = readFileSync(join(INC, FIGURE), "utf8").replace(/<!--[\s\S]*?-->/g, "");
  for (const m of fig.matchAll(LABEL_RE)) add(`input/includes/${FIGURE}`, unesc(m[2]!), "A toggle between the figure's two pictures.");
  for (const m of fig.matchAll(ATTR_RE)) add(`input/includes/${FIGURE}`, unesc(m[2]!), m[1] === "alt" ? "The ArchiMate picture's text alternative." : "A tooltip on the figure.");
  const cap = CAPTION_RE.exec(fig);
  if (cap) add(`input/includes/${FIGURE}`, cap[2]!.trim(), "The figure's caption. Keep each <a ...>...</a> with its href exactly as written; translate only the words.");
  return out;
}

const SKIP_URL = /^(?:[a-z][a-z0-9+.-]*:|\/|#|\{|\.\.\/)/i;
/** Every relative link and image one level up, for a page at `<locale>/`. */
function up(html: string): string {
  return html.replace(/\b(href|src)="([^"]*)"/g, (w, a: string, u: string) => (!u || SKIP_URL.test(u) ? w : `${a}="../${u}"`));
}

/**
 * A translated label's opening tag in a right-to-left language: read right to
 * left (so "IPS" or "QR" inside Arabic keeps its place), and still drawn from
 * the same point, since in that direction "end" is the left edge.
 */
export function rtlOpen(open: string): string {
  const flip: Record<string, string> = { start: "end", end: "start", middle: "middle" };
  const anchor = /text-anchor="(\w+)"/.exec(open)?.[1] ?? "start";
  const base = open.replace(/\s*text-anchor="\w+"/, "");
  return base.replace(/^<text\b/, `<text direction="rtl" text-anchor="${flip[anchor] ?? anchor}"`);
}

/** The drawing in one language. */
export function drawing(t: (s: string) => string, rtl = false): string {
  const op = (open: string) => (rtl ? rtlOpen(open) : open);
  const svg = readFileSync(join(INC, DRAWING), "utf8");
  return up(
    svg
      .replace(TITLE_RE, (_w, o: string, s: string, c: string) => `${o}${esc(t(unesc(s).trim()))}${c}`)
      .replace(TEXT_RE, (_w, open: string, tspans: string, close: string) => {
        const parts = [...tspans.matchAll(TSPAN_RE)];
        const src = labelText(tspans);
        const to = t(src);
        if (to === src) return `${open}${tspans}${close}`;
        const lines = wrap(to, parts.length);
        return `${op(open)}${parts.map((p, i) => (lines[i] !== undefined ? `${p[1]}${esc(lines[i]!)}${p[3]}` : "")).join("")}${close}`;
      })
      .replace(PLAIN_TEXT_RE, (w, o: string, s: string, c: string) => {
        const to = t(unesc(s).trim());
        return to === unesc(s).trim() ? w : `${op(o)}${esc(to)}${c}`;
      }),
  )
    // The drawing's coordinates are laid out left to right: on a right-to-left
    // page the inherited direction would anchor every label at its other end.
    .replace(/<svg\b([^>]*?)style="/, '<svg$1style="direction:ltr;')
    .replace("<!-- Generated by archimate/pretty.py", "<!-- Translated by input/scripts/workflow-figure.ts from workflow-pretty.svg, itself generated by archimate/pretty.py");
}

/** The figure in one language, including that language's drawing. */
export function figure(locale: string, t: (s: string) => string): string {
  const fig = readFileSync(join(INC, FIGURE), "utf8");
  return up(
    fig
      .replace(`{% include ${DRAWING} %}`, `{% include ${DRAWING.replace(".svg", `-${locale}.svg`)} %}`)
      .replace(LABEL_RE, (_w, o: string, s: string, c: string) => `${o}${esc(t(unesc(s).trim()))}${c}`)
      .replace(ATTR_RE, (_w, a: string, v: string) => `${a}="${escAttr(t(unesc(v)))}"`)
      .replace(CAPTION_RE, (_w, o: string, s: string, c: string) => `${o}${t(s.trim())}${c}`),
  ).replace(/^<!--/, `<!-- Translated (${locale}) by input/scripts/workflow-figure.ts from ${FIGURE}; do not edit.\n`);
}

function langOf(locale: string): ((s: string) => string) | undefined {
  const path = join(ROOT, "translations", locale, "workflow-figure.po");
  if (!existsSync(path)) return undefined;
  const po = parsePo(readFileSync(path, "utf8"));
  if (![...po.values()].some((v) => v.trim())) return undefined;
  return (s) => po.get(s)?.trim() || s;
}

function emit(path: string, want: string, check: boolean, same: (a: string, b: string) => boolean = (a, b) => a === b): boolean {
  const rel = path.slice(ROOT.length + 1);
  const have = existsSync(path) ? readFileSync(path, "utf8") : undefined;
  if (have !== undefined && same(have, want)) return true;
  if (check) {
    console.error(`${rel}: stale; run bun input/scripts/workflow-figure.ts`);
    return false;
  }
  mkdirSync(join(path, ".."), { recursive: true });
  writeFileSync(path, want);
  console.log(`${rel}: written`);
  return true;
}

if (import.meta.main) {
  const check = process.argv.includes("--check");
  const results: boolean[] = [];
  for (const locale of LOCALES) {
    const pot = formatPot(entries(), { projectName: "smart-ips-pilgrimage", locale });
    results.push(emit(join(ROOT, "translations", locale, "workflow-figure.pot"), pot, check, (a, b) => potWithoutTimestamp(a) === potWithoutTimestamp(b)));
    const t = langOf(locale);
    const files: [string, () => string][] = [
      [FIGURE.replace(".html", `-${locale}.html`), () => figure(locale, t!)],
      [DRAWING.replace(".svg", `-${locale}.svg`), () => drawing(t!, RTL.has(locale))],
    ];
    for (const [name, make] of files) {
      const path = join(INC, name);
      if (t) results.push(emit(path, make(), check));
      else if (existsSync(path)) {
        console.error(`input/includes/${name}: ${locale} translates none of the figure; delete it`);
        results.push(false);
      }
    }
  }
  if (!results.every(Boolean)) process.exit(1);
  if (check) console.log("✓ the figure's templates and translated copies are current");
}
