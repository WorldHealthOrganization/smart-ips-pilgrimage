---
title: Releasing the libraries
nav_order: 3
---

# Releasing the libraries

How an agent publishes the HCERT libraries (STT-NFR-002) once the owner has
supplied credentials. Nothing is published yet. **No GitHub workflow
publishes and no workflow holds a credential**: CI runs only the dry runs
below, in the `check`, `kotlin` and `rust` jobs of
`.github/workflows/requirements-kg.yml`. An agent runs the commands here, from
a clean checkout of the release tag, and stops at the first failure.

## What is published

One version for all of them, from [`VERSION`](https://github.com/litlfred/smart-trust-tools/blob/main/VERSION) (STT-NFR-001), with
an entry in [`CHANGELOG.md`](https://github.com/litlfred/smart-trust-tools/blob/main/CHANGELOG.md) that cites each smart-trust
`changes.md` entry it implements.

| Registry | Coordinates | Built by |
|---|---|---|
| Maven Central | `io.github.litlfred:hcert-api`, `io.github.litlfred:hcert-core` (Kotlin Multiplatform: the root module, plus `-jvm` and `-js`) | `gradle -p tools/hcert-kotlin publishDryRun` |
| crates.io | `litlfred-hcert` (library name `hcert`) | `cargo package` in `tools/hcert-rust` |
| npm | `@litlfred/hcert-kotlin-js` (Kotlin/JS ES module) | `tools/release-packaging/assemble-npm.mjs` |
| npm | `@litlfred/hcert-component` (the Rust WebAssembly component, transpiled with jco) | `tools/hcert-rust/build-component.sh`, then `assemble-npm.mjs` |

**The coordinates follow the repository's GitHub org** (the owner's decision of
2026-10-23). Their single source is `"repository": "<org>/<name>"` in
`smart-trust-tools.json`: the Maven group is `io.github.<org>` (a namespace
the org can verify on the Sonatype Central Portal through GitHub), the npm
scope is `@<org>`, and the crate is `<org>-hcert`, because crates.io has no
namespaces (the Rust library itself stays `hcert`). The Gradle build and
`tools/release-packaging/coordinates.mjs` derive them; `check-version.mjs`
fails if `Cargo.toml`, a POM or a `package.json` disagrees. Moving the
repository to another org (say, WorldHealthOrganization) means changing that
one field, renaming the crate in `Cargo.toml` and `Cargo.lock` as the check
asks, and verifying the new namespaces below. The Kotlin package root stays
`who.smart.trust`. Android uses the `-jvm` jar as it is; there is no AAR until
an `androidTarget()` exists.

## Once, before the first release

1. **Licence.** Apache-2.0 (the owner's decision of 2026-10-23; OI-14).
   `LICENSE` is the official text from apache.org (sha256 `cfc7749b…3d30`);
   the crate ships its copy `tools/hcert-rust/LICENSE` (the check requires it
   to be identical), `assemble-npm.mjs` copies it into each npm package, and
   every jar carries it as `META-INF/LICENSE`.
2. **Maven Central.** Sign in to <https://central.sonatype.com> with the
   `litlfred` GitHub account; the `io.github.litlfred` namespace is verified by
   that. Generate a user token (*View Account → Generate User Token*): it is a
   name and a password, `CENTRAL_TOKEN_USER` and `CENTRAL_TOKEN_PASS` below.
3. **Signing key.** Central requires an OpenPGP signature on every file.
   Generate a key for releases, then publish its public half:
   ```sh
   gpg --quick-gen-key "Carl Leitner (smart-trust-tools releases)" ed25519 sign 2y
   gpg --list-secret-keys --keyid-format long         # note the key id, KEYID below
   gpg --keyserver keys.openpgp.org --send-keys KEYID
   gpg --keyserver keyserver.ubuntu.com --send-keys KEYID
   ```
   The key stays on the owner's machine (or a hardware token). No key, token
   or passphrase is ever committed or given to a workflow.
4. **crates.io.** Sign in with GitHub at <https://crates.io>, verify an
   e-mail address, and create an API token scoped to `publish-new` and
   `publish-update` for the crate `litlfred-hcert` (`CARGO_REGISTRY_TOKEN`).
5. **npm.** The packages are scoped to the npm user `litlfred`. Create a
   granular access token with read and write on `@litlfred/*` (`NPM_TOKEN`),
   with two-factor authentication on the account.

## Pre-release checks

From the repository root, on `main`, with a clean tree:

```sh
git status --porcelain                         # must print nothing
git log -1 --format=%H origin/main             # must equal HEAD; CI green on it
cat VERSION                                    # the version to release, no pre-release suffix
```

1. Set the version, if it changes, in the three places that hold it, then let
   Cargo update its own entry in the lock (no other crate moves):
   ```sh
   echo 0.1.0 > VERSION
   sed -i 's/^version = ".*"/version = "0.1.0"/' tools/hcert-rust/Cargo.toml   # the [package] version, the only line it matches
   (cd tools/hcert-rust && cargo update --workspace --offline)
   ```
2. In `CHANGELOG.md`, replace `— unreleased` in the version's heading with the
   date (`## [0.1.0] — 2026-11-02`), make sure every wire-format or
   subclaim-default change cites its smart-trust `changes.md` entry, and point
   the link at the tag (`[0.1.0]: https://github.com/litlfred/smart-trust-tools/releases/tag/v0.1.0`).
   A wire-format or subclaim-default change needs a major or minor bump.
3. Run the checks CI runs, and the dry runs:
   ```sh
   node tools/release-packaging/check-version.mjs
   bun run check:req-nodes
   python3 tools/test-plan/make_test_plan.py --check
   python3 tools/wit2kotlin/wit2kotlin.py --check
   gradle -p tools/hcert-kotlin --no-daemon compileKotlinJvm compileKotlinJs :hcert-core:jvmTest :hcert-core:jvmTestCoverageCheck :hcert-core:compileProductionLibraryKotlinJs
   (cd tools/hcert-rust && cargo test --locked && cargo test --locked --features qr --test api)
   ```
4. Commit (`Release 0.1.0`), push to `main` of `litlfred/smart-trust-tools`,
   wait for CI to pass on that commit, then tag it with a signed tag and push
   the tag:
   ```sh
   git tag -s v0.1.0 -m "smart-trust-tools 0.1.0"
   git push origin v0.1.0
   ```

Every artefact is then built from a fresh clone of the tag, never from a
working copy:

```sh
git clone --branch v0.1.0 --depth 1 https://github.com/litlfred/smart-trust-tools.git /tmp/stt-release
cd /tmp/stt-release
bun run cat mount:lock && bun install          # the mounted layers, for check:req-nodes
. toolchain/node_tools.sh                       # jco, from the lockfile, no install scripts
```

## Maven Central (Central Portal bundle upload)

1. Publish into the build-local repository and check the result. Every
   archive is reproducible (no timestamps, fixed order), so building the tag
   twice from a fresh clone gives the same jars, klibs, sources jars and POMs.
   The Kotlin Gradle plugin (2.0.21) writes the `org.gradle.libraryelements`
   attribute into `hcert-api`'s `.module` files or not depending on which
   tasks the build runs, so run exactly this command:
   ```sh
   gradle -p tools/hcert-kotlin --no-daemon publishDryRun
   node tools/release-packaging/check-version.mjs tools/hcert-kotlin/build/maven-dry-run
   ```
   `publishDryRun` lists, for each of `hcert-api`, `hcert-api-jvm`,
   `hcert-api-js`, `hcert-core`, `hcert-core-jvm` and `hcert-core-js`: the
   `.pom`, the `.module` (Gradle metadata), the main artefact (`.jar`, or
   `.klib` for `-js`), `-sources.jar`, `-javadoc.jar` (the module README; the
   KDoc is in the sources) and, for the root modules,
   `-kotlin-tooling-metadata.json`. Gradle writes `.md5`, `.sha1`, `.sha256`
   and `.sha512` beside each.
2. Sign every artefact (not the checksums, not `maven-metadata.xml`):
   ```sh
   repo=tools/hcert-kotlin/build/maven-dry-run
   find "$repo" -name 'maven-metadata.xml*' -delete
   find "$repo" -type f ! -name '*.md5' ! -name '*.sha1' ! -name '*.sha256' ! -name '*.sha512' \
     -exec gpg --local-user KEYID --armor --detach-sign {} \;
   find "$repo" -name '*.asc' -exec gpg --verify {} \;
   ```
3. Bundle the repository layout and upload it, as a deployment the owner
   releases by hand (`USER_MANAGED`):
   ```sh
   (cd "$repo" && zip -qrX ../central-bundle-0.1.0.zip io)
   token=$(printf '%s:%s' "$CENTRAL_TOKEN_USER" "$CENTRAL_TOKEN_PASS" | base64 -w0)
   curl --fail --request POST \
     --header "Authorization: Bearer $token" \
     --form bundle=@tools/hcert-kotlin/build/central-bundle-0.1.0.zip \
     "https://central.sonatype.com/api/v1/publisher/upload?name=smart-trust-hcert-0.1.0&publishingType=USER_MANAGED"
   # prints the deployment id
   curl --fail --request POST --header "Authorization: Bearer $token" \
     "https://central.sonatype.com/api/v1/publisher/status?id=DEPLOYMENT_ID"
   ```
   Wait for `"deploymentState": "VALIDATED"`; on `FAILED`, the response lists
   each problem. Then release it, which cannot be undone:
   ```sh
   curl --fail --request POST --header "Authorization: Bearer $token" \
     "https://central.sonatype.com/api/v1/publisher/deployment/DEPLOYMENT_ID"
   ```
   (or *Publish* on the deployment at <https://central.sonatype.com/publishing/deployments>).

## crates.io

```sh
cd tools/hcert-rust
cargo package --locked --list        # exactly: Cargo.toml, Cargo.lock, README.md, DEPENDENCIES.md, LICENSE, src/*.rs
cargo package --locked               # builds the .crate on its own, from target/package/litlfred-hcert-0.1.0
cargo publish --locked --dry-run
CARGO_REGISTRY_TOKEN=... cargo publish --locked
```

The tests are not in the crate: they read the shared vectors at
`../../vectors`, so they run from the repository. The `component` feature
reads the WIT contract at `../../api/wit` and so builds only from the
repository too; the component is published to npm instead. A crates.io
version cannot be replaced, only yanked (`cargo yank --version 0.1.0`).

## npm

```sh
tools/hcert-rust/build-component.sh /tmp/stt-component
gradle -p tools/hcert-kotlin --no-daemon :hcert-core:compileProductionLibraryKotlinJs
node tools/release-packaging/assemble-npm.mjs --out /tmp/stt-npm \
  --component /tmp/stt-component \
  --kotlin-js tools/hcert-kotlin/hcert-core/build/compileSync/js/main/productionLibrary/kotlin
node tools/release-packaging/check-version.mjs /tmp/stt-npm
node tools/conformance-ts/run.mjs rust /tmp/stt-npm/hcert-component     # the shipped files pass the suite
node tools/conformance-ts/run.mjs kotlin /tmp/stt-npm/hcert-kotlin-js
for p in hcert-component hcert-kotlin-js; do
  (cd /tmp/stt-npm/$p && npm pack --ignore-scripts --pack-destination /tmp/stt-npm)
done
sha256sum /tmp/stt-npm/*.tgz                                             # record in the release notes
```

Then publish the tarballs that were checked, not the directories (scoped
packages are private unless `--access public`):

```sh
printf '//registry.npmjs.org/:_authToken=%s\n' "$NPM_TOKEN" > /tmp/stt-npmrc
npm publish /tmp/stt-npm/litlfred-hcert-component-0.1.0.tgz --access public --ignore-scripts --userconfig /tmp/stt-npmrc --otp=CODE
npm publish /tmp/stt-npm/litlfred-hcert-kotlin-js-0.1.0.tgz --access public --ignore-scripts --userconfig /tmp/stt-npmrc --otp=CODE
rm /tmp/stt-npmrc
```

An npm version cannot be republished once used, even after `npm unpublish`.

## After publishing

1. Check that each coordinate resolves to the release (the STT-NFR-002
   success criterion):
   ```sh
   curl -sI https://repo1.maven.org/maven2/io/github/litlfred/hcert-core-jvm/0.1.0/hcert-core-jvm-0.1.0.pom | head -1
   curl -s https://crates.io/api/v1/crates/litlfred-hcert/0.1.0 | head -c 200
   npm view @litlfred/hcert-component@0.1.0 version
   npm view @litlfred/hcert-kotlin-js@0.1.0 version
   ```
   Maven Central can take up to an hour to show a released deployment.
2. Create the GitHub release for the tag with the changelog entry and the
   sha256 of each artefact.
3. Open the next entry at the top of `CHANGELOG.md`
   (`## [0.2.0] — unreleased`) and set `VERSION` and `Cargo.toml` to it in
   the same commit, so `check-version.mjs` keeps passing.
