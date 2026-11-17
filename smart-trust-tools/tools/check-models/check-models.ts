import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "check-models",
    title: "Check the vectors against the models",
    description:
      "Decode the smart-trust PR 129 certificate and validate its payload against the CDDL (api/cddl and models/generated) and, through the JSON-LD context, the SHACL shapes.",
    install: { none: true },
    invoke: { shell: "python3 tools/check-models/check_models.py" },
    io: {
      inputs: [

      ],
      outputs: [
        { name: "report", schema: t("Text"), description: "One line per check; exit 1 on any failure." },
      ],
    },
    satisfies: ["hcert-conformance-testing"],
    selection: {
      when: "The CDDL, the derived models or a vector changed.",
      limits: "Checks the wire format and the payload shape only; the signature, the trust list and the time checks are hcert-core's tests.",
      cost: "Seconds.",
    },
    requires: { runtime: ["python3"], network: false },
  }),
);
