#!/usr/bin/env python3
"""Check the wire and payload schemas against the conformance vectors.

The generated shapes themselves conform to the SHACL shapes for SHACL
(W3C SHACL Appendix C, the copy pyshacl carries), so a malformed shape fails
here rather than silently constraining nothing. Then, for every certificate
in vectors/*/ :
  * CDDL: the COSE_Sign1, its protected header and its CWT claim set validate
    against api/cddl/hcert.cddl + models/generated/*.cddl
  * SHACL: the payload, read as JSON-LD through the generated context,
    conforms to the generated shapes
and a set of mutated payloads is rejected by both.

Verifies STT-CBR-004 (the wire format is specified in CDDL), STT-PAY-010 (the
payload models are derived from the FHIR logical models) and STT-TST-008
(schema checks against the vectors).

Requires: pip install cbor2 base45 pycddl pyshacl rdflib
"""

import copy
import json
import pathlib
import re
import sys
import zlib

import base45
import cbor2
import pycddl
import rdflib
from pyshacl import validate

ROOT = pathlib.Path(__file__).resolve().parents[2]
LM_ROOT = "http://smart.who.int/trust-phw/StructureDefinition/DVCMin"


def cddl_source():
    parts = [(ROOT / "api" / "cddl" / "hcert.cddl").read_text()]
    parts += [p.read_text() for p in sorted((ROOT / "models" / "generated").glob("*.cddl"))]
    text = "\n".join(parts)
    # Two deviations of the cddl-rs validator behind pycddl from RFC 8610
    # (XSD regex), worked around here so the CDDL files stay spec-correct:
    # escaped classes such as \s reach its regex engine as a literal "s",
    # and it searches rather than implicitly anchoring. Rewrite the escapes
    # the FHIR regexes use into escape-free equivalents, then anchor.
    def fix(m):
        rx = (m.group(1)
              .replace(r"[\\s\\S]", "(?s:.)")
              .replace(r"[^\\s]", "[^[:space:]]")
              .replace(r"\\-", "-").replace(r"\\.", "."))
        if "\\" in rx:
            raise SystemExit("check_models: no cddl-rs rewrite for regex %r" % m.group(1))
        return '.regexp "^(%s)$"' % rx
    text = re.sub(r'\.regexp "((?:[^"\\]|\\.)*)"', fix, text)
    # cddl-rs mis-validates `.cbor` inside arrays, so the embedded layers are
    # validated separately below and the envelope checks them as plain bstr.
    return re.sub(r"bstr \.cbor [a-z0-9-]+", "bstr", text)


def schema(root, text):
    return pycddl.Schema("root = %s\n%s" % (root, text))


def shacl_graph():
    g = rdflib.Graph()
    for p in sorted((ROOT / "models" / "generated").glob("*.shacl.ttl")):
        g.parse(p, format="turtle")
    return g


def payload_conforms(payload, context, shapes):
    doc = dict(payload)
    doc["@context"] = context["@context"]
    doc["@type"] = "DVCMin"
    data = rdflib.Graph().parse(data=json.dumps(doc), format="json-ld")
    ok, _, report = validate(data, shacl_graph=shapes)
    return ok, report


MUTATIONS = [
    ("vx without is and cn", lambda p: (p["vx"].pop("is", None), p["vx"].pop("cn", None))),
    ("dob not a FHIR date", lambda p: p.__setitem__("dob", "2026-13-01")),
    ("missing n", lambda p: p.pop("n")),
    ("is not a FHIR id", lambda p: p["vx"].__setitem__("is", "bad id with spaces")),
]
ACCEPTED = [
    ("vx with cn only", lambda p: p["vx"].pop("is", None)),
    ("partial dob (year only)", lambda p: p.__setitem__("dob", "2026")),
]


def main():
    text = cddl_source()
    cose_s, prot_s, claims_s = schema("hc1-cose", text), schema("protected-header", text), schema("cwt-claims", text)
    context = json.loads((ROOT / "models" / "generated" / "trust-phw.context.jsonld").read_text())
    shapes = shacl_graph()
    failures = 0

    def expect(ok, label):
        nonlocal failures
        print(("ok   " if ok else "FAIL ") + label)
        failures += 0 if ok else 1

    try:
        meta_ok, _, meta_report = validate(rdflib.Graph(), shacl_graph=shapes, meta_shacl=True)
    except Exception as e:  # pyshacl raises when the shapes graph fails SHACL-SHACL
        meta_ok, meta_report = False, str(e)
    expect(meta_ok, "models/generated/*.shacl.ttl: shapes conform to SHACL-SHACL" + ("" if meta_ok else "\n" + meta_report))

    for vf in sorted(ROOT.glob("vectors/*/*.json")):
        vector = json.loads(vf.read_text())
        if "certificates" not in vector:  # not an HCERT vector (e.g. vectors/ihe-vhl)
            continue
        for name, cert in vector["certificates"].items():
            tag = "%s/%s" % (vf.parent.name, name)
            cose = zlib.decompress(base45.b45decode(cert["hc1"][4:]))
            prot, _, payload_bytes, _ = cbor2.loads(cose).value
            for s, data, what in ((cose_s, cose, "COSE_Sign1"), (prot_s, prot, "protected header"),
                                  (claims_s, payload_bytes, "CWT claims")):
                try:
                    s.validate_cbor(data)
                    expect(True, "%s: CDDL %s" % (tag, what))
                except pycddl.ValidationError as e:
                    expect(False, "%s: CDDL %s: %s" % (tag, what, str(e).splitlines()[0]))
            claims = cbor2.loads(payload_bytes)
            payload = claims[-260][-6]
            ok, report = payload_conforms(payload, context, shapes)
            expect(ok, "%s: SHACL payload" % tag + ("" if ok else "\n" + report))

            for label, mutate, want in [(l, m, False) for l, m in MUTATIONS] + [(l, m, True) for l, m in ACCEPTED]:
                p = copy.deepcopy(payload)
                mutate(p)
                c = copy.deepcopy(claims)
                c[-260][-6] = p
                try:
                    claims_s.validate_cbor(cbor2.dumps(c))
                    cddl_ok = True
                except pycddl.ValidationError:
                    cddl_ok = False
                shacl_ok, _ = payload_conforms(p, context, shapes)
                verb = "accepted" if want else "rejected"
                expect(cddl_ok == want, "%s: CDDL %s: %s" % (tag, verb, label))
                expect(shacl_ok == want, "%s: SHACL %s: %s" % (tag, verb, label))

    print("%d failure(s)" % failures)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
