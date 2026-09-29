#!/usr/bin/env node
// Tests for the explorer's JavaScript engine (docs/engine.js) and its data
// file (docs/cells.js). No network, no R: everything is checked against the
// committed outputs in tables/.
//
//   node analysis/tests/test-tool-engine.mjs      (from the project root)
//
// What is checked, and why:
//   1. docs/cells.js matches tables/sim-quantiles.csv value for value, so a
//      rerun of the pipeline without rerunning 10-export-tool-data.R is caught.
//   2. The engine reproduces the R seat-allocation results for the two rules
//      the explorer can express exactly: proportional allocation (neutral
//      participation gradient) and the eligibility screen (rule "ed"), at the
//      configured treated effect with a neutral effect gradient. Both
//      estimands are compared, the distributional one (res_p10, res_p90,
//      gap_remaining) and the group one (gap_remaining_tracked), across every
//      budget in the CSV. This is the test that the port of make_quantile_fn,
//      weighted_quantile, the calibration, and make_ed_screen is faithful.
//   2b. The ED and not-ED outcomes (groupScenario) match
//      tables/sim-group-outcomes-<cell>.csv for both rules at every budget,
//      plus the 2019 and 2024 reference rows; the ED data in cells.js match
//      tables/sim-distribution-econdis.csv.
//   3. Invariants: a zero program returns the 2024 knots exactly; full
//      participation at a uniform effect is a pure shift in both modes;
//      water-filling conserves the budget and stays in [0, 1] at every tilt
//      level; each tilt level's named ratio matches its line. The screen
//      spends min(B, ED share), is r * s(p), leaves not-ED students in place,
//      and ignores the participation tilt.
//   4. The quantile-function points in cells.js: they reproduce the published
//      percentiles and the score distribution's bin points, and the curve
//      through them has no corners.
// Runs every check, prints each FAIL line, and exits non-zero if any failed.

import fs from "node:fs";
import vm from "node:vm";

// Inside a vm context, globalThis is the context object itself, so both
// files' globalThis assignments land on ctx.
const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync("docs/cells.js", "utf8"), ctx);
vm.runInContext(fs.readFileSync("docs/engine.js", "utf8"), ctx);
const DATA = ctx.TOOL_DATA, E = ctx.NAEPEngine;

let failures = 0, checks = 0;
function check(ok, msg) {
  checks++;
  if (!ok) { failures++; console.log("FAIL " + msg); }
}
const close = (a, b, tol) => Math.abs(a - b) <= tol;

// Minimal CSV reader: the tables are written by R's write.csv, so fields are
// either quoted strings without embedded quotes or plain numbers.
function readCsv(path) {
  const lines = fs.readFileSync(path, "utf8").trim().split(/\r?\n/);
  const split = (l) => l.match(/("([^"]*)"|[^,]*)(,|$)/g).slice(0, -1)
    .map((f) => f.replace(/,$/, "").replace(/^"(.*)"$/, "$1"));
  const head = split(lines[0]);
  return lines.slice(1).map((l) => {
    const f = split(l), row = {};
    head.forEach((h, i) => { row[h] = f[i]; });
    return row;
  });
}

const PS = DATA.percentiles;
const cellByLabel = Object.fromEntries(DATA.cells.map((c) => [c.label, c]));

// ---- 1. cells.js matches sim-quantiles.csv -------------------------------
const qd = readCsv("tables/sim-quantiles.csv");
for (const r of qd) {
  const c = cellByLabel[r.cell];
  check(c, `cells.js has no cell '${r.cell}'`);
  if (!c) continue;
  const i = PS.indexOf(Number(r.percentile));
  check(i >= 0, `percentile ${r.percentile} missing from cells.js`);
  for (const key of ["q2019", "d", "g_star"])
    check(close(c[key][i], Number(r[key]), 1e-9), `${r.cell} p${r.percentile} ${key}: ${c[key][i]} vs CSV ${r[key]}`);
  check(close(c.sd2019, Number(r.sd2019), 1e-9), `${r.cell} sd2019 mismatch`);
}
check(DATA.cells.length === new Set(qd.map((r) => r.cell)).size, "cell count differs from CSV");
// g* in the file is -D/S, the definition the page relies on.
for (const c of DATA.cells) c.g_star.forEach((g, i) =>
  check(close(g, -c.d[i] / c.sd2019, 1e-12), `${c.label} g* is not -D/S at p${PS[i]}`));

