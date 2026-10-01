// Computes every number and SVG fragment the redesign comps use, from the
// explorer's own engine and data (docs/engine.js, docs/cells.js) and the
// committed seat-allocation tables. Run from docs/.
const fs = require("fs");
const OUT = process.argv[2];
require(process.cwd() + "/cells.js"); require(process.cwd() + "/engine.js");
const D = globalThis.TOOL_DATA, E = globalThis.NAEPEngine;
const PS = D.percentiles;
const CP = []; for (let p = 10; p <= 90; p += 2) CP.push(p);
const FULLP = []; for (let p = 10; p <= 90; p++) FULLP.push(p);
const cell = D.cells.find((c) => c.label === "Math G8");
const S = cell.sd2019;
const MINUS = "−";
const sgn = (s) => s.replace(/^-/, MINUS);
const f0 = (x) => x.toFixed(0), f1 = (x) => x.toFixed(1), f2 = (x) => x.toFixed(2), f3 = (x) => x.toFixed(3);
const ord = (p) => p + "th";
function fmtPct(x) { const v = x * 100; return (Math.abs(v - Math.round(v)) < 0.05 ? v.toFixed(0) : v.toFixed(1)) + "%"; }
function niceTicks(lo, hi, n) {
  const span = hi - lo, raw = span / n, mag = Math.pow(10, Math.floor(Math.log10(raw)));
  const step = [1, 2, 2.5, 5, 10].map((s) => s * mag).find((s) => span / s <= n) || 10 * mag;
  const out = [];
  for (let t = Math.ceil(lo / step) * step; t <= hi + 1e-12; t += step) out.push(Math.abs(t) < 1e-12 ? 0 : t);
  return out;
}
const P = (pts) => pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(1) + "," + p[1].toFixed(1)).join("");
const n1 = (v) => v.toFixed(1);

const base = { effect: 0.155, share: 0.28, kPart: 0, kEffect: 0, mode: "distributional", rule: "tilt" };
const run = (o, ps = CP) => E.scenario(cell, PS, Object.assign({}, base, o), ps);
const K = (id) => E.TILT_LEVELS.find((l) => l.id === id).k;

// Generic frame: gridlines + y labels (left, optional right) + x labels.
function frame(o) {
  const { W, H, m, yDom, yTicks, yFmt, xTicks = PS, xDom = [10, 90], xFmt = ord, st } = o;
  const x = (p) => m.l + (p - xDom[0]) / (xDom[1] - xDom[0]) * (W - m.l - m.r);
  const y = (v) => m.t + (yDom[1] - v) / (yDom[1] - yDom[0]) * (H - m.t - m.b);
  let s = "";
  for (const t of yTicks) {
    s += `<line x1="${n1(m.l)}" x2="${n1(W - m.r)}" y1="${n1(y(t))}" y2="${n1(y(t))}" stroke="${st.grid}" stroke-width="1"></line>`;
    s += `<text x="${n1(m.l - 8)}" y="${n1(y(t) + 4)}" text-anchor="end" fill="${st.axis}" font-size="${st.fs}">${yFmt(t)}</text>`;
  }
  if (o.right) for (const t of o.right.ticks) {
    const yy = y(o.right.map(t));
    s += `<text x="${n1(W - m.r + 8)}" y="${n1(yy + 4)}" text-anchor="start" fill="${st.axis}" font-size="${st.fs}">${o.right.fmt(t)}</text>`;
  }
  for (const p of xTicks) {
    if (st.xgrid) s += `<line x1="${n1(x(p))}" x2="${n1(x(p))}" y1="${n1(m.t)}" y2="${n1(H - m.b)}" stroke="${st.grid}" stroke-width="1"></line>`;
    s += `<text x="${n1(x(p))}" y="${n1(H - m.b + 18)}" text-anchor="middle" fill="${st.axis}" font-size="${st.fs}">${xFmt(p)}</text>`;
  }
  if (yDom[0] < 0 && yDom[1] >= 0) s += `<line x1="${n1(m.l)}" x2="${n1(W - m.r)}" y1="${n1(y(0))}" y2="${n1(y(0))}" stroke="${st.zero}" stroke-width="1"></line>`;
  return { x, y, s, W, H, m };
}
const band = (F, rows, a, b) => P(rows.map((r) => [F.x(r.p), F.y(a(r))])) + P(rows.slice().reverse().map((r) => [F.x(r.p), F.y(b(r))])).replace("M", "L") + "Z";
const line = (F, rows, a) => P(rows.map((r) => [F.x(r.p), F.y(a(r))]));
const svgOpen = (W, H, label) => `<svg viewBox="0 0 ${W} ${H}" width="100%" role="img" aria-label="${label}" style="display: block; overflow: visible">`;

