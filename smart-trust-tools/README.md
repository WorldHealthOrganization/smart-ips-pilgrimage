# smart-trust-tools

Requirements, API contract, wire format and payload models for the SMART Trust
HCERT and Verifiable Health Link libraries (Kotlin first, for the JVM, Android
and Node; Rust second, for WebAssembly), derived from the WHO SMART Trust
implementation guide. It is a cat-harness downstream (`smart-trust-tools.json`,
needs `fhir-harness`); [`AGENTS.md`](AGENTS.md) is the cold start.

## Viewers

**https://litlfred.github.io/smart-trust-tools/** is published to `gh-pages` by
an agent with `bun cat-harness-tools/scripts/stage-local.ts --repo .` (main to the root, other branches to
`STAGING/<branch>/`), never by a workflow. Its viewers, under `viewers/`, are
the graph explorer, the traceability matrix, the requirements, the WIT contract
with its TypeScript reference, the Kotlin API and the wire and payload models.

## The knowledge graph

Every part of the graph is a cat-harness node, declared in
`smart-trust-tools.json`:

- [`skills/requirements/`](skills/requirements/): one `req:` node per library
  requirement, each citing the sources below in `reference` and naming in
  `derivedFrom` the broader requirement it specialises.
- [`library/`](library/): the WHO SMART Trust, smart-trust-phw and IHE ITI VHL
  pages and FSH the requirements cite, ingested section by section at a pinned
  commit.
- [`external-schemas/`](external-schemas/), [`references/`](references/),
  [`memory/`](memory/): the open standards, other WHO guides and owner
  directives the requirements cite.
- [`skills/`](skills/): the HCERT pipeline steps, VHL and library maintenance
  as skills that `satisfy` the requirements;
  [`processes/`](processes/) and [`scenarios/roles.json`](scenarios/roles.json)
  put them in BPMN processes and roles.
- [`tools/`](tools/): one Tool per folder satisfying the skills, with its code:
  [`tools/hcert-kotlin/`](tools/hcert-kotlin/) is the Kotlin library; the others
  generate the contract's views, check the graph and the models, and build the
  viewers.
- [`api/`](api/) (the WIT contract and CDDL), [`models/`](models/) (FHIR
  logical models and what is derived from them) and [`vectors/`](vectors/)
  (test vectors): the schemas, each directory a kind of its own
  ([`typologies/`](typologies/)).
- `beans/`: the open issues, each naming the requirements and sources it
  affects, kept on the state branch
  [`cat/smart-trust-tools/beans`](https://github.com/litlfred/smart-trust-tools/tree/cat/smart-trust-tools/beans/beans/defs)
  (`bun run cat state:mount` puts it on disk).

The viewers draw these fields as edges under the harness's names (FHIR R5
Requirements): a requirement `references` what its `reference` names and is
`derivedFrom` the requirement its `derivedFrom` names; the
[node kinds page](https://litlfred.github.io/smart-trust-tools/viewers/kinds.html)
lists every kind and edge. `bun run check:req-nodes` fails if any edge names no node.