// ---- 2. engine reproduces the R seat-allocation grid ---------------------
// The treated effect 06-seat-allocation.R used is the config's treated_effect.
const G = DATA.benchmarks.find((b) => b.id === DATA.treated_effect).g;
const ALLOC = {
  "Reading G4": "tables/sim-seat-allocation-reading-g4.csv",
  "Reading G8": "tables/sim-seat-allocation-reading-g8.csv",
  "Math G4": "tables/sim-seat-allocation-math-g4.csv",
  "Math G8": "tables/sim-seat-allocation-math-g8.csv",
};
// Tolerance in NAEP points. The engine and R use the same grids and formulas,
// so agreement should be near machine precision (about 1e-12 observed);
// 1e-9 leaves room for floating-point ordering differences in the sorts and
// sums and nothing else, and is what the methods page's "at least nine
// decimal places" rests on.
const TOL = 1e-9;
for (const [label, path] of Object.entries(ALLOC)) {
  const cell = cellByLabel[label];
  // The two R rules the page offers: proportional (the neutral tilt) and the
  // eligibility screen (rule "ed").
  const rows = readCsv(path).filter((r) => r.rule.startsWith("Proportional") || r.rule.startsWith("Eligibility"));
  check(rows.some((r) => r.rule.startsWith("Proportional")) && rows.some((r) => r.rule.startsWith("Eligibility")),
        `${path} lacks Proportional or Eligibility rows`);
  let worst = 0;
  for (const r of rows) {
    const B = Number(r.budget);
    const rule = r.rule.startsWith("Eligibility") ? "ed" : "tilt";
    const base = { effect: G, share: B, kPart: 0, kEffect: 0, rule };
    const dist = E.scenario(cell, PS, { ...base, mode: "distributional" }, [10, 90]);
    const grp  = E.scenario(cell, PS, { ...base, mode: "group" }, [10, 90]);
    const res = (s, p) => s.knots.find((k) => k.p === p).remaining * cell.sd2019;
    const gapD = res(dist, 10) - res(dist, 90);
    const gapG = res(grp, 10) - res(grp, 90);
    for (const [got, want, name] of [
      [res(dist, 10), Number(r.res_p10), "res_p10"],
      [res(dist, 90), Number(r.res_p90), "res_p90"],
      [gapD, Number(r.gap_remaining), "gap_remaining"],
      [gapG, Number(r.gap_remaining_tracked), "gap_remaining_tracked"],
    ]) {
      worst = Math.max(worst, Math.abs(got - want));
      check(close(got, want, TOL), `${label} ${rule} B=${B} ${name}: JS ${got} vs R ${want}`);
    }
  }
  console.log(`  ${label}: ${rows.length} rule x budget rows, max |JS - R| = ${worst.toExponential(2)} points`);
}

// ---- 2b. ED and not-ED outcomes match R's group tables -------------------
// tables/sim-group-outcomes-<cell>.csv from 06-seat-allocation.R: each
// group's p10-p90 after the program, for the proportional rule and the
// screen at every budget, plus the 2019 and 2024 reference rows.
const PCOL = PS.map((p) => "p" + p);
for (const [label, path] of Object.entries(ALLOC)) {
  const cell = cellByLabel[label];
  const gpath = path.replace("sim-seat-allocation-", "sim-group-outcomes-");
  const all = readCsv(gpath);
  check(all.length > 0, `${gpath} is missing or empty`);
  let worst = 0, n = 0;
  const cmp = (got, want, what) => {
    worst = Math.max(worst, Math.abs(got - want)); n++;
    check(close(got, want, TOL), `${label} ${what}: JS ${got} vs R ${want}`);
  };
  // Reference rows: the groups' own 2019 and 2024 quantiles.
  const ref = E.groupScenario(cell, { effect: 0, share: 0, kPart: 0, kEffect: 0, mode: "distributional" }, PS);
  for (const g of ref) for (const [rn, key] of [["2019", "q2019"], ["2024, no program", "q2024"]]) {
    const r = all.find((x) => x.rule === rn && x.group === g.id);
    PS.forEach((p, i) => cmp(g.rows[i][key], Number(r[PCOL[i]]), `${g.id} ${rn} p${p}`));
  }
  for (const r of all.filter((x) => x.rule.startsWith("Proportional") || x.rule.startsWith("Eligibility"))) {
    const rule = r.rule.startsWith("Eligibility") ? "ed" : "tilt";
    const out = E.groupScenario(cell, { effect: G, share: Number(r.budget), kPart: 0, kEffect: 0,
                                        mode: "distributional", rule }, PS);
    const g = out.find((x) => x.id === r.group);
    PS.forEach((p, i) => cmp(g.rows[i].post, Number(r[PCOL[i]]), `${r.group} ${rule} B=${r.budget} p${p}`));
  }
  console.log(`  ${label} groups: ${n} values, max |JS - R| = ${worst.toExponential(2)} points`);
}

