#!/usr/bin/env python3
"""Draw the overview of key process flows in the original figure's style, from the ArchiMate model.

Usage:
    python3 -I archimate/pretty.py           # write input/includes/workflow-pretty.svg
    python3 -I archimate/pretty.py --check   # fail if the committed drawing is stale

The ArchiMate view "Overview of key process flows" (archimate/build.py) is
the one source. This script reads it from the built model and draws it the
way input/images/workflow.png does: a pictogram per role instead of a typed
box, the two countries as large labels split by a dashed Y, and each flow as
an arrow with its number (blue) or letter (green) in a circle. Nothing is
typed here except how a role looks:

- every box is placed where the view places it;
- every pictogram is the role its element realises (the element's `role`
  property, scenarios/roles.json), labelled with the element's name (the IG's
  actor or persona) and linked to its page (the `page` property);
- every arrow is a Flow of the view, labelled with its name as the figure
  prints it, its circle linked to its journey moment, and its transaction
  code linked to IPS.HAJJ.TRANSACTION.

The archimate-pages visualiser draws the same view in ArchiMate notation; the
pages offer both, with a toggle. Standard library only.
"""

import html
import json
import math
import re
import sys
import textwrap
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "input/includes/workflow-pretty.svg"
IG = "https://litlfred.github.io/smart-ips-pilgrimage/"
VIEW = "Overview of key process flows"
XSI = "{http://www.w3.org/2001/XMLSchema-instance}type"
BLUE, BLUE_TEXT, GREEN, INK = "#4472C4", "#2F5597", "#548235", "#1f1f1f"
W, H = 1280, 760

# How each role looks: archimate/icons.json, traced from the original figure
# (smoothed, sharpened, then outlined), the GDHCN logo and the IPS logo.
ICONS = {k: v for k, v in json.loads((ROOT / "archimate/icons.json").read_text(encoding="utf-8")).items() if not k.startswith("_")}
ICON_H = {"pilgrim": 100, "trust-network": 120, "origin-hie": 150, "host-emr": 74}


def icon(name, cx, cy, height):
    """The named pictogram scaled to the given height, centred on (cx, cy); an icon with
    an anchor ("cx", such as the pilgrim's head) puts that anchor at cx instead."""
    i = ICONS[name]
    k = height / i["h"]
    return f'<g transform="translate({cx - i.get("cx", i["w"] / 2) * k:.1f} {cy - height / 2:.1f}) scale({k:.4f})">{i["svg"]}</g>'


def esc(s):
    return html.escape(str(s), quote=True)


def version():
    return re.search(r"^version:\s*(\S+)", (ROOT / "sushi-config.yaml").read_text(encoding="utf-8"), re.M).group(1)


def rel_link(url):
    """A link inside this guide is written relative, so a branch preview keeps it."""
    return url[len(IG):] if url.startswith(IG) else url


def read():
    path = ROOT / "archimate" / version() / "smart-ips-pilgrimage.archimate"
    with zipfile.ZipFile(path) as z:
        root = ET.fromstring(z.read("model.xml"))
    elements, rels = {}, {}
    for e in root.iter("element"):
        t = e.get(XSI, "").replace("archimate:", "")
        props = {p.get("key"): p.get("value") for p in e.findall("property")}
        if t.endswith("Relationship"):
            rels[e.get("id")] = (t[:-len("Relationship")], e.get("source"), e.get("target"), e.get("name") or "", props)
        elif t != "ArchimateDiagramModel":
            elements[e.get("id")] = (t, e.get("name"), props)
    view = next(e for e in root.iter("element") if e.get(XSI) == "archimate:ArchimateDiagramModel" and e.get("name") == VIEW)
    boxes, lines = {}, []

    def walk(node, ox, oy):
        for c in node.findall("child"):
            b = c.find("bounds")
            x, y = ox + int(b.get("x")), oy + int(b.get("y"))
            boxes[c.get("id")] = (c.get("archimateElement"), x, y, int(b.get("width")), int(b.get("height")))
            for sc in c.findall("sourceConnection"):
                lines.append((sc.get("archimateRelationship"), sc.get("source"), sc.get("target")))
            walk(c, x, y)

    walk(view, 0, 0)
    return elements, rels, boxes, lines


def clip(cx, cy, tx, ty, rect, gap):
    """Where the line from (cx, cy) towards (tx, ty) leaves rect (its centre, width, height), plus a gap.
    The line runs between the elements' own centres, so mirrored elements give mirrored angles."""
    rx, ry, w, h = rect
    dx, dy = tx - cx, ty - cy
    ts = []
    if dx:
        ts.append(((rx + (w / 2 if dx > 0 else -w / 2)) - cx) / dx)
    if dy:
        ts.append(((ry + (h / 2 if dy > 0 else -h / 2)) - cy) / dy)
    t = min(ts)
    d = math.hypot(dx, dy)
    return cx + dx * t + dx / d * gap, cy + dy * t + dy / d * gap


