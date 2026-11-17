#!/usr/bin/env python3
"""Build this guide's ArchiMate model from the journeys and the overview figure.

Usage:
    python3 -I archimate/build.py            # write archimate/<version>/smart-ips-pilgrimage.archimate
    python3 -I archimate/build.py --check    # fail if the committed model is not what the build makes

The model has one source for each thing it draws, and nothing is typed twice:

- the people and systems are the roles in scenarios/roles.json (a person role
  is a BusinessRole, a system role an ApplicationComponent);
- the journey moments are the user scenarios in user-scenarios/ (P0 to P7 as
  BusinessProcess elements, part of "The pilgrim's journey", each triggering the
  one it `follows`); each person or system a moment names (`personas`, mapped
  to roles through scenarios/actors/) is assigned to it or serves it;
- the overview of key process flows is the figure input/images/workflow.png
  transcribed (FIGURE below): the two countries as Location elements, the
  numbered flows 1 to 5 and A to B as Flow relationships named as the figure
  prints them, and every box at the place the figure draws it, so the view
  keeps the figure's layout (Home Country left, Host Country right, the pilgrim at the
  top between them, WHO GDHCN at the bottom).

The version is the IG's (sushi-config.yaml `version:`), as cat-harness's
archimate-models skill asks. The archive is written with fixed timestamps so
that --check can compare bytes. Standard library only.
"""

import html
import io
import json
import re
import sys
import uuid
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAMESPACE = "https://litlfred.github.io/smart-ips-pilgrimage/archimate"
SOURCE = "SMART Verifiable IPS for Pilgrimage (litlfred/smart-ips-pilgrimage): the pilgrim's journey and the overview of key process flows"
MODEL_NAME = "SMART Verifiable IPS for Pilgrimage"
FIXED_TIME = (2026, 1, 1, 0, 0, 0)
IG = "https://litlfred.github.io/smart-ips-pilgrimage/"
JOURNEYS = "en/smart-ips-pilgrimage/journeys/smart-ips-pilgrimage/"

# --- The overview figure, transcribed (input/images/workflow.png, 1280 x 720) ---
#
# Each system role gets the name this guide's system actors page gives it
# (system-actors.html), and the SMART reference architecture actor the earlier
# drawing of this figure (workflow.plantuml, 2026-11-07) mapped it to.
SYSTEMS = {
    "origin-wallet": ("Origin Country Wallet", "system-actors.html#ochw",
                      ["http://smart.who.int/ra/ActorDefinition/PointOfServiceSystem"]),
    "origin-hie": ("Origin Country HIE", "system-actors.html#ochie",
                   ["http://smart.who.int/ra/ActorDefinition/InteroperabilityLayer",
                    "http://smart.who.int/ra/ActorDefinition/SharedHealthRecord"]),
    "host-emr": ("Host Country EMR", "system-actors.html#hcemr",
                 ["http://smart.who.int/ra/ActorDefinition/PointOfServiceSystem"]),
    "trust-network": ("WHO GDHCN", "http://smart.who.int/trust/Binary-TrustDomain-IPS-PILGRIMAGE.html", []),
}

# Where the figure draws each box, in the figure's own pixels (x, y, width,
# height). A box inside a country is placed inside that country's Location.
COUNTRIES = {
    "home-country": ("Home Country", (10, 40, 550, 500)),
    "ksa": ("Host Country", (720, 40, 550, 500)),
}
# Mirrored about the pilgrim's centre line, as the original is, so that flows
# 2 and 4, and A and B, run at the same angle (45 degrees).
PLACES = {
    "pilgrim": (None, (570, 85, 140, 60)),
    "origin-wallet": ("home-country", (40, 85, 180, 60)),
    "origin-hie": ("home-country", (240, 330, 280, 70)),
    "host-health-worker": ("ksa", (1065, 85, 170, 60)),
    "host-emr": ("ksa", (805, 330, 190, 70)),
    "trust-network": (None, (530, 595, 220, 60)),
}

