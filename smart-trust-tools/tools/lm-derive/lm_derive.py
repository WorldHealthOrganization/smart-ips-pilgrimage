#!/usr/bin/env python3
"""Derive JSON-LD, SHACL and CDDL from FHIR logical models.

Reads the StructureDefinitions in models/fhir/ (compiled from the WHO SMART
IGs by tools/fetch-lms/fetch_lms.sh) and writes, per IG, to models/generated/:

    <ig>.context.jsonld   JSON-LD 1.1 context: payload JSON as RDF
    <ig>.shacl.ttl        SHACL shapes: cardinality, primitive patterns,
                          invariants, bindings and concept codes
    <ig>.cddl             CDDL (RFC 8610) for the CBOR wire encoding

Usage:
    python3 tools/lm-derive/lm_derive.py           regenerate
    python3 tools/lm-derive/lm_derive.py --check   fail if generated files are stale

Refuses what it cannot map. Every element, type and invariant of a model is
either mapped into all three outputs or named as a problem (model, element,
kind), and any problem fails both modes before anything is written. The one
way past a problem is an entry in tools/lm-derive/allow-unmapped.json, with a
reason; an allowed problem keeps its fallback (named below) and is printed on
every run, and an entry that matches no problem is itself refused, so the
list cannot outlive what it excuses.

Standard library only.
"""

import argparse
import collections
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
FHIR_DIR = ROOT / "models" / "fhir"
OUT_DIR = ROOT / "models" / "generated"
SHAPES = "https://github.com/litlfred/smart-trust-tools/models/shape/"
LMX = "https://github.com/litlfred/smart-trust-tools/models/lmx#"

# FHIR primitive -> XSD datatype carried as the lexical form (FHIR RDF maps
# partial dates to xsd:gYear / gYearMonth, so date-like values stay strings
# constrained by the FHIR regex rather than being coerced to xsd:date).
XSD = {
    "string": "xsd:string", "code": "xsd:string", "id": "xsd:string",
    "uri": "xsd:string", "date": "xsd:string", "dateTime": "xsd:string",
    "instant": "xsd:string", "integer": "xsd:integer", "integer64": "xsd:integer",
    "boolean": "xsd:boolean", "decimal": "xsd:decimal", "base64Binary": "xsd:string",
}
CDDL_BASE = {"integer": "int", "integer64": "int", "boolean": "bool", "decimal": "float"}

# Code systems with an official concept IRI pattern.
CONCEPT_IRI = {
    "http://snomed.info/sct": "http://snomed.info/id/{code}",
    "http://loinc.org": "http://loinc.org/rdf/{code}",
}

ALLOW_FILE = pathlib.Path(__file__).resolve().parent / "allow-unmapped.json"

# The FHIR version the primitive regexes (primitives-r5.json) were taken from.
FHIR_VERSION = "5.0.0"
FHIR_BASE = "http://hl7.org/fhir/StructureDefinition/Base"
# ElementDefinition properties: mapped into the outputs, or prose that carries
# no constraint on the payload (short becomes a label; the others are not
# written). Any other property is a constraint lm-derive does not map.
ELEMENT_MAPPED = {"path", "min", "max", "type", "binding", "code", "constraint", "short"}
ELEMENT_PROSE = {"id", "definition", "comment", "requirements", "alias", "label"}
# The root element: only invariants are mapped there.
ROOT_MAPPED = {"path", "constraint", "short"}
TYPE_MAPPED = {"code"}
BINDING_MAPPED = {"strength", "valueSet", "description"}
CODING_MAPPED = {"system", "code", "display"}
CONSTRAINT_MAPPED = {"key", "severity", "human", "expression", "source", "requirements", "xpath"}

# What each kind of problem falls back to when the allow-list excuses it.
FALLBACK = {
    "not-logical": "the definition is not read",
    "fhir-version": "R5 primitive regexes are applied anyway",
    "unknown-base": "only the model's own differential is read; nothing is inherited",
    "root-path": "the root element is read as the model's own",
    "nested-element": "the element is left out of every output",
    "unmapped-property": "the property is left out of every output",
    "untyped-element": "the element is typed string",
    "choice-type": "only the first type is mapped",
    "type-profile": "the profile is ignored; the type code is mapped",
    "unknown-type": "the element is typed string, with no pattern",
    "element-invariant": "the invariant is left out of every output",
    "untranslated-invariant": "SHACL carries the expression as lmx:untranslatedInvariant; CDDL leaves it out",
}