// cells.js ED data matches its sources: the population shares in
// sim-distribution-econdis.csv, and the share curve averages to the ED share.
const de = readCsv("tables/sim-distribution-econdis.csv");
for (const cell of DATA.cells) {
  const pop = (g) => Number(de.find((r) => r.cell === cell.label && r.year === "2024" && r.group === g).pop_share);
  check(close(cell.ed.pop, pop("Economically disadvantaged"), 1e-12), `${cell.label} ed.pop mismatch`);
  check(cell.ed.groups.length === 2 && close(cell.ed.groups[1].pop2024, pop("Not economically disadvantaged"), 1e-12),
        `${cell.label} not-ED pop2024 mismatch`);
  const s = E.edParticipation(cell.ed, cell.ed.pop)(E.FILL_GRID);
  check(close(E.mean(s), cell.ed.pop, 1e-3), `${cell.label} ED share curve averages ${E.mean(s)}, not ${cell.ed.pop}`);
}

// ---- 3. invariants --------------------------------------------------------
for (const cell of DATA.cells) {
  const q2024 = cell.q2019.map((q, i) => q + cell.d[i]);
  for (const mode of ["group", "distributional"]) {
    // No program: post-program quantiles are the published 2024 knots, and
    // the remaining requirement is g*.
    const s0 = E.scenario(cell, PS, { effect: 0.2, share: 0, kPart: 0.6, kEffect: -0.6, mode }, PS);
    s0.knots.forEach((k, i) => {
      check(close(k.post_pts, q2024[i], 1e-9), `${cell.label} ${mode} zero share p${k.p}: ${k.post_pts} vs ${q2024[i]}`);
      check(close(k.remaining, cell.g_star[i], 1e-9), `${cell.label} ${mode} zero share remaining != g*`);
    });
  }
  // Everyone treated with a uniform effect is a pure shift in both modes, so
  // the two estimands agree and each knot moves by exactly effect * S.
  const eff = 0.1;
  const sg = E.scenario(cell, PS, { effect: eff, share: 1, kPart: 0, kEffect: 0, mode: "group" }, PS);
  const sd = E.scenario(cell, PS, { effect: eff, share: 1, kPart: 0, kEffect: 0, mode: "distributional" }, PS);
  PS.forEach((p, i) => {
    check(close(sg.knots[i].gain, eff, 1e-9), `${cell.label} full uniform group gain at p${p}`);
    check(close(sd.knots[i].gain, eff, 1e-6), `${cell.label} full uniform distributional gain at p${p}: ${sd.knots[i].gain}`);
  });
}

