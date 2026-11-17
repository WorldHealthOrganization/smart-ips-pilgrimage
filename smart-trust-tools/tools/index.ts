/**
 * smart-trust-tools's Tool nodes — the `tools` graph of this instance.
 *
 * @module smart-trust-tools/tools
 * @graphNode tool
 *
 * One Tool per folder (`<id>/<id>.ts`, bean `tdir`), with the code that is
 * that Tool's alone beside it: the Kotlin library in `hcert-kotlin/`, the
 * generators of the contract's views, the checks and the site builder. The
 * pinned Node and Python toolchains several Tools share live in
 * `toolchain/`, not here, because every folder here must be one Tool.
 */
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

import type { ToolDefinition } from "@litlfred/cat-harness-tools/schemas/tools/tool.js";
import { toolsFromFolders } from "@litlfred/cat-harness-tools/schemas/tools/tool-folders.js";

export function tools(baseUrl?: string): ToolDefinition[] {
  return toolsFromFolders(dirname(fileURLToPath(import.meta.url)), baseUrl ?? "https://litlfred.github.io/smart-trust-tools/");
}
