<!-- GENERATED from smart-trust-tools/processes/content/hcert-issuance.bpmn by cat-harness-tools/scripts/bpmn-checklist.ts. Do not edit: change the diagram and regenerate (bun run cat bpmn:checklist). -->

# Checklist — Issue an HCERT QR code

> **Generated, and not the authority.** This is `smart-trust-tools/processes/content/hcert-issuance.bpmn` (process `Process_HcertIssuance`) walked as a state machine. The diagram and the workflow engine decide; this list only reads them. Follow the `next:` line of each step rather than the order on the page, and record each step with the call it names, so the engine's committed state — not this list — says which edge was taken.

QR Code Generation steps 1 to 9, as the library and its host divide them: the issuing system runs every step; the key holder only signs the bytes prepare returns, so the private key never enters the library (STT-ISS-004, STT-COS-006).

## Begin — A certificate is to be issued (`Start`)

- Begin here.
- Call `workflow_start` with `process: "Process_HcertIssuance"` and the subject this run is about; keep the instance id it returns.
- next: → `Task_SelectPayload` (Select the payload type and subclaim)

### 1. Select the payload type and subclaim (`Task_SelectPayload`)

- Who: the `HCERT issuing system` lane (role `hcert-issuing-system`).
- Skill: `hcert-select-payload`.
- What: Choose the logical model and the hcert subclaim for the use case from the registry QR Code Generation 2 defines: a DVC (key -6) when the certificate must verify offline, a VHL (key 5) when the records are larger than a QR code holds.
- Record it: `workflow_complete` with `node: "Task_SelectPayload"`.
- next: → `Task_AssemblePayload` (Assemble and validate the payload)

### 2. Assemble and validate the payload (`Task_AssemblePayload`)

- Who: the `HCERT issuing system` lane (role `hcert-issuing-system`).
- Skill: `hcert-assemble-payload`.
- What: Build the payload and validate it against its logical model (DVCMin, or the VHL payload), keeping elements the library does not know.
- Record it: `workflow_complete` with `node: "Task_AssemblePayload"`.
- next: → `Task_BuildCwt` (Build the CWT claim set)

### 3. Build the CWT claim set (`Task_BuildCwt`)

- Who: the `HCERT issuing system` lane (role `hcert-issuing-system`).
- Skill: `hcert-build-cwt`.
- What: Wrap the payload in a CWT claim set: iss, iat, exp inside the DSC's validity, and the payload at hcert (-260) under its subclaim.
- Record it: `workflow_complete` with `node: "Task_BuildCwt"`.
- next: → `Task_EncodeCbor` (Serialise as deterministic CBOR)

### 4. Serialise as deterministic CBOR (`Task_EncodeCbor`)

- Who: the `HCERT issuing system` lane (role `hcert-issuing-system`).
- Skill: `hcert-encode-cbor`.
- What: Serialise the claim set as RFC 8949 deterministic CBOR, so the same claims always give the same bytes.
- Record it: `workflow_complete` with `node: "Task_EncodeCbor"`.
- next: → `Task_Prepare` (Prepare the Sig_structure)

### 5. Prepare the Sig_structure (`Task_Prepare`)

- Who: the `HCERT issuing system` lane (role `hcert-issuing-system`).
- Skill: `hcert-sign-cose`.
- What: Build the COSE Sig_structure from the protected header (alg, kid = SHA-256 of the DSC, first 8 bytes) and the payload, and hand its bytes out to be signed.
- Record it: `workflow_complete` with `node: "Task_Prepare"`.
- next: → `Task_Sign` (Sign the bytes with the DSC key)

### 6. Sign the bytes with the DSC key (`Task_Sign`)

- Who: the `Signing key holder` lane (role `hcert-key-holder`).
- Skill: `hcert-sign-cose`.
- What: The key holder signs the Sig_structure bytes with the DSC private key (ES256, or PS256) and returns the raw signature.
- Record it: `workflow_complete` with `node: "Task_Sign"`.
- next: → `Task_Finish` (Attach the signature as COSE_Sign1)

### 7. Attach the signature as COSE_Sign1 (`Task_Finish`)

- Who: the `HCERT issuing system` lane (role `hcert-issuing-system`).
- Skill: `hcert-sign-cose`.
- What: Attach the returned signature to make the COSE_Sign1, checking it is the length the algorithm gives (64 bytes for ES256, r||s).
- Record it: `workflow_complete` with `node: "Task_Finish"`.
- next: → `Task_Compress` (Compress with ZLIB)

### 8. Compress with ZLIB (`Task_Compress`)

- Who: the `HCERT issuing system` lane (role `hcert-issuing-system`).
- Skill: `hcert-compress`.
- What: Compress the COSE_Sign1 with ZLIB/DEFLATE, after signing, never before.
- Record it: `workflow_complete` with `node: "Task_Compress"`.
- next: → `Task_Base45` (Encode as Base45)

### 9. Encode as Base45 (`Task_Base45`)

- Who: the `HCERT issuing system` lane (role `hcert-issuing-system`).
- Skill: `hcert-encode-base45`.
- What: Encode the compressed bytes as RFC 9285 Base45, the alphabet QR Alphanumeric mode stores compactly.
- Record it: `workflow_complete` with `node: "Task_Base45"`.
- next: → `Task_Prefix` (Prefix HC1:)

### 10. Prefix HC1: (`Task_Prefix`)

- Who: the `HCERT issuing system` lane (role `hcert-issuing-system`).
- Skill: `hcert-prefix-context`.
- What: Prefix the context identifier HC1: to make the QR-ready string.
- Record it: `workflow_complete` with `node: "Task_Prefix"`.
- next: → `Task_Render` (Render the QR code (Alphanumeric, EC Q))

### 11. Render the QR code (Alphanumeric, EC Q) (`Task_Render`)

- Who: the `HCERT issuing system` lane (role `hcert-issuing-system`).
- What: The application renders the HC1 string as a QR code in Alphanumeric mode, error correction Q, with its own QR encoder.
- Record it: `workflow_complete` with `node: "Task_Render"`.
- next: → `End` (QR-ready HC1 string)

## Done — QR-ready HC1 string (`End`)

- The instance completes here. `workflow_next` then reports nothing enabled — that, not this line, is the record of completion.
