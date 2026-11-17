# AGENTS.md — smart-trust-tools

This file is agent-generic: Claude Code, Gemini CLI, Cursor, Copilot and others
read it natively. The harness's
[`AGENTS.md`](https://github.com/litlfred/cat-harness/blob/HEAD/AGENTS.md) applies
everywhere. [`README.md`](README.md) says what this repository *is*.

## What this instance is

This repository holds the requirements and contracts for the SMART Trust HCERT
API libraries: Kotlin first (targeting JVM, Android and Node), Rust second
(targeting WebAssembly). They are derived from the WHO SMART Trust
implementation guide (`WorldHealthOrganization/smart-trust`, including PR 129's
QR code generation page) and its logical models in `smart-trust-phw`. The
instance is a cat-harness downstream: `smart-trust-tools.json` declares it,
`needs: ["fhir-harness"]`. `index.config.json` pins the layers below it, and
`index.lock.json` records the exact mounts.

## Cold start

```sh
bun run cat mount:lock      # lay the pinned layers down from index.lock.json (gitignored)
bun install
bun run cat mount:remote:check
```

To change a pin, edit `index.config.json` and run `bun run cat mount:remote`
(`--plan` first to see what it would do; `--help` for the flags).

## Rules

- **Only litlfred repositories are changed from here.** WHO repositories
  (`smart-trust`, `smart-trust-phw`) and WHO's gh-pages are read-only. Report
  issues there; never push to them.
- **gh-pages is published by an agent, not a workflow.** main publishes to the
  root. Every other branch publishes to `STAGING/<branch-slug>/`. Never
  dispatch a GitHub workflow to publish.
- **The graph is cat-harness nodes, nothing else.** Requirements are `req:`
  nodes in `skills/requirements/`: `derivedFrom` names only the broader
  requirement a requirement specialises, and `reference` (FHIR R5
  `Requirements.reference`) what it is drawn from, each itself a node: a
  library section, an external schema, a reference, a `memory/` directive, a
  test vector, a smart-trust FHIR Requirements canonical. Skills `satisfy` them,
  Tools satisfy skills, BPMN processes and roles use skills, and open issues are
  beans. There is no second graph format. `bun run check:req-nodes` fails on an
  edge that names no node.
- **All code is in a Tool folder.** Every folder in `tools/` is one Tool,
  `tools/<id>/<id>.ts` (`defineTool`), with the code that is that Tool's alone
  beside it; `tools/hcert-kotlin/` is the Kotlin library. The pinned Node and
  Python toolchains several Tools share are in `toolchain/`.
- **Generated is never edited by hand.** `api/generated/`, `models/generated/`
  and `tools/hcert-kotlin/hcert-api/` are written by the Tools `gen-api-types`,
  `lm-derive` and `wit2kotlin`. Change the source (`api/wit/`, `api/cddl/`,
  `models/fhir/`) and re-run the Tool.
- **Every dependency is pinned and verified; nothing is resolved at run
  time.** Node tools come from `toolchain/node/package-lock.json` (`npm ci
  --ignore-scripts`, never `npx`), Python from the hashed
  `toolchain/python/requirements.txt` (`pip install --require-hashes --no-deps`),
  Gradle artifacts from `tools/hcert-kotlin/gradle/verification-metadata.xml`, the harness
  from `bun.lock` (bunfig `minimumReleaseAge`), and GitHub Actions by commit
  SHA. A new or bumped dependency is a release at least 14 days old, resolved
  with that cutoff (`npm --before`, `uv --exclude-newer`), and its install
  scripts never run. Prefer writing a small, well-specified piece (Base45,
  deterministic CBOR) over adding a package for it.
- **Only open standards.** Every normative reference must be openly available:
  IETF RFCs, W3C, HL7 FHIR, WHO. No paywalled ISO.
