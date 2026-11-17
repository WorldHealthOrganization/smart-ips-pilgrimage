<!-- GENERATED from smart-trust-tools/processes/content/hcert-verification.bpmn by cat-harness-tools/scripts/bpmn-checklist.ts. Do not edit: change the diagram and regenerate (bun run cat bpmn:checklist). -->

# Checklist — Verify an HCERT QR code

> **Generated, and not the authority.** This is `smart-trust-tools/processes/content/hcert-verification.bpmn` (process `Process_HcertVerification`) walked as a state machine. The diagram and the workflow engine decide; this list only reads them. Follow the `next:` line of each step rather than the order on the page, and record each step with the call it names, so the engine's committed state — not this list — says which edge was taken.

QR Code Generation section 11 in the STT-VER-001 order.

## Begin — An HC1 QR code is scanned (`Start`)

- Begin here.
- Call `workflow_start` with `process: "Process_HcertVerification"` and the subject this run is about; keep the instance id it returns.
- next: → `Task_Decode` (Strip HC1:, Base45-decode and inflate)

### 1. Strip HC1:, Base45-decode and inflate (`Task_Decode`)

- Who: the `HCERT verifying system` lane (role `hcert-verifying-system`).
- Skill: `hcert-prefix-context`.
- What: Strip HC1: (refusing any other context), Base45-decode strictly and inflate within a size limit.
- Record it: `workflow_complete` with `node: "Task_Decode"`.
- next: → `Task_Parse` (Parse COSE_Sign1 and validate the protected header)

### 2. Parse COSE_Sign1 and validate the protected header (`Task_Parse`)

- Who: the `HCERT verifying system` lane (role `hcert-verifying-system`).
- Skill: `hcert-verify`.
- What: Parse the COSE_Sign1 within depth and size limits and check the protected header: a known alg, and a kid of 8 bytes.
- Record it: `workflow_complete` with `node: "Task_Parse"`.
- next: → `Task_Lookup` (Find every trusted DSC with the kid)

### 3. Find every trusted DSC with the kid (`Task_Lookup`)

- Who: the `HCERT verifying system` lane (role `hcert-verifying-system`).
- Skill: `hcert-trust-list`.
- What: Find every DSC in the host's trust list whose kid matches; more than one may, and each is tried.
- Record it: `workflow_complete` with `node: "Task_Lookup"`.
- next: → `Task_Check` (Check signature, key usage, CWT and time; dispatch the payload)

### 4. Check signature, key usage, CWT and time; dispatch the payload (`Task_Check`)

- Who: the `HCERT verifying system` lane (role `hcert-verifying-system`).
- Skill: `hcert-verify`.
- What: Verify the signature with each candidate, then the DSC's key usage for this payload type, the CWT's iat and exp against now, and dispatch the payload by subclaim.
- Record it: `workflow_complete` with `node: "Task_Check"`.
- next: → `End` (Verification result)

## Done — Verification result (`End`)

- The instance completes here. `workflow_next` then reports nothing enabled — that, not this line, is the record of completion.