INVARIANT_OR_EXISTS = re.compile(r"^\s*([A-Za-z0-9_]+)\.exists\(\)\s+or\s+([A-Za-z0-9_]+)\.exists\(\)\s*$")


def kebab(name):
    s = re.sub(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])", "-", name)
    return s.lower()


def ig_of(url):
    m = re.match(r"https?://smart\.who\.int/([^/]+)/StructureDefinition/", url)
    return m.group(1) if m else "models"


def anchorless(rx):
    if rx and rx.startswith("^") and rx.endswith("$"):
        return rx[1:-1]
    return rx


class Problems:
    """What lm-derive cannot map, keyed (model, element, kind)."""

    def __init__(self):
        self.found = collections.OrderedDict()

    def add(self, model, element, kind, detail):
        assert kind in FALLBACK, kind
        self.found.setdefault((model, element, kind), detail)


def load(problems):
    prim = json.loads((FHIR_DIR / "primitives-r5.json").read_text())["regex"]
    sds = collections.OrderedDict()
    for p in sorted(FHIR_DIR.glob("StructureDefinition-*.json")):
        sd = json.loads(p.read_text())
        name = sd.get("name", p.stem)
        if sd.get("kind") != "logical":
            problems.add(name, name, "not-logical", "kind is %r; lm-derive maps logical models only" % sd.get("kind"))
            continue
        if sd.get("fhirVersion") != FHIR_VERSION:
            problems.add(name, name, "fhir-version", "fhirVersion is %r; the primitive regexes are FHIR %s" % (sd.get("fhirVersion"), FHIR_VERSION))
        sds[sd["url"]] = sd
    return prim, sds


def invariant_pair(inv, elems):
    """The two element names of an "a.exists() or b.exists()" invariant over elements of the model, or None."""
    m = INVARIANT_OR_EXISTS.match(inv.get("expression", ""))
    if m and m.group(1) in elems and m.group(2) in elems:
        return m.group(1), m.group(2)
    return None


def effective(sd, sds, cache, problems):
    """Elements of a logical model after applying its parent chain.

    Returns (elements, invariants). Each element dict has: name, min, max,
    types (list), binding, codes, short, iri (where it was first defined).
    """
    url = sd["url"]
    if url in cache:
        return cache[url]
    elems = collections.OrderedDict()
    invariants = []
    model = sd["name"]
    base = sd.get("baseDefinition")
    if base in sds:
        pe, pi = effective(sds[base], sds, cache, problems)
        elems = collections.OrderedDict((k, dict(v)) for k, v in pe.items())
        invariants = list(pi)
    elif base != FHIR_BASE:
        problems.add(model, model, "unknown-base", "baseDefinition %s is neither FHIR Base nor a model here" % base)
    # A specialization's paths start with its own type; a constraint's with the type it constrains.
    roots = {model, sd.get("type", "").rsplit("/", 1)[-1]}
    for e in sd["differential"]["element"]:
        path = e["path"]
        parts = path.split(".")
        if parts[0] not in roots:
            problems.add(model, path, "root-path", "path starts with %r, not %s" % (parts[0], " or ".join(sorted(roots))))
        known = ROOT_MAPPED if len(parts) == 1 else ELEMENT_MAPPED
        for k in e:
            if k not in known and k not in ELEMENT_PROSE:
                problems.add(model, path, "unmapped-property", "%s = %s" % (k, json.dumps(e[k])[:120]))
        for c in e.get("constraint", []):
            for k in c:
                if k not in CONSTRAINT_MAPPED:
                    problems.add(model, path, "unmapped-property", "constraint %s.%s" % (c.get("key"), k))
        if len(parts) == 1:
            for c in e.get("constraint", []):
                invariants.append(dict(c, _model=model))
            continue
        if len(parts) > 2:
            problems.add(model, path, "nested-element", "lm-derive maps the model's direct elements only")
            continue
        name = parts[1]
        cur = elems.setdefault(name, {"name": name, "iri": "%s#%s" % (url, name),
                                      "min": 0, "max": "*", "types": [], "binding": None,
                                      "codes": [], "short": None, "constraints": []})
        for k in ("min", "max", "short"):
            if k in e:
                cur[k] = e[k]
        if "type" in e:
            cur["types"] = [t["code"] for t in e["type"]]
            if len(e["type"]) > 1:
                problems.add(model, path, "choice-type", "types %s; lm-derive maps one type" % ", ".join(cur["types"]))
            for t in e["type"]:
                extra = sorted(set(t) - TYPE_MAPPED)
                if extra:
                    problems.add(model, path, "type-profile", "type %s carries %s" % (t.get("code"), ", ".join(extra)))
                if t["code"] not in XSD and t["code"] not in sds:
                    problems.add(model, path, "unknown-type", "type %s is neither a FHIR primitive lm-derive maps nor a model here" % t["code"])
        if "binding" in e:
            cur["binding"] = e["binding"]
            for k in e["binding"]:
                if k not in BINDING_MAPPED:
                    problems.add(model, path, "unmapped-property", "binding.%s" % k)
        if "code" in e:
            cur["codes"] = cur["codes"] + e["code"]
            for c in e["code"]:
                for k in c:
                    if k not in CODING_MAPPED:
                        problems.add(model, path, "unmapped-property", "code.%s" % k)
        for c in e.get("constraint", []):
            cur["constraints"].append(c)
            problems.add(model, path, "element-invariant", "%s: %s" % (c.get("key"), c.get("expression")))
    for el in elems.values():
        if not el["types"] and el["iri"].startswith(url + "#"):
            problems.add(model, "%s.%s" % (model, el["name"]), "untyped-element", "no type here or in a parent")
    for inv in invariants:
        if inv["_model"] == model and invariant_pair(inv, elems) is None:
            problems.add(model, model, "untranslated-invariant", "%s: %s" % (inv.get("key"), inv.get("expression")))
    cache[url] = (elems, invariants)
    return cache[url]