// Budget conservation and range at every tilt level and a spread of budgets,
// including budgets high enough that the 4:1 tilt saturates.
for (const lvl of E.TILT_LEVELS) {
  for (const B of [0, 0.05, 0.13, 0.28, 0.5, 0.75, 0.9, 1]) {
    const pi = E.participation(B, lvl.k)(E.FILL_GRID);
    check(close(E.mean(pi), B, 1e-9), `mean participation ${E.mean(pi)} != budget ${B} at ${lvl.id}`);
    check(pi.every((v) => v >= 0 && v <= 1 + 1e-12), `participation outside [0,1] at ${lvl.id}, B=${B}`);
  }
  // Effect tilt: average over ranks equals the chosen effect, and stays positive.
  const ef = E.effectPoints(0.2, lvl.k, 1)(E.FILL_GRID);
  check(close(E.mean(ef), 0.2, 1e-12), `mean effect != 0.2 at ${lvl.id}`);
  check(ef.every((v) => v > 0), `non-positive effect at ${lvl.id}`);
  // The named ratio is the p90:p10 ratio of the tilt.
  const w = E.tilt(lvl.k), [a, b] = lvl.ratio.split(":").map(Number);
  check(close(w(90) / w(10), a / b, 1e-12), `${lvl.id} ratio ${w(90) / w(10)} != ${lvl.ratio}`);
}

// The screen: spends min(B, ED share), is r * s(p), and in "Same students"
// mode leaves not-ED students where they were while every ED student gains
// r * effect on average.
for (const cell of DATA.cells) {
  for (const B of [0, 0.1, 0.3, cell.ed.pop, 0.8, 1]) {
    const pi = E.edParticipation(cell.ed, B)(E.FILL_GRID);
    check(close(E.mean(pi), Math.min(B, cell.ed.pop), 1e-3), `${cell.label} screen spends ${E.mean(pi)} at B=${B}`);
    check(pi.every((v) => v >= 0 && v <= 1 + 1e-12), `${cell.label} screen participation outside [0,1] at B=${B}`);
  }
  const B = 0.2, eff = 0.1, r = Math.min(1, B / cell.ed.pop);
  const out = E.groupScenario(cell, { effect: eff, share: B, kPart: 0.6, kEffect: 0, mode: "group", rule: "ed" }, PS);
  const ed = out.find((g) => g.id === "ED"), ned = out.find((g) => g.id === "Not ED");
  PS.forEach((p, i) => {
    check(close(ned.rows[i].post, ned.rows[i].q2024, 1e-12), `${cell.label} screen moved not-ED students at p${p}`);
    check(close(ed.rows[i].post - ed.rows[i].q2024, r * eff * cell.sd2019, 1e-9), `${cell.label} screen ED gain at p${p}`);
  });
  // kPart is ignored under the screen.
  const a = E.scenario(cell, PS, { effect: eff, share: B, kPart: 0.6, kEffect: 0, mode: "distributional", rule: "ed" }, PS);
  const b = E.scenario(cell, PS, { effect: eff, share: B, kPart: -0.6, kEffect: 0, mode: "distributional", rule: "ed" }, PS);
  check(a.knots.every((k, i) => k.post_pts === b.knots[i].post_pts), `${cell.label} kPart changed the screen's result`);
}

