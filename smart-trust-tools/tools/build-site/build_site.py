#!/usr/bin/env python3
"""Build the static viewer site (graph explorer, traceability matrix, API,
wire/payload models, requirements, node kinds) into site/.

Usage:
    python3 tools/build-site/build_site.py [--git-ref REF] [--out site]

The graph is read from this instance's cat-harness nodes by kg_nodes.py. The
TypeScript API reference (site/api/typedoc/) is built separately by
build_site.sh, which needs Node.js. Requires PyYAML, rdflib, cbor2,
base45, and bun (to load the Tool nodes).
"""

import argparse
import collections
import html
import json
import pathlib
import re
import shutil
import subprocess
import sys
import urllib.parse
import zlib

import base45
import cbor2
import rdflib

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import kg_nodes  # noqa: E402

REPO = "litlfred/smart-trust-tools"

NAV = [
    ("index.html", "Overview"),
    ("explorer.html", "Graph explorer"),
    ("trace.html", "Traceability"),
    ("requirements.html", "Requirements"),
    ("api.html", "API (WIT)"),
    ("api/typedoc/index.html", "API reference (TS)"),
    ("kotlin.html", "Kotlin API"),
    ("models.html", "Wire & payload models"),
    ("kinds.html", "Node kinds"),
]

FONTS = ("https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,700"
         "&family=JetBrains+Mono:wght@400;600&family=Public+Sans:wght@400;550;650;700&display=swap")

def esc(s):
    return html.escape(str(s), quote=True)


def gh(ref, path):
    return "https://github.com/%s/blob/%s/%s" % (REPO, ref, path)


# ---------------------------------------------------------------------------
# Page shell
# ---------------------------------------------------------------------------

def topbar(current, up, extra_class=""):
    """The viewer top bar. `up` is the relative path from the page to the site
    root; the TypeDoc pages get it too, through inject_topbar.py."""
    nav = "".join(
        '<a href="%s%s"%s>%s</a>' % (up, href, ' aria-current="page"' if href == current else "", esc(label))
        for href, label in NAV)
    return (
        '<header class="topbar%s"><div class="topbar-inner">'
        '<a class="brand" href="%sindex.html"><span class="brand-mark" aria-hidden="true">%s</span>SMART Trust Tools</a>'
        '<nav class="nav" aria-label="Viewers">%s</nav></div></header>\n'
    ) % (" " + extra_class if extra_class else "", up, "<i></i>" * 9, nav)


def shell(current, title, body, ref, scripts=(), depth=0, fragment=False, head_extra=""):
    up = "../" * depth
    head = (
        '<title>%s</title>\n'
        '<meta name="claude:viewport-fit-sides" content="cover">\n'
        '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
        '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
        '<link rel="stylesheet" href="%s">\n'
        '<link rel="stylesheet" href="%sassets/site.css">\n%s'
    ) % (esc(title), FONTS, up, head_extra)
    top = topbar(current, up)
    tail = "".join('<script src="%s"></script>\n' % s for s in scripts)
    if fragment:
        return head + top + body + tail
    return ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            + head + '</head>\n<body>\n' + top + body + tail + '</body>\n</html>\n')


# ---------------------------------------------------------------------------
# Highlighting
# ---------------------------------------------------------------------------

STT_TAG = re.compile(r"\[((?:STT-[A-Z0-9]+-\d{3}(?:,\s*)?)+)\]")


def link_tags(text_html):
    def repl(m):
        ids = [x.strip() for x in m.group(1).split(",")]
        return "[" + ", ".join('<a href="explorer.html#%s">%s</a>' % (i, i) for i in ids) + "]"
    return STT_TAG.sub(repl, text_html)


def link_issues(text_html):
    return re.sub(r"\b(OI-\d{2})\b", r'<a href="explorer.html#\1">\1</a>', text_html)



def highlight_wit(src):
    out = []
    for line in src.split("\n"):
        m = re.match(r"^(\s*)(///?.*)$", line)
        if m:
            out.append(m.group(1) + '<span class="tok-comment">%s</span>' % link_issues(link_tags(esc(m.group(2)))))
            continue
        e = esc(line)
        e = re.sub(r"\b(package|interface|world|record|variant|enum|resource|type|use|func|import|export|include|constructor|flags)\b",
                   r'<span class="tok-key">\1</span>', e)
        e = re.sub(r'(<span class="tok-key">(?:interface|world|record|variant|enum|resource|type)</span>\s+)([a-z0-9-]+)',
                   lambda mm: '%s<span class="tok-name" id="wit-%s">%s</span>' % (mm.group(1), mm.group(2), mm.group(2)), e)
        e = re.sub(r"^(\s*)([a-z0-9-]+)(:\s*<span class=\"tok-key\">func</span>)",
                   r'\1<span class="tok-name">\2</span>\3', e)
        out.append(e)
    return "\n".join(out)


def highlight_cddl(src, anchor_prefix):
    out = []
    for line in src.split("\n"):
        code, _, comment = line.partition(";")
        e = esc(code)
        e = re.sub(r"(&quot;(?:[^&]|&(?!quot;))*&quot;)", r'<span class="tok-str">\1</span>', e)
        e = re.sub(r"^([a-z][a-z0-9-]*)(\s*=)",
                   lambda m: '<span class="tok-name" id="%s%s">%s</span>%s' % (anchor_prefix, m.group(1), m.group(1), m.group(2)), e)
        e = re.sub(r"(\.(?:cbor|regexp|size|ne))\b", r'<span class="tok-key">\1</span>', e)
        if comment or line.lstrip().startswith(";"):
            e += '<span class="tok-comment">;%s</span>' % link_issues(link_tags(esc(comment)))
        out.append(e)
    return "\n".join(out)


