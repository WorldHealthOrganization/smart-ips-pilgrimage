/* Graph explorer: an overview of grouped nodes, drill-down into a group or a
   node's neighbourhood with readable labels, and an optional full graph. */
(function () {
  "use strict";
  var S = window.STT, esc = S.esc;

  var FAMILIES = [
    { id: "requirement", label: "Requirements", color: "--fam-requirement" },
    { id: "source", label: "Sources & smart-trust", color: "--fam-source" },
    { id: "realization", label: "Skills, Tools & contract", color: "--fam-realization" },
    { id: "model", label: "Models (FHIR, payload)", color: "--fam-model" },
    { id: "issue", label: "Open issues", color: "--status-warning" }
  ];
  var SHAPE = {
    requirement: "round-rectangle", section: "rectangle", document: "cut-rectangle", standard: "cut-rectangle",
    directive: "star", upstream: "diamond", skill: "hexagon", api: "ellipse", tool: "barrel",
    process: "round-tag", role: "vee", test: "rhomboid", "test-plan": "tag", model: "pentagon", issue: "triangle"
  };
  var SHAPE_NOTE = [
    ["round-rectangle", "requirement"], ["rectangle", "source section"], ["cut-rectangle", "document or standard"],
    ["star", "owner directive"], ["diamond", "smart-trust FHIR requirement"], ["hexagon", "skill"],
    ["barrel", "Tool"], ["rhomboid", "test"], ["tag", "test plan"], ["round-tag", "process (BPMN)"], ["vee", "role"],
    ["ellipse", "contract item (WIT, CDDL)"], ["pentagon", "model (FHIR logical, payload)"], ["triangle", "open issue (bean)"]
  ];
  var COLUMN = { directive: 0, standard: 0, document: 0, section: 0, upstream: 0, requirement: 1,
    skill: 2, api: 2, issue: 2, tool: 3, test: 3, "test-plan": 3, process: 3, role: 3, model: 4 };
  var KIND_ORDER = { directive: 0, document: 1, section: 1, standard: 2, upstream: 3, requirement: 0,
    skill: 0, api: 1, issue: 2, tool: 0, test: 1, "test-plan": 1, process: 2, role: 3, model: 0 };
  var COLUMN_TITLE = ["Sources and smart-trust requirements", "Library requirements", "Skills · WIT · open issues",
    "Tools · tests · test plans · processes · roles", "Models (FHIR logical, payload)"];
  var CARD_W = 230, COL_GAP = 300;
  var REL_LABEL = {
    references: ["References", "Referenced by"], satisfies: ["Satisfies (smart-trust)", "Satisfied by"],
    derivedFrom: ["Derived from", "Basis for"],
    assesses: ["Assesses", "Test plans"], planCase: ["Cases (skills)", "In test plans"], precededBy: ["Preceded by", "Precedes"],
    realizedBy: ["Skills", "Realizes"], constrainsApi: ["Contract items (WIT, CDDL)", "Constrained by"],
    implementedBy: ["Tools", "Skills"], writes: ["Writes", "Written by"], usedIn: ["Processes", "Skills"], performedBy: ["Roles", "Skills"],
    testedBy: ["Tests", "Tests the skill"], verifies: ["Verifies", "Verified by tests"],
    affectedBy: ["Open issues", "Affects"], concerns: ["Concerns", "Raised by"], partOf: ["Part of", "Contains"]
  };
  /* Sources that read better as one group. A library entry's group (its
     upstream repository's FSH sources) and that group's label come from the
     graph data (graph.groups), read by kg_nodes from the entry's structure.json. */
  function docGroupOf(n) {
    if (n.origin === "reference") return "grp:other-igs";
    if (n.origin === "vector") return "grp:vectors";
    if (n.docGroup) return n.docGroup;
    return "doc:" + (n.doc || n.id);
  }
  /* Labels of the groups the explorer makes by kind: presentation, not data. */
  var GROUP_LABEL = {
    "grp:standards": "Standards (IETF, W3C, ITU-T, HL7, IHE, WHO)", "grp:directives": "Owner directives",
    "grp:other-igs": "Other WHO SMART IGs", "grp:vectors": "Test vectors",
    "grp:issues-up": "Open issues to fix upstream", "grp:issues-local": "Open issues in this project",
    "grp:models-logical": "FHIR logical models", "grp:models-payload": "Payload models (derived)",
    "grp:tools": "Tools", "grp:tests": "Tests", "grp:plans": "Test plans", "grp:processes": "Processes (BPMN)", "grp:roles": "Roles"
  };

  var G, cy, groups = {}, groupOf = {}, hidden = {}, stack = [], view = null;

  /* ---------------- grouping ---------------- */

  function groupKey(n) {
    switch (n.kind) {
      case "requirement": return "area:" + n.area;
      case "section": return docGroupOf(n);
      case "document": return docGroupOf(n);
      case "standard": return "grp:standards";
      case "directive": return "grp:directives";
      case "upstream": return "up:" + (n.parent || n.label);
      case "skill": return n.order < 100 ? "skill:" + n.id : "pkg:" + n.package;
      case "api": return "mod:" + n.module;
      case "tool": return "grp:tools";
      case "process": return "grp:processes";
      case "role": return "grp:roles";
      case "test": return "grp:tests";
      case "test-plan": return "grp:plans";
      case "model": return n.modelKind === "payload" ? "grp:models-payload" : "grp:models-logical";
      case "issue": return n.upstream ? "grp:issues-up" : "grp:issues-local";
    }
    return "grp:other";
  }

  function areaTitle(a) {
    for (var i = 0; i < G.areas.length; i++) if (G.areas[i][0] === a) return G.areas[i][1];
    return a;
  }

  function areaRank(a) {
    for (var i = 0; i < G.areas.length; i++) if (G.areas[i][0] === a) return i;
    return 99;
  }

  function buildGroups() {
    G.nodes.forEach(function (n) {
      var k = groupKey(n);
      groupOf[n.id] = k;
      if (!groups[k]) groups[k] = { id: k, members: [] };
      groups[k].members.push(n.id);
    });
    Object.keys(groups).forEach(function (k) {
      var g = groups[k], first = G.byId[g.members[0]], kind = k.split(":")[0], rest = k.slice(kind.length + 1);
      g.fam = first.fam;
      if (kind === "area") {
        g.label = rest + " · " + areaTitle(rest).replace(/^Step \d: /, "");
        g.shape = "round-rectangle"; g.col = 1; g.order = areaRank(rest);
      } else if (kind === "doc") {
        var d = G.byId[rest];
        g.label = d ? d.title : rest; g.shape = "cut-rectangle"; g.col = 0; g.order = 10;
      } else if (kind === "up") {
        g.label = rest + " (smart-trust)"; g.shape = "diamond"; g.col = 0; g.order = 30;
      } else if (kind === "skill") {
        g.label = first.order + ". " + first.label; g.shape = "hexagon"; g.col = 2; g.order = first.order;
      } else if (kind === "pkg") {
        g.label = "Skills: " + rest; g.shape = "hexagon"; g.col = 2; g.order = 50;
      } else if (kind === "mod") {
        g.label = "API module: " + rest; g.shape = "ellipse"; g.col = 2; g.order = 100;
      } else {
        var right = { "grp:tools": [3, 0, "barrel"], "grp:tests": [3, 1, "rhomboid"], "grp:processes": [3, 2, "round-tag"], "grp:roles": [3, 3, "vee"],
          "grp:models-logical": [4, 0, "pentagon"], "grp:models-payload": [4, 1, "pentagon"] }[k];
        g.label = (G.groups && G.groups[k]) || GROUP_LABEL[k] || rest;
        if (right) { g.col = right[0]; g.order = right[1]; g.shape = right[2]; return; }
        g.shape = k.indexOf("issues") >= 0 ? "triangle" : (k === "grp:directives" ? "star" : "cut-rectangle");
        g.col = k.indexOf("issues") >= 0 ? 2 : 0;
        g.order = k.indexOf("issues") >= 0 ? 200 : (k === "grp:directives" ? 0 : (k === "grp:standards" ? 20 : 15));
      }
    });
  }

  /* ---------------- styling ---------------- */

  function shapeSvg(shape, color) {
    var p = {
      "round-rectangle": '<rect x="1" y="3" width="12" height="8" rx="2.5"/>',
      "rectangle": '<rect x="1" y="3" width="12" height="8"/>',
      "cut-rectangle": '<path d="M3 3h8l2 2v4l-2 2H3l-2-2V5z"/>',
      "star": '<path d="M7 1l1.8 3.9 4.2.4-3.2 2.8 1 4.1L7 10l-3.8 2.2 1-4.1L1 5.3l4.2-.4z"/>',
      "diamond": '<path d="M7 1l6 6-6 6-6-6z"/>',
      "hexagon": '<path d="M4 2h6l3 5-3 5H4L1 7z"/>',
      "ellipse": '<ellipse cx="7" cy="7" rx="6" ry="4.5"/>',
      "triangle": '<path d="M7 1.5l6 11H1z"/>',
      "barrel": '<path d="M3 2h8q2 5 0 10H3q-2-5 0-10z"/>',
      "round-tag": '<path d="M2 3h7l4 4-4 4H2z"/>',
      "vee": '<path d="M1 2l6 3 6-3-6 10z"/>',
      "rhomboid": '<path d="M4 3h9l-3 8H1z"/>',
      "tag": '<path d="M1 3h8l4 4-4 4H1z"/>',
      "pentagon": '<path d="M7 1l6 4.4-2.3 7H3.3L1 5.4z"/>'
    }[shape];
    return '<svg class="glyph" viewBox="0 0 14 14" aria-hidden="true" fill="' + color + '">' + p + "</svg>";
  }

  function colors() {
    return {
      requirement: S.cssVar("--fam-requirement"), source: S.cssVar("--fam-source"),
      realization: S.cssVar("--fam-realization"), model: S.cssVar("--fam-model"), issue: S.cssVar("--status-warning"),
      fg: S.cssVar("--fg"), fg2: S.cssVar("--fg-2"), fg3: S.cssVar("--fg-3"), line: S.cssVar("--line"),
      accent: S.cssVar("--accent"), surface: S.cssVar("--surface"), bg: S.cssVar("--bg")
    };
  }

  function style() {
    var c = colors();
    return [
      { selector: "node", style: {
        "background-color": function (n) { return c[n.data("fam")] || c.fg3; },
        "shape": "data(shape)", "width": "data(w)", "height": "data(h)",
        "border-width": 1.5, "border-color": c.bg,
        "label": "data(label)", "font-family": "Public Sans, system-ui, sans-serif", "font-size": "data(fs)",
        "color": c.fg, "text-wrap": "wrap", "text-max-width": "data(tw)",
        "text-valign": "center", "text-halign": "right", "text-margin-x": 6, "min-zoomed-font-size": 6
      } },
      { selector: "node.card", style: {
        "shape": "round-rectangle", "background-color": c.surface, "background-opacity": 1, "border-width": 2,
        "border-color": function (n) { return c[n.data("fam")] || c.fg3; },
        "text-halign": "center", "text-margin-x": 0, "text-justification": "left"
      } },
      { selector: "node.card.member", style: { "border-width": 3.5, "font-weight": 600 } },
      { selector: "node.header", style: {
        "background-opacity": 0, "border-width": 0, "font-weight": 700, "color": c.fg2, "font-size": 13,
        "text-halign": "center", "text-margin-x": 0, "events": "no"
      } },
      { selector: "edge", style: {
        "width": "data(width)", "line-color": c.fg3, "opacity": "data(op)", "curve-style": "unbundled-bezier",
        "control-point-distances": [0], "control-point-weights": [0.5],
        "source-endpoint": "outside-to-node", "target-endpoint": "outside-to-node"
      } },
      { selector: ".faded", style: { "opacity": 0.12, "text-opacity": 0.25 } },
      { selector: "edge.hl", style: { "line-color": c.accent, "opacity": 0.95, "z-index": 9 } },
      { selector: "node.hl", style: { "border-color": c.accent, "z-index": 10 } },
      { selector: "node:selected", style: { "border-color": c.accent, "border-width": 4 } }
    ];
  }

  function trunc(s, n) { s = String(s || ""); return s.length > n ? s.slice(0, n - 1) + "…" : s; }

  function nodeLabel(n, compact) {
    if (compact) return n.label;
    if (n.kind === "requirement") return n.id + "\n" + trunc(n.title, 38);
    if (n.kind === "section") return n.label + "\n" + trunc(n.title, 38);
    if (n.kind === "issue") return n.id + "\n" + trunc(n.title, 38);
    if (n.kind === "api") return n.label + (n.qname ? "\n" + n.qname : "");
    if (n.kind === "upstream") return n.label + "\n" + trunc(n.title, 34);
    if (n.kind === "skill" || n.kind === "tool") return n.label + "\n" + trunc(n.title, 38);
    if (n.kind === "test") return trunc(n.label, 44);
    return trunc(n.title || n.label, 44);
  }

  /* ---------------- views ---------------- */

  function columnLayout(items, colOf, keyOf, gapY, gapX) {
    var cols = {};
    items.forEach(function (it) { var c = colOf(it); (cols[c] = cols[c] || []).push(it); });
    var pos = {}, tallest = 0;
    Object.keys(cols).forEach(function (c) { tallest = Math.max(tallest, cols[c].length); });
    Object.keys(cols).forEach(function (c) {
      var col = cols[c].sort(function (a, b) {
        var ka = keyOf(a), kb = keyOf(b);
        for (var i = 0; i < ka.length; i++) {
          var d = String(ka[i]).localeCompare(String(kb[i]), undefined, { numeric: true });
          if (d) return d;
        }
        return 0;
      });
      var offset = (tallest - col.length) * gapY / 2;
      col.forEach(function (it, i) { pos[it.id] = { x: Number(c) * gapX, y: offset + i * gapY }; });
    });
    return pos;
  }

  function nodeEl(n, opts) {
    if (opts.compact) {
      var req = n.kind === "requirement";
      return { group: "nodes", data: { id: n.id, label: n.label, fam: n.fam, kind: n.kind, shape: SHAPE[n.kind],
        w: req ? 26 : 18, h: req ? 16 : 18, fs: 9, tw: 120 } };
    }
    return { group: "nodes", classes: "card" + (opts.member ? " member" : ""), data: {
      id: n.id, label: nodeLabel(n), fam: n.fam, kind: n.kind, shape: "round-rectangle",
      w: CARD_W, h: 38, fs: 11.5, tw: CARD_W - 18 } };
  }

  function headers(pos, cols) {
    var minY = Infinity;
    Object.keys(pos).forEach(function (k) { minY = Math.min(minY, pos[k].y); });
    return cols.map(function (c) {
      return { group: "nodes", classes: "header", position: { x: c * COL_GAP, y: minY - 44 },
        data: { id: "hdr" + c, label: COLUMN_TITLE[c], shape: "round-rectangle", w: CARD_W, h: 20, fs: 13, tw: CARD_W } };
    });
  }

  function usedCols(items, colOf) {
    var seen = {};
    items.forEach(function (it) { seen[colOf(it)] = true; });
    return Object.keys(seen).map(Number);
  }

  function sortKey(n) {
    var k = KIND_ORDER[n.kind];
    if (n.kind === "requirement") return [k, areaRank(n.area), n.id];
    if (n.kind === "section") return [k, n.doc, n.label];
    if (n.kind === "skill") return [k, n.package, ("00" + n.order).slice(-3), n.label];
    if (n.kind === "api") return [k, n.module, n.label];
    return [k, n.kind, n.id];
  }

  function showOverview() {
    var gs = Object.keys(groups).map(function (k) { return groups[k]; })
      .filter(function (g) { return !hidden[g.fam]; });
    var shown = {};
    gs.forEach(function (g) { shown[g.id] = true; });
    var weights = {};
    G.edges.forEach(function (e) {
      var a = groupOf[e.s], b = groupOf[e.t];
      if (!a || !b || a === b || !shown[a] || !shown[b]) return;
      var anchor = function (k) { return k.indexOf("area:") === 0 || k.indexOf("grp:models-") === 0; };
      if (!anchor(a) && !anchor(b)) return;
      var key = a < b ? a + "|" + b : b + "|" + a;
      weights[key] = (weights[key] || 0) + 1;
    });
    var maxW = 1;
    Object.keys(weights).forEach(function (k) { maxW = Math.max(maxW, weights[k]); });
    var colOf = function (g) { return g.col; };
    var pos = columnLayout(gs, colOf, function (g) { return [g.order, g.label]; }, 36, COL_GAP);
    var els = gs.map(function (g) {
      return { group: "nodes", classes: "card", position: pos[g.id], data: {
        id: g.id, label: trunc(g.label, 34) + "  (" + g.members.length + ")", fam: g.fam, shape: "round-rectangle",
        isGroup: true, w: CARD_W, h: 28, fs: 12, tw: CARD_W - 16
      } };
    }).concat(headers(pos, usedCols(gs, colOf)));
    Object.keys(weights).forEach(function (k, i) {
      var p = k.split("|"), w = weights[k];
      els.push({ group: "edges", data: { id: "ov" + i, source: p[0], target: p[1], weight: w,
        width: 1 + 7 * Math.sqrt(w / maxW), op: 0.18 + 0.4 * (w / maxW) } });
    });
    render(els, { name: "preset" });
    setCount(gs.length + " groups · " + Object.keys(weights).length + " grouped links. Click a group to open it.");
  }

  function neighbourhood(memberIds) {
    var set = {}, members = {};
    memberIds.forEach(function (id) { set[id] = true; members[id] = true; });
    G.edges.forEach(function (e) {
      if (members[e.s] && G.byId[e.t]) set[e.t] = true;
      if (members[e.t] && G.byId[e.s]) set[e.s] = true;
    });
    return { set: set, members: members };
  }

  var FOCUS_LIMIT = 45;

  function showFocus(memberIds) {
    var nb = neighbourhood(memberIds);
    var nodes = Object.keys(nb.set).map(function (id) { return G.byId[id]; })
      .filter(function (n) { return nb.members[n.id] || !hidden[n.fam]; });
    if (nodes.length > FOCUS_LIMIT) return showFocusGrouped(memberIds, nb);
    var vis = {};
    nodes.forEach(function (n) { vis[n.id] = true; });
    var colOf = function (n) { return COLUMN[n.kind]; };
    var pos = columnLayout(nodes, colOf, sortKey, 46, COL_GAP);
    var els = nodes.map(function (n) {
      var el = nodeEl(n, { member: nb.members[n.id] });
      el.position = pos[n.id];
      return el;
    }).concat(headers(pos, usedCols(nodes, colOf)));
    G.edges.forEach(function (e, i) {
      if (vis[e.s] && vis[e.t] && (nb.members[e.s] || nb.members[e.t] || e.rel === "partOf")) {
        els.push({ group: "edges", data: { id: "f" + i, source: e.s, target: e.t, rel: e.rel, width: 1.2, op: 0.55 } });
      }
    });
    render(els, { name: "preset" });
    if (cy.zoom() > 1.15) { cy.zoom(1.15); cy.center(); }
    setCount(nodes.length + " nodes · " + cy.edges().length + " links");
  }

  /* Too many neighbours to read: keep the members as cards and fold each
     neighbour into its group, with link counts. */
  function showFocusGrouped(memberIds, nb) {
    var items = [], weights = {}, gcol = {};
    memberIds.forEach(function (id) {
      var n = G.byId[id];
      items.push({ id: id, col: COLUMN[n.kind], key: sortKey(n), node: n });
    });
    G.edges.forEach(function (e) {
      var m = nb.members[e.s] ? e.s : (nb.members[e.t] ? e.t : null);
      if (!m) return;
      var other = m === e.s ? e.t : e.s;
      if (nb.members[other] || !G.byId[other] || hidden[G.byId[other].fam]) return;
      var g = groupOf[other];
      gcol[g] = COLUMN[G.byId[other].kind];
      var k = m + "|" + g;
      weights[k] = (weights[k] || 0) + 1;
    });
    Object.keys(gcol).forEach(function (g) {
      var col = gcol[g];
      if (items.length && col === items[0].col) col = col === 1 ? 2 : 1;
      items.push({ id: g, col: col, key: [9, groups[g].order, groups[g].label], group: groups[g] });
    });
    var colOf = function (it) { return it.col; };
    var pos = columnLayout(items, colOf, function (it) { return it.key; }, 46, COL_GAP);
    var maxW = 1;
    Object.keys(weights).forEach(function (k) { maxW = Math.max(maxW, weights[k]); });
    var els = items.map(function (it) {
      if (it.node) { var el = nodeEl(it.node, { member: true }); el.position = pos[it.id]; return el; }
      return { group: "nodes", classes: "card", position: pos[it.id], data: {
        id: it.id, label: trunc(it.group.label, 34) + "  (" + it.group.members.length + ")", fam: it.group.fam,
        shape: "round-rectangle", isGroup: true, w: CARD_W, h: 28, fs: 12, tw: CARD_W - 16 } };
    }).concat(headers(pos, usedCols(items, colOf)));
    Object.keys(weights).forEach(function (k, i) {
      var p = k.split("|"), w = weights[k];
      els.push({ group: "edges", data: { id: "fg" + i, source: p[0], target: p[1], weight: w,
        width: 1 + 5 * Math.sqrt(w / maxW), op: 0.25 + 0.4 * (w / maxW) } });
    });
    render(els, { name: "preset" });
    if (cy.zoom() > 1.15) { cy.zoom(1.15); cy.center(); }
    setCount(memberIds.length + " members, with " + Object.keys(gcol).length +
      " connected groups. Click a member for details, or a group to open it.");
  }

  function showFull() {
    var nodes = G.nodes.filter(function (n) { return !hidden[n.fam]; });
    var vis = {};
    nodes.forEach(function (n) { vis[n.id] = true; });
    var pos = columnLayout(nodes, function (n) { return COLUMN[n.kind]; }, sortKey, 16, 420);
    var els = nodes.map(function (n) { var el = nodeEl(n, { compact: true }); el.position = pos[n.id]; return el; });
    G.edges.forEach(function (e, i) {
      if (vis[e.s] && vis[e.t]) els.push({ group: "edges", data: { id: "a" + i, source: e.s, target: e.t, width: 0.8, op: 0.25 } });
    });
    render(els, { name: "preset" });
    setCount(nodes.length + " nodes · " + cy.edges().length + " links. Zoom in to read labels, or use the overview.");
  }

  function render(els, layout) {
    cy.batch(function () {
      cy.elements().remove();
      cy.add(els);
    });
    cy.layout(Object.assign({ fit: true, padding: 40, animate: false }, layout)).run();
  }

  function setCount(t) { document.getElementById("ex-count").textContent = t; }

  /* ---------------- navigation ---------------- */

  function viewLabel(v) {
    if (v.type === "overview") return "Overview";
    if (v.type === "full") return "Full graph";
    if (v.type === "group") return groups[v.id].label;
    return v.id;
  }

  function encodeHash(v) {
    if (v.type === "group") return "grp-" + v.id.replace(":", "--");
    if (v.type === "node") return v.id;
    if (v.type === "full") return "full";
    return "";
  }

  function go(v, push) {
    if (push) stack.push(v); else stack = [v];
    view = v;
    draw();
  }

  function draw() {
    if (view.type === "overview") showOverview();
    else if (view.type === "full") showFull();
    else if (view.type === "group") showFocus(groups[view.id].members);
    else showFocus([view.id]);
    document.getElementById("view-overview").setAttribute("aria-pressed", view.type !== "full");
    document.getElementById("view-full").setAttribute("aria-pressed", view.type === "full");
    renderCrumbs();
    if (view.type === "node") { var n = cy.getElementById(view.id); n.select(); renderDetail(view.id); }
    else if (view.type === "group") renderGroupDetail(view.id);
    try { history.replaceState(null, "", "#" + encodeHash(view)); } catch (e) { /* sandboxed */ }
  }

  function renderCrumbs() {
    var el = document.getElementById("ex-crumbs");
    var parts = stack.map(function (v, i) {
      var label = esc(trunc(viewLabel(v), 48));
      return i === stack.length - 1 ? '<span class="here">' + label + "</span>"
        : '<button type="button" data-crumb="' + i + '">' + label + "</button>";
    });
    var hint = view.type === "overview" ? "Click a group to open it"
      : view.type === "full" ? "Everything at once"
      : "Click a node for details · double-click to centre on it";
    el.innerHTML = parts.join('<span class="sep">›</span>') + '<span class="hint small">' + hint + "</span>";
    Array.prototype.forEach.call(el.querySelectorAll("[data-crumb]"), function (b) {
      b.onclick = function () {
        var i = Number(b.getAttribute("data-crumb"));
        stack = stack.slice(0, i + 1);
        view = stack[i];
        draw();
      };
    });
  }

  function openNode(id) {
    var n = G.byId[id];
    if (!n) return;
    if (view && view.type === "node" && view.id === id) return;
    var base = [{ type: "overview" }];
    var gk = groupOf[id];
    if (stack.length && stack[stack.length - 1].type === "group") base = stack.slice();
    else if (gk) base.push({ type: "group", id: gk });
    stack = base.concat([{ type: "node", id: id }]);
    view = stack[stack.length - 1];
    draw();
  }

  /* ---------------- details ---------------- */

  function nodeLink(n) {
    return '<button type="button" class="d-link" data-goto="' + esc(n.id) + '">' + esc(n.label) + "</button>";
  }

  function relSection(id, rel, dir) {
    var items = S.related(G, id, rel, dir);
    if (!items.length) return "";
    var title = REL_LABEL[rel][dir === "in" ? 1 : 0];
    var lis = items.map(function (x) {
      var n = x.node, extra = "";
      if (n.kind === "api" && n.qname) extra = ' <span class="muted mono">' + esc(n.qname) + "</span>";
      else if (n.title && n.title !== n.label) extra = ' <span class="muted">' + esc(n.title) + "</span>";
      var q = x.edge.quote ? '<span class="d-quote">“' + esc(x.edge.quote) + "”</span>" : "";
      var urls = (rel === "references" || rel === "concerns") && dir !== "in" ? '<span class="d-urls">' + S.urlList(n.urls) + "</span>" : "";
      return "<li><span>" + nodeLink(n) + extra + "</span>" + q + urls + "</li>";
    }).join("");
    return '<div class="d-sec"><h4>' + esc(title) + " (" + items.length + ')</h4><ul class="d-list">' + lis + "</ul></div>";
  }

  /* The committed node a graph node was read from. */
  function fileLink(n) {
    if (!n.file) return "";
    return '<p class="small muted">Node: <a href="https://github.com/litlfred/smart-trust-tools/blob/main/' + esc(n.file) + '"><code>' + esc(n.file) + "</code></a></p>";
  }

  function badge(text, cls) { return '<span class="badge ' + (cls || "") + '">' + esc(text) + "</span>"; }

  function wireLinks(el) {
    Array.prototype.forEach.call(el.querySelectorAll("[data-goto]"), function (b) {
      b.onclick = function () { openNode(b.getAttribute("data-goto")); };
    });
  }

  function renderGroupDetail(gid) {
    var g = groups[gid], c = colors();
    var members = g.members.map(function (id) { return G.byId[id]; });
    var h = ['<div class="d-head"><span class="d-kind eyebrow">' + shapeSvg(g.shape, c[g.fam]) + "Group</span>",
      '<span class="d-title">' + esc(g.label) + "</span>",
      '<span class="small muted">' + members.length + " member" + (members.length === 1 ? "" : "s") +
      ", shown with everything directly connected to them (outlined nodes are the members).</span></div>"];
    h.push('<div class="d-sec"><h4>Members</h4><ul class="d-list">' + members.map(function (n) {
      return "<li><span>" + nodeLink(n) + (n.title && n.title !== n.label ? ' <span class="muted">' + esc(n.title) + "</span>" : "") + "</span></li>";
    }).join("") + "</ul></div>");
    var el = document.getElementById("detail");
    el.innerHTML = h.join("");
    el.scrollTop = 0;
    wireLinks(el);
  }

  function renderDetail(id) {
    var n = G.byId[id], h = [], c = colors();
    h.push('<div class="d-head"><span class="d-kind eyebrow">' + shapeSvg(SHAPE[n.kind], c[n.fam]) + esc(S.KIND_LABEL[n.kind]) + "</span>");
    h.push('<span class="mono small">' + esc(n.id) + '</span><span class="d-title">' + esc(n.title) + "</span></div>");
    if (n.kind === "requirement") {
      h.push('<div class="chips">' + badge(n.conformance, n.conformance.split(" ")[0].toLowerCase()) +
        '<span class="chip">' + esc(n.category) + '</span><span class="chip">' + esc(n.derivation) + "</span>" +
        n.targets.map(function (t) { return '<span class="chip">' + esc(t) + "</span>"; }).join("") + "</div>");
      h.push('<p class="d-statement">' + esc(n.statement) + "</p>");
      h.push(fileLink(n));
      h.push('<div class="d-actions small"><a href="requirements.html#' + esc(n.id.toLowerCase()) + '">In the requirements document</a> · <a href="trace.html#' + esc(n.id) + '">In the matrix</a></div>');
      if (n.criteria && n.criteria.length) h.push('<div class="d-sec"><h4>Success criteria</h4><ul class="small">' + n.criteria.map(function (c) {
        return '<li><span class="chip">' + esc(c.verification) + '</span> <span class="mono">' + esc(c.key) + "</span> " + esc(c.criterion) + "</li>";
      }).join("") + "</ul></div>");
      ["references", "satisfies", "realizedBy", "constrainsApi", "derivedFrom", "affectedBy"].forEach(function (r) { h.push(relSection(id, r, "out")); });
      h.push(relSection(id, "verifies", "in"));
      h.push(relSection(id, "assesses", "in"));
      h.push(relSection(id, "derivedFrom", "in"));
    } else if (n.kind === "issue") {
      h.push('<div class="chips"><span class="issue-mark">open</span>' + (n.upstream ? '<span class="chip">fix upstream</span>' : '<span class="chip">this project</span>') + "</div>");
      h.push('<p class="small">' + esc(n.text) + "</p>");
      if (n.hint) h.push('<p class="small"><strong>Suggested resolution:</strong> ' + esc(n.hint) + "</p>");
      h.push(fileLink(n));
      h.push(relSection(id, "affectedBy", "in"));
      h.push(relSection(id, "concerns", "out"));
    } else if (n.kind === "api") {
      h.push('<div class="chips"><span class="chip">' + esc(n.apiKind) + '</span><span class="chip">module ' + esc(n.module) + "</span></div>");
      var page = n.lang === "CDDL" ? "models.html#" + (n.name === n.module ? "cddl" : "cddl-" + n.name) : "api.html#file-" + n.srcFile.replace(/\.wit$/, "");
      h.push('<p class="small">' + esc(n.lang) + ': <a href="' + esc(page) + '"><code>' + esc(n.qname) + "</code></a> in <code>" + esc(n.srcFile) + "</code></p>");
      h.push(relSection(id, "constrainsApi", "in"));
      h.push(relSection(id, "partOf", "out"));
      h.push(relSection(id, "partOf", "in"));
    } else if (n.kind === "skill") {
      h.push('<div class="chips"><span class="chip">package ' + esc(n.package) + '</span></div>');
      h.push(fileLink(n));
      h.push(relSection(id, "realizedBy", "in"));
      ["implementedBy", "testedBy", "usedIn", "performedBy"].forEach(function (r) { h.push(relSection(id, r, "out")); });
      h.push(relSection(id, "planCase", "in"));
    } else if (n.kind === "test") {
      h.push(fileLink(n));
      h.push(relSection(id, "verifies", "out"));
      h.push(relSection(id, "testedBy", "in"));
    } else if (n.kind === "test-plan") {
      h.push('<div class="chips"><span class="chip">' + esc(n.status) + '</span><span class="chip">v' + esc(n.version) + '</span><span class="chip">scope: ' + esc(n.scope.kind) + (n.scope.target ? " " + esc(n.scope.target) : ", any implementation") + "</span></div>");
      h.push('<p class="small">' + esc(n.text) + "</p>");
      h.push('<p class="small"><strong>Exit criteria:</strong> ' + esc(n.exit) + "</p>");
      h.push(fileLink(n));
      h.push('<div class="d-sec"><h4>Cases (' + n.cases.length + ')</h4><ul class="small">' + n.cases.map(function (c) {
        return '<li><span class="mono">' + esc(c.id) + "</span> · " + c.assertions.length + " assertion" + (c.assertions.length === 1 ? "" : "s") + "</li>";
      }).join("") + "</ul></div>");
      ["precededBy", "planCase", "assesses"].forEach(function (r) { h.push(relSection(id, r, "out")); });
      h.push(relSection(id, "precededBy", "in"));
    } else if (n.kind === "model") {
      h.push('<div class="chips"><span class="chip">' + esc({ logical: "FHIR logical model", primitives: "FHIR primitive patterns", payload: "derived payload model" }[n.modelKind] || n.modelKind) + "</span></div>");
      if (n.canonical) h.push('<p class="small mono">' + esc(n.canonical) + "</p>");
      h.push(fileLink(n));
      h.push('<p class="small"><a href="models.html">Wire &amp; payload models</a></p>');
      h.push(relSection(id, "derivedFrom", "out"));
      h.push(relSection(id, "derivedFrom", "in"));
      h.push(relSection(id, "writes", "in"));
    } else if (n.kind === "tool" || n.kind === "process" || n.kind === "role") {
      if (n.text) h.push('<p class="small">' + esc(n.text) + "</p>");
      if (n.actorKinds) h.push('<div class="chips">' + n.actorKinds.map(function (a) { return '<span class="chip">' + esc(a) + "</span>"; }).join("") + "</div>");
      h.push(fileLink(n));
      h.push(relSection(id, { tool: "implementedBy", process: "usedIn", role: "performedBy" }[n.kind], "in"));
      if (n.kind === "tool") h.push(relSection(id, "writes", "out"));
    } else {
      if (n.note) h.push('<p class="small muted">' + esc(n.note) + "</p>");
      if (n.urls) h.push('<p class="d-urls">' + S.urlList(n.urls) + "</p>");
      ["partOf"].forEach(function (r) { h.push(relSection(id, r, "out")); h.push(relSection(id, r, "in")); });
      h.push(relSection(id, "derivedFrom", "out"));
      h.push(relSection(id, "writes", "in"));
      h.push(relSection(id, "references", "in"));
      h.push(relSection(id, "derivedFrom", "in"));
      h.push(relSection(id, "satisfies", "in"));
      h.push(relSection(id, "concerns", "in"));
    }
    var el = document.getElementById("detail");
    el.innerHTML = h.join("");
    el.scrollTop = 0;
    wireLinks(el);
  }

  /* ---------------- controls ---------------- */

  function highlight(node) {
    cy.batch(function () {
      cy.elements().addClass("faded").removeClass("hl");
      node.closedNeighborhood().removeClass("faded").addClass("hl");
    });
  }

  function clearHighlight() { cy.elements().removeClass("faded hl"); }

  function buildControls() {
    var counts = {};
    G.nodes.forEach(function (n) { counts[n.fam] = (counts[n.fam] || 0) + 1; });
    var famBox = document.getElementById("ex-families"), c = colors();
    FAMILIES.forEach(function (f) {
      var b = document.createElement("button");
      b.type = "button"; b.className = "fam-btn"; b.id = "fam-" + f.id; b.setAttribute("aria-pressed", "true");
      b.innerHTML = '<span class="swatch" style="background:' + c[f.id] + '"></span><span>' + esc(f.label) + '</span><span class="num muted">' + (counts[f.id] || 0) + "</span>";
      b.onclick = function () { hidden[f.id] = !hidden[f.id]; b.setAttribute("aria-pressed", hidden[f.id] ? "false" : "true"); draw(); };
      famBox.appendChild(b);
    });
    var area = document.getElementById("ex-area");
    G.areas.forEach(function (a) {
      var o = document.createElement("option"); o.value = a[0]; o.textContent = a[0] + " — " + a[1]; area.appendChild(o);
    });
    area.onchange = function () {
      if (!area.value) return;
      stack = [{ type: "overview" }]; go({ type: "group", id: "area:" + area.value }, true); area.value = "";
    };
    var dl = document.getElementById("ex-ids");
    G.nodes.forEach(function (n) { var o = document.createElement("option"); o.value = n.id; o.label = n.title; dl.appendChild(o); });
    var search = document.getElementById("ex-search");
    search.addEventListener("change", function () { find(search.value); });
    search.addEventListener("keydown", function (e) { if (e.key === "Enter") find(search.value); });
    document.getElementById("ex-shapes").innerHTML = SHAPE_NOTE.map(function (s) {
      return "<li>" + shapeSvg(s[0], c.fg2) + "<span>" + esc(s[1]) + "</span></li>";
    }).join("");
    document.getElementById("view-overview").onclick = function () { go({ type: "overview" }); };
    document.getElementById("view-full").onclick = function () { go({ type: "full" }); };
    document.getElementById("z-in").onclick = function () { cy.zoom({ level: cy.zoom() * 1.3, renderedPosition: { x: cy.width() / 2, y: cy.height() / 2 } }); };
    document.getElementById("z-out").onclick = function () { cy.zoom({ level: cy.zoom() / 1.3, renderedPosition: { x: cy.width() / 2, y: cy.height() / 2 } }); };
    document.getElementById("z-fit").onclick = function () { cy.fit(cy.elements(), 40); };
  }

  function find(q) {
    q = (q || "").trim();
    if (!q) return;
    var exact = G.byId[q] || G.byId[q.toUpperCase()];
    if (exact) return openNode(exact.id);
    var lq = q.toLowerCase();
    var hit = G.nodes.find(function (n) {
      return n.label.toLowerCase().indexOf(lq) >= 0 || (n.title || "").toLowerCase().indexOf(lq) >= 0 ||
        (n.statement || "").toLowerCase().indexOf(lq) >= 0;
    });
    if (hit) openNode(hit.id);
    else setCount("No node matches “" + q + "”");
  }

  function fromHash() {
    var h = decodeURIComponent((location.hash || "").slice(1));
    if (!h) return go({ type: "overview" });
    if (h === "full") return go({ type: "full" });
    if (h.indexOf("grp-") === 0) {
      var k = h.slice(4).replace("--", ":");
      if (groups[k]) { stack = [{ type: "overview" }]; return go({ type: "group", id: k }, true); }
    }
    if (G.byId[h]) { stack = []; return openNode(h); }
    go({ type: "overview" });
  }

  function init(g) {
    G = g;
    buildGroups();
    cy = cytoscape({ container: document.getElementById("cy"), style: style(), wheelSensitivity: 0.25,
      minZoom: 0.05, maxZoom: 4, boxSelectionEnabled: false });
    buildControls();
    cy.on("tap", "node", function (e) {
      var d = e.target.data();
      if (d.isGroup) { go({ type: "group", id: d.id }, true); return; }
      if (!G.byId[d.id]) return;
      cy.$(":selected").unselect(); e.target.select();
      highlight(e.target);
      renderDetail(d.id);
    });
    cy.on("dbltap", "node", function (e) { if (!e.target.data("isGroup") && G.byId[e.target.id()]) openNode(e.target.id()); });
    cy.on("mouseover", "node", function (e) { if (view.type === "overview") highlight(e.target); });
    cy.on("mouseout", "node", function () { if (view.type === "overview") clearHighlight(); });
    cy.on("tap", function (e) { if (e.target === cy) { cy.$(":selected").unselect(); clearHighlight(); } });
    var restyle = function () { cy.style(style()); };
    var mq = window.matchMedia("(prefers-color-scheme: dark)");
    if (mq.addEventListener) mq.addEventListener("change", restyle);
    new MutationObserver(restyle).observe(document.documentElement, { attributes: true, attributeFilter: ["data-fa-scheme"] });
    fromHash();
  }

  S.loadGraph().then(init).catch(function (err) {
    setCount("Could not load the graph data (" + err.message + ").");
  });
})();
