#!/usr/bin/env python3
"""Write test/plans/hcert-library-conformance.test-plan.json from the graph.

The library conformance plan is the skills and the requirements' success
criteria, laid out as a test-plan/v1: one case per skill, one assertion per
criterion its requirements verify by test, id req:<id>#<statement>/<criterion>.
Written from them so it cannot drift: --check fails when the file is stale.
The test data per case and the plan's prose are set here. Each case's
feature is test/features/<case>.feature, its Gherkin; the shared
cat-harness check:test-gherkin joins its Scenarios to the tests.

--check also fails when any plan's case names no feature file, or a feature
file in test/features/ is the feature of no case.

Usage:
    python3 tools/test-plan/make_test_plan.py [--check]
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "build-site"))
import kg_nodes as K  # noqa: E402

OUT = ROOT / "test" / "plans" / "hcert-library-conformance.test-plan.json"
R = {}
for f in (ROOT / "skills" / "requirements").glob("*.json"):
    d = json.loads(f.read_text()); R[d["id"]] = d
PR129 = [{"kind": "fixed", "path": "vectors/smart-trust-pr129/dvc-qr-example-XXA.json"}, {"kind": "fixed", "path": "vectors/smart-trust-pr129/dvc-qr-example-XXA-dsc.pem"}]
DATA = {
 "hcert-conformance-testing": PR129 + [{"kind": "fixed", "path": "vectors/negative/negative-vectors.json"},
   {"kind": "generated", "template": "vectors/smart-trust-pr129/dvc-qr-example-XXA.json", "generator": "seeded-mutation-fuzzer",
    "params": {"iterations": 1500, "targets": ["base45Decode", "zlibInflate", "cborDeterministic", "parseSign1", "verify", "verifyCose"], "mutations": ["bit-flip", "insert", "delete", "truncate", "boundary-byte", "duplicate-run"], "timeBoundMs": 1000},
    "seed": "the target's name (Kotlin: String.hashCode of it)"}],
 "hcert-verify": PR129 + [{"kind": "fixed", "path": "vectors/negative/negative-vectors.json"}],
 "hcert-trust-list": PR129 + [{"kind": "fixed", "path": "vectors/gdhcn-trust-domains/CodeSystem-Domains.json"}],
 "vhl-receive": [{"kind": "fixed", "path": "vectors/ihe-vhl/jwe-dir-a256gcm.json"}, {"kind": "fixed", "path": "vectors/ihe-vhl/iti-yy5-manifest-case-b.json"}],
 "vhl-share": [{"kind": "fixed", "path": "vectors/ihe-vhl/jwe-dir-a256gcm.json"}],
 "hcert-encode-cbor": PR129, "hcert-compress": PR129, "hcert-encode-base45": PR129, "hcert-prefix-context": PR129,
}
cases, reqs = [], set()
for name, s in K.load_skills().items():
    asserts = []
    for ref in s["satisfies"]:
        rid, _, key = ref.partition("#"); key = key or "statement"
        if rid == "req:stt-tst-009":
            continue  # the WHO-ITB comparison is its own plan, who-itb-agreement
        st = next(x for x in R[rid]["statements"] if x["key"] == key)
        for c in st["successCriteria"]:
            if c["verification"] != "test":
                continue
            reqs.add(rid)
            asserts.append({"id": "%s#%s/%s" % (rid, key, c["key"]),
                            "type": "informative" if st["conformance"] in ("SHOULD", "MAY", "SHOULD NOT") else "required",
                            "expectation": c["criterion"]})
    if asserts:
        cases.append({"id": name, "description": s["description"].strip(), "assertions": asserts, "testData": DATA.get(name, []),
                      "feature": "test/features/%s.feature" % name})
plan = {
 "$schema": "test-plan/v1",
 "id": "hcert-library-conformance",
 "title": "SMART Trust HCERT and VHL library conformance",
 "status": "draft",
 "version": "1",
 "description": "The plan any implementation of the library requirements runs: the Kotlin library (tools/hcert-kotlin) today, the Rust library when it exists. One case per skill; each assertion is a requirement statement's success criterion verified by test (req:<id>#<statement>/<criterion>), so a verdict on an assertion is a verdict on that criterion. Criteria verified by review or inspection are not in this plan: they are judged at release review. A case passes when every required assertion has a passing test named after its requirement in the implementation's suite, run in CI on every target (JVM and Node for Kotlin; native and wasm32 for Rust). The fixed data is the smart-trust PR 129 certificate, the negative vectors derived from it, the GDHCN trust domain code systems and the IHE VHL fixtures; the generated data is the seeded fuzzer's. CI also enforces a coverage floor (STT-TST-010). The WHO-ITB comparison is the separate plan who-itb-agreement, which runs after this one.",
 "scope": {"kind": "tool", "versionRange": "*"},
 "requirements": sorted(reqs),
 "testCases": cases,
 "dependencies": [{"description": "The implementation builds from pinned, verified dependencies only (tools/hcert-kotlin/gradle/verification-metadata.xml; Cargo.lock with cargo-vet for Rust) and needs no network at test time."}],
 "exitCriteria": {"decision": "processes/sdlc/decisions/test-certification.dmn#Decision_TestCertification",
                  "description": "The platform default: the run completed, its data hashed, every case has a verdict, the untainted checker agrees, no required assertion failed and at least one passed."},
}
text = json.dumps(plan, indent=2, ensure_ascii=False) + "\n"
def feature_links():
    """Every plan's case names a feature file, and every feature file is some case's."""
    problems, named = [], set()
    for p in sorted((ROOT / "test" / "plans").glob("*.test-plan.json")):
        for case in json.loads(p.read_text()).get("testCases", []):
            feat = case.get("feature")
            if not feat:
                problems.append("%s: case %s has no feature" % (p.name, case["id"]))
            elif not (ROOT / feat).is_file():
                problems.append("%s: case %s's feature %s is not a file" % (p.name, case["id"], feat))
            else:
                named.add(feat)
    for f in sorted((ROOT / "test" / "features").glob("**/*.feature")):
        rel = f.relative_to(ROOT).as_posix()
        if rel not in named:
            problems.append("%s is the feature of no test-plan case" % rel)
    return problems


if "--check" in sys.argv:
    if not OUT.exists() or OUT.read_text() != text:
        sys.exit("%s is stale: run python3 tools/test-plan/make_test_plan.py" % OUT.relative_to(ROOT))
    problems = feature_links()
    if problems:
        sys.exit("\n".join(problems))
    print("test plan is up to date, and every case's feature file is linked")
else:
    OUT.write_text(text)
    print(len(cases), "cases", sum(len(c["assertions"]) for c in cases), "assertions", len(reqs), "requirements")