# ---------------------------------------------------------------------------
# CBOR diagnostic notation (RFC 8949 section 8)
# ---------------------------------------------------------------------------

def diag(v, indent=0):
    pad = "  " * indent
    if isinstance(v, cbor2.CBORTag):
        return "%d(%s)" % (v.tag, diag(v.value, indent))
    if isinstance(v, bytes):
        return "h'%s'" % v.hex()
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "null"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, list):
        if not v:
            return "[]"
        return "[\n" + ",\n".join(pad + "  " + diag(x, indent + 1) for x in v) + "\n" + pad + "]"
    if isinstance(v, dict):
        if not v:
            return "{}"
        return "{\n" + ",\n".join(pad + "  " + diag(k, indent + 1) + ": " + diag(x, indent + 1)
                                   for k, x in v.items()) + "\n" + pad + "}"
    return repr(v)


# ---------------------------------------------------------------------------
# Pages
# ---------------------------------------------------------------------------

def requirements_page(ref, M, graph):
    """The requirement set as one document, read from the req: nodes and the edges kg_nodes draws."""
    by_id = {n["id"]: n for n in graph["nodes"]}
    out = collections.defaultdict(lambda: collections.defaultdict(list))
    for e in graph["edges"]:
        out[e["s"]][e["rel"]].append(by_id[e["t"]])

    def links(nodes, with_urls=False):
        items = []
        for n in nodes:
            u = n.get("urls") and next((n["urls"][k] for k in ("pinned", "published", "url", "main") if n["urls"].get(k)), None)
            label = esc(n["label"]) + (' <span class="muted">%s</span>' % esc(n["title"]) if n["title"] != n["label"] else "")
            items.append('<li><a href="explorer.html#%s">%s</a>%s</li>' % (
                esc(n["id"]), label, ' <a class="small" href="%s">source ↗</a>' % esc(u) if with_urls and u else ""))
        return "<ul>%s</ul>" % "".join(items)

    toc, blocks = [], []
    reqs = list(M["reqs"].values())
    for area, title in M["areas"].items():
        rs = [r for r in reqs if r["area"] == area]
        if not rs:
            continue
        toc.append('<li><a href="#area-%s">%s</a> <span class="muted small">%s · %d</span></li>' % (area.lower(), area, esc(title), len(rs)))
        blocks.append('<h2 id="area-%s">%s · %s</h2>' % (area.lower(), area, esc(title)))
        for r in rs:
            o = out[r["id"]]
            rows = [("References", o["references"], True), ("Satisfies (smart-trust)", o["satisfies"], True),
                    ("Derived from (broader requirement)", o["derivedFrom"], False),
                    ("Realized by skills", o["realizedBy"], False), ("Constrains (WIT, CDDL)", o["constrainsApi"], False),
                    ("Verified by tests", [by_id[e["s"]] for e in graph["edges"] if e["rel"] == "verifies" and e["t"] == r["id"]], False),
                    ("Test plans", [by_id[e["s"]] for e in graph["edges"] if e["rel"] == "assesses" and e["t"] == r["id"]], False),
                    ("Open issues", o["affectedBy"], False)]
            blocks.append(
                '<section class="req" id="%s"><h3>%s · %s</h3>'
                '<p><span class="badge %s">%s</span> <span class="chip">%s</span> <span class="chip">%s</span> %s'
                ' <span class="small"><a href="explorer.html#%s">open in explorer</a> · <a href="%s">node</a></span></p>'
                '<blockquote>%s</blockquote><p class="small">%s</p>%s</section>' % (
                    r["id"].lower(), r["id"], esc(r["title"]), r["conformance"].split(" ")[0].lower(), esc(r["conformance"]),
                    esc(r["category"]), esc(r["derivation"]), " ".join('<span class="chip">%s</span>' % esc(t) for t in r["targets"]),
                    r["id"], gh(ref, r["file"]), esc(r["statement"]), esc(r["description"]),
                    "".join("<h4>%s</h4>%s" % (h, links(ns, u)) for h, ns, u in rows if ns)))
    return ("""<main class="page"><article class="prose req-doc">
<span class="eyebrow">Requirements · read from skills/requirements/</span>
<h1>HCERT library requirements</h1>
<p>%d requirements, one cat-harness <code>req:</code> node each. Every link below is an edge in the graph:
library sections, external schemas, references and owner directives a requirement references; the broader
requirement it is derived from; the smart-trust FHIR Requirements it satisfies; the skills that realize it; the WIT items and CDDL rules whose comments cite it; and the open issues
(beans) that affect it.</p>
<ul>%s</ul>%s</article></main>""" % (len(reqs), "".join(toc), "".join(blocks)))


def wit_files_in_dependency_order():
    """The contract's .wit files, each after the files whose interfaces it uses,
    imports or exports (ties alphabetical), read from the files rather than listed."""
    files = {p.name: p.read_text() for p in sorted((ROOT / "api" / "wit").glob("*.wit"))}
    defines = {i: f for f, src in files.items() for i in re.findall(r"^\s*interface\s+([a-z0-9-]+)", src, flags=re.M)}
    needs = {f: {defines[i] for i in re.findall(r"^\s*(?:use|import|export)\s+([a-z0-9-]+)\b(?![:/])", src, flags=re.M)
                 if i in defines and defines[i] != f} for f, src in files.items()}
    order = []
    while needs:
        ready = sorted(f for f, d in needs.items() if d <= set(order)) or sorted(needs)[:1]
        order.append(ready[0])
        del needs[ready[0]]
    return [ROOT / "api" / "wit" / f for f in order]


