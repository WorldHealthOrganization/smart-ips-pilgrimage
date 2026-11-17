#!/usr/bin/env bash
# Validate api/wit and regenerate the TypeScript review view in api/generated/ts.
# Needs Node.js; jco comes from the pinned toolchain/node lockfile.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
. "$root/toolchain/node_tools.sh"
out="$root/api/generated/ts"

rm -rf "$out"
jco types "$root/api/wit" --world-name hcert --out-dir "$out" --quiet
echo "regenerated $out"
