import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "check-upstream-patches",
    title: "Check the upstream patches are well-formed",
    description:
      "Check every file under upstream/ (the upstream-patches graph, kept on the state branch cat/smart-trust-tools/upstream-patches and mounted by state:mount): each is a numbered git format-patch file, upstream/<target>/NNNN-<subject>.patch, with the mbox From line, an author, a date, a [PATCH] subject, a --- separator and at least one diff --git hunk.",
    install: { none: true },
    invoke: { shell: "bun tools/check-upstream-patches/check.ts" },
    io: {
      inputs: [

      ],
      outputs: [
        { name: "report", schema: t("Text"), description: "One line per problem; exit 1 on any, or when upstream/ is not mounted." },
      ],
    },
    satisfies: ["hcert-contract-maintenance"],
    selection: {
      when: "A patch for an upstream repository was added or changed.",
      limits: "Checks the patch's form, not that it applies: that needs the upstream tree at the commit the patch was made against, so the maintainers' apply is that test.",
      cost: "Under a second.",
    },
    requires: { runtime: ["bun"], network: false },
  }),
);
