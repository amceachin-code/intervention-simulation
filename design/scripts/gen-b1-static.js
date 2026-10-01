// SVG fragments for the rounds version of B1 (Math G8, c = 0.187, g = 0.155,
// equal chance, Same students). Values from docs/cells.js; run from docs/.
const fs = require("fs");
require(process.cwd() + "/cells.js");
const D = globalThis.TOOL_DATA;
const cell = D.cells.find((x) => x.label === "Math G8");
const S = cell.sd2019, c = 0.187, g = 0.155;
const d10 = cell.d[0], d90 = cell.d[4];            // negative, points
const step = c * g * S;                             // points per round
const n1 = (v) => v.toFixed(1);
const M = "−";
const sg = (v) => (v < 0 ? M + Math.abs(v) : v > 0 ? "+" + v : "0");
const out = {};

// ---------------------------------------------------------------- waffle
{
  let s = `<svg viewBox="0 0 260 260" width="260" height="260" role="img" aria-label="19 of 100 students take part in one round" style="display: block; flex-shrink: 0">`;
  for (let i = 0; i < 100; i++) {
    const cx = 13 + (i % 10) * 26, cy = 13 + Math.floor(i / 10) * 26;
    s += i < 19
      ? `<circle cx="${cx}" cy="${cy}" r="10" fill="#2A78D6"></circle>`
      : `<circle cx="${cx}" cy="${cy}" r="9.25" fill="#FFFFFF" stroke="#9AA1AB" stroke-width="1.5"></circle>`;
  }
  out.waffle = s + "</svg>";
}

// ---------------------------------------------------------------- dumbbell rows
{
  const W = 560, H = 200, l = 20, r = 20, x = (v) => l + (v + 12) / 14 * (W - l - r);
  let s = `<svg viewBox="0 0 ${W} ${H}" width="100%" role="img" aria-label="Points below the 2019 score at the 10th percentile after one round" style="display: block; overflow: visible">`;
  for (let t = -12; t <= 2; t += 2) {
    s += `<line x1="${n1(x(t))}" x2="${n1(x(t))}" y1="24" y2="168" stroke="#E8EBEF" stroke-width="1"></line>`;
    s += `<text x="${n1(x(t))}" y="188" text-anchor="middle" fill="#5B6370" font-size="12">${sg(t)}</text>`;
  }
  s += `<line x1="${n1(x(0))}" x2="${n1(x(0))}" y1="16" y2="168" stroke="#101418" stroke-width="1.5"></line>`;
  s += `<text x="${n1(x(0))}" y="10" text-anchor="middle" fill="#101418" font-size="12" font-weight="600">2019 score</text>`;
  const rows = [
    { y: 48, to: d10, color: "#7B818B", lab: "+0", name: "81 who did not take part" },
    { y: 96, to: d10 + g * S, color: "#2A78D6", lab: `+${(g * S).toFixed(1)} each`, name: "19 who took part" },
    { y: 144, to: d10 + step, color: "#101418", lab: `+${step.toFixed(1)}`, name: "Average of all 100" },
  ];
  for (const rw of rows) {
    s += `<text x="${n1(x(-12))}" y="${rw.y - 12}" fill="#3F4752" font-size="12" font-weight="600">${rw.name}</text>`;
    if (Math.abs(rw.to - d10) > 1e-9) s += `<line x1="${n1(x(d10))}" x2="${n1(x(rw.to))}" y1="${rw.y}" y2="${rw.y}" stroke="${rw.color}" stroke-width="3"></line>`;
    s += `<circle cx="${n1(x(d10))}" cy="${rw.y}" r="5" fill="#FFFFFF" stroke="#7B818B" stroke-width="2"></circle>`;
    s += `<circle cx="${n1(x(rw.to))}" cy="${rw.y}" r="6.5" fill="${rw.color}" stroke="#FFFFFF" stroke-width="2"></circle>`;
    s += `<text x="${n1(x(rw.to) + 12)}" y="${rw.y + 4}" fill="${rw.color === "#2A78D6" ? "#1B5FB8" : rw.color === "#7B818B" ? "#3F4752" : "#101418"}" font-size="13" font-weight="700">${rw.lab}</text>`;
  }
  out.dumbbell = s + "</svg>";
}

