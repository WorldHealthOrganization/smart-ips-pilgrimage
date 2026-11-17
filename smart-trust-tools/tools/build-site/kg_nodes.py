"""Read this instance's cat-harness nodes into the graph the viewers draw.

Every node and edge here is read from a committed node, never restated:

  requirement   skills/requirements/*.json (bootstrap RequirementSchema)
  section       a library entry's sections (library/<slug>/structure.json)
  document      a library entry, a reference (references/*.json), a test vector
  standard      an external schema (external-schemas/*.json)
  directive     an owner directive (memory/dir-*.md)
  upstream      a smart-trust FHIR Requirements instance or statement, read
                from the ingested Requirements.fsh
  skill         skills/<package>/*.md (front matter `satisfies`)
  tool          tools/<id>/<id>.ts (`satisfies`), read through `bun`
  process       processes/**/*.bpmn (tasks naming skills)
  role          scenarios/roles.json (a role's skills)
  api           an item of the contract (hcert-contract typology): a WIT
                interface, world or item (api/wit/*.wit), or a CDDL rule of the
                wire format (api/cddl/*.cddl), with the [STT-...] tags its
                comments carry
  issue         beans/defs/*.md (Requirements affected, Sources)
  test          a test a skill's `tested-by:` names: each Kotlin test function
                (named `STT-XXX-nnn ...` after the requirements it verifies),
                or a whole script for any other file
  test-plan     test/plans/*.test-plan.json (test-plan/v1), whose assertion
                ids are requirement statements' success criteria
  model         a FHIR logical model (models/fhir/, fhir-logical-models) or a
                payload model derived from them (models/generated/,
                payload-models)

Edges, named as the harness names the fields they come from (FHIR R5
Requirements): references (a requirement's `reference`, what it is drawn
from), satisfies (a smart-trust canonical in `reference`), derivedFrom (its
`derivedFrom`, the broader requirement it narrows),
realizedBy (requirement to skill), constrainsApi, affectedBy, concerns,
partOf, implementedBy (skill to Tool), usedIn (skill to process),
performedBy (skill to role), testedBy (skill to test), verifies (test to
requirement), assesses (test plan to requirement, through an assertion on
one of its success criteria), planCase (test plan to the skill a case is
named after), precededBy (test plan to the plan that must pass first),
derivedFrom (also: a model or vector to the library entry, standard, model or
vector it was compiled, derived or taken from), writes (Tool to the model or
vector it writes: a directory's `writer`, a vector set's `generator`).
A requirement's success criteria are data on its node.

Read from nodes too, not restated here: the requirement areas and their
titles (code-lists/requirement-area.json, folio-code-list/v1), the order of
the pipeline's skills (the sequence flows of the issuance and verification
processes), a library entry's short label (the CSL `title-short` of the
reference held at it) and its explorer group (its upstream repository, when
it was ingested from FSH).
"""

import collections
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
UPSTREAM = "http://smart.who.int/trust/Requirements/"
UPSTREAM_SITE = "https://smart.who.int/trust"

# The two processes whose tasks, in sequence-flow order, are the HCERT
# pipeline's skills: QR Code Generation steps 1 to 9, then verification.
PIPELINE_PROCESSES = ("hcert-issuance", "hcert-verification")

STT_TAG = re.compile(r"STT-[A-Z0-9]+-\d{3}")


def front_matter(text):
    """The YAML front matter of a Markdown node, parsed for the few shapes nodes here use."""
    import yaml
    m = re.match(r"^---\n(.*?)\n---\n?(.*)$", text, flags=re.S)
    return (yaml.safe_load(m.group(1)) or {}, m.group(2)) if m else ({}, text)


def load_areas():
    """The requirement areas, in reading order, from the requirement-area code list:
    {"GEN": "Scope, architecture and language strategy", ...}."""
    d = json.loads((ROOT / "code-lists" / "requirement-area.json").read_text())
    return collections.OrderedDict((c["code"].upper(), c["label"]) for c in d["codes"] if c.get("status") != "retired")


