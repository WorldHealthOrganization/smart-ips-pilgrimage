#!/usr/bin/env bash
# Recompile the DVCMin logical models from smart-trust-phw with SUSHI and
# refresh models/fhir/. Needs Node.js and network access to GitHub and to a
# FHIR package source (packages.fhir.org, or the hl7.fhir.r5.core npm package).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
sha="${1:-$(sed -n 's/^  sha: //p' "$root/models/fhir/SOURCE.yaml" | head -1)}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git clone -q https://github.com/WorldHealthOrganization/smart-trust-phw "$work/phw"
git -C "$work/phw" checkout -q "$sha"

mkdir -p "$work/build/input/fsh"
cp "$work"/phw/input/fsh/models/DVCMin*.fsh "$work/build/input/fsh/"
grep -h '^Alias' "$work"/phw/input/fsh/*.fsh > "$work/build/input/fsh/Aliases.fsh"
cat > "$work/build/sushi-config.yaml" <<YAML
canonical: http://smart.who.int/trust-phw
status: draft
version: 0.1.0
fhirVersion: 5.0.0
FSHOnly: true
YAML

. "$root/toolchain/node_tools.sh"
sushi build "$work/build"
cp "$work"/build/fsh-generated/resources/StructureDefinition-DVCMin*.json "$root/models/fhir/"
echo "updated models/fhir from smart-trust-phw@$sha; update SOURCE.yaml if the sha changed"