const out = {};
const knotTable = (res) => res.knots.map((k) => ({ p: k.p, gStar: f3(k.gStar), gain: f3(k.gain), rem: f3(-k.remaining), part: fmtPct(k.part),
  eff: f3(k.effect), share: k.gStar > 0 ? Math.round(k.gain / k.gStar * 100) + "%" : "n/a" }));

// ------------------------------------------------------------ scenarios
const def = run({}), low = run({ kPart: K("strong-neg") }), uni = run({ effect: 0.214, share: 1 });
const defFull = run({}, FULLP);
out.numbers = {
  S: f1(S), sdRound: f0(S), tenth: f0(0.1 * S), effPts: f1(0.155 * S),
  drop10: f0(-cell.d[0]), drop90: f0(-cell.d[4]), d10: f1(-cell.d[0]), d90: f1(-cell.d[4]),
  def: { knots: knotTable(def), gap: [f1(def.gap9010.y2019), f1(def.gap9010.y2024), f1(def.gap9010.post)] },
  low: { knots: knotTable(low), gap: [f1(low.gap9010.y2019), f1(low.gap9010.y2024), f1(low.gap9010.post)] },
  uni: { knots: knotTable(uni), gap: [f1(uni.gap9010.y2019), f1(uni.gap9010.y2024), f1(uni.gap9010.post)] },
  edpop: fmtPct(cell.ed.pop),
  g10: f3(def.knots[0].gStar), req: [1, 0.28, 0.187, 0.13].map((c) => ({ c, v: def.knots.map((k) => f2(k.gStar / c)) })),
  kraft2020: D.kraft2020,
};

// ------------------------------------------------------------ Today (Main)
{
  const st = { grid: "#ebeae6", axis: "#77766f", zero: "#77766f", fs: 11, xgrid: true };
  const rows = defFull.curve;
  const before = (r) => -r.gStar, after = (r) => -r.remaining;
  const vals = rows.flatMap((r) => [before(r), after(r)]);
  const lo = Math.min(-0.05, ...vals), hi = Math.max(0, ...vals), pad = (hi - lo) * 0.08;
  const yDom = [lo - pad, hi > 0 ? hi + pad : 0];
  const F = frame({ W: 720, H: 320, m: { l: 44, r: 12, t: 8, b: 26 }, yDom, yTicks: niceTicks(yDom[0], yDom[1], 6), yFmt: f2, st });
  // charts.js puts x labels at H - 8, not H - b + 18; redo that detail
  let s = svgOpen(720, 320, "Decline curve") + F.s.replace(/y="(\d+\.\d)" text-anchor="middle"/g, `y="312.0" text-anchor="middle"`);
  s += `<path d="${band(F, rows, before, (r) => Math.min(0, after(r)))}" fill="rgba(42, 120, 214, 0.16)"></path>`;
  s += `<path d="${line(F, rows, before)}" fill="none" stroke="#77766f" stroke-width="2" stroke-dasharray="5 4"></path>`;
  s += `<path d="${line(F, rows, after)}" fill="none" stroke="#2a78d6" stroke-width="2"></path>`;
  for (const r of rows.filter((r) => PS.includes(r.p))) {
    s += `<circle cx="${n1(F.x(r.p))}" cy="${n1(F.y(after(r)))}" r="4" fill="#2a78d6" stroke="#fcfcfb" stroke-width="2"></circle>`;
    s += `<circle cx="${n1(F.x(r.p))}" cy="${n1(F.y(before(r)))}" r="4" fill="#77766f" stroke="#fcfcfb" stroke-width="2"></circle>`;
  }
  out.today_main = s + "</svg>";
  const prof = (W, H, dom, fmt, acc, color, lab) => {
    const G = frame({ W, H, m: { l: 44, r: 12, t: 8, b: 26 }, yDom: dom, yTicks: niceTicks(dom[0], dom[1], 4), yFmt: fmt, st });
    return svgOpen(W, H, lab) + G.s.replace(/y="(\d+\.\d)" text-anchor="middle"/g, `y="${H - 8}.0" text-anchor="middle"`) +
      `<path d="${line(G, rows, acc)}" fill="none" stroke="${color}" stroke-width="2"></path></svg>`;
  };
  out.today_part = prof(340, 180, [0, 1], fmtPct, (r) => r.part, "#2a78d6", "Participation profile");
  out.today_eff = prof(340, 180, [0, Math.max(0.05, 0.155) * 1.1], f2, (r) => r.effect, "#eb6834", "Effect profile");
}

