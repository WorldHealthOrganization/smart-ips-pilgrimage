(function () {
  Array.prototype.forEach.call(document.querySelectorAll(".pt-diagram:not([data-pt-ready])"), init);
  function init(root) {
  root.setAttribute("data-pt-ready", "");
  // Every href in the sidecar is relative to the sidecar (it sits beside the
  // process page), so a page elsewhere on the site that shows the same
  // drawing resolves them to the same targets.
  // A drawing with no sidecar (a page that only highlights steps, where no
  // processes viewer is published) gets the highlight and nothing else.
  var sidecar = root.getAttribute("data-panel");
  var base = new URL(sidecar || "", location.href);
  function abs(h) { try { return new URL(h, base).href; } catch (e) { return h; } }
  // A page with no server-drawn markers gets them from the sidecar.
  var drawn = !!root.querySelector(".pt-layer");
  if (!drawn) {
    var ly = document.createElement("div"); ly.className = "pt-layer"; root.appendChild(ly);
    var pn = document.createElement("div"); pn.className = "pt-panel"; pn.setAttribute("role", "dialog");
    pn.setAttribute("aria-label", "Task details"); pn.hidden = true; root.appendChild(pn);
  }
  var panel = root.querySelector(".pt-panel"), data = null, pending = null, open = null;
  function load() {
    if (data) return Promise.resolve(data);
    if (!pending) pending = fetch(root.getAttribute("data-panel")).then(function (r) {
      if (!r.ok) throw new Error(r.status + " " + r.statusText);
      return r.json();
    }).then(function (j) { data = j; return j; });
    return pending;
  }
  function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }
  function link(l, cls) {
    var e = el(l.href ? "a" : "code", cls, l.name);
    if (l.href) e.href = abs(l.href); else e.title = "no page for this one";
    return e;
  }
  function obj(stereo, name, kind) {
    var box = el("div", "pt-obj pt-" + kind), head = el("div", "pt-head");
    head.appendChild(el("span", "pt-st", "\u00ab" + stereo + "\u00bb"));
    head.appendChild(typeof name === "string" ? el("b", null, name) : name);
    box.appendChild(head);
    return box;
  }
  function edge(label) { return el("div", "pt-edge", "\u2502 " + label + " \u25bc"); }
  function render(t) {
    panel.textContent = "";
    var close = el("button", "pt-close", "\u00d7"); close.type = "button"; close.setAttribute("aria-label", "Close");
    close.onclick = function () { hide(); }; panel.appendChild(close);
    // The title opens the step's description below the drawing; the step's
    // own page, where it has one, is its id.
    var title = link({ name: t.name, href: t.stepHref || t.href });
    if (t.stepHref) title.onclick = function () { hide(); };
    var task = obj(t.type.replace(/^bpmn:/, ""), title, "task");
    var idl = el("div", "pt-attr", "id = ");
    if (t.stepHref && t.href) idl.appendChild(link({ name: t.id, href: t.href })); else idl.appendChild(document.createTextNode(t.id));
    task.appendChild(idl);
    if (t.lane) {
      var ln = el("div", "pt-attr", "lane = "); ln.appendChild(link({ name: t.lane, href: t.laneHref }));
      // The lane is a partition; the Role it names is who acts (owner,
      // 2026-10-31: "i thought there was a Role/person or actor that should be
      // linked"). Shown here too, not only in the Role box further down.
      if (t.role) { ln.appendChild(el("span", "pt-st", " → role ")); ln.appendChild(link(t.role)); }
      task.appendChild(ln);
    }
    if (data && data.processHref) { var pr = el("div", "pt-attr", "process = "); pr.appendChild(link({ name: data.process, href: data.processHref })); task.appendChild(pr); }
    panel.appendChild(task);
    if (t.calls) {
      panel.appendChild(edge("calls"));
      var cp = obj("Process", link(t.calls), "proc");
      if (t.calls.diagram && t.calls.diagram !== t.calls.href) { var dg = el("div", "pt-attr"); dg.appendChild(link({ name: "diagram", href: t.calls.diagram })); cp.appendChild(dg); }
      panel.appendChild(cp);
    }
    if (t.shared) {
      panel.appendChild(edge("calls"));
      var gt = obj(t.shared.type.replace(/^bpmn:/, ""), t.shared.id, "proc");
      Object.keys(t.shared.inputs || {}).forEach(function (k) { gt.appendChild(el("div", "pt-attr", k + " = " + t.shared.inputs[k])); });
      panel.appendChild(gt);
    }
    var sk_on = !(data && data.skills === false);
    (sk_on ? t.skills : []).forEach(function (s) {
      panel.appendChild(edge("requires"));
      var sk = obj("Skill", link(s), "skill");
      (s.methodologies || []).forEach(function (m) {
        var row = el("div", "pt-attr"); row.appendChild(el("span", "pt-st", "uses-methodology \u2192 "));
        row.appendChild(link(m)); sk.appendChild(row);
      });
      panel.appendChild(sk);
    });
    if (sk_on && !t.skills.length && !t.calls) panel.appendChild(el("div", "pt-none", "This task names no skill."));
    if (t.role) {
      panel.appendChild(edge("lane names"));
      var role = obj("Role", link(t.role), "role");
      if (t.role.title) role.appendChild(el("div", "pt-attr", "title = " + t.role.title));
      if (sk_on) {
        var list = el("div", "pt-attr"); list.appendChild(el("span", "pt-st", "hasSkill: "));
        if (!t.role.skills.length) list.appendChild(el("i", null, "none listed"));
        t.role.skills.forEach(function (s, i) {
          if (i) list.appendChild(document.createTextNode(", "));
          list.appendChild(link(s));
          if (s.via) list.appendChild(el("span", "pt-via", " (via " + s.via + ")"));
        });
        role.appendChild(list);
      }
      panel.appendChild(role);
    } else if (t.binding) {
      panel.appendChild(el("div", "pt-none", "Lane role: " + t.binding + "."));
    }
  }
  // THE MARKERS FOLLOW THE DRAWING, not the box around it. The site's figure
  // viewer (docs-ui.js) swaps the <img> for an inlined <svg>, puts a toolbar
  // above it, and zooms and pans it inside a scroll box. Positioned against
  // this block, every marker and link drifted off its shape (owner,
  // 2026-10-31: "misaligned"). So the layer is laid over wherever the drawing
  // is actually drawn, and re-laid whenever that can change.
  var layer = root.querySelector(".pt-layer"), queued = false;
  function art() {
    var c = root.querySelectorAll("img, svg");
    for (var i = 0; i < c.length; i++) {
      var e = c[i];
      if (e.closest(".pt-layer, .pt-panel, .fa-figure-tools")) continue;
      if (e.parentElement && e.parentElement.closest("svg")) continue;
      return e;
    }
    return null;
  }
  // A page may name steps to pick out (a journey's step shows the tasks it
  // realises): `data-pt-highlight="Task_A Task_B"`. Marked once the drawing
  // is inline, which is when its shapes exist to mark.
  var hl = (root.getAttribute("data-pt-highlight") || "").split(/\s+/).filter(Boolean);
  if (hl.length) root.classList.add("pt-has-hl");
  function mark(a) {
    if (!hl.length || a.tagName.toLowerCase() !== "svg" || a.hasAttribute("data-pt-marked")) return;
    a.setAttribute("data-pt-marked", "");
    Array.prototype.forEach.call(a.querySelectorAll("[data-element-id]"), function (g) {
      if (hl.indexOf(g.getAttribute("data-element-id")) >= 0) g.setAttribute("data-pt-hl", "");
    });
  }
  function place() {
    queued = false;
    var a = art();
    if (a) mark(a);
    if (!layer || !a) return;
    var r = root.getBoundingClientRect(), b = a.getBoundingClientRect();
    var x = b.left - r.left, y = b.top - r.top, w = b.width, h = b.height, vw = 0, vh = 0;
    if (a.tagName.toLowerCase() === "img") { vw = a.naturalWidth; vh = a.naturalHeight; }
    else { var vb = (a.getAttribute("viewBox") || "").trim().split(/[\s,]+/).map(Number); vw = vb[2]; vh = vb[3]; }
    // An SVG keeps its aspect inside a box of another shape (xMidYMid meet).
    if (vw > 0 && vh > 0 && w > 0 && h > 0) {
      var k = vw / vh;
      if (w / h > k) { var nw = h * k; x += (w - nw) / 2; w = nw; } else { var nh = w / k; y += (h - nh) / 2; h = nh; }
    }
    layer.style.left = x + "px"; layer.style.top = y + "px"; layer.style.width = w + "px"; layer.style.height = h + "px";
    // Zoomed in, the drawing scrolls inside its box: markers past the edge are hidden with it.
    var sc = a.parentElement;
    while (sc && sc !== root && !(sc.scrollWidth > sc.clientWidth + 1 || sc.scrollHeight > sc.clientHeight + 1)) sc = sc.parentElement;
    if (sc && sc !== root) {
      var s = sc.getBoundingClientRect(), L = r.left + x, T = r.top + y;
      layer.style.clipPath = "inset(" + Math.max(0, s.top - T) + "px " + Math.max(0, L + w - s.right) + "px " +
        Math.max(0, T + h - s.bottom) + "px " + Math.max(0, s.left - L) + "px)";
    } else layer.style.clipPath = "";
    if (open) at(open);
  }
  function schedule() { if (!queued) { queued = true; requestAnimationFrame(place); } }
  if (window.ResizeObserver) new ResizeObserver(schedule).observe(root);
  if (window.MutationObserver) new MutationObserver(function (ms) {
    for (var i = 0; i < ms.length; i++) if (!layer || !layer.contains(ms[i].target)) { schedule(); return; }
  }).observe(root, { childList: true, subtree: true, attributes: true, attributeFilter: ["style", "class", "viewBox"] });
  root.addEventListener("scroll", schedule, true);
  root.addEventListener("load", schedule, true);
  window.addEventListener("resize", schedule);
  schedule();
  if (!drawn && sidecar) load().then(function (j) {
    (j.markers || []).forEach(function (m) {
      var t = j.tasks[m.id], to = t && t.calls ? (t.calls.diagram || t.calls.href) : null;
      if (to && m.box) {
        var g = el("a", "pt-go"); g.href = abs(to);
        g.style.left = m.box.left + "%"; g.style.top = m.box.top + "%"; g.style.width = m.box.width + "%"; g.style.height = m.box.height + "%";
        g.setAttribute("aria-label", "Open subprocess: " + m.name); g.title = "Open subprocess: " + m.name; layer.appendChild(g);
      }
      var b = el("button", "pt-mark", "i"); b.type = "button"; b.setAttribute("data-task", m.id);
      b.style.left = m.left + "%"; b.style.top = m.top + "%"; b.setAttribute("aria-expanded", "false");
      b.setAttribute("aria-label", "About step: " + m.name); b.title = "About: " + m.name; layer.appendChild(b);
    });
    schedule();
  }).catch(function (e) { console.warn("task panel: could not load " + base.href + " (" + e.message + ")"); });
  function at(b) {
    var r = root.getBoundingClientRect(), m = b.getBoundingClientRect();
    panel.style.left = (m.left + m.width / 2 - r.left) + "px"; panel.style.top = (m.top + m.height / 2 - r.top) + "px";
  }
  function hide() { panel.hidden = true; if (open) open.setAttribute("aria-expanded", "false"); open = null; }
  root.addEventListener("click", function (ev) {
    var b = ev.target.closest && ev.target.closest(".pt-mark");
    if (!b) return;
    if (open === b) { hide(); return; }
    if (open) open.setAttribute("aria-expanded", "false");
    open = b; b.setAttribute("aria-expanded", "true");
    at(b);
    panel.hidden = false; panel.textContent = "Loading\u2026";
    load().then(function (j) {
      var t = j.tasks[b.getAttribute("data-task")];
      if (open === b) { if (t) render(t); else panel.textContent = "No details for this task."; }
    }).catch(function (e) { if (open === b) panel.textContent = "Could not load task details: " + e.message; });
  });
  document.addEventListener("keydown", function (ev) { if (ev.key === "Escape" && open) hide(); });
  }
})();
