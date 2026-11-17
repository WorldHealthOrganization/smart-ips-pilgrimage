#!/usr/bin/env bash
# Measures the library's line and region coverage under the native test suite
# and fails below the floor (STT-TST-010). Uses only what the pinned toolchain
# ships: rustc's -C instrument-coverage and the llvm-tools component
# (rust-toolchain.toml), so there is no coverage tool to install.
# Verifies STT-TST-010/rust-floor.
#
#   tools/hcert-rust/coverage.sh [--report]
# --report also prints the per-file table. Stable rustc measures lines and
# regions, not branches, so the floor is on those two; it sits beside the
# Kotlin one (hcert-core's jvmTestCoverageCheck: 90% line, 70% branch) and was
# set just under the first measurement (85.7% lines, 81.8% regions). Raise it
# as tests reach more code, never lower it.
set -euo pipefail
LINE_FLOOR=85
REGION_FLOOR=80

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"
export CARGO_TARGET_DIR="$here/target/coverage"
export RUSTFLAGS="-C instrument-coverage"
prof="$CARGO_TARGET_DIR/profraw"
rm -rf "$prof"
mkdir -p "$prof"
export LLVM_PROFILE_FILE="$prof/%p-%m.profraw"
bin="$(rustc --print sysroot)/lib/rustlib/$(rustc -vV | sed -n 's/^host: //p')/bin"

# The same runs as CI: the default build, and the api tests with the demos' QR encoder.
runs=("--locked" "--locked --features qr --test api")
objects=()
for args in "${runs[@]}"; do
  # shellcheck disable=SC2086
  cargo test $args --quiet
  # shellcheck disable=SC2086
  while IFS= read -r exe; do objects+=("-object" "$exe"); done < <(
    cargo test $args --no-run --message-format=json 2>/dev/null |
      python3 -c 'import sys, json
for l in sys.stdin:
    m = json.loads(l)
    if m.get("reason") == "compiler-artifact" and m.get("executable") and m.get("profile", {}).get("test"):
        print(m["executable"])')
done

"$bin/llvm-profdata" merge -sparse "$prof"/*.profraw -o "$CARGO_TARGET_DIR/hcert.profdata"
# Only the library's own sources: not the tests, the standard library or crates.io.
ignore='(/\.cargo/|/rustc/|/tests/|/target/)'
cov=("$bin/llvm-cov")
if [[ "${1:-}" == "--report" ]]; then
  "${cov[@]}" report -instr-profile "$CARGO_TARGET_DIR/hcert.profdata" -ignore-filename-regex "$ignore" "${objects[@]}"
fi
"${cov[@]}" export -summary-only -instr-profile "$CARGO_TARGET_DIR/hcert.profdata" -ignore-filename-regex "$ignore" "${objects[@]}" |
  python3 -c '
import json, sys
line_floor, region_floor = float(sys.argv[1]), float(sys.argv[2])
t = json.load(sys.stdin)["data"][0]["totals"]
line, region = t["lines"]["percent"], t["regions"]["percent"]
fn = t["functions"]["percent"]
print(f"hcert-rust coverage: lines {line:.1f}% (floor {line_floor:.0f}%), regions {region:.1f}% (floor {region_floor:.0f}%), functions {fn:.1f}%")
low = [f"lines {line:.1f}% < {line_floor:.0f}%"] * (line < line_floor) + [f"regions {region:.1f}% < {region_floor:.0f}%"] * (region < region_floor)
if low:
    sys.exit("below the floor: " + ", ".join(low))
' "$LINE_FLOOR" "$REGION_FLOOR"