// ------------------------------------------------------------ new look
const NS = { grid: "#E8EBEF", axis: "#5B6370", zero: "#5B6370", fs: 12, xgrid: false };
const C = { before: "#7B818B", after: "#2A78D6", closed: "rgba(42, 120, 214, 0.16)", over: "rgba(235, 104, 52, 0.18)",
            ink: "#101418", blueText: "#1B5FB8", surface: "#FFFFFF" };

// A main chart, with a points axis on the right.
function declineChart(W, H, m, yDom, yStep, rightStep, labels, fs) {
  const rows = def.curve;
  const before = (r) => -r.gStar, after = (r) => -r.remaining;
  const ticks = []; for (let t = Math.ceil(yDom[0] / yStep - 1e-9) * yStep; t <= yDom[1] + 1e-9; t += yStep) ticks.push(Math.abs(t) < 1e-9 ? 0 : t);
  const rt = []; for (let t = 0; t / S >= yDom[0]; t -= rightStep) rt.push(t);
  const st = Object.assign({}, NS, { fs });
  const F = frame({ W, H, m, yDom, yTicks: ticks, yFmt: (t) => sgn(yStep < 0.1 ? f2(t) : f1(t)), st,
    right: rightStep ? { ticks: rt, map: (t) => t / S, fmt: (t) => sgn(f0(t)) } : null });
  let s = svgOpen(W, H, "How far each percentile sits below its 2019 score") + F.s;
  s += `<path d="${band(F, rows, before, (r) => Math.min(0, after(r)))}" fill="${C.closed}"></path>`;
  s += `<path d="${line(F, rows, before)}" fill="none" stroke="${C.before}" stroke-width="2" stroke-dasharray="6 5"></path>`;
  s += `<path d="${line(F, rows, after)}" fill="none" stroke="${C.after}" stroke-width="2.5"></path>`;
  for (const r of rows.filter((r) => PS.includes(r.p))) {
    s += `<circle cx="${n1(F.x(r.p))}" cy="${n1(F.y(before(r)))}" r="4" fill="${C.before}" stroke="${C.surface}" stroke-width="2"></circle>`;
    s += `<circle cx="${n1(F.x(r.p))}" cy="${n1(F.y(after(r)))}" r="4.5" fill="${C.after}" stroke="${C.surface}" stroke-width="2"></circle>`;
  }
  if (labels) {
    const at = (p) => rows.find((r) => r.p === p);
    const lp = labels.p;
    s += `<text x="${n1(F.x(lp))}" y="${n1(F.y(before(at(lp))) + 20)}" fill="${C.ink}" font-size="${fs + 1}" font-weight="600">2024, no program</text>`;
    s += `<text x="${n1(F.x(lp))}" y="${n1(F.y(after(at(lp))) - 12)}" fill="${C.blueText}" font-size="${fs + 1}" font-weight="600">2024, with the program</text>`;
    if (labels.band) {
      const bp = labels.band, r = at(bp);
      s += `<text x="${n1(F.x(bp))}" y="${n1((F.y(before(r)) + F.y(after(r))) / 2 + 4)}" fill="${C.blueText}" font-size="${fs}" text-anchor="middle">Drop undone</text>`;
    }
  }
  if (labels && labels.axisTitles) {
    s += `<text x="${n1(m.l - 8)}" y="${n1(m.t - 8)}" text-anchor="end" fill="${C.ink}" font-size="${fs}" font-weight="600">SD</text>`;
    if (rightStep) s += `<text x="${n1(W - m.r + 8)}" y="${n1(m.t - 8)}" text-anchor="start" fill="${C.ink}" font-size="${fs}" font-weight="600">Points</text>`;
  }
  return s + "</svg>";
}
out.a_main = declineChart(880, 380, { l: 56, r: 64, t: 28, b: 34 }, [-0.32, 0.02], 0.05, 2, { p: 60, band: 30, axisTitles: true }, 12);
out.phone_main = declineChart(358, 250, { l: 40, r: 34, t: 24, b: 30 }, [-0.32, 0.02], 0.1, 4, { p: 44, axisTitles: true }, 11);

