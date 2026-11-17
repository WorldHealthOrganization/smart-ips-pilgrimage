# AGENTS.md — smart-ips-pilgrimage

This file is agent-generic: Claude Code, Gemini CLI, Cursor, Copilot and others
read it natively. What binds everywhere is the harness's
[`AGENTS.md`](https://github.com/litlfred/cat-harness/blob/HEAD/AGENTS.md); what
this repository *is* is [`README.md`](README.md).

## What this instance is

The SMART Verifiable IPS for Pilgrimage implementation guide: FHIR IG source
under `input/`, built by the IG Publisher. It takes the `smart-trust` /
`smart-trust-phw` shape (owner, 2026-11-01 09:02Z, card Q-VC-8 A, issue #6).
It has no harness of its own: `index.config.json` mounts `smart-base` and the
layers below it, and `smart-ips-pilgrimage.json` declares what an index may
mount from here.

## The one rule

**The mounted graphs are generated from the IG's AST at publish, never authored.**
`fhir-artifact-index/` is not committed: fhir-harness's `ig-index:build`
writes its `index.json`, `menu.json`, `releases.json` and `package.tgz` at
publish from the IG's AST (fhir-harness#124), so never commit, hand-edit or
re-ingest them. `document-kinds/` holds this IG's DAK coverage report,
generated at publish from `fhir-artifact-index/` by `smart-base:document-kinds`.

## What an index mounts from here

`fhir-artifact-index/` and `document-kinds/`, plus this file and the README as
declared assets. The IG source (`input/`) is not mounted. Neither is `docs/`,
which is built at publish by `smart-ips-pilgrimage:pages` (fhir-harness's
`gen-ig-pages.ts`) and never committed. `fhir-ast/` is restored from its cache
branch by `ig-cache.sh`.

## Builds

The WHO IG builds inherited from upstream (`ghbuild.yml`, `fhirbuild.yml`,
`release.yml`) run only by hand (`workflow_dispatch`). The checks on every pull
request are `harness-pr-checks.yml`.

## Before running SUSHI

Read fhir-harness's
[`fhir-validation`](https://github.com/litlfred/fhir-harness/blob/main/skills/content/fhir-ig-authoring/fhir-validation.md#when-a-package-host-refuses-you)
§"When a package host refuses you" first.

## Translations

The harness's generic process is
[`translation-refresh`](https://github.com/litlfred/cat-harness/blob/HEAD/skills/library/library-core/translation-refresh.md)
and `translation-manager` §"Translating into several locales as a team"; this
section names what that skill leaves to the instance. Locales: ar, es, fr, ru,
zh, all unofficial (agent, no human sign-off). Each locale is its own PR to
main.

| step | here |
|---|---|
| templates | `bun input/scripts/translation-pot.ts` (`--check` in CI): `input/pagecontent/` and the BPMN of the IG into `translations/<locale>/{pagecontent,processes}/` |
| new and obsolete strings | `bun input/scripts/po-status.ts --merge` appends new msgids empty and keeps obsolete ones as `#~`; without `--merge` it reports |
| FHIR terms | one CodeSystem supplement per locale, `input/fsh/translations/<locale>.fsh`; never edit a resource's own text |

`.github/workflows/translations.yml` runs the template check, the officiality
check and `po-status --github`. Merge policy: **merge-when-green** (owner, 2026-11-07). A
refresh run merges its own refresh PR only when every check is green and the
untainted round trip on the changed strings records no fail; anything red,
uncertain or failing is left open and reported to the owner. Merging is not
sign-off: the translations stay unofficial.
