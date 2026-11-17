<!-- GENERATED from smart-trust-tools/processes/content/vhl-sharing.bpmn by cat-harness-tools/scripts/bpmn-checklist.ts. Do not edit: change the diagram and regenerate (bun run cat bpmn:checklist). -->

# Checklist — Share records by Verifiable Health Link

> **Generated, and not the authority.** This is `smart-trust-tools/processes/content/vhl-sharing.bpmn` (process `Process_VhlSharing`) walked as a state machine. The diagram and the workflow engine decide; this list only reads them. Follow the `next:` line of each step rather than the order on the page, and record each step with the call it names, so the engine's committed state — not this list — says which edge was taken.

Journeys J4.0 and J4.1: the sharer issues one passcode-protected VHL per family member; a clinic abroad verifies it, retrieves the manifest over mutual TLS (the host's HTTP) and decrypts the documents (IHE ITI-YY3 to ITI-YY5).

## Begin — A holder chooses records to share (`Start`)

- Begin here.
- Call `workflow_start` with `process: "Process_VhlSharing"` and the subject this run is about; keep the instance id it returns.
- next: → `Task_Key` (Generate the link key and encrypt each document)

### 1. Generate the link key and encrypt each document (`Task_Key`)

- Who: the `VHL sharer` lane (role `vhl-sharer`).
- Skill: `vhl-share`.
- What: Generate a 32-byte random key for the link and encrypt each document as JWE compact, dir / A256GCM.
- Record it: `workflow_complete` with `node: "Task_Key"`.
- next: → `Task_Link` (Issue the VHL payload as an HCERT (key 5, CBOR map))

### 2. Issue the VHL payload as an HCERT (key 5, CBOR map) (`Task_Link`)

- Who: the `VHL sharer` lane (role `vhl-sharer`).
- Skill: `vhl-share`.
- What: Issue the VHL payload (url, key, exp, flag, label) as a CBOR map at HCERT key 5, signed like any HCERT.
- Record it: `workflow_complete` with `node: "Task_Link"`.
- next: → `Task_VerifyLink` (Verify the VHL HCERT and its exp)

### 3. Verify the VHL HCERT and its exp (`Task_VerifyLink`)

- Who: the `VHL receiver` lane (role `vhl-receiver`).
- Skill: `hcert-verify`.
- What: Verify the VHL as an HCERT, and refuse a link whose exp has passed.
- Record it: `workflow_complete` with `node: "Task_VerifyLink"`.
- next: → `Task_Request` (Build and sign the ITI-YY5 manifest request)

### 4. Build and sign the ITI-YY5 manifest request (`Task_Request`)

- Who: the `VHL receiver` lane (role `vhl-receiver`).
- Skill: `vhl-receive`.
- What: Build the ITI-YY5 request: POST <url>/List/_search with the form body (passcode only when the P flag is set), its Content-Digest and its RFC 9421 HTTP Message Signature.
- Record it: `workflow_complete` with `node: "Task_Request"`.
- next: → `Task_Read` (Read the manifest Bundle and decrypt each document)

### 5. Read the manifest Bundle and decrypt each document (`Task_Read`)

- Who: the `VHL receiver` lane (role `vhl-receiver`).
- Skill: `vhl-receive`.
- What: Read the searchset Bundle the sharer returns and decrypt each document with the link key, accepting zip DEF.
- Record it: `workflow_complete` with `node: "Task_Read"`.
- next: → `End` (Documents read)

## Done — Documents read (`End`)

- The instance completes here. `workflow_next` then reports nothing enabled — that, not this line, is the record of completion.
