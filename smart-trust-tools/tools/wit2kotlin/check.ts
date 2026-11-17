/**
 * The WIT contract parses and its Kotlin skeleton is current: the gate form
 * of wit2kotlin's own `--check`.
 *
 * @module smart-trust-tools/tools/wit2kotlin/check
 * @covers hcert-contract
 *
 * `wit2kotlin.py --check` parses every interface of api/wit, renders the
 * Kotlin skeleton in memory and fails when tools/hcert-kotlin/hcert-api
 * differs, so a WIT change that does not parse, or that was not carried to
 * the skeleton, fails here. Python standard library only.
 *
 *   bun tools/wit2kotlin/check.ts
 */
import { spawnSync } from "node:child_process";
import { join } from "node:path";

const r = spawnSync("python3", [join(import.meta.dir, "wit2kotlin.py"), "--check"], { stdio: "inherit" });
process.exit(r.status ?? 1);
