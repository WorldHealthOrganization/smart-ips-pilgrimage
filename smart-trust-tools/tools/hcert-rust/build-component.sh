#!/usr/bin/env bash
# Builds the WebAssembly component of the `hcert` world in api/wit and
# transpiles it to an ES module with jco (STT-GEN-005), into DIR:
#   hcert.component.wasm   the component, for any component host
#   js/hcert.js            the ES module (browsers and Node), its core wasm,
#                          its TypeScript declarations, and wasi-random.js
# jco comes from toolchain/node (pinned in its package-lock.json, installed
# with --ignore-scripts). Paths are remapped as in bundle-demo.sh, so the
# same commit gives the same bytes.
#   tools/hcert-rust/build-component.sh <dir>
set -euo pipefail
out="${1:?usage: build-component.sh <dir>}"
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
. "$repo/toolchain/node_tools.sh"
cargo_home="${CARGO_HOME:-$HOME/.cargo}"
export RUSTFLAGS="--remap-path-prefix=$here=/hcert --remap-path-prefix=$cargo_home=/cargo --remap-path-prefix=$HOME=/home"
# rustup takes the toolchain (and its wasm target) from rust-toolchain.toml in
# the working directory, not from --manifest-path, so build from here.
(cd "$here" && cargo build --locked --release --features component --target wasm32-unknown-unknown)
mkdir -p "$out/js"
jco new "$here/target/wasm32-unknown-unknown/release/hcert.wasm" -o "$out/hcert.component.wasm"
# The one import, wasi:random, maps to the local shim instead of preview2-shim.
jco transpile "$out/hcert.component.wasm" -o "$out/js" --name hcert --map 'wasi:random/random=./wasi-random.js#random' --quiet
cp "$here/js/component/wasi-random.js" "$out/js/"
echo "wrote $out (hcert.component.wasm $(sha256sum "$out/hcert.component.wasm" | cut -d' ' -f1))"