# The numbered flows, as printed (the figure's two lines joined), with the
# journey moment and the IPS.HAJJ.TRANSACTION code each one is.
FLOWS = [
    ("1", "pilgrim", "origin-wallet", "Pilgrim configures access to IPS via QR code on national health wallet", "p1-health-check-and-consent", "consent-wallet"),
    ("2", "origin-wallet", "origin-hie", "IPS generated from patient care history in Home country", "p2-summary-signed", "doc-sign"),
    ("3", "pilgrim", "host-health-worker", "Pilgrim seeks care and shows IPS QR code to health worker", "p3-taken-ill-in-mina", None),
    ("4", "host-health-worker", "host-emr", "Health worker scans IPS QR code in their EMR", "p4-scanned-and-checked", "shl-get-manifest"),
    ("5", "origin-hie", "host-emr", "EMR retrieves IPS from Home country HIE", "p5-record-read-and-treated", "doc-get"),
    ("A", "origin-hie", "trust-network", "IPS verification keys published to GDHCN", "p0-keys-and-codes-shared", "keys-put"),
    ("B", "trust-network", "host-emr", "Verification keys retrieved by EMR to ensure provenance of IPS", "p4-scanned-and-checked", "keys-get"),
]

OVERVIEW = "Overview of key process flows"
JOURNEY_VIEW = "The pilgrim's journey"


def esc(s):
    return html.escape(str(s), quote=True)


def version():
    return re.search(r"^version:\s*(\S+)", (ROOT / "sushi-config.yaml").read_text(encoding="utf-8"), re.M).group(1)


_NS = uuid.uuid5(uuid.NAMESPACE_URL, NAMESPACE)


def oid(*parts):
    return "id-" + uuid.uuid5(_NS, "/".join(parts)).hex


def load():
    roles = json.loads((ROOT / "scenarios/roles.json").read_text(encoding="utf-8"))["roles"]
    actors = {p.stem: json.loads(p.read_text(encoding="utf-8")) for p in sorted((ROOT / "scenarios/actors").glob("*.json"))}
    moments = [json.loads(p.read_text(encoding="utf-8")) for p in sorted((ROOT / "user-scenarios").glob("*.json"))]
    return roles, actors, moments


def build():
    roles, actors, moments = load()
    els = {}  # key -> (type, name, doc, props)
    rels = []  # (key, type, source, target, name, doc, props)

    for r in roles:
        k = r["id"]
        props = {"role": f"scenarios/roles.json#{k}"}
        # The IG's own name for the role, from its otherNames: "Host Country EMR (IG system actor HCEMR)".
        ig = next((re.match(r"^(.*) \((IG [^)]*)\)$", n) for n in r.get("otherNames", []) if re.match(r"^(.*) \((IG [^)]*)\)$", n)), None)
        if ig:
            props["igActor"] = ig.group(2)
        if "person" in r["actorKinds"]:
            els[k] = ("BusinessRole", ig.group(1) if ig else r["title"], r["description"], {**props, "page": IG + "personas.html"})
        else:
            name, page, ra = SYSTEMS[k]
            props["page"] = page if page.startswith("http") else IG + page
            for i, a in enumerate(ra):
                props[f"smartRaActor{i + 1 if len(ra) > 1 else ''}"] = a
            els[k] = ("ApplicationComponent", ig.group(1) if ig else name, r["description"], props)

    for k, (name, _) in COUNTRIES.items():
        els[k] = ("Location", name, f"Where the figure's {name} side is.", {})
        for key, (country, _) in PLACES.items():
            if country == k:
                rels.append((f"{k}>{key}", "Aggregation", k, key, "", "", {}))

    parent = next(m for m in moments if not m.get("partOf"))
    parts = sorted((m for m in moments if m.get("partOf") == parent["id"]), key=lambda m: m["id"])
    els[parent["id"]] = ("BusinessProcess", parent["title"], parent["description"],
                         {"userScenario": f"user-scenarios/{parent['id']}.json", "page": IG + JOURNEYS + parent["id"] + "/"})
    for m in parts:
        els[m["id"]] = ("BusinessProcess", m["title"], m["description"],
                        {"userScenario": f"user-scenarios/{m['id']}.json", "page": IG + JOURNEYS + m["id"] + "/",
                         "when": m.get("when", ""), "where": m.get("where", "")})
        rels.append((f"{parent['id']}>{m['id']}", "Composition", parent["id"], m["id"], "", "", {}))
        if m.get("follows"):
            rels.append((f"{m['follows']}>{m['id']}", "Triggering", m["follows"], m["id"], "", "", {}))
        seen = set()
        for p in m.get("personas", []):
            for role in actors[p]["roles"]:
                if role in seen:
                    continue
                seen.add(role)
                t = "Assignment" if els[role][0] == "BusinessRole" else "Serving"
                a, b = (role, m["id"])
                rels.append((f"{role}>{m['id']}", t, a, b, "", "", {}))

    for step, a, b, text, moment, tx in FLOWS:
        props = {"step": step, "journeyMoment": IG + JOURNEYS + moment + "/"}
        if tx:
            props["transaction"] = f"{IG}artifact/CodeSystem-IPS.HAJJ.TRANSACTION.html#IPS.HAJJ.TRANSACTION-{tx}"
        if "IPS QR code" in text:
            props["carries"] = "IPS QR code"
        rels.append((f"flow-{step}", "Flow", a, b, f"{step}. {text}", f"Step {step} of the overview of key process flows.", props))
    return els, rels, parts