def load_pipeline():
    """The skills of the HCERT pipeline, in order: each process of PIPELINE_PROCESSES
    walked along its sequence flows from its start event, each task's skill taken
    the first time it is reached."""
    order = []
    for name in PIPELINE_PROCESSES:
        x = (ROOT / "processes" / "content" / (name + ".bpmn")).read_text()
        flows = dict(re.findall(r'<bpmn:sequenceFlow id="[^"]+" sourceRef="([^"]+)" targetRef="([^"]+)"', x))
        skill = {}
        for m in re.finditer(r'<bpmn:(\w*[tT]ask) id="([^"]+)"[^>]*>(.*?)</bpmn:\1>', x, flags=re.S):
            r = re.search(r'<bootstrap\.processes:skill ref="([^"]+)"', m.group(3))
            if r:
                skill[m.group(2)] = r.group(1)
        node, seen = re.search(r'<bpmn:startEvent id="([^"]+)"', x).group(1), set()
        while node in flows and node not in seen:
            seen.add(node)
            node = flows[node]
            if node in skill and skill[node] not in order:
                order.append(skill[node])
    return order


def load_short_titles():
    """Short labels of library entries: the CSL `title-short` of the reference
    (references/*.json, folio-reference/v1) whose `heldAt` is the entry."""
    out = {}
    for f in sorted((ROOT / "references").glob("*.json")):
        d = json.loads(f.read_text())
        if d.get("heldAt", "").startswith("library/") and d.get("title-short"):
            out[d["heldAt"][len("library/"):]] = d["title-short"]
    return out


def doc_group(repo, path):
    """The explorer group of a library entry ingested from FSH: one per upstream
    repository (its FSH logical models, profiles, Requirements, ActorDefinitions),
    read from the entry's upstream path. Other entries are a group of their own."""
    if repo and (path or "").startswith("input/fsh/"):
        name = repo.rstrip("/").rsplit("/", 1)[-1]
        return "grp:fsh-" + name.lower().replace(".", "-"), name + " FSH sources"
    return None, None


def display_id(req_id):
    """req:stt-cos-002 -> STT-COS-002, the id the IG and the WIT comments use."""
    return req_id[len("req:"):].upper()


def load_library():
    entries, sections = {}, {}
    short = load_short_titles()
    for st in sorted((ROOT / "library").glob("*/structure.json")):
        d = json.loads(st.read_text())
        slug = d["doc_id"]
        up = d["source"].get("upstream", {})
        repo = up.get("repository", "").rstrip("/")
        pinned = "%s/blob/%s/%s" % (repo, up["commit"], up["path"]) if repo and up.get("commit") else None
        eid = "library/" + slug
        entries[eid] = {
            "slug": slug, "title": d["metadata"].get("title") or slug, "short": short.get(slug),
            "group": doc_group(repo, up.get("path")),
            "urls": {k: v for k, v in (("pinned", pinned), ("published", up.get("published"))) if v},
            "repository": repo, "commit": up.get("commit"), "ref": up.get("ref"), "path": up.get("path"),
        }
        for s in d["sections"]:
            urls = {}
            if pinned:
                urls["pinned"] = pinned + ("#L%d-L%d" % (s["line_start"], s["line_end"]) if s.get("line_start") else "")
            if up.get("published"):
                urls["published"] = up["published"]
            sections["%s/sections/%s" % (eid, s["id"])] = {"entry": eid, "heading": s["title"], "urls": urls}
    return entries, sections


def section_label(entries, sec):
    e = entries[sec["entry"]]
    short = e["short"] or e["title"][:24]
    m = re.match(r"^(\d+(?:\.\d+)*|[A-Z](?:\.\d+)?)\.?\s", sec["heading"])
    if m:
        return "%s §%s" % (short, m.group(1))
    m = re.match(r"^(\d+:\d+(?:\.[A-Z0-9]+)+)\s", sec["heading"])
    if m:
        return "%s %s" % (short, m.group(1))
    return "%s: %s" % (short, sec["heading"][:28])