def api_page(ref, M):
    files = wit_files_in_dependency_order()
    index, blocks = [], []
    for p in files:
        src = p.read_text()
        names = re.findall(r"^(?:interface|world)\s+([a-z0-9-]+)", src, flags=re.M)
        index.append('<li><a href="#file-%s"><code>%s</code></a> <span class="muted small">%s</span></li>'
                     % (p.stem, p.name, ", ".join(names)))
        blocks.append(
            '<section class="section" id="file-%s"><div class="section-head"><h2><code>%s</code></h2>'
            '<a class="small" href="%s">source</a></div><pre class="wit"><code>%s</code></pre></section>'
            % (p.stem, p.name, gh(ref, "api/wit/" + p.name), highlight_wit(src)))
    worlds = (ROOT / "api" / "wit" / "worlds.wit").read_text()
    rows = []
    for name, body in re.findall(r"world\s+([a-z0-9-]+)\s*\{(.*?)\}", worlds, flags=re.S):
        imps = re.findall(r"import\s+([a-z0-9-]+)", body)
        exps = re.findall(r"export\s+([a-z0-9-]+)", body)
        inc = re.findall(r"include\s+([a-z0-9-]+)", body)
        rows.append("<tr><td><code>%s</code></td><td>%s</td><td>%s</td></tr>" % (
            name, " ".join('<span class="chip">%s</span>' % x for x in imps) or "—",
            " ".join('<span class="chip">%s</span>' % x for x in exps)
            or "includes " + ", ".join("<code>%s</code>" % x for x in inc)))
    body = """
<main class="page">
  <section class="section prose">
    <span class="eyebrow">Library API contract · WIT package who:smart-trust@0.1.0</span>
    <h1>API (WIT)</h1>
    <p>The API is defined first, in WIT, the WebAssembly Component Model interface language. Rust exports it from its
    WebAssembly component; Kotlin follows it through fixed mapping rules. Requirement tags such as
    <code>[STT-COS-002]</code> link into the graph explorer. For the same API as JavaScript callers see it, open the
    <a href="api/typedoc/index.html">TypeScript reference</a>, generated by jco and TypeDoc.</p>
  </section>
  <section class="section">
    <h2>Worlds: the WebAssembly components the Rust build ships</h2>
    <div class="table-wrap"><table><thead><tr><th>World</th><th>Imports (host provides)</th><th>Exports</th></tr></thead>
    <tbody>%s</tbody></table></div>
  </section>
  <section class="section"><h2>Files</h2><ul class="small">%s</ul></section>
  %s
</main>""" % ("".join(rows), "".join(index), "".join(blocks))
    return body


KT_KEYWORDS = ("package|import|interface|sealed|data|class|object|enum|fun|val|var|typealias|"
               "override|inline|when|is|as|return|null")


def highlight_kotlin(src):
    out = []
    for line in src.split("\n"):
        stripped = line.lstrip()
        if stripped.startswith(("//", "/**", "*", "*/")):
            out.append('<span class="tok-comment">%s</span>' % link_tags(esc(line)))
            continue
        e = esc(line)
        e = re.sub(r"\b(%s)\b" % KT_KEYWORDS, r'<span class="tok-key">\1</span>', e)
        e = re.sub(r'(<span class="tok-key">(?:interface|class|object|typealias)</span>\s+)([A-Z][A-Za-z0-9]*)',
                   lambda m: '%s<span class="tok-name" id="kt-%s">%s</span>' % (m.group(1), m.group(2), m.group(2)), e)
        out.append(e)
    return "\n".join(out)


def kotlin_page(ref):
    base = ROOT / "tools" / "hcert-kotlin" / "hcert-api" / "src" / "commonMain" / "kotlin"
    files = sorted(base.rglob("*.kt"), key=lambda p: (p.parent != base / "who" / "smart" / "trust", p.as_posix()))
    index, blocks = [], []
    for p in files:
        rel = p.relative_to(ROOT).as_posix()
        short = p.relative_to(base / "who" / "smart" / "trust").as_posix()
        anchor = "kt-file-" + short.replace("/", "-").replace(".kt", "")
        src = p.read_text()
        decls = re.findall(r"^(?:sealed |data |enum |fun )?(?:interface|class|object|typealias)\s+([A-Z]\w*)", src, flags=re.M)
        index.append('<li><a href="#%s"><code>%s</code></a> <span class="muted small">%s</span></li>'
                     % (anchor, short, ", ".join(decls[:8]) + (" …" if len(decls) > 8 else "")))
        blocks.append('<section class="section" id="%s"><div class="section-head"><h2><code>%s</code></h2>'
                      '<a class="small" href="%s">source</a></div><pre><code>%s</code></pre></section>'
                      % (anchor, short, gh(ref, rel), highlight_kotlin(src)))
    return """
<main class="page">
  <section class="section prose">
    <span class="eyebrow">Kotlin Multiplatform · generated from the WIT contract</span>
    <h1>Kotlin API</h1>
    <p>Declarations only, with no behaviour, implemented by <code>hcert-core</code>. <code>tools/wit2kotlin/wit2kotlin.py</code> generates them from
    <a href="api.html">the contract</a>, so the Kotlin and Rust libraries cannot drift apart, but the Kotlin API names no WIT: records become
    data classes, variants sealed interfaces, resources <code>AutoCloseable</code> interfaces, and a call that can fail returns
    <code>HcertResult&lt;T, E&gt;</code>. Each exported interface becomes a Kotlin interface the library implements, for example
    <code>Codec</code> or <code>Verifier</code>; imported ones (<code>Signer</code>, <code>Terminology</code>) are implemented by the host
    application. The entry point is <code>object Hcert</code>: <code>Hcert.verifier</code>, <code>Hcert.issuer</code> and so on.</p>
    <p>The module targets the JVM (Java 11+), which Android uses as-is, and Node.js through Kotlin/JS IR with generated TypeScript
    declarations. Regenerate with <code>python3 tools/wit2kotlin/wit2kotlin.py</code>; CI fails if the API is out of date with the contract.</p>
  </section>
  <section class="section"><h2>Files</h2><ul class="small">%s</ul></section>
  %s
</main>""" % ("".join(index), "".join(blocks))


