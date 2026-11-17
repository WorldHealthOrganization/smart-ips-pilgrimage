import { toolFactory } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";
import { defineTool } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";

export default toolFactory((t) =>
  defineTool({
    id: "hcert-kotlin",
    title: "HCERT and VHL library (Kotlin Multiplatform)",
    description:
      "The Kotlin implementation of the HCERT pipeline and Verifiable Health Links, for the JVM (Android as-is) and Node: `hcert-api`, the declarations wit2kotlin generates from the WIT contract, and `hcert-core`, the behaviour (deterministic CBOR, COSE_Sign1 ES256/PS256, ZLIB, Base45, HC1, the trust list, verification, the VHL payload, the ITI-YY5 manifest request and JWE dir/A256GCM). No third-party runtime dependency; every build artefact is pinned in gradle/verification-metadata.xml.",
    install: { none: true },
    invoke: { shell: "gradle -p tools/hcert-kotlin --dependency-verification strict build" },
    io: {
      inputs: [
        { name: "task", schema: t("Slug"), required: false, arg: { positional: 0 }, description: "A Gradle task instead of `build`, for example `:hcert-core:jvmTest` or `:hcert-core:compileProductionLibraryKotlinJs`." },
      ],
      outputs: [
        { name: "libraries", schema: t("RepoPath"), description: "The JVM jars and the Kotlin/JS ES module under each module's build/." },
      ],
    },
    satisfies: ["hcert-select-payload", "hcert-assemble-payload", "hcert-build-cwt", "hcert-encode-cbor", "hcert-sign-cose", "hcert-compress", "hcert-encode-base45", "hcert-prefix-context", "hcert-verify", "hcert-trust-list", "vhl-share", "vhl-receive", "hcert-library-architecture"],
    selection: {
      when: "An application on the JVM, Android or Node issues, verifies or reads an HCERT, or shares or receives a VHL; or a change to the contract or the core is built and tested.",
      limits: "No QR rendering (the host renders the HC1 string), no HTTP (the host sends the ITI-YY5 request it builds), no key storage (the host signs the bytes prepare-sign returns). Rust (native and WebAssembly) is the second implementation, in tools/hcert-rust.",
      cost: "About a minute cold for the JVM and JS tests; Gradle downloads only artefacts the verification metadata lists.",
    },
    requires: { runtime: ["gradle", "java"], network: true },
    remedies: [
      { host: "repo.maven.apache.org", error: "429", none: "Re-run through Google's mirror of Maven Central: `--init-script gradle/central-mirror.init.gradle`. The verification metadata still pins every artefact's sha256, so the mirror is trusted for nothing." },
      { host: "plugins.gradle.org", none: "The Kotlin plugins are also on Maven Central; the same mirror init script serves them." },
    ],
  }),
);
