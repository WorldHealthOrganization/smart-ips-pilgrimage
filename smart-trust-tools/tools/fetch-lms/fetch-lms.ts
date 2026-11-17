import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "fetch-lms",
    title: "Fetch the FHIR logical models",
    description:
      "Fetch the DVCMin logical models as FHIR R5 StructureDefinitions from the smart-trust-phw build at the commit models/fhir/SOURCE.yaml pins, into models/fhir/.",
    install: { none: true },
    invoke: { shell: "bash tools/fetch-lms/fetch_lms.sh" },
    io: {
      inputs: [

      ],
      outputs: [
        { name: "models", schema: t("RepoPath"), description: "models/fhir/StructureDefinition-*.json." },
      ],
    },
    satisfies: ["hcert-contract-maintenance"],
    selection: {
      when: "The pinned smart-trust-phw commit moved, and the logical models must be refreshed before lm-derive.",
      limits: "Fetches only the files SOURCE.yaml lists; never resolves a branch at run time.",
      cost: "One download per model.",
    },
    requires: { runtime: ["bash", "node", "npm"], network: true },
    remedies: [
      { host: "github.com", none: "It clones smart-trust-phw at the pinned commit; without GitHub keep the committed models/fhir/, which lm-derive and check-models read." },
      { host: "packages.fhir.org", none: "SUSHI needs the FHIR R5 core package; without the registry keep the committed models/fhir/." },
    ],
  }),
);