// Participation sparklines for the "who takes part" options, at 28 percent.
{
  const opts = [["strong-neg", {}], ["mild-neg", {}], ["neutral", {}], ["mild-pos", {}], ["strong-pos", {}], ["ed", { rule: "ed" }]];
  out.spark = {};
  for (const [id, o] of opts) {
    const r = id === "ed" ? run(o) : run({ kPart: K(id) });
    const W = 72, H = 32, x = (p) => 2 + (p - 10) / 80 * (W - 4), y = (v) => H - 3 - v / 0.5 * (H - 6);
    const pts = r.curve.map((k) => [x(k.p), y(k.part)]);
    out.spark[id] = { path: P(pts), area: P(pts) + `L${n1(W - 2)},${n1(H - 3)}L2.0,${n1(H - 3)}Z`, p10: fmtPct(r.curve[0].part), p90: fmtPct(r.curve[r.curve.length - 1].part), gap: f1(r.gap9010.post) };
  }
}

// 90-10 gap dot plot, points 100 to 112.
function gapDots(W, vals, colors, names) {
  const x = (v) => 12 + (v - 100) / 12 * (W - 24);
  let s = svgOpen(W, 70, "90-10 gap");
  s += `<line x1="12" x2="${W - 12}" y1="40" y2="40" stroke="#D9DDE3" stroke-width="2"></line>`;
  for (let t = 100; t <= 112; t += 2) s += `<text x="${n1(x(t))}" y="64" text-anchor="middle" fill="#5B6370" font-size="12">${t}</text><line x1="${n1(x(t))}" x2="${n1(x(t))}" y1="36" y2="44" stroke="#D9DDE3" stroke-width="1"></line>`;
  vals.forEach((v, i) => {
    s += `<circle cx="${n1(x(v))}" cy="40" r="7" fill="${colors[i].fill}" stroke="${colors[i].stroke}" stroke-width="2"></circle>`;
    s += `<text x="${n1(x(v))}" y="${i === 2 ? 22 : 22}" text-anchor="${colors[i].anchor}" fill="${colors[i].text}" font-size="12" font-weight="600">${names[i]}</text>`;
  });
  return s + "</svg>";
}
out.a_gap = gapDots(560, [def.gap9010.y2019, def.gap9010.y2024, def.gap9010.post],
  [{ fill: "#FFFFFF", stroke: "#7B818B", text: "#3F4752", anchor: "middle" }, { fill: "#7B818B", stroke: "#7B818B", text: "#3F4752", anchor: "end" },
   { fill: "#2A78D6", stroke: "#FFFFFF", text: "#1B5FB8", anchor: "start" }],
  [`2019: ${f1(def.gap9010.y2019)}`, `2024: ${f1(def.gap9010.y2024)}`, `With the program: ${f1(def.gap9010.post)}`]);