def element_xml(key, t, name, doc, props):
    body = f"\n      <documentation>{esc(doc)}</documentation>" if doc else ""
    props = {**props, "source": SOURCE}
    body += "".join(f'\n      <property key="{esc(k)}" value="{esc(v)}"/>' for k, v in props.items() if v)
    return f'\n    <element xsi:type="archimate:{t}" name="{esc(name)}" id="{oid("element", key)}">{body}\n    </element>'


def rel_xml(key, t, a, b, name, doc, props):
    attrs = f' name="{esc(name)}"' if name else ""
    body = f"\n      <documentation>{esc(doc)}</documentation>" if doc else ""
    body += "".join(f'\n      <property key="{esc(k)}" value="{esc(v)}"/>' for k, v in props.items())
    open_ = f'\n    <element xsi:type="archimate:{t}Relationship" id="{oid("rel", key)}"{attrs} source="{oid("element", a)}" target="{oid("element", b)}"'
    return open_ + (f">{body}\n    </element>" if body else "/>")


class View:
    """One diagram: boxes (some nested) and the lines between them."""

    def __init__(self, name, slug):
        self.name = name
        self.slug = slug  # the view's page path (cat-harness-tools archimate/schemas/slugs.ts)
        self.boxes = {}  # key -> (parent key or None, x, y, w, h) in view coordinates
        self.lines = []  # (rel key, source key, target key)

    def box(self, key, x, y, w, h, parent=None):
        self.boxes[key] = (parent, x, y, w, h)

    def line(self, rel, a, b):
        self.lines.append((rel, a, b))

    def xml(self, doc):
        vid = oid("view", self.name)
        did = lambda k: oid("view", self.name, "obj", k)
        cid = lambda r: oid("view", self.name, "conn", r)
        src, tgt = {}, {}
        for r, a, b in self.lines:
            src.setdefault(a, []).append(
                f'<sourceConnection xsi:type="archimate:Connection" id="{cid(r)}" source="{did(a)}" target="{did(b)}" archimateRelationship="{oid("rel", r)}"/>')
            tgt.setdefault(b, []).append(cid(r))

        def child(k, depth):
            parent, x, y, w, h = self.boxes[k]
            if parent:  # Archi stores a nested box relative to its parent
                x, y = x - self.boxes[parent][1], y - self.boxes[parent][2]
            ind = "  " * depth
            tc = f' targetConnections="{" ".join(tgt[k])}"' if k in tgt else ""
            out = (f'\n{ind}<child xsi:type="archimate:DiagramObject" id="{did(k)}"{tc} archimateElement="{oid("element", k)}">'
                   f'\n{ind}  <bounds x="{x}" y="{y}" width="{w}" height="{h}"/>')
            out += "".join(f"\n{ind}  {s}" for s in src.get(k, []))
            for kid in [c for c, v in self.boxes.items() if v[0] == k]:
                out += child(kid, depth + 1)
            return out + f"\n{ind}</child>"

        body = "".join(child(k, 4) for k, v in self.boxes.items() if v[0] is None)
        return (f'\n      <element xsi:type="archimate:ArchimateDiagramModel" name="{esc(self.name)}" id="{vid}">'
                f"\n        <documentation>{esc(doc)}</documentation>"
                f'\n        <property key="source" value="{esc(SOURCE)}"/>'
                f'\n        <property key="slug" value="{esc(self.slug)}"/>{body}\n      </element>')


