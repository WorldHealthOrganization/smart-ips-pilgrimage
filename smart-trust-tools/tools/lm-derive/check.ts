/**
 * The derived payload models are current with the logical models: the gate
 * form of lm-derive's own `--check`.
 *
 * @module smart-trust-tools/tools/lm-derive/check
 * @covers payload-models
 * @covers fhir-logical-models
 *
 * `lm_derive.py --check` derives models/generated/ from models/fhir/ in
 * memory and fails when a committed file differs. Before deriving, it refuses
 * a logical model it cannot map (not a kind=logical FHIR 5.0.0 model, an
 * unknown base or type, an element-level invariant, ...), so it judges both
 * kinds. Python standard library only.
 *
 *   bun tools/lm-derive/check.ts
 */
import { spawnSync } from "node:child_process";
import { join } from "node:path";

const r = spawnSync("python3", [join(import.meta.dir, "lm_derive.py"), "--check"], { stdio: "inherit" });
process.exit(r.status ?? 1);