def models_page(ref, M):
    env = (ROOT / "api" / "cddl" / "hcert.cddl").read_text()
    gen = (ROOT / "models" / "generated" / "trust-phw.cddl").read_text()
    ctx = json.loads((ROOT / "models" / "generated" / "trust-phw.context.jsonld").read_text())
    vec = json.loads((ROOT / "vectors" / "smart-trust-pr129" / "dvc-qr-example-XXA.json").read_text())
    cert = vec["certificates"]["hepb1"]
    cose = zlib.decompress(base45.b45decode(cert["hc1"][4:]))
    tagged = cbor2.loads(cose)
    prot, unprot, payload_b, sig = tagged.value
    claims = cbor2.loads(payload_b)
    layered = cbor2.CBORTag(18, ["<<%s>>" % diag(cbor2.loads(prot)), unprot, "<<CWT claims, below>>", sig])
    cose_diag = diag(layered).replace('"<<', "<< ").replace('>>"', " >>").replace("\\n", "\n")
    payload = claims[-260][-6]
    doc = dict(payload)
    doc = {"@context": ctx["@context"], "@type": "DVCMin", **doc}
    g = rdflib.Graph().parse(data=json.dumps(doc), format="json-ld")
    nquads = "\n".join(sorted(g.serialize(format="nt").strip().splitlines()))
    playground = "https://json-ld.org/playground/#startTab=tab-nquads&json-ld=" + urllib.parse.quote(json.dumps(doc))
    cbor_me = "https://cbor.me/?bytes=" + cose.hex()

    shapes = rdflib.Graph().parse(ROOT / "models" / "generated" / "trust-phw.shacl.ttl", format="turtle")
    SH = rdflib.Namespace("http://www.w3.org/ns/shacl#")
    LMX = rdflib.Namespace("https://github.com/litlfred/smart-trust-tools/models/lmx#")
    SKOS = rdflib.Namespace("http://www.w3.org/2004/02/skos/core#")
    RDFS = rdflib.RDFS
    shape_html = []
    for shape in sorted(shapes.subjects(rdflib.RDF.type, SH.NodeShape)):
        label = shapes.value(shape, RDFS.label)
        target = shapes.value(shape, SH.targetClass)
        abstract = str(shapes.value(shape, LMX.abstract)) == "true"
        rows = []
        props = list(shapes.objects(shape, SH.property))
        props.sort(key=lambda p: str(shapes.value(p, SH.name)))
        # keep logical-model order where possible
        order = list(payload.keys()) + list(payload["vx"].keys())
        props.sort(key=lambda p: order.index(str(shapes.value(p, SH.name))) if str(shapes.value(p, SH.name)) in order else 99)
        for p in props:
            name = shapes.value(p, SH.name)
            path = shapes.value(p, SH.path)
            mn = shapes.value(p, SH.minCount)
            mx = shapes.value(p, SH.maxCount)
            card = "%s..%s" % (mn or 0, mx or "*")
            node = shapes.value(p, SH.node)
            ftype = shapes.value(p, LMX.fhirType)
            ty = ('<a href="#shape-%s">%s</a>' % (str(node).rsplit("/", 1)[1], str(node).rsplit("/", 1)[1])
                  if node else "<code>%s</code>" % ftype)
            vs = shapes.value(p, LMX.valueSet)
            strength = shapes.value(p, LMX.bindingStrength)
            binding = ('%s <a href="%s">%s</a>' % (esc(strength), esc(vs), esc(str(vs).rsplit("/", 1)[-1]))
                       if vs else "")
            codes = sorted(str(c) for c in shapes.objects(path, SKOS.closeMatch))
            code_html = " ".join('<a class="chip" href="%s">%s</a>' % (esc(c), esc(c.rsplit("/", 1)[-1].split("#")[-1]))
                                 for c in codes if c.startswith("http"))
            rows.append("<tr><td><code>%s</code></td><td class=\"num\">%s</td><td>%s</td><td class=\"small\">%s</td>"
                        "<td class=\"small\">%s</td><td>%s</td></tr>" % (
                            esc(name), card, ty, esc(shapes.value(p, SH.description) or ""), binding, code_html))
        msg = shapes.value(shape, SH.message)
        sname = str(shape).rsplit("/", 1)[1]
        shape_html.append(
            '<div class="section" id="shape-%s"><div class="section-head"><h3>%s</h3>'
            '<span class="small muted">%s · <a href="%s">logical model</a></span></div>'
            '<div class="table-wrap"><table><thead><tr><th>Element</th><th>Card.</th><th>Type</th><th>Meaning</th>'
            '<th>Binding</th><th>Concept codes</th></tr></thead><tbody>%s</tbody></table></div>%s</div>'
            % (sname, esc(label), "abstract" if abstract else "concrete",
               esc(str(target).replace("/StructureDefinition/", "/StructureDefinition-") + ".html"),
               "".join(rows),
               '<p class="small muted">Invariant: %s</p>' % esc(msg) if msg else ""))

    return """
<main class="page">
  <section class="section prose">
    <span class="eyebrow">Wire format and payload models</span>
    <h1>Wire &amp; payload models</h1>
    <p>The CBOR wire format is specified in CDDL (IETF RFC 8610). Payload models are derived mechanically from the
    WHO SMART FHIR logical models into a JSON-LD context, SHACL shapes and CDDL rules. Every example below is the
    Hepatitis B birth-dose certificate from smart-trust PR 129, which CI validates against all of these.</p>
    <div class="chips">
      <a class="chip" href="#cddl">CDDL</a><a class="chip" href="#example">CBOR example</a>
      <a class="chip" href="#jsonld">JSON-LD</a><a class="chip" href="#shacl">SHACL shapes</a>
      <a class="chip" href="explorer.html#grp-grp--models-logical">Logical models in the graph</a>
      <a class="chip" href="explorer.html#grp-grp--models-payload">Payload models in the graph</a>
    </div>
  </section>

  <section class="section" id="cddl">
    <div class="section-head"><h2>CDDL: HCERT envelope</h2><a class="small" href="%(env_src)s">api/cddl/hcert.cddl</a></div>
    <pre><code>%(env)s</code></pre>
    <div class="section-head"><h2>CDDL: payload rules, generated from the logical models</h2><a class="small" href="%(gen_src)s">models/generated/trust-phw.cddl</a></div>
    <pre><code>%(gen)s</code></pre>
  </section>

  <section class="section" id="example">
    <div class="section-head"><h2>CBOR example in diagnostic notation</h2>
      <a class="chip" href="%(cbor_me)s">Open the COSE bytes in cbor.me ↗</a></div>
    <p class="small muted">HC1 string (%(hc1_len)d characters), then the COSE_Sign1 with each embedded layer decoded
      (&lt;&lt; &gt;&gt; marks a byte string holding CBOR).</p>
    <pre><code>%(hc1)s</code></pre>
    <pre><code>%(cose)s</code></pre>
    <pre><code>%(claims)s</code></pre>
  </section>

  <section class="section" id="jsonld">
    <div class="section-head"><h2>JSON-LD: the payload as linked data</h2>
      <a class="chip" href="%(playground)s">Open in JSON-LD Playground ↗</a></div>
    <p class="small muted">Adding the generated context and a type to the payload's JSON view turns it into RDF.
      Each short element name expands to <code>&lt;StructureDefinition URL&gt;#&lt;element&gt;</code>.</p>
    <pre><code>%(doc)s</code></pre>
    <h3>Resulting triples (N-Triples)</h3>
    <pre><code>%(nquads)s</code></pre>
    <details><summary class="small">Generated context (<a href="%(ctx_src)s">trust-phw.context.jsonld</a>)</summary>
      <pre><code>%(ctx)s</code></pre></details>
  </section>

  <section class="section" id="shacl">
    <div class="section-head"><h2>SHACL shapes</h2><a class="small" href="%(shacl_src)s">trust-phw.shacl.ttl</a></div>
    <p class="small muted">Cardinality and FHIR primitive patterns are enforced; bindings are recorded (the PreQual
      value set has no published expansion); concept codes come from each element's <code>ElementDefinition.code</code>.
      To render or edit these shapes in a dedicated tool, load the TTL into
      <a href="https://shacl-play.sparna.fr/play/">SHACL Play!</a>.</p>
    %(shapes)s
  </section>
</main>""" % {
        "env": highlight_cddl(env, "cddl-"), "gen": highlight_cddl(gen, "cddl-"),
        "env_src": gh(ref, "api/cddl/hcert.cddl"), "gen_src": gh(ref, "models/generated/trust-phw.cddl"),
        "ctx_src": gh(ref, "models/generated/trust-phw.context.jsonld"),
        "shacl_src": gh(ref, "models/generated/trust-phw.shacl.ttl"),
        "cbor_me": esc(cbor_me), "playground": esc(playground),
        "hc1": esc(cert["hc1"]), "hc1_len": len(cert["hc1"]),
        "cose": esc(cose_diag), "claims": esc("/ CWT claims /\n" + diag(claims)),
        "doc": esc(json.dumps({"@context": "trust-phw.context.jsonld", "@type": "DVCMin", **payload},
                              indent=2, ensure_ascii=False)),
        "nquads": esc(nquads), "ctx": esc(json.dumps(ctx, indent=2)), "shapes": "".join(shape_html),
    }


