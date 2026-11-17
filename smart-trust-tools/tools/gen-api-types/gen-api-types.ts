import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "gen-api-types",
    title: "TypeScript declarations from the WIT contract",
    description:
      "Run jco over api/wit to write the TypeScript view of the contract into api/generated/ts, the API reference that Node and browser callers read. jco comes from the pinned toolchain/node lockfile, installed with scripts disabled.",
    install: { none: true },
    invoke: { shell: "bash tools/gen-api-types/gen_api_types.sh" },
    io: {
      inputs: [

      ],
      outputs: [
        { name: "types", schema: t("RepoPath"), description: "api/generated/ts/." },
      ],
    },
    satisfies: ["hcert-contract-maintenance"],
    selection: {
      when: "api/wit changed, or CI re-generates the view and diffs it.",
      limits: "Types only: jco also validates the WIT package as it reads it, so a malformed contract fails here first.",
      cost: "Seconds after the one-off `npm ci --ignore-scripts`.",
    },
    requires: { runtime: ["node", "npm"], network: false },
  }),
);
