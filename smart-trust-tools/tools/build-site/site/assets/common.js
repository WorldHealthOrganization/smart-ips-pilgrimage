/* Shared helpers for the explorer and traceability pages. */
(function () {
  "use strict";

  var KIND_LABEL = {
    requirement: "Requirement", section: "Source section", document: "Source document",
    standard: "Standard", directive: "Owner directive", upstream: "smart-trust requirement",
    skill: "Skill", api: "WIT item", tool: "Tool", test: "Test", "test-plan": "Test plan", process: "Process (BPMN)", role: "Role",
    model: "Model (FHIR logical or payload)", issue: "Open issue (bean)"
  };
  var URL_LABEL = {
    pinned: "Source (pinned commit)", preview: "PR preview build", main: "Source on main",
    ci: "CI build", published: "Published IG", url: "Link"
  };
  var URL_ORDER = ["pinned", "preview", "published", "ci", "main", "url"];

  function loadGraph() {
    return fetch("data/graph.json").then(function (r) {
      if (!r.ok) throw new Error("graph.json: HTTP " + r.status);
      return r.json();
    }).then(index);
  }

  /* Adds lookup tables: byId, out[id] = [{rel, node, edge}], inn[id] likewise. */
  function index(g) {
    g.byId = {};
    g.out = {};
    g.inn = {};
    g.nodes.forEach(function (n) { g.byId[n.id] = n; g.out[n.id] = []; g.inn[n.id] = []; });
    g.edges.forEach(function (e) {
      if (!g.byId[e.s] || !g.byId[e.t]) return;
      g.out[e.s].push({ rel: e.rel, node: g.byId[e.t], edge: e });
      g.inn[e.t].push({ rel: e.rel, node: g.byId[e.s], edge: e });
    });
    return g;
  }

  function related(g, id, rel, dir) {
    var list = (dir === "in" ? g.inn : g.out)[id] || [];
    return list.filter(function (x) { return x.rel === rel; });
  }

  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  function urlList(urls) {
    if (!urls) return "";
    return URL_ORDER.filter(function (k) { return urls[k]; }).map(function (k) {
      return '<a href="' + esc(urls[k]) + '" target="_blank" rel="noopener">' + esc(URL_LABEL[k]) + " ↗</a>";
    }).join(" · ");
  }

  function bestUrl(urls) {
    if (!urls) return null;
    for (var i = 0; i < URL_ORDER.length; i++) if (urls[URL_ORDER[i]]) return urls[URL_ORDER[i]];
    return null;
  }

  function cssVar(name) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  }

  window.STT = {
    KIND_LABEL: KIND_LABEL, loadGraph: loadGraph, related: related, esc: esc,
    urlList: urlList, bestUrl: bestUrl, cssVar: cssVar
  };
})();