def views(els, rels, parts):
    ov = View(OVERVIEW, "overview-of-key-process-flows")
    for k, (_, (x, y, w, h)) in COUNTRIES.items():
        ov.box(k, x, y, w, h)
    for k, (country, (x, y, w, h)) in PLACES.items():
        ov.box(k, x, y, w, h, parent=country)
    for step, a, b, *_ in FLOWS:
        ov.line(f"flow-{step}", a, b)

    jv = View(JOURNEY_VIEW, "the-pilgrims-journey")
    W, H, GAP = 140, 70, 18
    n = len(parts)
    parent = next(k for k, v in els.items() if v[0] == "BusinessProcess" and k not in {m["id"] for m in parts})
    jv.box(parent, 10, 10, n * (W + GAP) + GAP, H + 2 * GAP + 30)
    for i, m in enumerate(parts):
        jv.box(m["id"], 10 + GAP + i * (W + GAP), 50, W, H, parent=parent)
    for r in rels:
        if r[1] == "Triggering":
            jv.line(r[0], r[2], r[3])
    out = [
        (ov, "The overview of key process flows from the home page (input/images/workflow.png), with every box where the figure draws it: "
             "Home Country on the left, Host Country on the right, the pilgrim at the top between them and WHO GDHCN at the bottom. "
             "Each numbered flow is named as the figure prints it and links its moment of the pilgrim's journey and its transaction."),
        (jv, "The pilgrim's journey, moment by moment (P0 to P7, user-scenarios/), each moment triggering the next. "
             "Each moment has a view of its own with the people assigned to it and the systems that serve it."),
    ]
    # One view per moment: the moment, its people above it, the systems that serve it below.
    for m in parts:
        v = View(els[m["id"]][1], m["id"])
        mine = [r for r in rels if r[1] in ("Assignment", "Serving") and r[3] == m["id"]]
        people = [r[2] for r in mine if r[1] == "Assignment"]
        systems = [r[2] for r in mine if r[1] == "Serving"]
        width = max(len(people), len(systems), 1) * (W + 40 + GAP) + GAP
        for row, keys in ((10, people), (260, systems)):
            span = len(keys) * (W + 40 + GAP) - GAP
            for i, k in enumerate(keys):
                v.box(k, int((width - span) / 2) + i * (W + 40 + GAP), row, W + 40, 55)
        v.box(m["id"], int((width - W - 60) / 2), 135, W + 60, H)
        for r in mine:
            v.line(r[0], r[2], r[3])
        out.append((v, f"{els[m['id']][1]}: {m.get('when', '')}, {m.get('where', '')}. The people assigned to this moment and the systems that serve it (user-scenarios/{m['id']}.json)."))
    return out


FOLDERS = [("Strategy", "strategy"), ("Business", "business"), ("Application", "application"),
           ("Technology &amp; Physical", "technology"), ("Motivation", "motivation"),
           ("Implementation &amp; Migration", "implementation_migration"), ("Other", "other"),
           ("Relations", "relations"), ("Views", "diagrams")]
FOLDER_OF = {"BusinessRole": "business", "BusinessProcess": "business", "ApplicationComponent": "application", "Location": "other"}


def model_xml():
    els, rels, parts = build()
    content = {f: "" for _, f in FOLDERS}
    for k, (t, name, doc, props) in els.items():
        content[FOLDER_OF[t]] += element_xml(k, t, name, doc, props)
    for r in rels:
        content["relations"] += rel_xml(*r)
    for v, doc in views(els, rels, parts):
        content["diagrams"] += v.xml(doc)
    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           f'<archimate:model xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:archimate="http://www.archimatetool.com/archimate" name="{esc(MODEL_NAME)}" id="{oid("model")}" version="5.0.0">']
    for name, f in FOLDERS:
        fid = oid("folder", f)
        out.append(f'  <folder name="{name}" id="{fid}" type="{f}">{content[f]}\n  </folder>' if content[f]
                   else f'  <folder name="{name}" id="{fid}" type="{f}"/>')
    out.append(f"  <purpose>{esc(SOURCE)}. Generated by archimate/build.py; do not edit in Archi.</purpose>")
    out.append("</archimate:model>\n")
    return "\n".join(out)


def archive():
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(zipfile.ZipInfo("model.xml", FIXED_TIME), model_xml().encode("utf-8"))
    return buf.getvalue()


def main(argv):
    target = ROOT / "archimate" / version() / "smart-ips-pilgrimage.archimate"
    data = archive()
    if "--check" in argv:
        if not target.exists() or target.read_bytes() != data:
            print(f"{target.relative_to(ROOT)}: stale; run python3 -I archimate/build.py", file=sys.stderr)
            return 1
        print(f"{target.relative_to(ROOT)}: current")
        return 0
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
    print(f"{target.relative_to(ROOT)}: written")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
