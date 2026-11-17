import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "lm-derive",
    title: "Payload models from the FHIR logical models",
    description:
      "Derive, from the FHIR logical models in models/fhir, the JSON-LD context, SHACL shapes and CDDL rules in models/generated/ that the payload codecs and the conformance checks read.",
    install: { none: true },
    invoke: { shell: "python3 tools/lm-derive/lm_derive.py" },
    io: {
      inputs: [
        { name: "check", schema: t("Flag"), required: false, arg: { flag: "--check" }, description: "Write nothing; fail if a generated file is stale." },
      ],
      outputs: [
        { name: "models", schema: t("RepoPath"), description: "models/generated/trust-phw.{context.jsonld,shacl.ttl,cddl}." },
      ],
    },
    satisfies: ["hcert-contract-maintenance"],
    selection: {
      when: "A logical model changed, or CI checks the derived models are current.",
      limits: "Maps kind=logical FHIR 5.0.0 models: direct elements of a FHIR primitive or model type, cardinality, bindings, codes, and \"a.exists() or b.exists()\" invariants. Anything else (a nested element, another type, a choice, a profile, an element invariant, another expression) is an error naming the model and element, in both modes, unless tools/lm-derive/allow-unmapped.json excuses it with a reason.",
      cost: "Milliseconds.",
    },
    requires: { runtime: ["python3"], network: false },
  }),
);
