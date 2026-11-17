// The release coordinates, derived from the repository's GitHub org: the
// instance declaration's "repository": "<org>/<name>" (smart-trust-tools.json)
// is their single source, so moving the repository to another org moves the
// Maven group, the npm scope and the crate name with it. The Gradle build
// derives the Maven group the same way; check-version.mjs checks they agree.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

export const repoRoot = fileURLToPath(new URL("../../", import.meta.url));
const declared = JSON.parse(readFileSync(join(repoRoot, "smart-trust-tools.json"), "utf8")).repository;
const m = /^([A-Za-z0-9-]+)\/([A-Za-z0-9._-]+)$/.exec(declared ?? "");
if (!m) throw new Error(`smart-trust-tools.json: "repository" must be "<org>/<name>", got ${JSON.stringify(declared)}`);

export const org = m[1];
export const repoName = m[2];
export const repoUrl = `https://github.com/${org}/${repoName}`;
export const homepage = `https://${org.toLowerCase()}.github.io/${repoName}/`;
/** Maven group: a namespace the org can verify on the Central Portal. */
export const mavenGroup = `io.github.${org.toLowerCase()}`;
/** npm scope: the org's. */
export const npmScope = `@${org.toLowerCase()}`;
/** crates.io has no namespaces, so the org is part of the crate's name; the Rust library itself stays `hcert`. */
export const crateName = `${org.toLowerCase()}-hcert`;
