#!/usr/bin/env python3
"""Write the bindings of each system under test, from the tags in its tests.

A system under test is test/systems/<id>.system.json (system/v1, the owner's
decision D1 of 2026-10-24): the system's surfaces, targets and the plans it
claims, and the suites that test it. Those fields are written by hand. This
Tool writes the rest (decision D2: the tags in the tests are the source, and
a Tool writes the map onto the system):

  bindings   for each assertion of a claimed plan, the tests that verify it,
             each with the surface and target its suite runs on
  uncovered  each required assertion, with the declared targets on which no
             test verifies it, less what `unbound` explains

A test's tag is the run of requirement ids its name starts with, as the
suites already name them: `STT-VER-001 STT-VER-002 a tampered payload ...`
in Kotlin and TypeScript, `stt_ver_003_headers_are_checked...` in Rust. A tag
STT-XXX-nnn verifies that requirement's success criterion with key `test`,
or its only criterion verified by test when it has one, or, when it has
several, the one whose key is a word of the test's name ("... decode as
published" verifies STT-TST-011's `decode`). A tag that matches
neither names nothing it can verify, and is reported.

A script that is a test as a whole (a check, a smoke test, a coverage floor)
carries its tags in a sentence that starts with "Verifies", in its header
comment or docstring. There a tag may name the criterion too,
`STT-TST-010/rust-floor`, since a script's name is free text.

A suite's surface and target are "*" when the check does not depend on the
implementation (check_models.py validates the vectors against the schemas):
such a binding counts on every target of the system.

Usage:
    python3 tools/test-systems/make_test_systems.py [--check]

--check writes nothing and fails when a file is stale or a tag names no
requirement. An uncovered assertion is listed, not failed: the list is what
a reviewer reads.
"""

import collections
import glob
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "build-site"))
import kg_nodes as K  # noqa: E402

SYSTEMS = ROOT / "test" / "systems"
PLANS = ROOT / "test" / "plans"
# Leading requirement ids, separated by spaces, or by "-" in a looped id[${key}] title (no whitespace).
LEADING = re.compile(r"^((?:STT-[A-Z0-9]+-\d{3}[\s-]+)+)")
REQ_ID = re.compile(r"STT-[A-Z0-9]+-\d{3}")
TS_TEST = re.compile(r"\brun\(\s*[\"`](STT-[^\"`]*)[\"`]")
VERIFIES = re.compile(r"\bVerifies\s+(.*?)(?:\n\s*(?:#|//)?\s*\n|\"\"\"|$)", re.S)
SCRIPT_TAG = re.compile(r"STT-[A-Z0-9]+-\d{3}(?:/[a-z0-9-]+)?")
GENERATED = ("bindings", "uncovered")

requirements = {}
for f in (ROOT / "skills" / "requirements").glob("*.json"):
    d = json.loads(f.read_text())
    requirements[d["id"]] = d

plans = {}
for f in PLANS.glob("*.test-plan.json"):
    p = json.loads(f.read_text())
    plans[p["id"]] = p


def criterion_for(tag, name=None):
    """STT-VER-001 -> req:stt-ver-001#statement/test, or None when it names nothing verifiable."""
    tag, _, key = tag.partition("/")
    rid = "req:" + tag.lower()
    req = requirements.get(rid)
    if req is None:
        return None, "names no requirement"
    if key:
        hits = ["%s#%s/%s" % (rid, st["key"], key) for st in req["statements"]
                if any(c["key"] == key and c.get("verification") == "test" for c in st.get("successCriteria", []))]
        return (hits[0], None) if len(hits) == 1 else (None, "names no criterion %s verified by test" % key)
    found = []
    for st in req["statements"]:
        tests = [c["key"] for c in st.get("successCriteria", []) if c.get("verification") == "test"]
        if "test" in tests:
            found.append("%s#%s/test" % (rid, st["key"]))
        elif len(tests) == 1:
            found.append("%s#%s/%s" % (rid, st["key"], tests[0]))
        elif tests:
            # Several criteria: the one whose key is a word of the test's name.
            words = set(re.findall(r"[a-z0-9-]+", (name or "").lower()))
            hit = [k for k in tests if k in words]
            if len(hit) == 1:
                found.append("%s#%s/%s" % (rid, st["key"], hit[0]))
            else:
                return None, "has criteria %s verified by test, and the test's name contains %s of their keys" % (", ".join(tests), "none" if not hit else "several")
    if len(found) == 1:
        return found[0], None
    return None, "has %s criteria verified by test" % ("no" if not found else "several statements with")