def draw():
    elements, rels, boxes, lines = read()
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" role="img" aria-labelledby="wf-title" '
           f'style="width:100%;height:auto;font-family:Helvetica,Arial,sans-serif">',
           f'<title id="wf-title">{esc(VIEW)}</title>',
           "<!-- Generated by archimate/pretty.py from the ArchiMate view of the same name. Do not edit; edit archimate/build.py and rerun both. -->",
           f'<defs><marker id="wf-a-blue" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="{BLUE}"/></marker>'
           f'<marker id="wf-a-green" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0 0 L10 5 L0 10 z" fill="{GREEN}"/></marker></defs>',
           '<rect width="100%" height="100%" fill="#fff"/>']

    VIEW_PAGE = f"en/smart-ips-pilgrimage/archimate/{version()}/views/overview-of-key-process-flows/"
    # The countries: a dashed Y between them, and each one's name, large, at its outer edge.
    locs = [(elements[e][1], x, y, w, h) for e, x, y, w, h in boxes.values() if elements[e][0] == "Location"]
    gdhcn = next((b for b in boxes.values() if elements[b[0]][2].get("role", "").endswith("#trust-network")), None)
    fork_y = gdhcn[2] - 150 if gdhcn else H - 260
    out.append(f'<path d="M{W / 2} 30 V{fork_y} M{W / 2} {fork_y} L{W / 2 - 330} {H - 10} M{W / 2} {fork_y} L{W / 2 + 330} {H - 10}" '
               'stroke="#a9bde6" stroke-width="3" stroke-dasharray="10 8" fill="none"/>')
    for name, x, y, w, h in locs:
        left = x + w / 2 < W / 2
        tx = x + 20 if left else x + w - 20
        words = name.split()
        lines_ = [" ".join(words[: len(words) // 2 or 1]), " ".join(words[len(words) // 2 or 1:])] if len(words) > 1 else words
        out.append(f'<a href="{VIEW_PAGE}" target="_top"><title>{esc(name)}: the ArchiMate view of these flows</title>'
                   f'<text x="{tx}" y="{y + h * 0.66}" text-anchor="{"start" if left else "end"}" font-size="30" font-weight="700" fill="{BLUE}">'
                   + "".join(f'<tspan x="{tx}" dy="{0 if i == 0 else 34}">{esc(t)}</tspan>' for i, t in enumerate(l for l in lines_ if l))
                   + "</text></a>")

    # The roles: a pictogram each, named as the IG names the actor or persona, linked to its page.
    centre = {}
    for oid, (eid, x, y, w, h) in boxes.items():
        t, name, props = elements[eid]
        if t == "Location":
            continue
        role = props.get("role", "").split("#")[-1]
        cx, cy = x + w / 2, y + h / 2
        colour = GREEN if role == "trust-network" else INK
        rows = textwrap.wrap(name, 22)
        label = "".join(f'<tspan x="{cx}" dy="{0 if i == 0 else 17}">{esc(t)}</tspan>' for i, t in enumerate(rows))
        ih = ICON_H.get(role, 84)
        icy = cy - 18 + (84 - ih) / 4
        ly0 = icy + ih / 2 + 10
        # what an arrow keeps clear of: the pictogram and its label below it
        top, bottom = icy - ih / 2, ly0 + 17 * len(rows) - 4
        iw = ICONS[role]["w"] * ih / ICONS[role]["h"] if role in ICONS else w
        centre[oid] = ((cx, cy), (cx, (top + bottom) / 2, max(iw, 160), bottom - top))
        sub = ""
        body = ((icon(role, cx, icy, ih) if role in ICONS else "")
                + f'<text x="{cx}" y="{ly0 + 6:.1f}" text-anchor="middle" font-size="14" font-weight="700" letter-spacing=".2" fill="{colour}">{label}</text>{sub}')
        page = props.get("page")
        actor = props.get("igActor")
        tip = f"<title>{esc(name)}{' (' + esc(actor) + ')' if actor else ''}: role {esc(role)}</title>"
        out.append(f'<a href="{esc(rel_link(page))}" target="_top">{tip}{body}</a>' if page else f"<g>{tip}{body}</g>")

    # The flows: an arrow each, with its step in a circle and its label as printed.
    for rid, s, t in lines:
        kind, _, _, name, props = rels[rid]
        if kind != "Flow" or s not in centre or t not in centre:
            continue
        step = props.get("step", "")
        green = step.isalpha()
        colour, text_colour = (GREEN, GREEN) if green else (BLUE, BLUE_TEXT)
        ((sx, sy), srect), ((tx, ty), trect) = centre[s], centre[t]
        x1, y1 = clip(sx, sy, tx, ty, srect, 10)
        x2, y2 = clip(tx, ty, sx, sy, trect, 10)
        if abs(y2 - y1) < 0.2 * abs(x2 - x1):
            # a nearly level flow is drawn level, as the original draws it
            y1 = y2 = (y1 + y2) / 2
        out.append(f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{colour}" stroke-width="2.5" '
                   f'marker-end="url(#wf-a-{"green" if green else "blue"})"/>')
        mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        moment = props.get("journeyMoment")
        circle = (f'<circle cx="{mx:.1f}" cy="{my:.1f}" r="15" fill="#fff" stroke="{colour}" stroke-width="2.5"/>'
                  f'<text x="{mx:.1f}" y="{my + 6:.1f}" text-anchor="middle" font-size="17" font-weight="700" fill="{colour}">{esc(step)}</text>')
        out.append(f'<a href="{esc(rel_link(moment))}" target="_top"><title>Step {esc(step)}: its moment of the pilgrim\'s journey</title>{circle}</a>'
                   if moment else circle)
        # The label sits beside the arrow: above it, or for a lettered flow on the side away from the middle.
        dx, dy = x2 - x1, y2 - y1
        d = math.hypot(dx, dy)
        nx, ny = -dy / d, dx / d
        if green:
            if (nx < 0) != (mx < W / 2):
                nx, ny = -nx, -ny
        elif ny > 0 or (abs(ny) < 1e-6 and nx > 0):
            nx, ny = -nx, -ny
        # The narrative is one block, linked to its transaction (or its moment): what the flow
        # carries, as the original shows it, first (a key for the trust lists, a QR code for the
        # IPS), as tall as the text beside it. The transaction code is in the link, not printed.
        text = re.sub(r"^\w+\.\s*", "", name)
        wrapped = textwrap.wrap(text, 34)
        rows = len(wrapped)
        lx = mx + nx * 48
        # the block's near edge sits 26px from the arrow; first baseline 12px below its top
        ly = my + ny * 26 + 12 - (rows * 19 if ny < -0.3 else 0 if ny > 0.3 else rows * 9.5)
        anchor = "middle" if abs(nx) < 0.5 else ("start" if nx > 0 else "end")
        badge = "key" if green else "qr" if props.get("carries") == "IPS QR code" else None
        bh = 19 * rows - 4
        bw = ICONS[badge]["w"] * bh / ICONS[badge]["h"] if badge else 0
        tw = 7.0 * max(len(r) for r in wrapped)
        width = bw + (10 if badge else 0) + tw
        left = lx - (width / 2 if anchor == "middle" else width if anchor == "end" else 0)
        tx0 = left + width - tw
        lab = "".join(f'<tspan x="{tx0:.1f}" dy="{0 if i == 0 else 19}">{esc(w_)}</tspan>' for i, w_ in enumerate(wrapped))
        block = (f'<rect x="{left - 6:.1f}" y="{ly - 18:.1f}" width="{width + 12:.1f}" height="{19 * rows + 8:.1f}" rx="6" fill="#fff" fill-opacity=".85"/>'
                 + (icon(badge, left + bw / 2, ly - 12 + bh / 2, bh) if badge else "")
                 + f'<text x="{tx0:.1f}" y="{ly:.1f}" font-size="15" letter-spacing=".3" fill="{text_colour}">{lab}</text>')
        tx_ = props.get("transaction")
        if tx_:
            code = tx_.split("TRANSACTION-")[-1]
            out.append(f'<a href="{esc(rel_link(tx_))}" target="_top"><title>Transaction {esc(code)} (IPS.HAJJ.TRANSACTION)</title>{block}</a>')
        elif moment:
            out.append(f'<a href="{esc(rel_link(moment))}" target="_top"><title>Step {esc(step)}: its moment of the pilgrim\'s journey</title>{block}</a>')
        else:
            out.append(block)
    out.append("</svg>\n")
    return "\n".join(out)


def main(argv):
    svg = draw()
    rel = OUT.relative_to(ROOT)
    if "--check" in argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != svg:
            print(f"{rel}: stale; run python3 -I archimate/pretty.py", file=sys.stderr)
            return 1
        print(f"{rel}: current")
        return 0
    OUT.write_text(svg, encoding="utf-8")
    print(f"{rel}: written")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
