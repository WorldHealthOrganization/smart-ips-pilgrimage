import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "fhir-validate",
    title: "Validate the FHIR logical models",
    description:
      "Run the HL7 FHIR Validator (validator_cli.jar) on the StructureDefinitions in models/fhir against the FHIR version they declare, with the jar and every FHIR package pinned by sha256 in toolchain/fhir-validator/validator.json, verified before use, and no fetch at run time (-no-http-access, -tx n/a). The site's pre step: it runs when the site is published to main and says it is not run for a staging preview.",
    install: { none: true },
    invoke: { shell: "python3 tools/fhir-validate/fhir_validate.py" },
    io: {
      inputs: [
        { name: "site", schema: t("Flag"), required: false, arg: { flag: "--site" }, description: "As the site's pre step: run only when SITE_BASEURL is the root's (main), not a STAGING preview's." },
        { name: "always", schema: t("Flag"), required: false, arg: { flag: "--always" }, description: "Run regardless of the build." },
      ],
      outputs: [
        { name: "report", schema: t("Text"), description: "The validator's messages per StructureDefinition; exit 1 on an error, an unpinned artefact or a sha256 mismatch." },
      ],
    },
    satisfies: ["hcert-contract-maintenance"],
    selection: {
      when: "The site is published to main, or a logical model in models/fhir changed and should be checked against FHIR itself.",
      limits: "Validates the StructureDefinitions as FHIR resources, without a terminology server; whether they map to the payload models is lm-derive's check. Refuses to run while any package validator.json lists has no sha256.",
      cost: "About a minute; the first run downloads the 200 MB jar and the packages into the cache.",
    },
    requires: { runtime: ["python3", "java", "curl"], network: true },
    remedies: [
      { host: "github.com", none: "The jar is a release asset; place a copy with the pinned sha256 at the cache path the error names." },
      { host: "registry.npmjs.org", none: "Place each package tarball with its pinned sha256 at the cache path the error names." },
      { host: "packages.fhir.org", none: "Place each package tarball with its pinned sha256 at the cache path the error names." },
    ],
  }),
);