# ---------------------------------------------------------------------------
# JSON-LD
# ---------------------------------------------------------------------------

def jsonld_context(sds, roots, cache, problems):
    def terms(sd):
        elems, _ = effective(sd, sds, cache, problems)
        out = collections.OrderedDict()
        for el in elems.values():
            t = el["types"][0] if el["types"] else "string"
            if t in sds:
                out[el["name"]] = {"@id": el["iri"], "@context": terms(sds[t])}
            else:
                term = {"@id": el["iri"]}
                xsd = XSD.get(t, "xsd:string")
                if xsd != "xsd:string":
                    term["@type"] = xsd
                out[el["name"]] = term
        return out

    ctx = collections.OrderedDict([("@version", 1.1), ("xsd", "http://www.w3.org/2001/XMLSchema#")])
    for sd in sds.values():
        ctx[sd["name"]] = {"@id": sd["url"]}
    # Root-level terms: union over the root models (they share element names).
    for url in roots:
        for k, v in terms(sds[url]).items():
            ctx.setdefault(k, v)
    return {"@context": ctx}


# ---------------------------------------------------------------------------
# SHACL
# ---------------------------------------------------------------------------

def ttl_str(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def concept_iri(c):
    pat = CONCEPT_IRI.get(c["system"])
    return pat.format(code=c["code"]) if pat else "%s#%s" % (c["system"], c["code"])


def shacl(sds, prim, cache, problems):
    L = [
        "@prefix sh: <http://www.w3.org/ns/shacl#> .",
        "@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .",
        "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .",
        "@prefix skos: <http://www.w3.org/2004/02/skos/core#> .",
        "@prefix lmx: <%s> ." % LMX,
        "",
    ]
    props = collections.OrderedDict()
    for sd in sds.values():
        elems, invariants = effective(sd, sds, cache, problems)
        shape = SHAPES + sd["name"]
        lines = [
            "<%s>" % shape,
            "    a sh:NodeShape ;",
            "    rdfs:label %s ;" % ttl_str(sd.get("title") or sd["name"]),
            "    rdfs:isDefinedBy <%s> ;" % sd["url"],
            "    sh:targetClass <%s> ;" % sd["url"],
            "    lmx:abstract %s ;" % ("true" if sd.get("abstract") else "false"),
        ]
        or_pairs = []
        for inv in invariants:
            pair = invariant_pair(inv, elems)
            if pair:
                a, b = elems[pair[0]]["iri"], elems[pair[1]]["iri"]
                or_pairs.append((inv, a, b))
            else:
                # Reached only through an allow-list entry (main refuses it otherwise).
                lines.append("    lmx:untranslatedInvariant %s ;" % ttl_str("%s: %s" % (inv.get("key"), inv.get("expression"))))
        for el in elems.values():
            t = el["types"][0] if el["types"] else "string"
            pl = ["sh:path <%s>" % el["iri"], "sh:name %s" % ttl_str(el["name"])]
            if el.get("short"):
                pl.append("sh:description %s" % ttl_str(el["short"]))
            if el["min"]:
                pl.append("sh:minCount %d" % el["min"])
            if el["max"] != "*":
                pl.append("sh:maxCount %s" % el["max"])
            if t in sds:
                pl.append("sh:node <%s%s>" % (SHAPES, sds[t]["name"]))
            else:
                pl.append("sh:datatype %s" % XSD.get(t, "xsd:string"))
                rx = anchorless(prim.get(t))
                if rx:
                    pl.append("sh:pattern %s" % ttl_str("^(%s)$" % rx))
                pl.append("lmx:fhirType %s" % ttl_str(t))
            b = el.get("binding")
            if b:
                pl.append("lmx:bindingStrength %s" % ttl_str(b.get("strength", "")))
                if b.get("valueSet"):
                    pl.append("lmx:valueSet <%s>" % b["valueSet"])
            lines.append("    sh:property [ %s ] ;" % " ; ".join(pl))
            props.setdefault(el["iri"], el)
        for inv, a, b in or_pairs:
            lines.append("    sh:or ( [ sh:path <%s> ; sh:minCount 1 ] [ sh:path <%s> ; sh:minCount 1 ] ) ;" % (a, b))
            lines.append("    sh:message %s ;" % ttl_str("%s: %s" % (inv.get("key"), inv.get("human", ""))))
        lines[-1] = lines[-1][:-2] + " ."
        L.extend(lines)
        L.append("")
    # Property vocabulary: labels and the concept codes from ElementDefinition.code
    for iri, el in props.items():
        lines = ["<%s>" % iri, "    rdfs:label %s ;" % ttl_str(el["short"] or el["name"])]
        for c in el["codes"]:
            lines.append("    skos:closeMatch <%s> ;" % concept_iri(c))
        lines[-1] = lines[-1][:-2] + " ."
        L.extend(lines)
        L.append("")
    return "\n".join(L)


# ---------------------------------------------------------------------------
# CDDL
# ---------------------------------------------------------------------------

def cddl_text(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def cddl(sds, prim, cache, problems):
    used_prims = set()
    L = [
        "; Generated by tools/lm-derive/lm_derive.py from FHIR logical models. Do not edit.",
        "; Wire (CBOR) encoding of the payload logical models. Element names are",
        "; the logical-model element names; primitive types carry the FHIR R5",
        "; regex (RFC 8610 .regexp: XSD regex, implicitly anchored).",
        "",
    ]
    for sd in sds.values():
        elems, invariants = effective(sd, sds, cache, problems)
        name = kebab(sd["name"])
        entries = collections.OrderedDict()
        for el in elems.values():
            t = el["types"][0] if el["types"] else "string"
            if t in sds:
                ty = kebab(sds[t]["name"])
            else:
                ty = "fhir-%s" % kebab(t)
                used_prims.add(t)
            if el["max"] == "*":
                ty = "[%s %s]" % ("+" if el["min"] else "*", ty)
            occ = "" if el["min"] or el["max"] == "*" else "? "
            comment = []
            if el.get("binding"):
                b = el["binding"]
                comment.append("binding %s %s" % (b.get("strength"), b.get("valueSet", "")))
            entries[el["name"]] = (occ, ty, "; ".join(comment))
        rows = []  # (entry text, comment)
        for inv in invariants:
            pair = invariant_pair(inv, entries)
            if pair:
                # "a.exists() or b.exists()" over two optional entries becomes
                # a group choice: a required and b optional, or a optional
                # and b required. Each alternative names both entries.
                a, b = pair
                ta, tb = entries.pop(a)[1], entries.pop(b)[1]
                rows.append(("(%s: %s, ? %s: %s // ? %s: %s, %s: %s)" % (a, ta, b, tb, a, ta, b, tb),
                             inv.get("key")))
            # else: reached only through an allow-list entry, and left out (FALLBACK).
        rows = [("%s%s: %s" % (occ, k, ty), c) for k, (occ, ty, c) in entries.items()] + rows
        L.append("; %s%s" % (sd["url"], " (abstract)" if sd.get("abstract") else ""))
        L.append("%s = {" % name)
        for i, (text, comment) in enumerate(rows):
            sep = "," if i < len(rows) - 1 else ""
            L.append("  %s%s%s" % (text, sep, ("  ; " + comment) if comment else ""))
        L.append("}")
        L.append("")
    L.append("; FHIR R5 primitive types (hl7.fhir.r5.core#5.0.0)")
    for t in sorted(used_prims):
        base = CDDL_BASE.get(t)
        rx = anchorless(prim.get(t))
        if base:
            L.append("fhir-%s = %s" % (kebab(t), base))
        elif rx:
            L.append("fhir-%s = tstr .regexp %s" % (kebab(t), cddl_text(rx)))
        else:
            L.append("fhir-%s = tstr" % kebab(t))
    return "\n".join(L) + "\n"


def read_allow():
    """The allow-list: [(model, element, kind, reason)]. A malformed entry is refused."""
    if not ALLOW_FILE.exists():
        return [], []
    data = json.loads(ALLOW_FILE.read_text())
    entries, bad = [], []
    for i, e in enumerate(data.get("entries", [])):
        model, element, kind, reason = (e.get(k) for k in ("model", "element", "kind", "reason"))
        if not all(isinstance(v, str) and v.strip() for v in (model, element, kind, reason)) or kind not in FALLBACK:
            bad.append("%s entry %d: needs model, element, a kind (%s) and a reason" % (ALLOW_FILE.name, i, ", ".join(FALLBACK)))
            continue
        entries.append((model, element, kind, reason))
    return entries, bad


def triage(problems, allow, bad):
    """Split the problems into refused and allowed; an allow entry that matches nothing is refused too."""
    refused, allowed = list(bad), []
    keys = {(m, el, k): r for m, el, k, r in allow}
    for (model, element, kind), detail in problems.found.items():
        reason = keys.get((model, element, kind))
        if reason is None:
            refused.append("%s %s: %s (%s) cannot be mapped" % (model, element, kind, detail))
        else:
            allowed.append("%s %s: %s (%s) allowed: %s; %s" % (model, element, kind, detail, reason, FALLBACK[kind]))
    for model, element, kind, _ in allow:
        if (model, element, kind) not in problems.found:
            refused.append("%s names %s %s %s, which matches no problem: remove the entry" % (ALLOW_FILE.name, model, element, kind))
    return refused, allowed


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    problems = Problems()
    prim, sds = load(problems)
    cache = {}
    by_ig = collections.OrderedDict()
    for url, sd in sds.items():
        by_ig.setdefault(ig_of(url), collections.OrderedDict())[url] = sd
    outputs = {}
    for ig, group in by_ig.items():
        used_as_type = {t["code"] for sd in group.values()
                        for e in sd["differential"]["element"] for t in e.get("type", [])}
        roots = [u for u in group if u not in used_as_type]
        outputs["%s.context.jsonld" % ig] = json.dumps(jsonld_context(group, roots, cache, problems), indent=2) + "\n"
        outputs["%s.shacl.ttl" % ig] = shacl(group, prim, cache, problems)
        outputs["%s.cddl" % ig] = cddl(group, prim, cache, problems)
    refused, allowed = triage(problems, *read_allow())
    for a in allowed:
        print("allowed: " + a, file=sys.stderr)
    if refused:
        for r in refused:
            print("error: " + r, file=sys.stderr)
        print("lm-derive: %d problem(s); nothing %s. Map them in tools/lm-derive/lm_derive.py, or excuse each in %s with a reason."
              % (len(refused), "checked" if args.check else "written", ALLOW_FILE.relative_to(ROOT)), file=sys.stderr)
        return 1

    if args.check:
        stale = [n for n, c in outputs.items()
                 if not (OUT_DIR / n).exists() or (OUT_DIR / n).read_text() != c]
        if stale:
            print("stale: %s (run tools/lm-derive/lm_derive.py)" % ", ".join(stale), file=sys.stderr)
            return 1
        print("model outputs are up to date")
        return 0
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for n, c in outputs.items():
        (OUT_DIR / n).write_text(c)
    print("wrote " + ", ".join(sorted(outputs)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
