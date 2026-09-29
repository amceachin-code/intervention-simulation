// Shared SVG chart helpers for the explorer (index.html) and its methods
// page (methods.html). No libraries: every chart is a handful of SVG paths.
//
// Every chart here runs along the percentile axis from the 10th to the 90th,
// the range the published NAEP percentiles support. Load after cells.js:
// frame() marks the published percentiles from it by default.
"use strict";
(function () {
  const NS = "http://www.w3.org/2000/svg";

  // "10th", "21st", "52nd", "73rd".
  const ord = (p) => p + (p % 10 === 1 && p !== 11 ? "st" : p % 10 === 2 && p !== 12 ? "nd" : p % 10 === 3 && p !== 13 ? "rd" : "th");

  // Create an SVG element with attributes, optionally appending it.
  function el(tag, attrs, parent) {
    const e = document.createElementNS(NS, tag);
    for (const [a, v] of Object.entries(attrs)) e.setAttribute(a, v);
    if (parent) parent.appendChild(e);
    return e;
  }

  // Round tick values for a y axis: the smallest "nice" step (1, 2, 2.5, 5 x
  // a power of ten) that gives no more than n intervals.
  function niceTicks(lo, hi, n) {
    const span = hi - lo, raw = span / n, mag = Math.pow(10, Math.floor(Math.log10(raw)));
    const step = [1, 2, 2.5, 5, 10].map((s) => s * mag).find((s) => span / s <= n) || 10 * mag;
    const out = [];
    for (let t = Math.ceil(lo / step) * step; t <= hi + 1e-12; t += step) out.push(Math.abs(t) < 1e-12 ? 0 : t);
    return out;
  }

  // SVG path data through a list of [x, y] points.
  const path = (pts) => pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(1) + "," + p[1].toFixed(1)).join("");

  // Shared chart frame: clears the container's old SVG, draws y gridlines
  // and labels, an x gridline and label at each percentile in xTicks (by
  // default the five NAEP reports, from cells.js), and a zero line when the y
  // domain crosses zero. Returns the scales and the SVG to draw into.
  function frame(containerId, W, H, yDom, yFmt, nTicks, xTicks = globalThis.TOOL_DATA.percentiles) {
    const box = document.getElementById(containerId);
    box.querySelector("svg")?.remove();
    const m = { l: 44, r: 12, t: 8, b: 26 };
    const svg = el("svg", { viewBox: `0 0 ${W} ${H}`, role: "img" });
    box.prepend(svg);
    const x = (p) => m.l + (p - 10) / 80 * (W - m.l - m.r);
    const y = (v) => m.t + (yDom[1] - v) / (yDom[1] - yDom[0]) * (H - m.t - m.b);
    const ax = el("g", { class: "axis" }, svg);
    niceTicks(yDom[0], yDom[1], nTicks).forEach((t) => {
      el("line", { class: "gridline", x1: m.l, x2: W - m.r, y1: y(t), y2: y(t) }, ax);
      el("text", { x: m.l - 6, y: y(t) + 4, "text-anchor": "end" }, ax).textContent = yFmt(t);
    });
    xTicks.forEach((p) => {
      el("text", { x: x(p), y: H - 8, "text-anchor": "middle" }, ax).textContent = ord(p);
      el("line", { class: "gridline", x1: x(p), x2: x(p), y1: m.t, y2: H - m.b }, ax);
    });
    if (yDom[0] < 0 && yDom[1] > 0) el("line", { class: "zero", x1: m.l, x2: W - m.r, y1: y(0), y2: y(0) }, svg);
    return { svg, x, y, m, W, H, box };
  }

  // Crosshair and tooltip: snap to the nearest whole percentile in the curve.
  // The container must hold a <div class="tip">.
  function hover(F, curve, yOf, html) {
    const { svg, x, m, W, H, box } = F;
    const tip = box.querySelector(".tip");
    const cross = el("line", { x1: 0, x2: 0, y1: m.t, y2: H - m.b, stroke: "var(--text-muted)", "stroke-width": 1, visibility: "hidden" }, svg);
    const dot = el("circle", { r: 5, fill: "none", stroke: "var(--text-primary)", "stroke-width": 2, visibility: "hidden" }, svg);
    const hit = el("rect", { x: m.l, y: m.t, width: W - m.l - m.r, height: H - m.t - m.b, fill: "transparent" }, svg);
    function move(ev) {
      const pt = svg.createSVGPoint(); pt.x = ev.clientX; pt.y = ev.clientY;
      const loc = pt.matrixTransform(svg.getScreenCTM().inverse());
      const p = Math.round(10 + (loc.x - m.l) / (W - m.l - m.r) * 80);
      const r = curve.find((c) => c.p === Math.min(90, Math.max(10, p)));
      if (!r) return;
      cross.setAttribute("x1", x(r.p)); cross.setAttribute("x2", x(r.p));
      dot.setAttribute("cx", x(r.p)); dot.setAttribute("cy", yOf(r));
      cross.setAttribute("visibility", "visible"); dot.setAttribute("visibility", "visible");
      tip.innerHTML = html(r); tip.style.display = "block";
      const bb = box.getBoundingClientRect(), px = ev.clientX - bb.left;
      tip.style.left = Math.min(px + 12, bb.width - tip.offsetWidth - 4) + "px";
      tip.style.top = "8px";
    }
    function leave() { cross.setAttribute("visibility", "hidden"); dot.setAttribute("visibility", "hidden"); tip.style.display = "none"; }
    hit.addEventListener("pointermove", move);
    hit.addEventListener("pointerdown", move);
    hit.addEventListener("pointerleave", leave);
  }

  // The whole-percentile grid every curve is drawn on, p10 to p90 (the range
  // frame() maps).
  const CURVE_P = Array.from({ length: 81 }, (_, i) => 10 + i);

  globalThis.NAEPCharts = { ord, el, niceTicks, path, frame, hover, CURVE_P };

  // ---------------------------------------------------------------------
  // Page helpers shared by both pages: number formats, display names, and
  // config lookups. One copy, so the explorer and the methods page cannot
  // drift apart in wording or rounding.

  const f0 = (x) => x.toFixed(0), f1 = (x) => x.toFixed(1), f2 = (x) => x.toFixed(2), f3 = (x) => x.toFixed(3);
  // Percent with one decimal unless the value is a whole percent.
  function fmtPct(x) { const v = x * 100; return (Math.abs(v - Math.round(v)) < 0.05 ? v.toFixed(0) : v.toFixed(1)) + "%"; }

  // Display names. The data keys stay as the pipeline writes them ("Reading
  // G4"); only what the reader sees changes ("Reading, grade 4").
  const cellName = (label) => label.replace(/ G(\d+)$/, ", grade $1");

  // Look up a config entry by id and fail loudly if it is missing, rather
  // than falling back to a hand-typed number (parameters live only in the
  // config).
  function configValue(list, id) {
    const hit = list.find((x) => x.id === id);
    if (!hit) throw new Error(`cells.js has no config entry '${id}'; rerun analysis/10-export-tool-data.R`);
    return hit;
  }

  // Plain-language preset names, keyed by config id. The numbers still come
  // from the config; an id without an entry here falls back to its label.
  const CHIP_NAMES = {
    tut_scale:   "Tutoring, large programs (1,000+ students)",
    tut_mid:     "Tutoring, mid-size programs (400 to 999 students)",
    summer_math: "Summer school, math (average across studies)",
    summer_real: "Summer school since COVID (what districts saw)",
    universal:   "Every student",
    hdt_dist:    "District tutoring (common planning figure)",
    optin:       "Sign-up rate for optional tutoring",
    summer:      "Summer school attendance",
  };
  const chipName = (x) => CHIP_NAMES[x.id] || x.label;

  // Button labels for the five tilt levels, by engine level id, with a line
  // break where the explorer's narrow buttons wrap. The same levels drive
  // both controls, so each gets its own wording. tiltName gives the one-line
  // form for running text and tables.
  const TILT_LABELS = {
    part: {
      "strong-neg": "Mostly<br>low scorers", "mild-neg": "More<br>low scorers", neutral: "All<br>equally",
      "mild-pos": "More<br>high scorers", "strong-pos": "Mostly<br>high scorers",
    },
    effect: {
      "strong-neg": "Low scorers,<br>much more", "mild-neg": "Low scorers,<br>more", neutral: "All<br>equally",
      "mild-pos": "High scorers,<br>more", "strong-pos": "High scorers,<br>much more",
    },
  };
  const tiltName = (kind, id) => TILT_LABELS[kind][id].replace("<br>", " ");

  // "Data: path (md5 abcd1234), ..." for the given source files, or all of
  // them when no paths are named.
  function provenanceText(D, paths) {
    const srcs = paths ? D.sources.filter((f) => paths.includes(f.path)) : D.sources;
    return `Data: ${srcs.map((f) => `${f.path} (md5 ${f.md5.slice(0, 8)})`).join(", ")}.`;
  }

  globalThis.NAEPShared = { f0, f1, f2, f3, fmtPct, cellName, configValue, CHIP_NAMES, chipName,
                            TILT_LABELS, tiltName, provenanceText };
})();
