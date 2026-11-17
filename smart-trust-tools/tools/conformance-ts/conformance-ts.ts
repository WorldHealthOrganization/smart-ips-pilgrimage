import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "conformance-ts",
    title: "One TypeScript conformance suite for both libraries",
    description:
      "suite.ts: 45 checks over every interface of the `hcert` world, type-checked (tsc, toolchain/node) against api/generated/ts, the TypeScript jco derives from the WIT contract, and driven by the shared vectors. run.mjs runs it against the Kotlin/JS package (hcert-core's WitJs facade) or the jco-transpiled Rust component; each loader only regroups its package's exports under the interface names. Both must pass (STT-TST-007). cross.mjs loads both and runs cross.ts: each library verifies the other's ES256 and PS256 certificates, built from byte-identical Sig_structures (STT-TST-003, STT-GEN-006).",
    install: { none: true },
    invoke: { shell: "node tools/conformance-ts/run.mjs" },
    io: {
      inputs: [
        { name: "implementation", schema: t("Slug"), required: true, arg: { positional: 0 }, description: "rust or kotlin." },
        { name: "dir", schema: t("RepoPath"), required: true, arg: { positional: 1 }, description: "rust: the directory build-component.sh wrote; kotlin: hcert-core's build/compileSync/js/main/productionLibrary/kotlin." },
      ],
      outputs: [
        { name: "report", schema: t("Text"), description: "One line per check; exit 1 on any failure." },
      ],
    },
    satisfies: ["hcert-conformance-testing"],
    selection: {
      when: "Either library or the WIT contract changed, or CI checks that the two implementations behave the same.",
      limits: "Runs on Node 22.18 or later (type stripping); the type check needs toolchain/node's tsc. Signs with node:crypto through the fixtures, so the suite itself has no Node types.",
      cost: "Seconds, once both libraries are built.",
    },
    requires: { runtime: ["node"], network: false },
  }),
);