// B1 requirement chart at an 18.7 percent sign-up rate.
{
  const W = 900, H = 440, m = { l: 56, r: 210, t: 28, b: 34 }, yDom = [0, 1.75];
  const ticks = [0, 0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75];
  const F = frame({ W, H, m, yDom, yTicks: ticks, yFmt: f2, st: NS });
  const rows = def.curve, c = 0.187;
  let s = svgOpen(W, H, "Effect needed at each percentile") + F.s;
  const k = D.kraft2020;
  s += `<rect x="${n1(m.l)}" y="${n1(F.y(k.p90))}" width="${n1(W - m.l - m.r)}" height="${n1(F.y(0) - F.y(k.p90))}" fill="rgba(42, 120, 214, 0.08)"></rect>`;
  for (const [v, a, b] of [[k.p90, "90th percentile of RCT effects", f2(k.p90) + " SD"], [k.p50, "Median RCT effect", f2(k.p50) + " SD"]]) {
    s += `<line x1="${n1(m.l)}" x2="${n1(W - m.r)}" y1="${n1(F.y(v))}" y2="${n1(F.y(v))}" stroke="${C.blueText}" stroke-width="1.5" stroke-dasharray="3 4"></line>`;
    s += `<text x="${n1(W - m.r + 10)}" y="${n1(F.y(v) - 3)}" fill="${C.blueText}" font-size="12" font-weight="600">${a}</text>`;
    s += `<text x="${n1(W - m.r + 10)}" y="${n1(F.y(v) + 13)}" fill="${C.blueText}" font-size="12">${b}</text>`;
  }
  s += `<path d="${line(F, rows, (r) => r.gStar)}" fill="none" stroke="${C.before}" stroke-width="2" stroke-dasharray="6 5"></path>`;
  s += `<path d="${line(F, rows, (r) => r.gStar / c)}" fill="none" stroke="${C.ink}" stroke-width="3"></path>`;
  const last = rows[rows.length - 1];
  s += `<text x="${n1(W - m.r + 10)}" y="${n1(F.y(last.gStar / c) + 4)}" fill="${C.ink}" font-size="13" font-weight="700">At 18.7% taking part</text>`;
  s += `<text x="${n1(W - m.r + 10)}" y="${n1(F.y(last.gStar) + 16)}" fill="#3F4752" font-size="12">If every student took part</text>`;
  for (const kn of def.knots) {
    const v = kn.gStar / c;
    s += `<circle cx="${n1(F.x(kn.p))}" cy="${n1(F.y(v))}" r="5" fill="${C.ink}" stroke="#FFFFFF" stroke-width="2"></circle>`;
    s += `<text x="${n1(F.x(kn.p))}" y="${n1(F.y(v) - 12)}" text-anchor="middle" fill="${C.ink}" font-size="13" font-weight="700">${f2(v)}</text>`;
  }
  s += `<text x="${n1(m.l - 8)}" y="${n1(m.t - 10)}" text-anchor="end" fill="${C.ink}" font-size="12" font-weight="600">SD</text>`;
  out.b1_main = s + "</svg>";
}
// B1 take-up curve: what the 10th percentile needs, by share taking part.
{
  const W = 560, H = 270, m = { l: 48, r: 24, t: 24, b: 38 }, g = def.knots[0].gStar;
  const F = frame({ W, H, m, yDom: [0, 3], yTicks: [0, 0.5, 1, 1.5, 2, 2.5, 3], yFmt: f1, st: NS,
    xDom: [0.1, 1], xTicks: [0.1, 0.25, 0.5, 0.75, 1], xFmt: (v) => Math.round(v * 100) + "%" });
  const pts = []; for (let c = 0.1; c <= 1.0001; c += 0.01) pts.push([F.x(c), F.y(Math.min(3.2, g / c))]);
  let s = svgOpen(W, H, "Effect needed at the 10th percentile by share taking part") + F.s;
  s += `<line x1="${n1(m.l)}" x2="${n1(W - m.r)}" y1="${n1(F.y(D.kraft2020.p90))}" y2="${n1(F.y(D.kraft2020.p90))}" stroke="${C.blueText}" stroke-width="1.5" stroke-dasharray="3 4"></line>`;
  s += `<text x="${n1(W - m.r)}" y="${n1(F.y(D.kraft2020.p90) - 6)}" text-anchor="end" fill="${C.blueText}" font-size="12">90th percentile of RCT effects</text>`;
  s += `<path d="${P(pts)}" fill="none" stroke="${C.ink}" stroke-width="2.5"></path>`;
  const marks = [[1, "Every student", "start", 0], [0.28, "District tutoring", "start", 0], [0.187, "Sign-up rate", "start", 0], [0.13, "Summer school", "start", 0]];
  for (const [c, lab, anchor] of marks) {
    const v = g / c, sel = c === 0.187;
    s += `<circle cx="${n1(F.x(c))}" cy="${n1(F.y(v))}" r="${sel ? 6 : 4.5}" fill="${sel ? C.ink : "#FFFFFF"}" stroke="${C.ink}" stroke-width="2"></circle>`;
    s += `<text x="${n1(F.x(c) + 10)}" y="${n1(F.y(v) + (c === 1 ? -10 : 4))}" text-anchor="${c === 1 ? "end" : anchor}" fill="${C.ink}" font-size="12" font-weight="${sel ? 700 : 400}">${lab}: ${f2(v)}</text>`;
  }
  s += `<text x="${n1(m.l - 8)}" y="${n1(m.t - 10)}" text-anchor="end" fill="${C.ink}" font-size="12" font-weight="600">SD</text>`;
  out.b1_takeup = s + "</svg>";
}

