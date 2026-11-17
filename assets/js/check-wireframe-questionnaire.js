// GENERATED from fhir-harness/scripts/check-wireframe-questionnaire.ts; do not edit.
const VOID = new Set(["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"]);
function attr(attrs, name) {
  const m = new RegExp(`(?:^|\\s)${name}\\s*=\\s*(?:"([^"]*)"|'([^']*)'|([^\\s"'>]+))`, "i").exec(attrs);
  return m ? m[1] ?? m[2] ?? m[3] : undefined;
}
export function wireframeLayouts(html) {
  const body = html.replace(/<!--[\s\S]*?-->/g, "").replace(/<(script|style)\b[\s\S]*?<\/\1\s*>/gi, "");
  const whole = { name: "(whole document)", fields: [] };
  const named = new Map;
  const stack = [];
  const tagRe = /<(\/?)([a-zA-Z][\w-]*)([^>]*?)(\/?)>/g;
  for (let m;m = tagRe.exec(body); ) {
    const [, closing, rawTag, attrs, selfClose] = m;
    const tag = rawTag.toLowerCase();
    if (closing) {
      const i = stack.map((e) => e.tag).lastIndexOf(tag);
      if (i >= 0)
        stack.length = i;
      continue;
    }
    const layout = attr(attrs, "data-layout");
    const current = layout ?? [...stack].reverse().find((e) => e.layout)?.layout;
    const id = attr(attrs, "data-element");
    if (id) {
      if (current) {
        if (!named.has(current))
          named.set(current, { name: current, fields: [] });
        named.get(current).fields.push(id.trim());
      } else
        whole.fields.push(id.trim());
    } else if (layout && !named.has(layout))
      named.set(layout, { name: layout, fields: [] });
    if (!selfClose && !VOID.has(tag))
      stack.push({ tag, layout });
  }
  if (named.size === 0)
    return [whole];
  const layouts = [...named.values()];
  if (whole.fields.length)
    for (const l of layouts)
      l.fields.unshift(...whole.fields);
  return layouts;
}
export function questionnaireItems(q) {
  const out = [];
  const walk = (items) => {
    for (const it of items ?? []) {
      if (it.type !== "group" && it.type !== "display") {
        const ids = new Set;
        if (it.definition) {
          ids.add(it.definition);
          const hash = it.definition.indexOf("#");
          if (hash >= 0 && hash < it.definition.length - 1)
            ids.add(it.definition.slice(hash + 1));
        }
        for (const c of it.code ?? [])
          if (c.code)
            ids.add(c.code);
        out.push({ linkId: it.linkId ?? "(no linkId)", ids: [...ids] });
      }
      walk(it.item);
    }
  };
  walk(q.item);
  return out;
}
export function judgeLayout(layout, items) {
  const f = [];
  const at = `[${layout.name}]`;
  const seen = new Set;
  for (const id of layout.fields) {
    if (seen.has(id))
      f.push(`${at} data element "${id}" appears twice in this layout`);
    seen.add(id);
  }
  const used = new Set;
  const matched = [];
  for (const id of new Set(layout.fields)) {
    const i = items.findIndex((it, k) => !used.has(k) && it.ids.includes(id));
    if (i < 0)
      f.push(`${at} field "${id}" has no Questionnaire item`);
    else {
      used.add(i);
      matched.push({ field: id, item: i });
    }
  }
  items.forEach((it, k) => {
    if (used.has(k))
      return;
    if (it.ids.length === 0)
      f.push(`${at} item "${it.linkId}" names no data element (no definition, no code)`);
    else
      f.push(`${at} item "${it.linkId}" (${it.ids.join(" | ")}) has no field in the wireframe`);
  });
  for (let k = 1;k < matched.length; k++) {
    if (matched[k].item < matched[k - 1].item) {
      f.push(`${at} order differs: field "${matched[k].field}" follows "${matched[k - 1].field}" in the wireframe, ` + `but item "${items[matched[k].item].linkId}" comes before "${items[matched[k - 1].item].linkId}"`);
      break;
    }
  }
  return f;
}
export function judge(html, questionnaire) {
  const items = questionnaireItems(questionnaire);
  return wireframeLayouts(html).flatMap((l) => judgeLayout(l, items));
}
export function structureWarnings(q) {
  const all = [];
  const walk = (items) => {
    for (const it of items ?? []) {
      all.push(it);
      walk(it.item);
    }
  };
  walk(q.item);
  const w = [];
  const ids = new Set;
  const twice = new Set;
  for (const it of all) {
    if (it.linkId === undefined)
      continue;
    if (ids.has(it.linkId))
      twice.add(it.linkId);
    ids.add(it.linkId);
  }
  for (const id of twice)
    w.push(`linkId "${id}" is used by more than one item`);
  for (const it of all)
    for (const ew of it.enableWhen ?? [])
      if (ew.question !== undefined && !ids.has(ew.question))
        w.push(`item "${it.linkId ?? "(no linkId)"}" has enableWhen on "${ew.question}", which is no item's linkId`);
  return w;
}
function parseQuestionnaire(text) {
  let q;
  try {
    q = JSON.parse(text);
  } catch (e) {
    return { error: `not JSON: ${e.message}` };
  }
  if (q === null || typeof q !== "object" || q.resourceType !== "Questionnaire")
    return { error: `not a Questionnaire (resourceType ${String(q?.resourceType ?? "missing")})` };
  return { q };
}
function warningsOf(q, ctx) {
  const w = structureWarnings(q);
  if (ctx.wireframe !== undefined && wireframeLayouts(ctx.wireframe).some((l) => l.fields.length))
    w.push(...judge(ctx.wireframe, q));
  return w;
}
export function checkSuggestion(before, after, ctx = {}) {
  const a = parseQuestionnaire(after);
  if (!a.q)
    return { errors: [a.error], warnings: [] };
  const b = parseQuestionnaire(before);
  const had = new Set(b.q ? warningsOf(b.q, ctx) : []);
  return { errors: [], warnings: warningsOf(a.q, ctx).filter((w) => !had.has(w)) };
}
if (import.meta.main) {
  const { readFileSync } = await import("node:fs");
  const [wf, qPath] = process.argv.slice(2);
  if (!wf || !qPath) {
    console.error("usage: check-wireframe-questionnaire.ts <wireframe.html> <questionnaire.json>");
    process.exit(2);
  }
  let html, q;
  try {
    html = readFileSync(wf, "utf8");
    q = JSON.parse(readFileSync(qPath, "utf8"));
  } catch (e) {
    console.error(`could not read input: ${e.message}`);
    process.exit(2);
  }
  if (q.resourceType !== "Questionnaire") {
    console.error(`${qPath} is not a Questionnaire (resourceType ${q.resourceType ?? "missing"})`);
    process.exit(2);
  }
  const fields = wireframeLayouts(html).reduce((n, l) => n + l.fields.length, 0);
  if (fields === 0) {
    console.error(`${wf} has no data-element fields: nothing to compare`);
    process.exit(2);
  }
  const findings = judge(html, q);
  for (const x of findings)
    console.log(x);
  console.log(findings.length ? `${findings.length} finding(s)` : "faithful: every field has its item, in order");
  process.exit(findings.length ? 1 : 0);
}