KIND_SOURCES = [
    ("requirement", "skills/requirements/*.json", "bootstrap requirement (req:)"),
    ("section", "library/<entry>/sections/", "cat-harness library section"),
    ("document", "library/<entry>/, references/*.json, vectors/<set>/*", "library entry, folio-reference/v1, test vector (every file of a vector set but its SOURCE.yaml and README)"),
    ("standard", "external-schemas/*.json", "folio-external-schema/v1"),
    ("directive", "memory/dir-*.md", "folio-memory/v1"),
    ("upstream", "library/who-smart-trust-requirements-fsh", "smart-trust FHIR Requirements, as ingested"),
    ("skill", "skills/<package>/*.md", "skill with satisfies"),
    ("tool", "tools/<id>/<id>.ts", "cat-harness Tool (defineTool)"),
    ("process", "processes/*/*.bpmn", "BPMN process, tasks naming skills"),
    ("role", "scenarios/roles.json", "role graph"),
    ("api", "api/wit/*.wit, api/cddl/*.cddl", "WIT interface, world or item, or CDDL rule (hcert-contract typology)"),
    ("issue", "beans/defs/*.md", "bean"),
    ("test", "the files a skill's tested-by names", "a Kotlin test function named after the requirements it verifies, or a script"),
    ("test-plan", "test/plans/*.test-plan.json", "test-plan/v1 (cat-harness), shaped after FHIR R5 TestPlan"),
    ("model", "models/fhir/*.json, models/generated/*", "FHIR logical model (fhir-logical-models: an R5 StructureDefinition, or the R5 primitive patterns), or a payload model lm-derive writes from them (payload-models: JSON-LD context, SHACL shapes, CDDL)"),
]

