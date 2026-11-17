/**
 * The shape of vectors/negative/negative-vectors.json, which
 * make_negative_vectors.py writes and the Kotlin, Rust and Node suites load.
 *
 * A Zod schema, as the harness writes its node schemas. The file itself
 * carries no `$schema`: the hcert-test-vectors typology says vectors must not
 * gain one, so the schema is applied by name, from check-req-nodes.
 *
 * Each case's expected `step` and `reason` are cases of the WIT enums `step`
 * and `failure-reason` (api/wit/types.wit, STT-VER-001 and STT-VER-008),
 * written as the suites compare them: upper case, `-` as `_`
 * (`trust-lookup` → `TRUST_LOOKUP`). They are parsed from the WIT on every
 * check, never listed here, so a failure the contract drops or renames fails
 * the check rather than lingering in the vectors.
 */
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { z } from "zod";

/** The cases of `enum <name> { … }` in a WIT source, in order. */
export function witEnum(wit: string, name: string): string[] {
  const body = new RegExp(`\\benum\\s+${name}\\s*\\{([^}]*)\\}`).exec(wit)?.[1];
  if (body === undefined) throw new Error(`no enum ${name} in the WIT`);
  return body
    .split("\n")
    .map((l) => l.replace(/\/\/.*$/, "").trim())
    .flatMap((l) => l.split(","))
    .map((c) => c.trim())
    .filter(Boolean);
}

/** The failure taxonomy as the vectors write it: `trust-lookup` → `TRUST_LOOKUP`. */
export function failureTaxonomy(wit: string): { steps: string[]; reasons: string[] } {
  const upper = (c: string) => c.toUpperCase().replace(/-/g, "_");
  return { steps: witEnum(wit, "step").map(upper), reasons: witEnum(wit, "failure-reason").map(upper) };
}

const nonEmpty = <T extends string>(xs: T[], what: string): [T, ...T[]] => {
  if (!xs.length) throw new Error(`the WIT enum for ${what} is empty`);
  return xs as [T, ...T[]];
};

/** The schema of the file, its expectations bound to a failure taxonomy. */
export function negativeVectorsSchema(taxonomy: { steps: string[]; reasons: string[] }) {
  const Case = z
    .object({
      id: z.string().regex(/^[a-z0-9][a-z0-9-]*$/, "a case id is lower-case kebab"),
      description: z.string().min(1),
      /** An HC1 string, run through every layer. */
      hc1: z.string().optional(),
      /** Raw COSE_Sign1 bytes as hex, verified without the QR layers. */
      coseHex: z.string().regex(/^(?:[0-9a-f]{2})+$/, "coseHex is lower-case hex of whole bytes").optional(),
      /** Overrides defaults.now: the verifier's clock, seconds since the epoch. */
      now: z.number().int().nonnegative().optional(),
      /** Overrides defaults.trust: the DSCs the verifier trusts (repository paths). */
      trust: z.array(z.string().min(1)).optional(),
      expect: z
        .object({
          step: z.enum(nonEmpty(taxonomy.steps, "step")),
          reason: z.enum(nonEmpty(taxonomy.reasons, "failure-reason")),
        })
        .strict(),
    })
    .strict()
    .refine((c) => (c.hc1 === undefined) !== (c.coseHex === undefined), {
      message: "a case gives exactly one input: hc1 or coseHex",
    });

  return z
    .object({
      $comment: z.string().min(1),
      defaults: z
        .object({
          trust: z.array(z.string().min(1)).min(1),
          now: z.number().int().nonnegative(),
          clockSkewSeconds: z.number().int().nonnegative(),
        })
        .strict(),
      cases: z.array(Case).min(1),
    })
    .strict()
    .superRefine((doc, ctx) => {
      const seen = new Set<string>();
      for (const c of doc.cases) {
        if (seen.has(c.id)) ctx.addIssue({ code: "custom", message: `case id ${c.id} appears twice` });
        seen.add(c.id);
      }
    });
}

export const NEGATIVE_VECTORS = "vectors/negative/negative-vectors.json";
export const FAILURE_TAXONOMY = "api/wit/types.wit";

/** Check the file under `root` against the schema and the WIT; one line per problem. */
export function checkNegativeVectors(root: string): { cases: number; problems: string[] } {
  const problems: string[] = [];
  const doc = JSON.parse(readFileSync(join(root, NEGATIVE_VECTORS), "utf-8"));
  const r = negativeVectorsSchema(failureTaxonomy(readFileSync(join(root, FAILURE_TAXONOMY), "utf-8"))).safeParse(doc);
  if (!r.success) {
    for (const i of r.error.issues) problems.push(`${NEGATIVE_VECTORS}: ${i.path.join(".") || "(root)"}: ${i.message}`);
    return { cases: 0, problems };
  }
  const paths = [...r.data.defaults.trust, ...r.data.cases.flatMap((c) => c.trust ?? [])];
  for (const p of new Set(paths)) if (!existsSync(join(root, p))) problems.push(`${NEGATIVE_VECTORS}: trust ${p} does not exist`);
  return { cases: r.data.cases.length, problems };
}
