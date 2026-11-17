import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "test-systems",
    title: "Systems under test and their bindings",
    description:
      "Write the bindings and uncovered lists of each test/systems/<id>.system.json (system/v1) from the tags in its tests: the requirement ids a Kotlin, Rust or TypeScript test's name starts with, or a script's \"Verifies\" sentence. Each assertion of a plan the system claims gets the tests that verify it, with the surface and target each runs on; each required assertion a declared target leaves unverified, and no `unbound` entry explains, is listed as uncovered.",
    install: { none: true },
    invoke: { shell: "python3 tools/test-systems/make_test_systems.py" },
    io: {
      inputs: [
        { name: "check", schema: t("Flag"), required: false, arg: { flag: "--check" }, description: "Write nothing; fail if a system file is stale or a tag names no requirement or criterion." },
      ],
      outputs: [
        { name: "systems", schema: t("RepoPath"), description: "test/systems/*.system.json, with bindings and uncovered rewritten." },
      ],
    },
    satisfies: ["hcert-conformance-testing"],
    selection: {
      when: "A test is added or renamed, a suite moves, a requirement's success criteria change, or CI checks the systems are current.",
      limits: "Reads tags, not results: a binding says which test verifies an assertion, not that it passed. A run records the verdict.",
      cost: "Under a second.",
    },
    requires: { runtime: ["python3"], network: false },
  }),
);