REL_NOTES = [
    ("references", "requirement → source", "reference of the req: node (FHIR Requirements.reference): what it is drawn from"),
    ("satisfies", "requirement → smart-trust", "a smart-trust FHIR Requirements canonical in reference"),
    ("derivedFrom", "requirement → requirement; model or vector → library entry, standard, model or vector",
     "derivedFrom of the req: node (FHIR Requirements.derivedFrom): the broader requirement it narrows. For a model: the library entry whose FSH declares it, "
     "its baseDefinition, the FHIR core package it was taken from, or the directory declaration's derivedFrom (a payload model). For a vector: its "
     "SOURCE.yaml's derivedFrom, or the library entry its files: line names"),
    ("writes", "Tool → model or vector", "the directory declaration's writer (payload-models), or a vector set's SOURCE.yaml generator"),
    ("realizedBy", "requirement → skill", "the skill's satisfies"),
    ("implementedBy", "skill → Tool", "the Tool's satisfies"),
    ("usedIn", "skill → process", "a BPMN task's skill ref"),
    ("performedBy", "skill → role", "the role's skills"),
    ("constrainsApi", "requirement → WIT item or CDDL rule", "an [STT-…] tag in the item's comments"),
    ("affectedBy", "requirement → issue", "the bean's Requirements affected"),
    ("testedBy", "skill → test", "the skill's tested-by"),
    ("verifies", "test → requirement", "the requirement ids a test is named after"),
    ("assesses", "test plan → requirement", "an assertion id, a success criterion req:<id>#<statement>/<criterion>"),
    ("planCase", "test plan → skill", "a case named after the skill"),
    ("precededBy", "test plan → test plan", "a dependency's predecessor"),
    ("concerns", "issue → source", "the bean's Sources"),
    ("partOf", "section → entry, statement → requirement, item → interface or CDDL file", "structure"),
]


def kinds_page(ref, M, graph):
    counts = collections.Counter(n["kind"] for n in graph["nodes"])
    rels = collections.Counter(e["rel"] for e in graph["edges"])
    # The tables describe the kinds and edges kg_nodes draws; a kind or edge
    # added there and not described here fails the build rather than going unlisted.
    undescribed = (set(kg_nodes.FAMILY) ^ {k for k, _, _ in KIND_SOURCES}) | (set(rels) - {r for r, _, _ in REL_NOTES})
    if undescribed:
        raise ValueError("kinds.html does not describe: %s" % sorted(undescribed))
    krows = "".join('<tr><td>%s</td><td class="num">%d</td><td><code>%s</code></td><td class="small muted">%s</td></tr>'
                    % (esc(k), counts[k], esc(src), esc(what)) for k, src, what in KIND_SOURCES)
    rrows = "".join('<tr><td><code>%s</code></td><td class="num">%d</td><td>%s</td><td class="small muted">%s</td></tr>'
                    % (esc(r), rels[r], esc(dom), esc(how)) for r, dom, how in REL_NOTES)
    return """
<main class="page">
  <section class="section prose">
    <span class="eyebrow">Requirements knowledge graph</span>
    <h1>Node kinds</h1>
    <p>The graph the explorer and the matrix draw is read from this instance's cat-harness nodes, nothing else. Each
    kind below is a directory declared in <a href="%(decl)s">smart-trust-tools.json</a>, and each edge is a field of
    one of those nodes. <code>tools/check-req-nodes</code> fails the build if any edge names no node.</p>
  </section>
  <section class="section"><h2>Kinds</h2>
    <div class="table-wrap"><table><thead><tr><th>Kind</th><th>Nodes</th><th>Read from</th><th>Node type</th></tr></thead><tbody>%(k)s</tbody></table></div></section>
  <section class="section"><h2>Edges</h2>
    <div class="table-wrap"><table><thead><tr><th>Edge</th><th>Count</th><th>From → to</th><th>Field</th></tr></thead><tbody>%(r)s</tbody></table></div></section>
  <section class="section"><h2>Data</h2>
    <p class="small">The whole graph as JSON: <a href="data/graph.json">data/graph.json</a>.</p></section>
</main>""" % {"decl": gh(ref, "smart-trust-tools.json"), "k": krows, "r": rrows}


