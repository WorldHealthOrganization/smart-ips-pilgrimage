#!/usr/bin/env bash
# Builds the WebAssembly module reproducibly and writes the live-demo bundle
# (hcert.wasm, hcert.js, hcert-demo.js, hcert-demo.css, dvc-qr-example-XXR.json,
# XXR-DSC-did.json, WHO-signing-did.json, SOURCE.md) to DIR,
# for a page such as the smart-trust QR Code Generation page to load.
#   tools/hcert-rust/bundle-demo.sh <dir>
# Paths are remapped so the module's bytes do not depend on where the
# repository is checked out: the same commit gives the same sha256.
set -euo pipefail
out="${1:?usage: bundle-demo.sh <dir>}"
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
cargo_home="${CARGO_HOME:-$HOME/.cargo}"
export RUSTFLAGS="--remap-path-prefix=$here=/hcert --remap-path-prefix=$cargo_home=/cargo --remap-path-prefix=$HOME=/home"
# rustup takes the toolchain (and its wasm target) from rust-toolchain.toml in
# the working directory, not from --manifest-path, so build from here.
(cd "$here" && cargo build --locked --release --features qr --target wasm32-unknown-unknown)
mkdir -p "$out"
cp "$here/target/wasm32-unknown-unknown/release/hcert.wasm" "$out/hcert.wasm"
cp "$here/js/hcert.mjs" "$out/hcert.js"
cp "$here/js/demo/hcert-demo.js" "$here/js/demo/hcert-demo.css" "$out/"
# The page's two certificates (QR Code Generation 12.6), for the published demo.
cp "$repo/vectors/smart-trust-af75be2/dvc-qr-example-XXR.json" "$out/"
# XXR's DSC DID document from the GDHCN DEV trust list, so the published demo verifies them.
cp "$repo/vectors/smart-trust-af75be2/XXR-DSC-did.json" "$out/"
# The WHO DEV signing DID document, against which the demo verifies that document's proof first (STT-TRU-006).
cp "$repo/vectors/gdhcn-dev-trustlist/WHO-signing-did.json" "$out/"
commit="$(git -C "$repo" rev-parse HEAD)"
sha() { sha256sum "$1" | cut -d' ' -f1; }
cat > "$out/SOURCE.md" <<MD
# hcert live demo

Built from [litlfred/smart-trust-tools](https://github.com/litlfred/smart-trust-tools)
at commit \`$commit\` by \`tools/hcert-rust/bundle-demo.sh\`. Do not edit
these files here; change them there and rebuild.

| File | sha256 |
|---|---|
| hcert.wasm | \`$(sha "$out/hcert.wasm")\` |
| hcert.js | \`$(sha "$out/hcert.js")\` |
| hcert-demo.js | \`$(sha "$out/hcert-demo.js")\` |
| hcert-demo.css | \`$(sha "$out/hcert-demo.css")\` |
| dvc-qr-example-XXR.json | \`$(sha "$out/dvc-qr-example-XXR.json")\` |
| XXR-DSC-did.json | \`$(sha "$out/XXR-DSC-did.json")\` |
| WHO-signing-did.json | \`$(sha "$out/WHO-signing-did.json")\` |

The WebAssembly module imports nothing. Keys are generated and used by
WebCrypto in the reader's browser, and everything issued is TEST ONLY.
MD
echo "wrote $out (hcert.wasm $(sha "$out/hcert.wasm"))"
