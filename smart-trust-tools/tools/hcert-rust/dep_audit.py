#!/usr/bin/env python3
"""Check every crate in Cargo.lock against the dependency policy (AGENTS.md).

Each must be a release at least 14 days older than CUTOFF, which moves only
when a dependency is added or bumped. Prints one line per crate, marking
build scripts and procedural macros (each reviewed in DEPENDENCIES.md), and
exits 1 if any crate is newer than the cutoff. Reads release dates from the
crates.io API, so it needs the network; CI builds with --locked instead.

Usage:
    python3 tools/hcert-rust/dep_audit.py
"""
import json,urllib.request,datetime,subprocess,sys
CUTOFF = datetime.date(2026, 10, 8)
cut = CUTOFF
d=json.loads(subprocess.run(["cargo","metadata","--format-version","1","--locked","--all-features","--manifest-path",str(__import__("pathlib").Path(__file__).with_name("Cargo.toml"))],capture_output=True,text=True,check=True).stdout)
used={n['id'] for n in d['resolve']['nodes']}
bad=0
for p in sorted(d['packages'],key=lambda p:p['name']):
    if p['source'] is None or p['id'] not in used: continue
    bs=any(t['kind']==['custom-build'] for t in p['targets'])
    pm=any('proc-macro' in t['kind'] for t in p['targets'])
    req=urllib.request.Request(f"https://crates.io/api/v1/crates/{p['name']}/{p['version']}",headers={'User-Agent':'smart-trust-tools-dep-audit'})
    v=json.load(urllib.request.urlopen(req))['version']
    date=v['created_at'][:10]; ok=datetime.date.fromisoformat(date)<=cut
    bad+= not ok
    print(f"{p['name']:24} {p['version']:12} {date} {'' if ok else 'TOO-NEW'} {'build.rs' if bs else ''}{' proc-macro' if pm else ''} {p.get('license','')}")
sys.exit(1 if bad else 0)
