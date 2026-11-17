# Payload models

The payload schemas are **derived from the WHO SMART FHIR logical models**,
not written by hand [STT-PAY-010].

```
smart-trust-phw FSH ──sushi──▶ models/fhir/*.json ──lm-derive──▶ models/generated/
 (pinned commit)               (vendored, SOURCE.yaml)                    trust-phw.context.jsonld
                                                                          trust-phw.shacl.ttl
                                                                          trust-phw.cddl
```

| Output | Standard | What it gives you |
|---|---|---|
| `trust-phw.context.jsonld` | W3C JSON-LD 1.1 | Read an HCERT payload's JSON view (`{"n": …, "vx": {…}}`) as RDF. Each short name maps to `<StructureDefinition url>#<element>`. |
| `trust-phw.shacl.ttl` | W3C SHACL | Cardinality, FHIR R5 primitive regexes, the `must-have-issuer-or-clinician-name` invariant, bindings (as annotations) and the LOINC/SNOMED/ICVP concept codes of each element (`skos:closeMatch`). |
| `trust-phw.cddl` | IETF RFC 8610 | The CBOR wire encoding, combined with the envelope in [`../api/cddl/hcert.cddl`](../api/cddl/hcert.cddl). |

Translation rules:
- FHIR primitives keep their lexical form (`xsd:string` plus the FHIR regex).
  FHIR `date` allows partial dates (`2026`, `2026-09`), so dates are not
  coerced to `xsd:date`.
- Profiles that constrain a parent (`DVCMinPreQual`) inherit the parent's
  elements and keep the parent's element IRIs.
- Invariants of the form `a.exists() or b.exists()` become `sh:or` in SHACL
  and a group choice in CDDL. Anything else is reported and kept as an
  annotation.
- Value-set bindings are recorded, not enforced.

## Using the JSON-LD context

```json
{
  "@context": "models/generated/trust-phw.context.jsonld",
  "@type": "DVCMin",
  "n": "Chanthala SOUVANNALATH",
  "dob": "2026-09-28",
  "vx": { "vp": "XM9V38", "dv": "2026-09-28", "bo": "HEPB-2026-0914", "is": "org-xxa-provincial-hospital" }
}
```

## Commands

```sh
python3 tools/lm-derive/lm_derive.py            # regenerate models/generated (stdlib only)
python3 tools/lm-derive/lm_derive.py --check    # CI: fail if stale
# Both refuse an element, type or invariant they cannot map, unless
# tools/lm-derive/allow-unmapped.json excuses it with a reason.
pip install cbor2 base45 pycddl pyshacl rdflib
python3 tools/check-models/check_models.py         # CDDL + SHACL against vectors/, plus mutations
tools/fetch-lms/fetch_lms.sh [sha]              # recompile models/fhir from smart-trust-phw (needs network)
```

## Known issues

- OI-17: `DVCMin` is abstract upstream, but the example payloads are DVCMin.
- OI-36: the `s` binding points at a CodeSystem URL instead of a ValueSet
  (reported as smart-trust-phw#20, fix in smart-trust-phw#21).
- OI-19: these artefacts should eventually be generated and published by the
  smart-trust-phw IG build. The HCERT envelope CDDL belongs in smart-trust.
- OI-20: the CDDL validator used in CI (pycddl) deviates from RFC 8610.
  `tools/check-models/check_models.py` works around it so the CDDL stays spec-correct.
