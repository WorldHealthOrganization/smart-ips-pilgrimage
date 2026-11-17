import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "test-plan",
    title: "Library conformance test plan",
    description:
      "Write test/plans/hcert-library-conformance.test-plan.json (test-plan/v1) from the skills and the requirements' success criteria: one case per skill, one assertion per criterion verified by test. The plan any implementation of the library, Kotlin or Rust, runs.",
    install: { none: true },
    invoke: { shell: "python3 tools/test-plan/make_test_plan.py" },
    io: {
      inputs: [
        { name: "check", schema: t("Flag"), required: false, arg: { flag: "--check" }, description: "Write nothing; fail if the plan is stale." },
      ],
      outputs: [
        { name: "plan", schema: t("RepoPath"), description: "test/plans/hcert-library-conformance.test-plan.json." },
      ],
    },
    satisfies: ["hcert-conformance-testing"],
    selection: {
      when: "A requirement's success criteria or a skill's satisfies changed, or CI checks the plan is current.",
      limits: "Writes the library plan only; who-itb-agreement is authored by hand.",
      cost: "Milliseconds.",
    },
    requires: { runtime: ["python3"], network: false },
  }),
);