// ---------------------------------------------------------------- rounds chart
const K = 11;
const cm = { W: 1200, H: 430, l: 60, r: 250, t: 30, b: 40 };
const cx = (k) => cm.l + k / K * (cm.W - cm.l - cm.r);
{
  const { W, H, l, r, t, b } = cm, yDom = [-12, 8];
  const y = (v) => t + (yDom[1] - v) / (yDom[1] - yDom[0]) * (H - t - b);
  let s = `<svg viewBox="0 0 ${W} ${H}" width="100%" role="img" aria-label="Average score at the 10th and 90th percentiles, round by round" style="display: block; overflow: visible">`;
  for (let v = -12; v <= 8; v += 2) {
    s += `<line x1="${l}" x2="${W - r}" y1="${n1(y(v))}" y2="${n1(y(v))}" stroke="#E8EBEF" stroke-width="1"></line>`;
    s += `<text x="${l - 10}" y="${n1(y(v) + 4)}" text-anchor="end" fill="#5B6370" font-size="12">${sg(v)}</text>`;
  }
  for (let k = 0; k <= K; k++) s += `<text x="${n1(cx(k))}" y="${H - b + 22}" text-anchor="middle" fill="#5B6370" font-size="12">${k}</text>`;
  s += `<text x="${l - 10}" y="${t - 12}" text-anchor="end" fill="#101418" font-size="12" font-weight="600">Points</text>`;
  // zero line
  s += `<line x1="${l}" x2="${W - r}" y1="${n1(y(0))}" y2="${n1(y(0))}" stroke="#101418" stroke-width="1.5"></line>`;
  s += `<text x="${W - r + 12}" y="${n1(y(0) + 4)}" fill="#101418" font-size="13" font-weight="700">2019 score</text>`;
  // reach-once milestone
  s += `<line x1="${n1(cx(6))}" x2="${n1(cx(6))}" y1="${t}" y2="${H - b}" stroke="#5B6370" stroke-width="1.5" stroke-dasharray="4 4"></line>`;
  s += `<text x="${n1(cx(6) + 8)}" y="${t + 12}" fill="#101418" font-size="13" font-weight="700">Round 6: every student reached once</text>`;
  s += `<text x="${n1(cx(6) + 8)}" y="${t + 29}" fill="#3F4752" font-size="12">10th still 4.5 points below 2019</text>`;
  // no-program references
  s += `<line x1="${l}" x2="${W - r}" y1="${n1(y(d10))}" y2="${n1(y(d10))}" stroke="#7B818B" stroke-width="2" stroke-dasharray="6 5"></line>`;
  s += `<line x1="${l}" x2="${W - r}" y1="${n1(y(d90))}" y2="${n1(y(d90))}" stroke="#7B818B" stroke-width="2" stroke-dasharray="6 5"></line>`;
  // series
  const ser = [{ d: d10, color: "#123F7A", w: 3, name: "10th percentile" }, { d: d90, color: "#4F92E0", w: 3, name: "90th percentile" }];
  for (const se of ser) {
    const pts = []; for (let k = 0; k <= K; k++) pts.push([cx(k), y(se.d + k * step)]);
    s += `<path d="${pts.map((p, i) => (i ? "L" : "M") + n1(p[0]) + "," + n1(p[1])).join("")}" fill="none" stroke="${se.color}" stroke-width="${se.w}"></path>`;
    for (const p of pts) s += `<circle cx="${n1(p[0])}" cy="${n1(p[1])}" r="4.5" fill="${se.color}" stroke="#FFFFFF" stroke-width="2"></circle>`;
  }
  // right-end labels
  const labs = [
    { v: d90 + K * step, t: "90th percentile", c: "#1B5FB8" },
    { v: d10 + K * step, t: "10th percentile", c: "#123F7A" },
    { v: d90, t: "90th, no program", c: "#3F4752" },
    { v: d10, t: "10th, no program", c: "#3F4752" },
  ];
  for (const lb of labs) s += `<text x="${W - r + 12}" y="${n1(y(lb.v) + 4)}" fill="${lb.c}" font-size="13" font-weight="${lb.c === "#3F4752" ? 400 : 700}">${lb.t}</text>`;
  // zero crossings
  const x90 = -d90 / step, x10 = -d10 / step;
  s += `<circle cx="${n1(cx(x90))}" cy="${n1(y(0))}" r="7" fill="#FFFFFF" stroke="#4F92E0" stroke-width="2.5"></circle>`;
  s += `<text x="${n1(cx(x90) - 12)}" y="${n1(y(0) - 12)}" text-anchor="end" fill="#1B5FB8" font-size="13" font-weight="700">90th back to 2019 during round 5</text>`;
  s += `<circle cx="${n1(cx(x10))}" cy="${n1(y(0))}" r="7" fill="#FFFFFF" stroke="#123F7A" stroke-width="2.5"></circle>`;
  s += `<text x="${n1(cx(x10) + 4)}" y="${n1(y(0) + 34)}" text-anchor="middle" fill="#123F7A" font-size="13" font-weight="700">10th back to 2019</text>`;
  s += `<text x="${n1(cx(x10) + 4)}" y="${n1(y(0) + 50)}" text-anchor="middle" fill="#123F7A" font-size="13" font-weight="700">after round 10</text>`;
  s += `<text x="${n1(cx(x10) + 4)}" y="${n1(y(0) + 66)}" text-anchor="middle" fill="#3F4752" font-size="12">The 90th is then 6.5 above</text>`;
  // bracket between the lines at round 1
  const bx = cx(1) + 22, ya = y(d90 + step), yb = y(d10 + step);
  s += `<path d="M${n1(bx - 6)},${n1(ya)}L${n1(bx)},${n1(ya)}L${n1(bx)},${n1(yb)}L${n1(bx - 6)},${n1(yb)}" fill="none" stroke="#101418" stroke-width="1.5"></path>`;
  s += `<text x="${n1(bx + 8)}" y="${n1((ya + yb) / 2 - 4)}" fill="#101418" font-size="13" font-weight="700">6.4 points apart</text>`;
  s += `<text x="${n1(bx + 8)}" y="${n1((ya + yb) / 2 + 13)}" fill="#101418" font-size="13" font-weight="700">in every round</text>`;
  // best-case note, in the empty upper left
  s += `<text x="${l + 12}" y="${n1(y(7))}" fill="#B4461A" font-size="13" font-weight="700">Best case</text>`;
  s += `<text x="${l + 12}" y="${n1(y(7) + 18)}" fill="#3F4752" font-size="12">Gains add up and never fade,</text>`;
  s += `<text x="${l + 12}" y="${n1(y(7) + 34)}" fill="#3F4752" font-size="12">and a second turn helps as much as the first.</text>`;
  out.rounds = s + "</svg>";
  out.check = { step: step.toFixed(4), x90: x90.toFixed(3), x10: x10.toFixed(3), p10at6: (d10 + 6 * step).toFixed(2), p90at10: (d90 + 10 * step).toFixed(2), gap: (d90 - d10).toFixed(3) };
}