// ---- 4. quantile functions ------------------------------------------------
// cells.js carries, per cell and year, the points the quantile function
// passes through (quantile_points in analysis/mixture.R): the score
// distribution's bin points plus the published percentiles. Checked here
// against the CSVs directly rather than by re-running the R merge:
//   - the points run from 0 to 100 percent and strictly increase;
//   - every published percentile is a point, at its published score;
//   - every non-empty bin of tables/sim-distribution.csv contributes its
//     (cumulative percent, upper edge) point, unless it lands on a percentile;
//   - the spline passes through every point;
//   - no corners: across the whole p1 to p99 range the explorer draws, the
//     left and right slopes agree closely.
//     The five-percentile function this replaced (normal tails joined at p10
//     and p90) failed this at p90 by a factor of 1.4 to 1.8.
const DIST = readCsv("tables/sim-distribution.csv");
for (const cell of DATA.cells) {
  for (const [yr, key, knots] of [[2019, "qf2019", cell.q2019], [2024, "qf2024", cell.q2019.map((q, i) => q + cell.d[i])]]) {
    const qf = cell[key], tag = `${cell.label} ${yr}`;
    check(qf && qf.pct.length === qf.score.length && qf.pct.length > PS.length, `${tag}: ${key} missing or malformed`);
    if (!qf) continue;
    check(qf.pct[0] === 0 && qf.pct[qf.pct.length - 1] === 100, `${tag}: points do not run from 0 to 100`);
    check(qf.pct.every((v, i) => i === 0 || v > qf.pct[i - 1]) && qf.score.every((v, i) => i === 0 || v > qf.score[i - 1]),
      `${tag}: points do not strictly increase`);
    PS.forEach((p, i) => {
      const j = qf.pct.indexOf(p);
      check(j >= 0 && close(qf.score[j], knots[i], 1e-9), `${tag}: published p${p} is not a point`);
    });
    const bins = DIST.filter((r) => r.cell === cell.label && Number(r.year) === yr);
    const total = bins.reduce((t, r) => t + Number(r.pct), 0);
    let cum = 0;
    for (const r of bins) {
      cum += Number(r.pct);
      if (Number(r.pct) <= 0) continue;
      const pc = cum / total * 100;
      if (PS.some((p) => Math.abs(p - pc) < 1e-9)) continue;
      const j = qf.pct.findIndex((v) => Math.abs(v - pc) < 1e-9);
      check(j >= 0 && qf.score[j] === Number(r.hi), `${tag}: bin ${r.bin} point (${pc.toFixed(4)}, ${r.hi}) missing`);
    }
    const Q = E.makeQuantileFn(qf.pct, qf.score);
    qf.pct.forEach((p, i) => check(close(Q(p), qf.score[i], 1e-9), `${tag}: spline misses point ${p}`));
    let worst = 0;
    for (let p = 1; p <= 99; p += 0.5) {
      const h = 0.01, left = (Q(p) - Q(p - h)) / h, right = (Q(p + h) - Q(p)) / h;
      worst = Math.max(worst, Math.max(left, right) / Math.min(left, right));
    }
    check(worst < 1.1, `${tag}: slope jumps by ${worst.toFixed(3)} somewhere in p1 to p99 (a corner)`);
  }
}

// ---- 5. methods-page data -------------------------------------------------
// kraft_target is copied from the by-target benchmark table: every exported
// row must match its CSV row, and the export must hold exactly one row per
// grade 4/8 x subject x group, so the methods page shows no stale or missing
// cells. The filter repeats KRAFT_TARGETS and the grade/size filter in
// analysis/10-export-tool-data.R on purpose, as an independent check; change
// both together.
const KT = readCsv("tables/kraft-2023-benchmarks-by-target.csv")
  .filter((r) => ["4", "8"].includes(r.grade) && r.size_bin === "All sizes" &&
                 ["universal", "targeted_low", "pooled"].includes(r.target));
check(DATA.kraft_target.length === KT.length && KT.length === 12,
  `kraft_target has ${DATA.kraft_target.length} rows, CSV has ${KT.length}, expected 12`);
for (const r of KT) {
  const hit = DATA.kraft_target.filter((x) => String(x.grade) === r.grade && x.subject === r.subject && x.target === r.target);
  check(hit.length === 1, `kraft_target has ${hit.length} rows for grade ${r.grade} ${r.subject} ${r.target}`);
  if (hit.length !== 1) continue;
  for (const key of ["studies", "p50"])
    check(close(hit[0][key], Number(r[key]), 1e-12), `kraft_target ${r.grade} ${r.subject} ${r.target} ${key}: ${hit[0][key]} vs CSV ${r[key]}`);
  check(hit[0].thin === (r.thin === "TRUE"), `kraft_target ${r.grade} ${r.subject} ${r.target} thin flag`);
}
// The methods page reports the validation: the differential change (p90
// difference minus p10 difference) from the public data rounds to the
// article's Table 2(a) value in every cell.
check(Object.keys(DATA.table2a).length === DATA.cells.length, "table2a does not cover every cell");
for (const c of DATA.cells) {
  const dc = c.d[PS.indexOf(90)] - c.d[PS.indexOf(10)];
  check(dc.toFixed(1) === DATA.table2a[c.label].toFixed(1), `${c.label} differential change ${dc.toFixed(1)} vs Table 2(a) ${DATA.table2a[c.label]}`);
}

console.log(`${checks} checks, ${failures} failed`);
process.exit(failures ? 1 : 0);
