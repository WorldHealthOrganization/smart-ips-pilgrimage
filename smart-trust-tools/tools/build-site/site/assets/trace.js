/* Traceability matrix built from the same graph data as the explorer. */
(function () {
  "use strict";
  var S = window.STT, esc = S.esc, G;

  function chipLinks(items, cls) {
    if (!items.length) return '<span class="gap">—</span>';
    return '<div class="chips">' + items.map(function (x) {
      var n = x.node, label = n.kind === "api" && n.qname ? n.qname : n.label;
      if (n.kind === "test") label = "test: " + n.label;
      if (n.kind === "skill") label = n.label.replace(/^hcert-/, "");
      return '<a class="chip ' + (cls || "") + '" href="explorer.html#' + esc(n.id) + '" title="' + esc(n.title) + '">' + esc(label) + "</a>";
    }).join("") + "</div>";
  }

  function rowData(n) {
    var out = function (rel) { return S.related(G, n.id, rel, "out"); };
    var verified = S.related(G, n.id, "verifies", "in");
    return {
      n: n, satisfies: out("satisfies"), steps: out("realizedBy"), api: out("constrainsApi"),
      verified: verified, issues: out("affectedBy"), sources: out("references"),
      tested: verified.length > 0
    };
  }

  function render(rows) {
    var tb = document.querySelector("#trace-table tbody");
    tb.innerHTML = rows.map(function (r) {
      var n = r.n;
      var src = r.sources.map(function (x) {
        var u = S.bestUrl(x.node.urls);
        var label = esc(x.node.label);
        return u ? '<a href="' + esc(u) + '" target="_blank" rel="noopener" title="' + esc(x.node.title) + '">' + label + "</a>" : label;
      }).join(", ");
      var issues = r.issues.length ? '<div class="chips">' + r.issues.map(function (x) {
        return '<a class="issue-mark" href="explorer.html#' + esc(x.node.id) + '" title="' + esc(x.node.title) + '">' + esc(x.node.id) + "</a>";
      }).join(" ") + "</div>" : '<span class="gap">—</span>';
      var verified = r.verified.length ? chipLinks(r.verified) : (n.category === "test" ? '<span class="small muted">is a test</span>' : '<span class="gap">—</span>');
      return '<tr id="' + esc(n.id) + '"><td><a class="rid" href="explorer.html#' + esc(n.id) + '">' + esc(n.id) + "</a> " +
        '<span class="badge ' + n.conformance.split(" ")[0].toLowerCase() + '">' + esc(n.conformance) + "</span>" +
        '<span class="rtitle">' + esc(n.title) + '</span><span class="small muted">' + esc(n.category) + " · " + esc(n.derivation) + "</span></td>" +
        "<td>" + chipLinks(r.satisfies) + "</td><td>" + chipLinks(r.steps) + "</td><td>" + chipLinks(r.api) + "</td>" +
        "<td>" + verified + "</td><td>" + issues + '</td><td class="small">' + src + "</td></tr>";
    }).join("") || '<tr><td colspan="7" class="muted">No requirement matches these filters.</td></tr>';
    document.getElementById("tf-count").textContent = rows.length + " of " + ALL.length + " requirements";
  }

  var ALL = [];

  function filter() {
    var q = document.getElementById("tf-search").value.trim().toLowerCase();
    var area = document.getElementById("tf-area").value;
    var conf = document.getElementById("tf-conf").value;
    var cat = document.getElementById("tf-cat").value;
    var withIssues = document.getElementById("tf-issues").checked;
    var untested = document.getElementById("tf-untested").checked;
    render(ALL.filter(function (r) {
      var n = r.n;
      if (area && n.area !== area) return false;
      if (conf && n.conformance !== conf) return false;
      if (cat && n.category !== cat) return false;
      if (withIssues && !r.issues.length) return false;
      if (untested && r.tested) return false;
      if (q && (n.id + " " + n.title + " " + n.statement).toLowerCase().indexOf(q) < 0) return false;
      return true;
    }));
  }

  function summary() {
    var ups = G.nodes.filter(function (n) { return n.kind === "upstream" && n.parent; });
    var upCovered = ups.filter(function (n) { return S.related(G, n.id, "satisfies", "in").length; }).length;
    var steps = G.nodes.filter(function (n) { return n.kind === "skill"; });
    var stepsCovered = steps.filter(function (n) { return S.related(G, n.id, "implementedBy", "out").length; }).length;
    var realized = ALL.filter(function (r) { return r.steps.length; }).length;
    var tested = ALL.filter(function (r) { return r.tested; }).length;
    var issues = G.nodes.filter(function (n) { return n.kind === "issue"; });
    var upIssues = issues.filter(function (n) { return n.upstream; }).length;
    var cards = [
      [upCovered + "/" + ups.length, "smart-trust statements cited", "statements of the FHIR Requirements resources"],
      [realized + "/" + ALL.length, "requirements realized by a skill", "a skill's satisfies names them"],
      [stepsCovered + "/" + steps.length, "skills with a Tool", "a Tool's satisfies names them"],
      [tested + "/" + ALL.length, "requirements verified by a test", "a test named after the requirement, or a test requirement"],
      [issues.length, "open issues (beans)", upIssues + " to be fixed upstream"]
    ];
    document.getElementById("trace-summary").innerHTML = cards.map(function (c) {
      return '<div class="card"><strong>' + esc(c[0]) + '</strong><span>' + esc(c[1]) + '</span><span class="small muted">' + esc(c[2]) + "</span></div>";
    }).join("");
    document.getElementById("trace-upstream").innerHTML = ups.map(function (n) {
      var by = S.related(G, n.id, "satisfies", "in");
      return '<div class="cov-row"><span><a href="explorer.html#' + esc(n.id) + '" class="mono">' + esc(n.id) + '</a><br><span class="muted">' + esc(n.title) + "</span></span>" +
        (by.length ? chipLinks(by) : '<span class="gap">not covered by any library requirement</span>') + "</div>";
    }).join("");
  }

  function fillSelect(id, values) {
    var sel = document.getElementById(id);
    values.forEach(function (v) {
      var o = document.createElement("option"); o.value = v[0]; o.textContent = v[1]; sel.appendChild(o);
    });
  }

  S.loadGraph().then(function (g) {
    G = g;
    ALL = G.nodes.filter(function (n) { return n.kind === "requirement"; }).map(rowData);
    var areaRank = {};
    G.areas.forEach(function (a, i) { areaRank[a[0]] = i; });
    ALL.sort(function (a, b) { return (areaRank[a.n.area] - areaRank[b.n.area]) || (a.n.id < b.n.id ? -1 : 1); });
    fillSelect("tf-area", G.areas.map(function (a) { return [a[0], a[0] + " — " + a[1]]; }));
    var uniq = function (k) { return Array.from(new Set(ALL.map(function (r) { return r.n[k]; }))).sort().map(function (v) { return [v, v]; }); };
    fillSelect("tf-conf", uniq("conformance"));
    fillSelect("tf-cat", uniq("category"));
    ["tf-search", "tf-area", "tf-conf", "tf-cat", "tf-issues", "tf-untested"].forEach(function (id) {
      document.getElementById(id).addEventListener("input", filter);
    });
    summary();
    filter();
    var h = decodeURIComponent((location.hash || "").slice(1));
    var row = h && document.getElementById(h);
    if (row) { row.classList.add("flash"); row.scrollIntoView({ block: "center" }); }
  }).catch(function (err) {
    document.querySelector("#trace-table tbody").innerHTML = '<tr><td colspan="7">Could not load the graph data (' + esc(err.message) + ").</td></tr>";
  });
})();
