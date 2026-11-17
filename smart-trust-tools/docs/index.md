---
title: SMART Trust HCERT library tools
nav_order: 1
---

# SMART Trust HCERT library tools

Requirements and contracts for the SMART Trust HCERT API libraries: Kotlin first
(JVM, Android, Node), Rust second (WebAssembly). They are derived from the WHO
SMART Trust implementation guide, in particular the QR Code Generation page of
[WorldHealthOrganization/smart-trust#129](https://github.com/WorldHealthOrganization/smart-trust/pull/129).

## Viewers

| Viewer | What it shows |
|---|---|
| [Overview](viewers/index.html) | The viewers' own landing page, with counts and the pipeline |
| [Graph explorer](viewers/explorer.html) | The requirements knowledge graph, grouped and drillable |
| [Traceability matrix](viewers/trace.html) | Every requirement against its sources, skills, contract items (WIT, CDDL) and open issues |
| [Requirements](viewers/requirements.html) | The library requirements (cat-harness `req:` nodes), each with every edge of the graph |
| [API contract](viewers/api.html) | The library API in WIT, with its TypeScript reference |
| [Wire and payload models](viewers/models.html) | CDDL wire format; JSON-LD, SHACL and CDDL from the FHIR logical models |
| [Kotlin skeleton](viewers/kotlin.html) | The Kotlin Multiplatform API generated from the WIT |
| [Node kinds](viewers/kinds.html) | Which cat-harness nodes the graph is read from, and the field each edge comes from |
| [User journeys](journeys.html) | What the library does for each step of journeys J1 to J4, and the gaps |

## Sources

Every part of the graph is a cat-harness node of this instance:

- requirements: [`skills/requirements/`](https://github.com/litlfred/smart-trust-tools/tree/main/skills/requirements), one `req:` node per `STT-<AREA>-nnn`, each citing what it is drawn from in `reference`;
- what they cite: [`library/`](https://github.com/litlfred/smart-trust-tools/tree/main/library) (WHO SMART Trust, smart-trust-phw and IHE ITI VHL, section by section at pinned commits), [`external-schemas/`](https://github.com/litlfred/smart-trust-tools/tree/main/external-schemas), [`references/`](https://github.com/litlfred/smart-trust-tools/tree/main/references) and [`memory/`](https://github.com/litlfred/smart-trust-tools/tree/main/memory);
- what realizes them: the skills in [`skills/`](https://github.com/litlfred/smart-trust-tools/tree/main/skills), the Tools in [`tools/`](https://github.com/litlfred/smart-trust-tools/tree/main/tools) (the Kotlin library is `tools/hcert-kotlin/`), and the processes in [`processes/content/`](https://github.com/litlfred/smart-trust-tools/tree/main/processes/content);
- open issues: the beans in [`beans/defs/`](https://github.com/litlfred/smart-trust-tools/tree/cat/smart-trust-tools/beans/beans/defs).