def index_page(ref, M, graph):
    reqs = list(M["reqs"].values())
    conf = collections.Counter(r["conformance"] for r in reqs)
    issues = list(M["beans"].values())
    upstream_issues = sum(1 for i in issues if i.get("upstream"))
    steps = [n for n in graph["nodes"] if n["kind"] == "skill" and n["order"] < 100]
    steps.sort(key=lambda n: n["order"])
    step_items = "".join(
        '<li><a href="explorer.html#%s"><span class="step-n num">%d</span><span>%s</span></a></li>'
        % (esc(n["id"]), n["order"], esc(n["label"])) for n in steps)
    stmts = [n for n in graph["nodes"] if n["kind"] == "upstream" and n.get("parent")]
    sat = {e["t"] for e in graph["edges"] if e["rel"] == "satisfies"}
    covered = sum(1 for n in stmts if n["id"] in sat)
    prov = "".join('<li><a href="%s/tree/%s">%s</a> <code>%s</code>%s</li>' % (
        esc(x["repository"]), x["commit"], esc(x["repository"].split("github.com/")[-1]), x["commit"][:12],
        ' <span class="muted">(%s)</span>' % esc(x["ref"]) if x.get("ref") else "") for x in kg_nodes.provenance(M["entries"]))
    issue_rows = "".join(
        '<li><a href="explorer.html#%s"><span class="issue-mark">%s</span></a> %s%s</li>'
        % (i["id"], i["id"], esc(i["title"]), ' <span class="chip">fix upstream</span>' if i.get("upstream") else "")
        for i in issues)
    return """
<main class="page landing">
  <section class="hero">
    <div class="hero-text">
      <span class="eyebrow">WHO SMART Trust · HCERT libraries · Kotlin first, Rust second</span>
      <h1>From the QR Code Generation spec to a library you can build</h1>
      <p class="lede">Requirements, API contract, wire format and payload models for the Kotlin (JVM, Android, Node)
      and Rust (WebAssembly) HCERT libraries. Everything here is derived from, and links back to, the
      <a href="https://github.com/WorldHealthOrganization/smart-trust/pull/129">smart-trust QR Code Generation page (PR 129)</a>
      and the deployed WHO SMART Trust specifications.</p>
    </div>
    <dl class="facts">
      <div><dt>Requirements</dt><dd class="num">%(nreq)d</dd><span class="small muted">%(conf)s</span></div>
      <div><dt>smart-trust statements cited</dt><dd class="num">%(cov)d/%(nup)d</dd><span class="small muted">FHIR Requirements</span></div>
      <div><dt>Open issues</dt><dd class="num">%(niss)d</dd><span class="small muted">%(upiss)d to fix upstream</span></div>
    </dl>
  </section>

  <section class="section">
    <div class="section-head"><h2>The HCERT pipeline</h2><span class="small muted">One skill per step; each opens its requirements, Tool and processes in the explorer</span></div>
    <ol class="pipeline">%(steps)s</ol>
  </section>

  <section class="section">
    <h2>Viewers</h2>
    <div class="viewer-grid">
      <a class="viewer" href="explorer.html"><span class="eyebrow">Knowledge graph</span><h3>Graph explorer</h3>
        <p>Every requirement with its sources, smart-trust parents, skills, Tools, processes, contract items (WIT, CDDL) and open issues,
        and the FHIR logical models with the payload models derived from them.
        Filter, search and focus on a neighbourhood.</p>
        <span class="legend"><i style="background:var(--fam-requirement)"></i>requirement <i style="background:var(--fam-source)"></i>source <i style="background:var(--fam-realization)"></i>skill, Tool, process, contract <i style="background:var(--fam-model)"></i>model <i style="background:var(--status-warning)"></i>issue</span></a>
      <a class="viewer" href="trace.html"><span class="eyebrow">Review</span><h3>Traceability matrix</h3>
        <p>One row per requirement: what it satisfies upstream, which skill realizes it and which WIT item or CDDL rule it shapes, how it is tested,
        and what is still open. Filter by area, conformance or gaps.</p></a>
      <a class="viewer" href="requirements.html"><span class="eyebrow">Document</span><h3>Requirements</h3>
        <p>The full requirement set as a document, each requirement with its source quotes and every edge of the graph.</p></a>
      <a class="viewer" href="api.html"><span class="eyebrow">Library API · WIT</span><h3>API contract</h3>
        <p>The WIT package that both libraries implement, with requirement tags linked and the deployable worlds
        summarised.</p></a>
      <a class="viewer" href="api/typedoc/index.html"><span class="eyebrow">Library API · TypeScript</span><h3>API reference</h3>
        <p>The same API as Node and browser callers see it, generated by jco and TypeDoc.</p></a>
      <a class="viewer" href="kotlin.html"><span class="eyebrow">Library API · Kotlin</span><h3>Kotlin API</h3>
        <p>The Kotlin Multiplatform interfaces and types generated from the WIT, ready to implement for JVM, Android and Node.</p></a>
      <a class="viewer" href="models.html"><span class="eyebrow">Wire format · payload models</span><h3>CDDL, JSON-LD, SHACL</h3>
        <p>The CBOR envelope, payload rules derived from the FHIR logical models, and the PR 129 certificate decoded
        layer by layer.</p></a>
      <a class="viewer" href="kinds.html"><span class="eyebrow">Knowledge graph</span><h3>Node kinds</h3>
        <p>Which cat-harness nodes the graph is read from, and the field each edge comes from.</p></a>
    </div>
  </section>

  <section class="section two-col">
    <div class="section">
      <h2>External tools, prefilled</h2>
      <ul class="tool-list">
        <li><a href="models.html#jsonld">JSON-LD Playground</a> <span class="muted small">the DVC payload expanded to triples</span></li>
        <li><a href="models.html#example">cbor.me</a> <span class="muted small">the COSE_Sign1 bytes of the example certificate</span></li>
        <li><a href="https://shacl-play.sparna.fr/play/">SHACL Play!</a> <span class="muted small">load <a href="%(shacl)s">trust-phw.shacl.ttl</a></span></li>
        <li><a href="https://smart.who.int/trust/">WHO SMART Trust IG</a> <span class="muted small">published specification</span></li>
      </ul>
      <h2>Provenance</h2>
      <p class="small muted">The upstream commits the library pins:</p>
      <ul class="tool-list small">
        %(prov)s
        <li>Built from <a href="https://github.com/%(repo)s/tree/%(ref)s">%(repo)s@%(ref)s</a></li>
      </ul>
    </div>
    <div class="section">
      <h2>Open issues</h2>
      <ul class="issue-list small">%(issues)s</ul>
    </div>
  </section>
</main>""" % {
        "nreq": len(reqs), "conf": ", ".join("%d %s" % (conf[c], c) for c in ("SHALL", "SHOULD", "MAY", "SHALL NOT") if conf[c]),
        "cov": covered, "nup": len(stmts), "niss": len(issues), "upiss": upstream_issues,
        "steps": step_items, "issues": issue_rows, "shacl": gh(ref, "models/generated/trust-phw.shacl.ttl"),
        "prov": prov, "repo": REPO, "ref": esc(ref),
    }