def tests_in(path, lang):
    """(selector, tags) for each test in one file."""
    text = (ROOT / path).read_text()
    if lang == "kotlin":
        names = K.KOTLIN_TEST.findall(text)
        out = [(n, n) for n in names]
    elif lang == "rust":
        out = [(f, K.rust_test_name(f)) for f in K.RUST_TEST.findall(text)]
    elif lang == "ts":
        out = [(n, n) for n in TS_TEST.findall(text)]
    elif lang == "script":
        m = VERIFIES.search(text)
        return [(path, SCRIPT_TAG.findall(m.group(1)) if m else [], "")]
    else:
        raise SystemExit("unknown suite lang %r in %s" % (lang, path))
    result = []
    for selector, name in out:
        m = LEADING.match(name + " ")
        tags = REQ_ID.findall(m.group(1)) if m else []
        # A TypeScript name may carry a template expression; the selector keeps it as written.
        result.append(("%s::%s" % (path, selector), tags, name))
    return result


def build(system):
    problems = []
    claimed = {}
    for pid in system.get("plans", []):
        if pid not in plans:
            problems.append("%s: plan %s is not in test/plans/" % (system["id"], pid))
            continue
        for case in plans[pid]["testCases"]:
            for a in case["assertions"]:
                claimed.setdefault(a["id"], a["type"])
    surfaces = {s["id"] for s in system["surfaces"]}
    targets = list(system.get("targets", []))
    bound = collections.defaultdict(list)
    for suite in system["suites"]:
        if suite["surface"] != "*" and suite["surface"] not in surfaces:
            problems.append("%s: suite %s names surface %s, which the system does not declare" % (system["id"], suite["glob"], suite["surface"]))
        if suite["target"] != "*" and suite["target"] not in targets:
            problems.append("%s: suite %s names target %s, which the system does not declare" % (system["id"], suite["glob"], suite["target"]))
        files = sorted(glob.glob(str(ROOT / suite["glob"]), recursive=True))
        if not files:
            problems.append("%s: suite %s matches no file" % (system["id"], suite["glob"]))
        for f in files:
            rel = pathlib.Path(f).relative_to(ROOT).as_posix()
            for selector, tags, label in tests_in(rel, suite["lang"]):
                for tag in tags:
                    aid, why = criterion_for(tag, label)
                    if aid is None:
                        if why:
                            problems.append("%s: %s tags %s, which %s" % (system["id"], selector, tag, why))
                        continue
                    if aid not in claimed:
                        continue
                    entry = {"surface": suite["surface"], "target": suite["target"], "selector": selector}
                    if entry not in bound[aid]:
                        bound[aid].append(entry)
    for u in system.get("unbound", []):
        if "assertion" in u and u["assertion"] not in claimed:
            problems.append("%s: unbound %s is not an assertion of a claimed plan" % (system["id"], u["assertion"]))
        if "target" in u and u["target"] not in targets:
            problems.append("%s: unbound target %s is not a declared target" % (system["id"], u["target"]))
        if not u.get("reason"):
            problems.append("%s: an unbound entry gives no reason" % system["id"])

    def explained(aid, target):
        return any(u.get("assertion", aid) == aid and u.get("target", target) == target for u in system.get("unbound", []))

    bindings = [{"assertion": aid, "tests": sorted(bound[aid], key=lambda e: (e["surface"], e["target"], e["selector"]))}
                for aid in sorted(bound)]
    uncovered = []
    for aid in sorted(claimed):
        if claimed[aid] != "required":
            continue
        have = {e["target"] for e in bound.get(aid, [])}
        missing = [] if "*" in have else [t for t in targets if t not in have and not explained(aid, t)]
        if missing:
            uncovered.append({"assertion": aid, "targets": missing})
    return bindings, uncovered, problems


def main():
    check = "--check" in sys.argv
    problems, stale = [], []
    files = sorted(SYSTEMS.glob("*.system.json"))
    for f in files:
        system = json.loads(f.read_text())
        if system.get("$schema") != "system/v1" or system.get("id") + ".system.json" != f.name:
            problems.append("%s: not a system/v1 named after its id" % f.relative_to(ROOT))
            continue
        bindings, uncovered, p = build(system)
        problems += p
        out = {k: v for k, v in system.items() if k not in GENERATED}
        out["bindings"] = bindings
        out["uncovered"] = uncovered
        text = json.dumps(out, indent=2, ensure_ascii=False) + "\n"
        if f.read_text() != text:
            if check:
                stale.append(f.relative_to(ROOT).as_posix())
            else:
                f.write_text(text)
        n = len({a["id"] for pid in system.get("plans", []) for c in plans.get(pid, {}).get("testCases", []) for a in c["assertions"] if a["type"] == "required"})
        print("%s: %d assertion(s) bound, %d required uncovered on some target (of %d required)" % (system["id"], len(bindings), len(uncovered), n))
    for s in stale:
        problems.append("%s is stale: run python3 tools/test-systems/make_test_systems.py" % s)
    for p in problems:
        print(p, file=sys.stderr)
    if problems:
        sys.exit(1)


if __name__ == "__main__":
    main()
