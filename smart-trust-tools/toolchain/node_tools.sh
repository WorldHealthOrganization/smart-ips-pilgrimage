#!/usr/bin/env bash
# Install the pinned Node tools from toolchain/node/package-lock.json. Every
# package is checked against its lockfile integrity hash, and no package runs
# an install script. Source this file; it puts the tools' bin on PATH.
set -euo pipefail
node_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/node" && pwd)"
if [ ! -d "$node_dir/node_modules" ] || [ "$node_dir/package-lock.json" -nt "$node_dir/node_modules/.package-lock.json" ]; then
  (cd "$node_dir" && npm ci --ignore-scripts --no-audit --no-fund --loglevel=error)
fi
export PATH="$node_dir/node_modules/.bin:$PATH"
export NODE_TOOLS="$node_dir/node_modules"