// B2: four seat rules at a 28 percent budget. Shapes follow alloc-rules.R.
{
  const edRun = run({ rule: "ed" });
  // geomtakeup_line, scaled so its mean over GEOM_GRID equals the budget (no cap binds at 0.28).
  const geom = (p) => 0.10 * Math.pow(2, (Math.min(90, Math.max(10, p)) - 10) / 40);
  const grid = []; for (let p = 0.05; p < 100; p += 0.1) grid.push(geom(p));
  const gmean = grid.reduce((a, b) => a + b, 0) / grid.length;
  const shapes = {
    bottom: (p) => (p <= 28 ? 1 : 0),
    prop: () => 0.28,
    optin: (p) => geom(p) * 0.28 / gmean,
    ed: (p) => edRun.curve.find((k) => k.p === p).part,
  };
  out.b2 = { gmean: gmean.toFixed(4), optin10: fmtPct(shapes.optin(10)), optin90: fmtPct(shapes.optin(90)),
             ed10: fmtPct(shapes.ed(10)), ed90: fmtPct(shapes.ed(90)) };
  out.b2_mini = {};
  for (const [id, fn] of Object.entries(shapes)) {
    const W = 300, H = 130, m = { l: 40, r: 10, t: 12, b: 28 };
    const F = frame({ W, H, m, yDom: [0, 1], yTicks: [0, 0.5, 1], yFmt: (t) => Math.round(t * 100) + "%", st: Object.assign({}, NS, { fs: 11 }),
      xTicks: [10, 50, 90] });
    let pts;
    if (id === "bottom") pts = [[F.x(10), F.y(1)], [F.x(28), F.y(1)], [F.x(28), F.y(0)], [F.x(90), F.y(0)]];
    else pts = CP.map((p) => [F.x(p), F.y(fn(p))]);
    const area = P(pts) + `L${n1(F.x(90))},${n1(F.y(0))}L${n1(F.x(10))},${n1(F.y(0))}Z`;
    out.b2_mini[id] = svgOpen(W, H, "Share of students at each percentile who get a seat") + F.s +
      `<path d="${area}" fill="${C.closed}"></path><path d="${P(pts)}" fill="none" stroke="${C.after}" stroke-width="2.5"></path></svg>`;
  }
  // Committed results at budget 0.28 (tables/sim-seat-allocation-math-g8.csv).
  const csv = fs.readFileSync(process.cwd() + "/../tables/sim-seat-allocation-math-g8.csv", "utf8").trim().split("\n").slice(1)
    .map((l) => l.match(/"([^"]+)",(.*)/)).map((mm) => [mm[1], ...mm[2].split(",").map(Number)]);
  out.b2_rows = csv.filter((r) => Math.abs(r[1] - 0.28) < 1e-9).map((r) => ({ rule: r[0], res10: f1(r[2]), res90: f1(r[3]), gap: f1(r[5]), gapTracked: f1(r[6]), barPct: (r[5] / 10 * 100).toFixed(1) }));
  out.b2_none = { res10: f1(-cell.d[0]), res90: f1(-cell.d[4]), gap: f1(-cell.d[0] + cell.d[4]), barPct: ((-cell.d[0] + cell.d[4]) / 10 * 100).toFixed(1) };
}

