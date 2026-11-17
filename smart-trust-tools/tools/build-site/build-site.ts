import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "build-site",
    title: "Build the viewer pages",
    description:
      "Write the viewer pages that site.build serves under viewers/: the graph explorer and traceability matrix over this instance's nodes (requirements, library sections, external schemas, references, directives, skills, Tools, processes, roles and beans), the requirements document, the WIT contract, the TypeScript reference (TypeDoc), the Kotlin skeleton and the wire and payload models. Also copies docs/*.md into the Jekyll source (site_docs.sh).",
    install: { none: true },
    invoke: { shell: "bash tools/build-site/site_viewers.sh" },
    io: {
      inputs: [
        { name: "site", schema: t("RepoPath"), required: true, arg: { positional: 0 }, description: "The built site; pages are written to <site>/viewers/." },
      ],
      outputs: [
        { name: "viewers", schema: t("RepoPath"), description: "<site>/viewers/." },
      ],
    },
    satisfies: ["hcert-kg-publication"],
    selection: {
      when: "As the siteSteps of index.config.json's site.build recipe, when gh-pages is published by stage-local.",
      limits: "Reads the nodes as committed; does not validate them (check-req-nodes does).",
      cost: "Seconds, plus TypeDoc.",
    },
    requires: { runtime: ["python3", "node", "npm"], network: false },
  }),
);
