<!-- GENERATED from smart-trust-tools/processes/content/hcert-contract-change.bpmn by cat-harness-tools/scripts/bpmn-checklist.ts. Do not edit: change the diagram and regenerate (bun run cat bpmn:checklist). -->

# Checklist — Change the library contract

> **Generated, and not the authority.** This is `smart-trust-tools/processes/content/hcert-contract-change.bpmn` (process `Process_HcertContractChange`) walked as a state machine. The diagram and the workflow engine decide; this list only reads them. Follow the `next:` line of each step rather than the order on the page, and record each step with the call it names, so the engine's committed state — not this list — says which edge was taken.

A WHO or IHE specification changed, or an open issue (bean) was resolved: the maintainer amends the requirements and the WIT or CDDL, regenerates what is derived from them, tests both implementations against the shared vectors, and publishes the graph.

## Begin — A source specification changed (`Start`)

- Begin here.
- Call `workflow_start` with `process: "Process_HcertContractChange"` and the subject this run is about; keep the instance id it returns.
- next: → `Task_Requirements` (Amend the requirements within the architecture rules)

### 1. Amend the requirements within the architecture rules (`Task_Requirements`)

- Who: the `Library maintainer` lane (role `library-maintainer`).
- Skill: `hcert-library-architecture`.
- What: Change the req: nodes in skills/requirements/ within the architecture rules (one contract, a synchronous core with no I/O, open standards only), citing the changed source by reference.
- Record it: `workflow_complete` with `node: "Task_Requirements"`.
- next: → `Task_Contract` (Change the WIT or CDDL and regenerate its views)

### 2. Change the WIT or CDDL and regenerate its views (`Task_Contract`)

- Who: the `Library maintainer` lane (role `library-maintainer`).
- Skill: `hcert-contract-maintenance`.
- What: Change api/wit or api/cddl, then run wit2kotlin, gen-api-types and, if a logical model moved, fetch-lms and lm-derive.
- Record it: `workflow_complete` with `node: "Task_Contract"`.
- next: → `Task_Test` (Test against the shared vectors)

### 3. Test against the shared vectors (`Task_Test`)

- Who: the `Library maintainer` lane (role `library-maintainer`).
- Skill: `hcert-conformance-testing`.
- What: Run check-models and the hcert-core tests on the JVM and Node against the shared vectors.
- Record it: `workflow_complete` with `node: "Task_Test"`.
- next: → `Task_Publish` (Check the graph and publish the site)

### 4. Check the graph and publish the site (`Task_Publish`)

- Who: the `Library maintainer` lane (role `library-maintainer`).
- Skill: `hcert-kg-publication`.
- What: Run check-req-nodes, then publish gh-pages with stage-local: main to the root, a branch to STAGING.
- Record it: `workflow_complete` with `node: "Task_Publish"`.
- next: → `End` (Contract published)

## Done — Contract published (`End`)

- The instance completes here. `workflow_next` then reports nothing enabled — that, not this line, is the record of completion.