def load_upstream():
    """smart-trust FHIR Requirements: {instance: {title, statements: {key: label}}}."""
    out = collections.OrderedDict()
    for f in sorted((ROOT / "library" / "who-smart-trust-requirements-fsh" / "sections").glob("*.md")):
        cur, key = None, None
        for line in f.read_text().split("\n"):
            m = re.match(r"^Instance:\s+(\S+)", line)
            if m:
                cur = out.setdefault(m.group(1), {"title": m.group(1), "statements": collections.OrderedDict()})
                continue
            m = re.match(r'^\* title = "([^"]+)"', line)
            if m and cur:
                cur["title"] = m.group(1)
            m = re.match(r'^\* statement\[\+\]\.key = "([^"]+)"', line)
            if m and cur:
                key = m.group(1)
                cur["statements"][key] = key
            m = re.match(r'^\* statement\[=\]\.label = "([^"]+)"', line)
            if m and cur and key:
                cur["statements"][key] = m.group(1)
    return out


def load_requirements():
    reqs = collections.OrderedDict()
    for p in sorted((ROOT / "skills" / "requirements").glob("*.json")):
        n = json.loads(p.read_text())
        st = n["statements"][0]
        tags = n.get("tags", [])
        reqs[n["id"]] = {
            "id": display_id(n["id"]), "iri": n["id"], "title": n["title"], "description": n.get("description", ""),
            "statement": " ".join(st["requirement"].split()), "conformance": st["conformance"],
            "category": st.get("category", ""), "actors": n.get("actors", []),
            "derivation": next((t for t in tags if t in ("direct", "derived", "directive")), ""),
            "targets": [t.split(":", 1)[1] for t in tags if t.startswith("target:")] or ["kotlin", "rust"],
            "derivedFrom": n.get("derivedFrom", []), "reference": n.get("reference", []),
            "criteria": [dict(statement=s["key"], **c) for s in n["statements"] for c in s.get("successCriteria", [])],
            "area": display_id(n["id"]).split("-")[1], "file": p.relative_to(ROOT).as_posix(),
        }
    return reqs


def load_skills():
    skills = collections.OrderedDict()
    for pkg in sorted(p for p in (ROOT / "skills").iterdir() if p.is_dir() and p.name != "requirements"):
        for f in sorted(pkg.glob("*.md")):
            fm, _ = front_matter(f.read_text())
            skills[fm["name"]] = {
                "name": fm["name"], "package": pkg.name, "description": " ".join(str(fm.get("description", "")).split()),
                "satisfies": [s.split("#")[0] for s in fm.get("satisfies", [])], "file": f.relative_to(ROOT).as_posix(),
                "testedBy": list(fm.get("tested-by") or []),
            }
    return skills


KOTLIN_TEST = re.compile(r"@Test\s+fun\s+`([^`]+)`")
RUST_TEST = re.compile(r"#\[test\]\s*fn\s+(stt_[a-z0-9_]+)\s*\(")
RUST_ID = re.compile(r"stt_([a-z0-9]+)_(\d{3})_")


def rust_test_name(fn):
    """`stt_tst_001_stt_kid_001_the_kid` -> `STT-TST-001 STT-KID-001 the kid`."""
    head = ""
    while (m := RUST_ID.match(fn)):
        head += "STT-%s-%s " % (m.group(1).upper(), m.group(2))
        fn = fn[m.end():]
    return head + fn.replace("_", " ")


def test_names(path, text):
    if path.endswith(".kt"):
        return KOTLIN_TEST.findall(text)
    if path.endswith(".rs"):
        return [rust_test_name(f) for f in RUST_TEST.findall(text)]
    return []


def load_tests(skills):
    """The tests the skills' `tested-by:` name: {id: {name, file, reqs, skills}}."""
    tests = collections.OrderedDict()
    for s in skills.values():
        for path in s["testedBy"]:
            text = (ROOT / path).read_text()
            found = test_names(path, text)
            for name in found or [None]:
                tid = "test:%s::%s" % (pathlib.Path(path).name, name) if name else "test:" + path
                t = tests.setdefault(tid, {
                    "name": name or pathlib.Path(path).name, "file": path, "skills": [],
                    "reqs": sorted(set(STT_TAG.findall(name if name else text))),
                })
                t["skills"].append(s["name"])
    return tests


