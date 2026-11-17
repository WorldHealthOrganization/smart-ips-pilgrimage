import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "negative-vectors",
    title: "Shared negative test vectors",
    description:
      "Derive vectors/negative/negative-vectors.json from the smart-trust PR 129 certificates: one language-neutral file of inputs a conforming verifier must refuse, each with the step and reason it must stop at. The Kotlin suite, the Node smoke test and the Rust suite load the same file. Nothing is newly signed: each case changes a byte, a prefix, the clock or the trust list.",
    install: { none: true },
    invoke: { shell: "python3 tools/negative-vectors/make_negative_vectors.py" },
    io: {
      inputs: [
        { name: "check", schema: t("Flag"), required: false, arg: { flag: "--check" }, description: "Write nothing; fail if the file is stale." },
      ],
      outputs: [
        { name: "vectors", schema: t("RepoPath"), description: "vectors/negative/negative-vectors.json." },
      ],
    },
    satisfies: ["hcert-conformance-testing"],
    selection: {
      when: "A negative case is added, or the PR 129 vector changes.",
      limits: "Covers the steps reachable without a new signature; a case needing a new signer (a key usage mismatch, a missing hcert claim) stays in the Kotlin tests' testkit.",
      cost: "Milliseconds.",
    },
    requires: { runtime: ["python3"], network: false },
  }),
);