// ---------------------------------------------------------------- reach strip
{
  const W = cm.W, H = 150, top = 22, base = 118, h = base - top;
  let s = `<svg viewBox="0 0 ${W} ${H}" width="100%" role="img" aria-label="Share of students reached, round by round" style="display: block; overflow: visible">`;
  s += `<line x1="${cm.l}" x2="${W - cm.r}" y1="${base}" y2="${base}" stroke="#D9DDE3" stroke-width="1"></line>`;
  s += `<line x1="${cm.l}" x2="${W - cm.r}" y1="${top}" y2="${top}" stroke="#E8EBEF" stroke-width="1"></line>`;
  s += `<text x="${cm.l - 10}" y="${base + 4}" text-anchor="end" fill="#5B6370" font-size="12">0%</text>`;
  s += `<text x="${cm.l - 10}" y="${top + 4}" text-anchor="end" fill="#5B6370" font-size="12">100%</text>`;
  const once = ["19%", "37%", "56%", "75%", "94%", "100%"];
  const rnd = [];
  for (let k = 1; k <= K; k++) {
    const kc = k * c, reach = Math.min(1, kc), twice = Math.max(0, Math.min(1, kc - 1));
    const x0 = cx(k) - 16;
    s += `<rect x="${n1(x0)}" y="${n1(base - reach * h)}" width="32" height="${n1(reach * h)}" fill="#C6DBF6"></rect>`;
    if (twice > 0) s += `<rect x="${n1(x0)}" y="${n1(base - twice * h)}" width="32" height="${n1(twice * h)}" fill="#1B5FB8"></rect>`;
    if (k <= 6) s += `<text x="${n1(cx(k))}" y="${n1(base - reach * h - 6)}" text-anchor="middle" fill="#101418" font-size="12" font-weight="600">${once[k - 1]}</text>`;
    rnd.push([cx(k), base - (1 - Math.pow(1 - c, k)) * h]);
    s += `<text x="${n1(cx(k))}" y="${base + 20}" text-anchor="middle" fill="#5B6370" font-size="12">${k}</text>`;
  }
  s += `<path d="${rnd.map((p, i) => (i ? "L" : "M") + n1(p[0]) + "," + n1(p[1])).join("")}" fill="none" stroke="#B4461A" stroke-width="2" stroke-dasharray="5 4"></path>`;
  for (const p of rnd) s += `<circle cx="${n1(p[0])}" cy="${n1(p[1])}" r="3.5" fill="#B4461A"></circle>`;
  s += `<text x="${n1(rnd[5][0] + 20)}" y="${n1(rnd[5][1] + 16)}" fill="#B4461A" font-size="12" font-weight="700">71%</text>`;
  s += `<text x="${n1(rnd[9][0] + 20)}" y="${n1(rnd[9][1] + 16)}" fill="#B4461A" font-size="12" font-weight="700">87%</text>`;
  // legend in the right margin
  const lx = W - cm.r + 12;
  s += `<rect x="${lx}" y="${top}" width="12" height="12" fill="#C6DBF6"></rect><text x="${lx + 18}" y="${top + 10}" fill="#3F4752" font-size="12">Reached once, new students each round</text>`;
  s += `<rect x="${lx}" y="${top + 22}" width="12" height="12" fill="#1B5FB8"></rect><text x="${lx + 18}" y="${top + 32}" fill="#3F4752" font-size="12">Reached twice</text>`;
  s += `<line x1="${lx}" x2="${lx + 12}" y1="${top + 50}" y2="${top + 50}" stroke="#B4461A" stroke-width="2" stroke-dasharray="4 3"></line><text x="${lx + 18}" y="${top + 54}" fill="#3F4752" font-size="12">Reached at least once if each</text>`;
  s += `<text x="${lx + 18}" y="${top + 70}" fill="#3F4752" font-size="12">round is a fresh random draw</text>`;
  out.reach = s + "</svg>";
}

fs.writeFileSync(process.argv[2], JSON.stringify(out, null, 1));
console.log(JSON.stringify(out.check));
for (const k of Object.keys(out)) if (typeof out[k] === "string") console.log(k, out[k].length);
