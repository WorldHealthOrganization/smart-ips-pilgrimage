// One version and one set of coordinates for every artefact (STT-NFR-001,
// STT-NFR-002). The coordinates follow the repository's GitHub org
// (coordinates.mjs): the crate is <org>-hcert, the npm packages are under
// @<org>, the Maven group is io.github.<org>, and each artefact carries
// LICENSE. VERSION at the repository
// root is the source. This fails if it is not a semantic version, if
// tools/hcert-rust/Cargo.toml says otherwise, if the Gradle build stops
// reading it (or a module sets its own version), or if CHANGELOG.md has no
// entry for it. Each directory given is searched for built artefacts too:
// every package.json must carry the version, no dependencies and no scripts,
// and every .pom must carry the version.
//
//   node tools/release-packaging/check-version.mjs [<dist-or-repo-dir> ...]
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { crateName, mavenGroup, npmScope, repoRoot as repo, repoUrl } from "./coordinates.mjs";

const read = (p) => readFileSync(join(repo, p), "utf8");
const problems = [];

const version = read("VERSION").trim();
// semver.org 2.0.0, without build metadata (registries ignore it).
if (!/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$/.test(version)) {
  problems.push(`VERSION: "${version}" is not a semantic version`);
}

const cargo = read("tools/hcert-rust/Cargo.toml");
const pkg = cargo.split(/^\[/m).find((s) => s.startsWith("package]")) ?? "";
const cargoVersion = /^version\s*=\s*"([^"]*)"/m.exec(pkg)?.[1];
if (cargoVersion !== version) problems.push(`tools/hcert-rust/Cargo.toml: version ${cargoVersion} != VERSION ${version}`);
const cargoName = /^name\s*=\s*"([^"]*)"/m.exec(pkg)?.[1];
if (cargoName !== crateName) problems.push(`tools/hcert-rust/Cargo.toml: name ${cargoName} != ${crateName} (from the repository's org)`);
const cargoRepo = /^repository\s*=\s*"([^"]*)"/m.exec(pkg)?.[1];
if (cargoRepo !== repoUrl) problems.push(`tools/hcert-rust/Cargo.toml: repository ${cargoRepo} != ${repoUrl}`);
if (!/^\[lib\]\s*\nname\s*=\s*"hcert"/m.test(cargo)) problems.push("tools/hcert-rust/Cargo.toml: [lib] name must stay hcert");
const lock = read("tools/hcert-rust/Cargo.lock");
const lockVersion = new RegExp(`\\[\\[package\\]\\]\\nname = "${crateName}"\\nversion = "([^"]*)"`).exec(lock)?.[1];
if (lockVersion !== version) problems.push(`tools/hcert-rust/Cargo.lock: ${crateName} ${lockVersion} != VERSION ${version}`);
if (!existsSync(join(repo, "LICENSE"))) problems.push("LICENSE: missing");
else if (read("LICENSE") !== read("tools/hcert-rust/LICENSE")) problems.push("tools/hcert-rust/LICENSE: differs from LICENSE (the crate ships its own copy)");

const gradle = read("tools/hcert-kotlin/build.gradle.kts");
if (!gradle.includes('rootProject.file("../../VERSION").readText().trim()')) {
  problems.push("tools/hcert-kotlin/build.gradle.kts: no longer reads ../../VERSION");
}
for (const m of ["hcert-api", "hcert-core"]) {
  if (/^\s*version\s*=/m.test(read(`tools/hcert-kotlin/${m}/build.gradle.kts`))) {
    problems.push(`tools/hcert-kotlin/${m}/build.gradle.kts: sets its own version; VERSION is the only source`);
  }
}

const changelog = read("CHANGELOG.md");
if (!new RegExp(`^## \\[${version.replace(/\./g, "\\.")}\\]`, "m").test(changelog)) {
  problems.push(`CHANGELOG.md: no "## [${version}]" entry`);
}

function* files(dir, depth) {
  for (const n of readdirSync(dir).sort()) {
    const p = join(dir, n);
    if (statSync(p).isDirectory()) {
      if (depth > 0 && n !== "node_modules") yield* files(p, depth - 1);
    } else yield p;
  }
}
let artefacts = 0;
for (const dir of process.argv.slice(2)) {
  if (!existsSync(dir)) { problems.push(`${dir}: no such directory`); continue; }
  for (const f of files(dir, 8)) {
    if (f.endsWith("/package.json")) {
      artefacts++;
      const j = JSON.parse(readFileSync(f, "utf8"));
      if (j.version !== version) problems.push(`${f}: version ${j.version} != VERSION ${version}`);
      if (!j.name?.startsWith(`${npmScope}/`)) problems.push(`${f}: name ${j.name} is not under ${npmScope}`);
      if (!existsSync(join(f, "..", "LICENSE"))) problems.push(`${f}: no LICENSE beside it`);
      for (const k of ["dependencies", "peerDependencies", "optionalDependencies", "scripts"]) {
        if (j[k] && Object.keys(j[k]).length) problems.push(`${f}: has ${k}`);
      }
    } else if (f.endsWith(".pom")) {
      artefacts++;
      const pom = readFileSync(f, "utf8");
      const v = /<artifactId>[^<]*<\/artifactId>\s*<version>([^<]*)<\/version>/.exec(pom)?.[1];
      if (v !== version) problems.push(`${f}: version ${v} != VERSION ${version}`);
      const g = /<groupId>([^<]*)<\/groupId>/.exec(pom)?.[1];
      if (g !== mavenGroup) problems.push(`${f}: groupId ${g} != ${mavenGroup}`);
    }
  }
}

if (problems.length) {
  for (const p of problems) console.error(`FAIL ${p}`);
  process.exit(1);
}
console.log(`ok   version ${version} (${crateName}, ${npmScope}/*, ${mavenGroup}): VERSION, Cargo.toml, Cargo.lock, Gradle, CHANGELOG.md, LICENSE${artefacts ? `, ${artefacts} built artefact(s)` : ""}`);