// C: three programs overlaid.
{
  const W = 900, H = 400, m = { l: 56, r: 190, t: 28, b: 34 }, yDom = [-0.32, 0.12];
  const ticks = []; for (let t = -0.3; t <= 0.1001; t += 0.05) ticks.push(Math.abs(t) < 1e-9 ? 0 : t);
  const F = frame({ W, H, m, yDom, yTicks: ticks, yFmt: (t) => sgn(f2(t)), st: NS });
  const series = [
    { id: "p1", res: def, color: "#2A78D6", name: "1  Large tutoring" },
    { id: "p2", res: low, color: "#3D2F99", name: "2  Aimed at low scorers" },
    { id: "p3", res: uni, color: "#D9622B", name: "3  Every student" },
  ];
  let s = svgOpen(W, H, "Three programs compared") + F.s;
  s += `<path d="${line(F, def.curve, (r) => -r.gStar)}" fill="none" stroke="${C.before}" stroke-width="2" stroke-dasharray="6 5"></path>`;
  for (const se of series) s += `<path d="${line(F, se.res.curve, (r) => -r.remaining)}" fill="none" stroke="${se.color}" stroke-width="2.5"></path>`;
  const ends = [{ y: F.y(-def.curve[40].gStar), t: "2024, no program", c: "#3F4752" }]
    .concat(series.map((se) => ({ y: F.y(-se.res.curve[40].remaining), t: se.name.replace("  ", " "), c: se.color })));
  ends.sort((a, b) => a.y - b.y);
  for (let i = 1; i < ends.length; i++) if (ends[i].y - ends[i - 1].y < 17) ends[i].y = ends[i - 1].y + 17;
  for (const e of ends) s += `<text x="${n1(W - m.r + 10)}" y="${n1(e.y + 4)}" fill="${e.c}" font-size="13" font-weight="600">${e.t}</text>`;
  for (const se of series) for (const k of se.res.knots)
    s += `<circle cx="${n1(F.x(k.p))}" cy="${n1(F.y(-k.remaining))}" r="4" fill="${se.color}" stroke="#FFFFFF" stroke-width="2"></circle>`;
  s += `<text x="${n1(m.l - 8)}" y="${n1(m.t - 10)}" text-anchor="end" fill="${C.ink}" font-size="12" font-weight="600">SD</text>`;
  s += `<text x="${n1(m.l + 6)}" y="${n1(F.y(0) - 6)}" fill="#3F4752" font-size="12">Back to 2019</text>`;
  out.c_main = s + "</svg>";
}

fs.writeFileSync(OUT, JSON.stringify(out, null, 1));
console.log(JSON.stringify(out.numbers, null, 0));
console.log(JSON.stringify(out.spark, (k, v) => (k === "path" || k === "area" ? undefined : v)));
console.log(JSON.stringify(out.b2), JSON.stringify(out.b2_rows), JSON.stringify(out.b2_none));
for (const k of Object.keys(out)) if (typeof out[k] === "string") console.log(k, out[k].length);