def load_tools():
    script = ('import {tools} from "./tools/index.ts"; console.log(JSON.stringify(tools().map(t => '
              '({id: t.id, title: t.title, description: t.description, satisfies: t.satisfies}))))')
    out = subprocess.run(["bun", "-e", script], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    return collections.OrderedDict((t["id"], t) for t in json.loads(out))


def load_processes():
    procs = collections.OrderedDict()
    for f in sorted((ROOT / "processes").glob("*/*.bpmn")):
        x = f.read_text()
        m = re.search(r'<bpmn:process id="([^"]+)" name="([^"]+)"', x)
        doc = re.search(r"<bpmn:documentation>(.*?)</bpmn:documentation>", x, flags=re.S)
        procs[f.stem] = {
            "id": f.stem, "name": m.group(2) if m else f.stem, "file": f.relative_to(ROOT).as_posix(),
            "doc": " ".join(doc.group(1).split()) if doc else "",
            "skills": sorted(set(re.findall(r'<bootstrap\.processes:skill ref="([^"]+)"', x))),
        }
    return procs


def load_roles():
    return json.loads((ROOT / "scenarios" / "roles.json").read_text())["roles"]


def load_beans():
    beans = collections.OrderedDict()
    for f in sorted((ROOT / "beans" / "defs").glob("*.md")):
        fm, body = front_matter(f.read_text())
        parts = re.split(r"^## ", body, flags=re.M)
        text = parts[0].strip()
        sec = {p.split("\n", 1)[0].strip(): p.split("\n", 1)[1] if "\n" in p else "" for p in parts[1:]}
        refs = lambda k: re.findall(r"^- (\S+)", sec.get(k, ""), flags=re.M)
        m = re.match(r"^(OI-\d+):\s*(.*)$", fm.get("title", ""))
        beans[f.name] = {
            "id": m.group(1) if m else f.stem, "title": m.group(2) if m else fm.get("title", f.stem),
            "text": " ".join(text.split()), "hint": " ".join(sec.get("Resolution", "").split()),
            "upstream": "upstream" in (fm.get("tags") or []), "status": fm.get("status"),
            "requirements": refs("Requirements affected"), "sources": refs("Sources"),
            "file": f.relative_to(ROOT).as_posix(),
        }
    return beans


def load_wit():
    """Items of the WIT contract: {wit:iface.item: {...}}, with the [STT-...] tags of each doc comment."""
    items = collections.OrderedDict()
    for f in sorted((ROOT / "api" / "wit").glob("*.wit")):
        iface, doc = None, []
        for line in f.read_text().split("\n"):
            s = line.strip()
            if s.startswith("//"):
                doc.append(s)
                continue
            m = re.match(r"^(interface|world)\s+([a-z0-9-]+)", s)
            if m:
                iface = m.group(2)
                key = "wit:" + iface
                items[key] = {"module": iface, "name": iface, "kind": m.group(1), "file": f.name,
                              "tags": sorted(set(STT_TAG.findall(" ".join(doc)))), "doc": doc}
                doc = []
                continue
            m = (re.match(r"^(record|variant|enum|flags|resource|type)\s+([a-z0-9-]+)", s)
                 or re.match(r"^()([a-z0-9-]+):\s*(?:static\s+)?func\b", s))
            if m and iface:
                key = "wit:%s.%s" % (iface, m.group(2))
                if key not in items:
                    items[key] = {"module": iface, "name": m.group(2), "kind": m.group(1) or "func", "file": f.name,
                                  "tags": sorted(set(STT_TAG.findall(" ".join(doc)))), "doc": doc}
            if s and not s.startswith("//"):
                doc = []
    for v in items.values():
        v["qname"] = "%s.%s" % (v["module"], v["name"]) if v["name"] != v["module"] else v["module"]
        v["lang"] = "WIT"
        v["text"] = " ".join(re.sub(r"^///?\s?", "", d) for d in v.pop("doc"))
    return items


CDDL_RULE = re.compile(r"^([a-z][a-z0-9-]*)\s*=")


def load_cddl():
    """Rules of the wire format: {cddl:file.rule: {...}}, with the [STT-...] tags of the
    comment block before each rule and of the comments inside it."""
    items = collections.OrderedDict()
    for f in sorted((ROOT / "api" / "cddl").glob("*.cddl")):
        module = f.name
        items["cddl:" + f.stem] = {"module": module, "name": module, "kind": "cddl file", "file": f.name,
                                   "lang": "CDDL", "tags": [], "text": "", "parent": f.stem}
        doc, cur = [], None
        for line in f.read_text().split("\n"):
            code, _, comment = line.partition(";")
            if not line.strip():
                doc, cur = [], None
                continue
            m = CDDL_RULE.match(code)
            if m:
                text = " ".join(doc) or comment.strip()
                cur = items.setdefault("cddl:%s.%s" % (f.stem, m.group(1)), {
                    "module": module, "name": m.group(1), "kind": "cddl rule", "file": f.name, "lang": "CDDL",
                    "tags": STT_TAG.findall(text), "text": text, "parent": f.stem})
                doc = []
            if cur is not None:
                cur["tags"] += STT_TAG.findall(comment)
            elif not code.strip():
                doc.append(comment.strip())
    for v in items.values():
        v["tags"] = sorted(set(v["tags"]))
        v["qname"] = "%s %s" % (v["module"], v["name"]) if v["name"] != v["module"] else v["module"]
    return items


def provenance(entries):
    """The upstream commits the library pins, one line per repository and ref."""
    seen = collections.OrderedDict()
    for e in entries.values():
        if e["repository"] and e["commit"]:
            seen.setdefault((e["repository"], e["commit"]), e["ref"])
    return [{"repository": r, "commit": c, "ref": ref} for (r, c), ref in seen.items()]


def load_plans():
    plans = collections.OrderedDict()
    for f in sorted((ROOT / "test" / "plans").glob("*.test-plan.json")):
        p = json.loads(f.read_text())
        p["file"] = f.relative_to(ROOT).as_posix()
        plans[p["id"]] = p
    return plans


def declared_dirs():
    """This instance's directory declarations (smart-trust-tools.json), by id."""
    d = json.loads((ROOT / "smart-trust-tools.json").read_text())
    return {x["id"]: x for x in d["directories"]}


def dirs_of(typology):
    return [x for x in declared_dirs().values() if typology in x.get("graphTypologies", [])]


# The format of a derived payload model, by suffix: how the viewer names it.
PAYLOAD_FORMAT = {".jsonld": "JSON-LD context", ".ttl": "SHACL shapes", ".cddl": "CDDL rules"}


def load_models(entries):
    """The FHIR logical models and the payload models derived from them.

    Logical models: each file of a fhir-logical-models directory. A
    StructureDefinition is matched to the library entry whose ingested FSH
    declares it (`Logical:` or `Profile:` <name>), in the repository the
    directory's SOURCE.yaml names, and to its baseDefinition when that is a
    model here too. The R5 primitive patterns are matched to the external
    schema of the FHIR core package they were taken from.

    Payload models: each file of a payload-models directory, derived from
    every file of the directories its declaration's `derivedFrom` names and
    written by the Tool its `writer` lies in.
    """
    import yaml
    models = collections.OrderedDict()
    decl = declared_dirs()
    declares = {}
    for eid, e in entries.items():
        for sec in sorted((ROOT / eid / "sections").glob("*.md")):
            for name in re.findall(r"^(?:Logical|Profile):\s+(\S+)", sec.read_text(), flags=re.M):
                declares.setdefault((e["repository"], name), eid)
    by_dir = collections.defaultdict(list)
    for d in dirs_of("fhir-logical-models"):
        base = ROOT / d["path"]
        src = yaml.safe_load((base / "SOURCE.yaml").read_text()) if (base / "SOURCE.yaml").exists() else {}
        repo = "https://github.com/" + src.get("logical_models", {}).get("repo", "")
        pkg = src.get("primitives", {}).get("package", "")
        for f in sorted(base.glob("*.json")):
            rel = f.relative_to(ROOT).as_posix()
            j = json.loads(f.read_text())
            by_dir[d["id"]].append(rel)
            if j.get("resourceType") == "StructureDefinition":
                models[rel] = {"kind": "logical", "label": j["name"], "title": j.get("title") or j["name"], "url": j.get("url"),
                               "file": rel, "fhirVersion": j.get("fhirVersion"), "abstract": j.get("abstract"),
                               "entry": declares.get((repo, j["name"])), "base": j.get("baseDefinition"), "derivedFrom": []}
            else:
                version = pkg.partition("#")[2]
                std = next((x for x in sorted((ROOT / "external-schemas").glob("hl7-fhir-*.json"))
                            if version and json.loads(x.read_text()).get("version") == version), None)
                models[rel] = {"kind": "primitives", "label": f.stem, "title": "FHIR primitive patterns (%s)" % pkg, "file": rel,
                               "standard": std.relative_to(ROOT).with_suffix("").as_posix() if std else None, "derivedFrom": []}
    urls = {m["url"]: k for k, m in models.items() if m.get("url")}
    for m in models.values():
        if m.get("base") in urls:
            m["derivedFrom"].append(urls[m["base"]])
    for d in dirs_of("payload-models"):
        writer = [w.split("/")[1] for w in d.get("writer", []) if w.startswith("tools/")]
        for f in sorted((ROOT / d["path"]).iterdir()):
            if f.suffix not in PAYLOAD_FORMAT:
                continue
            rel = f.relative_to(ROOT).as_posix()
            models[rel] = {"kind": "payload", "label": f.name, "title": "%s (%s)" % (PAYLOAD_FORMAT[f.suffix], f.name), "file": rel,
                           "derivedFrom": [x for src in d.get("derivedFrom", []) if src in decl for x in by_dir[src]],
                           "writtenBy": writer}
    return models


def load_vectors(entries):
    """Every test vector file (hcert-test-vectors directories), with what its set's
    SOURCE.yaml says of it: the vector it is derived from (`derivedFrom`), the
    Tool that writes it (`generator`), and the library entry it was taken from
    (its `files:` line starting with that entry's upstream path in `repo`)."""
    import yaml
    vecs = collections.OrderedDict()
    by_path = {(e["repository"], up_path): eid for eid, e in entries.items() for up_path in [e.get("path")] if up_path}
    for d in dirs_of("hcert-test-vectors"):
        for sdir in sorted(p for p in (ROOT / d["path"]).iterdir() if p.is_dir()):
            src = yaml.safe_load((sdir / "SOURCE.yaml").read_text()) if (sdir / "SOURCE.yaml").exists() else {}
            repo = "https://github.com/" + src["repo"] if src.get("repo") else ""
            gen = src.get("generator", "")
            for f in sorted(sdir.iterdir()):
                if f.name in ("SOURCE.yaml", "README.md") or not f.is_file():
                    continue
                line = str((src.get("files") or {}).get(f.name, "")).strip()
                entry = next((eid for (r, up), eid in by_path.items() if r == repo and line.startswith(up)), None)
                vecs[f.relative_to(ROOT).as_posix()] = {
                    "derivedFrom": [src["derivedFrom"]] if src.get("derivedFrom") else [],
                    "writtenBy": [gen.split("/")[1]] if gen.startswith("tools/") else [],
                    "entry": entry,
                }
    return vecs


def load(with_tools=True):
    """The nodes. Without Tools when the harness is not mounted (CI): tools/index.ts imports it."""
    entries, sections = load_library()
    skills = load_skills()
    return {
        "areas": load_areas(), "pipeline": load_pipeline(),
        "entries": entries, "sections": sections, "upstream": load_upstream(), "reqs": load_requirements(),
        "skills": skills, "tests": load_tests(skills), "tools": load_tools() if with_tools else {}, "processes": load_processes(),
        "roles": load_roles(), "beans": load_beans(), "wit": load_wit(), "cddl": load_cddl(), "plans": load_plans(),
        "models": load_models(entries), "vectors": load_vectors(entries),
    }


FAMILY = {
    "requirement": "requirement",
    "section": "source", "document": "source", "standard": "source", "directive": "source", "upstream": "source",
    "skill": "realization", "api": "realization", "tool": "realization", "process": "realization", "role": "realization",
    "test": "realization", "test-plan": "realization",
    "model": "model",
    "issue": "issue",
}


def build_graph(M):
    nodes = collections.OrderedDict()
    edges = []
    reqs_by_display = {r["id"]: r for r in M["reqs"].values()}

    def add(nid, kind, label, title, **kw):
        if nid not in nodes:
            nodes[nid] = dict(id=nid, kind=kind, fam=FAMILY[kind], label=label, title=title, **kw)
        return nodes[nid]

    def edge(s, t, rel, **kw):
        edges.append(dict(s=s, t=t, rel=rel, **kw))

    def add_upstream(inst, key=None):
        u = M["upstream"][inst]
        url = {"published": "%s/Requirements-%s.html" % (UPSTREAM_SITE, inst)}
        add(UPSTREAM + inst, "upstream", inst, u["title"], urls=url)
        if key is None:
            return UPSTREAM + inst
        nid = "%s%s#%s" % (UPSTREAM, inst, key)
        if nid not in nodes:
            add(nid, "upstream", key, u["statements"].get(key, key), parent=inst, urls=url)
            edge(nid, UPSTREAM + inst, "partOf")
        return nid

    groups = {}

    def group_of(eid):
        key, label = M["entries"][eid]["group"]
        if not key:
            return {}
        groups[key] = label
        return {"docGroup": key}

    def add_source(ref):
        """The node a requirement's `reference` or a bean's Sources names; returns its id."""
        if ref.startswith(UPSTREAM):
            inst, _, key = ref[len(UPSTREAM):].partition("#")
            return add_upstream(inst, key or None)
        if ref in M["sections"]:
            s = M["sections"][ref]
            add(ref, "section", section_label(M["entries"], s), s["heading"].replace("`", ""), doc=s["entry"], urls=s["urls"],
                **group_of(s["entry"]))
            add_source(s["entry"])
            if not any(e["s"] == ref and e["rel"] == "partOf" for e in edges):
                edge(ref, s["entry"], "partOf")
            return ref
        if ref in M["entries"]:
            e = M["entries"][ref]
            add(ref, "document", e["short"] or e["title"][:34], e["title"], urls=e["urls"], origin="library", **group_of(ref))
            return ref
        path = ROOT / ref
        if ref.startswith("external-schemas/"):
            d = json.loads(path.with_suffix(".json").read_text())
            add(ref, "standard", d.get("version") or d["id"], d["title"], authority=d.get("authority"),
                urls={"url": d.get("specUrl")}, note=d.get("note", ""))
        elif ref.startswith("references/"):
            d = json.loads(path.with_suffix(".json").read_text())
            add(ref, "document", d["title"][:34], d["title"], urls={"url": d.get("URL")}, origin="reference")
        elif ref.startswith("memory/"):
            fm, body = front_matter(path.with_suffix(".md").read_text())
            add(ref, "directive", fm.get("id", ref), fm.get("summary", ""), note=" ".join(body.split()))
        elif ref.startswith("vectors/"):
            add(ref, "document", path.name, "Test vector " + ref, origin="vector",
                urls={"main": "https://github.com/litlfred/smart-trust-tools/blob/main/" + ref})
        else:
            raise ValueError("unresolved reference " + ref)
        return ref

    for r in M["reqs"].values():
        add(r["id"], "requirement", r["id"], r["title"], area=r["area"], statement=r["statement"],
            conformance=r["conformance"], category=r["category"], derivation=r["derivation"], targets=r["targets"],
            iri=r["iri"], file=r["file"], criteria=r["criteria"])
    for r in M["reqs"].values():
        for d in r["derivedFrom"]:
            edge(r["id"], display_id(d), "derivedFrom")
        for d in r["reference"]:
            edge(r["id"], add_source(d), "satisfies" if d.startswith(UPSTREAM) else "references")

    order = {s: i + 1 for i, s in enumerate(M["pipeline"])}
    for s in M["skills"].values():
        add("skill:" + s["name"], "skill", s["name"], s["description"], package=s["package"],
            order=order.get(s["name"], 100), file=s["file"])
        for rid in s["satisfies"]:
            edge(display_id(rid), "skill:" + s["name"], "realizedBy")
    for t in M["tools"].values():
        add("tool:" + t["id"], "tool", t["id"], t["title"], text=t["description"], file="tools/%s/%s.ts" % (t["id"], t["id"]))
        for s in t["satisfies"]:
            edge("skill:" + s, "tool:" + t["id"], "implementedBy")
    for tid, t in M["tests"].items():
        label = re.sub(r"^(?:STT-[A-Z0-9]+-\d{3}\s+)+", "", t["name"])
        add(tid, "test", label, t["name"], file=t["file"], reqs=t["reqs"])
        for s in t["skills"]:
            edge("skill:" + s, tid, "testedBy")
        for r in t["reqs"]:
            if r in reqs_by_display:
                edge(tid, r, "verifies")
    for p in M["processes"].values():
        add("process:" + p["id"], "process", p["name"], p["name"], text=p["doc"], file=p["file"])
        for s in p["skills"]:
            edge("skill:" + s, "process:" + p["id"], "usedIn")
    for ro in M["roles"]:
        add("role:" + ro["id"], "role", ro["title"], ro["description"], actorKinds=ro.get("actorKinds", []))
        for s in ro.get("skills", []):
            edge("skill:" + s, "role:" + ro["id"], "performedBy")
    for prefix, items in (("wit:", M["wit"]), ("cddl:", M["cddl"])):
        for key, w in items.items():
            add(key, "api", w["name"], w["text"] or w["qname"], module=w["module"], qname=w["qname"], apiKind=w["kind"],
                lang=w["lang"], srcFile=w["file"])
            for tag in w["tags"]:
                if tag in reqs_by_display:
                    edge(tag, key, "constrainsApi")
            if w["name"] != w["module"]:
                edge(key, prefix + w.get("parent", w["module"]), "partOf")
    for p in M["plans"].values():
        pid = "plan:" + p["id"]
        cases = [dict(id=c["id"], description=c.get("description", ""), assertions=[a["id"] for a in c["assertions"]]) for c in p["testCases"]]
        add(pid, "test-plan", p["id"], p["title"], text=p.get("description", ""), status=p["status"], version=p["version"],
            scope=p["scope"], cases=cases, exit=p["exitCriteria"].get("description", p["exitCriteria"]["decision"]), file=p["file"])
        for rid in dict.fromkeys(a["id"].split("#")[0] for c in p["testCases"] for a in c["assertions"]):
            edge(pid, display_id(rid), "assesses")
        for c in p["testCases"]:
            if "skill:" + c["id"] in nodes:
                edge(pid, "skill:" + c["id"], "planCase")
        for d in p.get("dependencies", []):
            if d.get("predecessor"):
                edge(pid, "plan:" + d["predecessor"], "precededBy")
    for rel, m in M["models"].items():
        add(rel, "model", m["label"], m["title"], modelKind=m["kind"], file=m["file"], canonical=m.get("url"),
            urls={"main": "https://github.com/litlfred/smart-trust-tools/blob/main/" + rel})
    for rel, m in M["models"].items():
        if m.get("entry"):
            edge(rel, add_source(m["entry"]), "derivedFrom")
        if m.get("standard"):
            edge(rel, add_source(m["standard"]), "derivedFrom")
        for d in m["derivedFrom"]:
            edge(rel, d, "derivedFrom")
        for t in m.get("writtenBy", []):
            if "tool:" + t in nodes:
                edge("tool:" + t, rel, "writes")
    for rel, v in M["vectors"].items():
        add_source(rel)
        if v["entry"]:
            edge(rel, add_source(v["entry"]), "derivedFrom")
        for d in v["derivedFrom"]:
            edge(rel, add_source(d), "derivedFrom")
        for t in v["writtenBy"]:
            if "tool:" + t in nodes:
                edge("tool:" + t, rel, "writes")
    for b in M["beans"].values():
        add(b["id"], "issue", b["id"], b["title"], text=b["text"], hint=b["hint"], upstream=b["upstream"],
            status=b["status"], file=b["file"])
        for r in b["requirements"]:
            edge(display_id(r), b["id"], "affectedBy")
        for s in b["sources"]:
            edge(b["id"], add_source(s), "concerns")

    known = set(nodes)
    dangling = [e for e in edges if e["s"] not in known or e["t"] not in known]
    if dangling:
        raise ValueError("edges to no node: %s" % dangling[:5])
    return {"nodes": list(nodes.values()), "edges": edges, "areas": [[k, v] for k, v in M["areas"].items()],
            "groups": groups}


if __name__ == "__main__":
    import sys
    # CI: every edge resolves. Without --with-tools the Tool edges are left to
    # the site build's pre step, which runs with the harness mounted.
    g = build_graph(load(with_tools="--with-tools" in sys.argv))
    skills = {n["id"] for n in g["nodes"] if n["kind"] == "skill"}
    lost = sorted(skills - {e["s"] for e in g["edges"] if e["rel"] in ("usedIn", "performedBy")})
    if lost:
        sys.exit("skills in no process or role: %s" % lost)
    print("%d nodes, %d edges, all resolve" % (len(g["nodes"]), len(g["edges"])))
