#!/usr/bin/env bash
# Build the viewer site into site/ (or $1): Python pages plus the TypeDoc
# reference for the jco-generated TypeScript declarations.
# Needs Python (pyyaml rdflib cbor2 base45), Node.js and bun.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
out="${1:-$root/site}"
ref="${SITE_GIT_REF:-}"

python3 "$root/tools/build-site/build_site.py" --out "$out" ${ref:+--git-ref "$ref"}

# The browser libraries, TypeScript and TypeDoc come from the pinned
# toolchain/node lockfile, so the site has no CDN dependency and nothing is
# resolved at build time.
. "$root/toolchain/node_tools.sh"
vendor="$out/assets/vendor"
mkdir -p "$vendor"
cp "$NODE_TOOLS/cytoscape/dist/cytoscape.min.js" "$vendor/"

# The jco declarations use Symbol.dispose, hence ESNext.Disposable; type-check
# them strictly before documenting.
tsc -p "$root/tools/build-site/site/tsconfig.typedoc.json"
rm -rf "$out/api/typedoc"
typedoc --options "$root/tools/build-site/site/typedoc.json" --out "$out/api/typedoc" --logLevel Warn
# TypeDoc writes its own page shell; give it the viewer top bar too.
python3 "$root/tools/build-site/inject_topbar.py" "$out"
echo "site ready: $out"
