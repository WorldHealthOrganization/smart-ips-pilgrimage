import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "release-packaging",
    title: "Release packaging (dry run)",
    description:
      "Assemble the two npm packages of the libraries, @litlfred/hcert-component (the jco-transpiled Rust component) and @litlfred/hcert-kotlin-js (the Kotlin/JS library), from their build outputs, each with a package.json that has the VERSION, no dependencies and no scripts; and check that VERSION, the single version source, is a semantic version that Cargo.toml, Cargo.lock, the Gradle build, CHANGELOG.md and every built package.json and POM agree with. The Maven dry run is the hcert-kotlin build's publishDryRun task and the crate's is cargo package; docs/RELEASING.md is the runbook an agent follows to publish.",
    install: { none: true },
    invoke: { shell: "node tools/release-packaging/check-version.mjs" },
    io: {
      inputs: [
        { name: "artefacts", schema: t("RepoPath"), required: false, arg: { positional: 0 }, description: "A directory of built artefacts (the npm dist directory, the Maven dry-run repository) whose package.json and .pom versions are checked too." },
      ],
      outputs: [
        { name: "packages", schema: t("RepoPath"), description: "With assemble-npm.mjs --out <dist>: <dist>/hcert-component and <dist>/hcert-kotlin-js, ready for npm pack." },
      ],
    },
    satisfies: ["hcert-library-architecture"],
    selection: {
      when: "Before a release, or in CI: the version must agree everywhere and every artefact must package, without publishing.",
      limits: "Publishes nothing and holds no credentials: an agent publishes by docs/RELEASING.md, never a workflow. No Android AAR (the JVM jar serves Android until an androidTarget exists). The crate leaves out the tests, which read ../../vectors, and its `component` feature, which reads ../../api/wit, builds only from the repository.",
      cost: "Milliseconds, once the libraries are built.",
    },
    requires: { runtime: ["node"], network: false },
  }),
);
