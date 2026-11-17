#!/usr/bin/env python3
"""Give every page of the TypeDoc reference the viewer top bar, so leaving
"API reference (TS)" does not mean losing the site's navigation.

Usage:
    python3 tools/build-site/inject_topbar.py SITE_DIR [TYPEDOC_SUBDIR]

TYPEDOC_SUBDIR defaults to api/typedoc. TypeDoc 0.26 has no option that adds
markup to its pages, so the bar is inserted after it has written them: the
same `topbar()` the Python pages use, with paths relative to each page, and
assets/topbar.css (tokens and bar only) so TypeDoc's own stylesheet keeps the
rest of the page. Running it twice changes nothing.
"""

import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from build_site import FONTS, topbar  # noqa: E402

CURRENT = "api/typedoc/index.html"
MARK = 'class="topbar in-typedoc"'


def main():
    site = pathlib.Path(sys.argv[1])
    sub = sys.argv[2] if len(sys.argv) > 2 else "api/typedoc"
    pages = sorted((site / sub).rglob("*.html"))
    if not pages:
        sys.exit("inject_topbar: no HTML under %s" % (site / sub))
    for page in pages:
        text = page.read_text(encoding="utf-8")
        if MARK in text:
            continue
        up = "../" * (len(page.relative_to(site).parts) - 1)
        head = ('<link rel="stylesheet" href="%s">\n'
                '<link rel="stylesheet" href="%sassets/topbar.css">\n') % (FONTS, up)
        text, n_head = re.subn(r"</head>", lambda m: head + m.group(0), text, count=1)
        text, n_body = re.subn(r"<body[^>]*>", lambda m: m.group(0) + topbar(CURRENT, up, "in-typedoc"),
                               text, count=1)
        if not (n_head and n_body):
            sys.exit("inject_topbar: no <head>/<body> in %s" % page)
        page.write_text(text, encoding="utf-8")
    print("inject_topbar: %d page(s) under %s" % (len(pages), site / sub))


if __name__ == "__main__":
    main()
