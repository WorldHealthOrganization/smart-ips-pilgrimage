#!/usr/bin/env python3
"""Validate the FHIR logical models with the pinned HL7 FHIR Validator.

Runs HL7's validator_cli.jar on every StructureDefinition in models/fhir/,
against the FHIR version they declare (fhirVersion, which must be the one
toolchain/fhir-validator/validator.json pins packages for).

Nothing is resolved at run time. The jar and each FHIR package are fetched
from the URL validator.json names into the cache only when absent, and their
sha256 is checked before every use; a mismatch, or a package with no sha256,
refuses the run. The packages are laid into a fresh package cache for each
run, and the validator runs with -no-http-access (so it cannot fetch a
package itself) and -tx n/a (no terminology server).

Any Error or Fatal fails the run unless known-errors.json beside this script
lists it: an error in the upstream models, by file and message, with the
upstream issue that tracks its fix. An entry the validator no longer reports
also fails the run, so the list cannot go stale.

Usage:
    python3 tools/fhir-validate/fhir_validate.py --site     the site's pre step:
        run only when the site build is main's (published at the root), and
        say so and exit 0 for a staging preview
    python3 tools/fhir-validate/fhir_validate.py --always   run regardless

The site build (cat-harness-tools build-instance-site.ts) gives each pre step
SITE_BASEURL: /<repo> for the root, /<repo>/STAGING/<slug> for a preview.

Cache: $FHIR_VALIDATOR_CACHE, else $XDG_CACHE_HOME/smart-trust-tools/fhir-validator,
else ~/.cache/smart-trust-tools/fhir-validator.

Needs python3, java (17 or later), curl and network access to the pinned URLs
on the first run only. Standard library only.
"""

import argparse
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
PINS = ROOT / "toolchain" / "fhir-validator" / "validator.json"
MODELS = ROOT / "models" / "fhir"
KNOWN = pathlib.Path(__file__).resolve().parent / "known-errors.json"


def say(msg):
    print("fhir-validate: " + msg, file=sys.stderr, flush=True)


def cache_dir():
    if os.environ.get("FHIR_VALIDATOR_CACHE"):
        return pathlib.Path(os.environ["FHIR_VALIDATOR_CACHE"])
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache")
    return pathlib.Path(base) / "smart-trust-tools" / "fhir-validator"


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch_verified(label, url, want, dest):
    """dest, downloaded from url only when absent, and refused unless its sha256 is want."""
    if not want or not re.fullmatch(r"[0-9a-f]{64}", want):
        raise SystemExit("fhir-validate: %s has no sha256 in %s; refusing to fetch or run an unpinned artefact"
                         % (label, PINS.relative_to(ROOT)))
    if not dest.exists():
        dest.parent.mkdir(parents=True, exist_ok=True)
        part = dest.with_name(dest.name + ".part")
        say("fetching %s from %s" % (label, url))
        r = subprocess.run(["curl", "-sSfL", "--retry", "2", "-o", str(part), url])
        if r.returncode != 0:
            part.unlink(missing_ok=True)
            raise SystemExit("fhir-validate: could not download %s from %s (curl exit %d)" % (label, url, r.returncode))
        part.replace(dest)
    got = sha256(dest)
    if got != want:
        raise SystemExit("fhir-validate: %s at %s has sha256 %s, not the pinned %s; refusing (delete the file to fetch it again)"
                         % (label, dest, got, want))
    return dest


def is_main_build():
    """True for the root's build, False for a preview; refuses outside a site build."""
    baseurl = os.environ.get("SITE_BASEURL") or os.environ.get("FOLIO_SITE_BASEURL")
    if baseurl is None:
        raise SystemExit("fhir-validate: --site runs as a site pre step, which sets SITE_BASEURL; "
                         "none is set, so whether this is main's publish is unknown. Pass --always to run it here.")
    return "STAGING" not in [p for p in baseurl.split("/") if p]


def model_files(fhir_version):
    files = sorted(MODELS.glob("StructureDefinition-*.json"))
    if not files:
        raise SystemExit("fhir-validate: no StructureDefinition in %s" % MODELS.relative_to(ROOT))
    for f in files:
        v = json.loads(f.read_text()).get("fhirVersion")
        if v != fhir_version:
            raise SystemExit("fhir-validate: %s declares fhirVersion %r; %s pins packages for %s"
                             % (f.relative_to(ROOT), v, PINS.relative_to(ROOT), fhir_version))
    return files


