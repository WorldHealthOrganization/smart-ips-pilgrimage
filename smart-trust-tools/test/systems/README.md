# Systems under test

Each file here is a `system/v1` node: one implementation of the library
contract (`api/wit/worlds.wit#hcert`) that can be run against a plan in
[`../plans/`](../plans/). This shape is the owner's decision D1 of
2026-10-24 ([cat-harness#552](https://github.com/litlfred/cat-harness/pull/552)).
It is tried here first (decision D5). The schema moves into cat-harness once
it is proven.

| File | System | Surfaces | Targets |
|---|---|---|---|
| [`hcert-kotlin.system.json`](hcert-kotlin.system.json) | the Kotlin Multiplatform library | the library; the Kotlin/JS package | jvm, node, android |
| [`hcert-rust.system.json`](hcert-rust.system.json) | the Rust library | the crate; the WebAssembly component (jco) | native, wasm32 |

An MCP server over the Rust library would be one more surface of
`hcert-rust`, with its own suite entry. The plan would not change.

## What is written by hand and what is generated

Written by hand: `id`, `title`, `kind`, `implements`, `actors`, `surfaces`,
`targets`, `plans` (the plans the system claims), `suites` (which test files
run on which surface and target) and `unbound` (an assertion or target that
no test verifies, **with the reason**).

Written by the `test-systems` Tool (`python3 tools/test-systems/make_test_systems.py`),
never by hand:

- `bindings`: for each assertion of a claimed plan, the tests that verify it,
  with the surface and target each runs on.
- `uncovered`: each required assertion, with the declared targets on which no
  test verifies it and that `unbound` does not explain.

CI runs `--check`. It fails when a file is stale, or when a tag names no
requirement or criterion. An uncovered assertion is listed, not failed.

## The tags are in the tests

This is decision D2. A test says what it verifies in its own code, so the map
cannot drift from the tests:

- **Kotlin, TypeScript:** the requirement ids the test's name starts with:
  `` `STT-VER-001 STT-VER-002 a tampered payload fails at the signature…` ``.
- **Rust:** the same, in snake case:
  `stt_ver_003_headers_are_checked_before_any_signature`.
- **A script that is a test as a whole** (a check, a smoke test, a coverage
  floor): a sentence starting with `Verifies` in its header,
  `# Verifies STT-TST-010/rust-floor.` Only a script may name the criterion
  after a `/`, because JVM test names cannot contain one.

A tag `STT-XXX-nnn` verifies the requirement's criterion with key `test`. If
there is no such key, it verifies the requirement's only criterion verified
by test. If there are several, it verifies the one whose key is a word of the
test's name: "the XXR certificates **verify** against…" verifies
`req:stt-tst-011#statement/verify`.

A suite whose surface and target are `*` does not depend on the
implementation (`check_models.py` validates the vectors against the
schemas). Its bindings count on every target.
