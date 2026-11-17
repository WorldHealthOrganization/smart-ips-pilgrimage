import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "wit2kotlin",
    title: "Kotlin skeleton from the WIT contract",
    description:
      "Generate the Kotlin declarations in tools/hcert-kotlin/hcert-api from api/wit by fixed mapping rules: records to data classes, variants to sealed interfaces, resources to AutoCloseable interfaces, result<T, E> to HcertResult; worlds are not generated, and no Kotlin name or KDoc mentions WIT.",
    install: { none: true },
    invoke: { shell: "python3 tools/wit2kotlin/wit2kotlin.py" },
    io: {
      inputs: [
        { name: "check", schema: t("Flag"), required: false, arg: { flag: "--check" }, description: "Write nothing; fail if a generated file is stale." },
      ],
      outputs: [
        { name: "skeleton", schema: t("RepoPath"), description: "tools/hcert-kotlin/hcert-api/src/commonMain/kotlin/who/smart/trust/." },
      ],
    },
    satisfies: ["hcert-contract-maintenance"],
    selection: {
      when: "api/wit changed, or CI checks the Kotlin skeleton is current.",
      limits: "Reads the subset of WIT this contract uses; an unsupported construct is an error, not a guess. Writes declarations only, never behaviour.",
      cost: "Milliseconds; standard library only.",
    },
    requires: { runtime: ["python3"], network: false },
  }),
);