def lay_package(tgz, packages, name, version):
    """Extract a verified package tarball into the package cache as name#version/package/."""
    dest = packages / ("%s#%s" % (name, version))
    dest.mkdir(parents=True)
    with tarfile.open(tgz, "r:gz") as t:
        for m in t.getmembers():
            if not (m.isfile() or m.isdir()) or not m.name.startswith("package/"):
                raise SystemExit("fhir-validate: %s holds %s, which is not a plain file under package/; refusing" % (tgz.name, m.name))
        t.extractall(dest, filter="data")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--site", action="store_true", help="run only for main's site build")
    mode.add_argument("--always", action="store_true", help="run regardless of the build")
    args = ap.parse_args()

    if args.site and not is_main_build():
        say("staging preview (SITE_BASEURL has a STAGING segment): the FHIR Validator runs only on publish to main; not run")
        return 0

    pins = json.loads(PINS.read_text())
    files = model_files(pins["fhirVersion"])
    cache = cache_dir()
    v = pins["validator"]
    jar = fetch_verified("%s %s" % (v["name"], v["version"]), v["url"], v["sha256"],
                         cache / ("validator_cli-%s.jar" % v["version"]))
    tarballs = []
    for p in pins["packages"]:
        label = "%s#%s" % (p["name"], p["version"])
        tarballs.append((p, fetch_verified(label, p["url"], p.get("sha256"), cache / "packages" / ("%s-%s.tgz" % (p["name"], p["version"])))))

    java = shutil.which("java")
    if not java:
        raise SystemExit("fhir-validate: java is not on PATH")
    with tempfile.TemporaryDirectory(prefix="fhir-validate-") as home:
        packages = pathlib.Path(home) / ".fhir" / "packages"
        for p, tgz in tarballs:
            lay_package(tgz, packages, p["name"], p["version"])
        cmd = [java, "-Duser.home=" + home, "-jar", str(jar),
               "-version", pins["fhirVersion"], "-tx", "n/a", "-no-http-access",
               *[str(f.relative_to(ROOT)) for f in files]]
        say("validator %s, FHIR %s, %d StructureDefinition(s), packages %s"
            % (v["version"], pins["fhirVersion"], len(files), ", ".join("%s#%s" % (p["name"], p["version"]) for p, _ in tarballs)))
        r = subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE, text=True)
    sys.stdout.write(r.stdout)
    errors = validator_errors(r.stdout, files)
    if errors is None:
        say("the FHIR Validator did not report on every model (exit %d)" % r.returncode)
        return 1
    known = json.loads(KNOWN.read_text())["errors"]
    unknown = [(f, m) for f, m in errors if not any(k["file"] == f and k["contains"] in m for k in known)]
    stale = [k for k in known if not any(k["file"] == f and k["contains"] in m for f, m in errors)]
    for k in known:
        if k not in stale:
            say("known upstream error, allowed until %s is fixed: %s: %s" % (k["issue"], k["file"], k["contains"]))
    for f, m in unknown:
        say("error: %s: %s" % (f, m))
    for k in stale:
        say("%s lists an error the validator no longer reports, so remove it: %s: %s"
            % (KNOWN.relative_to(ROOT), k["file"], k["contains"]))
    if unknown or stale:
        return 1
    say("no errors" if not errors else "no errors beyond the %d known upstream one(s)" % len(errors))
    return 0


def validator_errors(out, files):
    """The (model file, message) of every Error or Fatal line, or None unless every model has its section."""
    errors, seen, current = [], set(), None
    for line in out.splitlines():
        m = re.match(r"^-- (\S+) -+$", line)
        if m:
            current = m.group(1)
            seen.add(current)
            continue
        m = re.match(r"^\s+(Error|Fatal) @ (.*)$", line)
        if m and current:
            errors.append((current, m.group(2)))
    wanted = {str(f.relative_to(ROOT)) for f in files}
    return errors if wanted <= seen else None


if __name__ == "__main__":
    sys.exit(main())