LANDING_CSS = """
<style>
.landing .hero { display: grid; grid-template-columns: minmax(0, 1.6fr) minmax(0, 1fr); gap: 28px; align-items: end; padding-block: 8px 4px; }
.landing .hero-text { display: grid; gap: 12px; }
.landing .lede { font-size: var(--step-1); color: var(--fg-2); max-width: 62ch; margin: 0; }
.facts { display: grid; gap: 10px; margin: 0; }
.facts div { display: grid; grid-template-columns: 1fr auto; align-items: baseline; gap: 0 12px; border-top: 1px solid var(--line); padding-top: 8px; }
.facts dt { color: var(--fg-2); font-size: var(--step--1); }
.facts dd { margin: 0; font-family: var(--font-display); font-size: var(--step-2); font-weight: 700; grid-row: span 2; }
.pipeline { list-style: none; margin: 0; padding: 0; display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 112px), 1fr)); gap: 6px; }
.pipeline a { display: grid; grid-template-columns: auto 1fr; gap: 8px; align-items: center; text-decoration: none; color: var(--fg); background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); padding: 8px 10px; font-size: var(--step--1); height: 100%; }
.pipeline a:hover { border-color: var(--fam-realization); }
.step-n { font-family: var(--font-mono); font-weight: 600; color: var(--accent); }
.viewer-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 320px), 1fr)); gap: 12px; }
.viewer { display: grid; gap: 6px; align-content: start; text-decoration: none; color: var(--fg); background: var(--surface); border: 1px solid var(--line); border-radius: var(--radius); padding: 14px 16px; }
.viewer:hover { border-color: var(--accent); }
.viewer p { margin: 0; color: var(--fg-2); font-size: var(--step--1); }
.legend { display: flex; flex-wrap: wrap; gap: 4px 10px; align-items: center; font-size: 0.75rem; color: var(--fg-2); }
.legend i { width: 9px; height: 9px; border-radius: 2px; display: inline-block; margin-right: -6px; }
.two-col { grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 28px; }
.tool-list, .issue-list { margin: 0; padding-left: 1.1em; display: grid; gap: 5px; }
.issue-list { list-style: none; padding-left: 0; }
@media (max-width: 760px) { .landing .hero, .two-col { grid-template-columns: 1fr; } }
</style>
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--git-ref", default=None)
    ap.add_argument("--out", default=str(ROOT / "site"))
    args = ap.parse_args()
    ref = args.git_ref or subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--abbrev-ref", "HEAD"],
                                         capture_output=True, text=True).stdout.strip() or "main"
    out = pathlib.Path(args.out)

    M = kg_nodes.load()
    graph = kg_nodes.build_graph(M)

    if out.exists():
        for child in out.iterdir():
            if child.name != "api":
                shutil.rmtree(child) if child.is_dir() else child.unlink()
    (out / "data").mkdir(parents=True, exist_ok=True)
    shutil.copytree(HERE / "site" / "assets", out / "assets", dirs_exist_ok=True)
    (out / ".nojekyll").write_text("")  # serve TypeDoc's files as-is
    (out / "data" / "graph.json").write_text(json.dumps(graph, ensure_ascii=False, separators=(",", ":")))

    pages = {
        "explorer.html": ("Graph Explorer", (HERE / "site" / "explorer.body.html").read_text(),
                          ["assets/vendor/cytoscape.min.js", "assets/common.js", "assets/explorer.js"]),
        "trace.html": ("Traceability Matrix", (HERE / "site" / "trace.body.html").read_text(),
                       ["assets/common.js", "assets/trace.js"]),
        "requirements.html": ("HCERT Library Requirements", requirements_page(ref, M, graph), []),
        "api.html": ("HCERT API Contract", api_page(ref, M), []),
        "models.html": ("HCERT Wire and Payload Models", models_page(ref, M), []),
        "kinds.html": ("Requirements Graph Node Kinds", kinds_page(ref, M, graph), []),
        "kotlin.html": ("Kotlin API", kotlin_page(ref), []),
    }
    for name, (title, body, scripts) in pages.items():
        (out / name).write_text(shell(name, title, body, ref, scripts))
    landing = index_page(ref, M, graph)
    (out / "index.html").write_text(shell("index.html", "SMART Trust Tools", landing, ref, head_extra=LANDING_CSS))
    print("wrote site to %s (%d graph nodes, %d edges)" % (out, len(graph["nodes"]), len(graph["edges"])))
    return 0


if __name__ == "__main__":
    sys.exit(main())
