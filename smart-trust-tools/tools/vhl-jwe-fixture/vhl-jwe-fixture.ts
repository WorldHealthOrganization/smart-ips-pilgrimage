import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "vhl-jwe-fixture",
    title: "Independent JWE fixture",
    description:
      "Make vectors/ihe-vhl/jwe-dir-a256gcm.json with node:crypto alone, so the library's RFC 7516 dir / A256GCM decryption (with and without zip DEF) is checked against an implementation that is not the library. TEST ONLY: the key is in the file.",
    install: { none: true },
    invoke: { shell: "node tools/vhl-jwe-fixture/make-jwe-fixture.mjs" },
    io: {
      inputs: [

      ],
      outputs: [
        { name: "fixture", schema: t("RepoPath"), description: "vectors/ihe-vhl/jwe-dir-a256gcm.json." },
      ],
    },
    satisfies: ["hcert-conformance-testing"],
    selection: {
      when: "The JWE fixture is lost or its format must change.",
      limits: "Random each run: the committed file is the vector, and re-running replaces it.",
      cost: "Milliseconds.",
    },
    requires: { runtime: ["node"], network: false },
  }),
);
