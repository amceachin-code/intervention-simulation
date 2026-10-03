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
//   5. The methods-page data (Kraft 2023 rows, Table 2(a) targets).
//   6. The rounds arithmetic behind rounds.html (E.rounds): rounds to restore
//      p10 and p90 match g* from the CSV for every preset pair; one round
//      matches scenario()'s group answer and k rounds its pure shift; the
//      90-10 gap never moves; reach-everyone counts, fresh-draw reach, the
//      rounding at whole numbers, "never" at zero, and monotonicity.
// Runs every check, prints each FAIL line, and exits non-zero if any failed.

import fs from "node:fs";
import vm from "node:vm";

// Inside a vm context, globalThis is the context object itself, so both
// files' globalThis assignments land on ctx.
const ctx = vm.createContext({});
vm.runInContext(fs.readFileSync("docs/cells.js", "utf8"), ctx);
vm.runInContext(fs.readFileSync("docs/years.js", "utf8"), ctx);
vm.runInContext(fs.readFileSync("docs/engine.js", "utf8"), ctx);
const DATA = ctx.TOOL_DATA, YEARS = ctx.TOOL_YEARS, E = ctx.NAEPEngine;

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
// The engine works on pairs built from years.js by E.pair(). Every check
// below that compares with R runs on the 2019 to 2024 pair, which section 0
// ties to cells.js value for value, so the paper's results are unchanged.
const yearsByLabel = Object.fromEntries(YEARS.cells.map((c) => [c.label, c]));
const PAIRS = DATA.cells.map((c) => E.pair(yearsByLabel[c.label], 2019, 2024));
const pairByLabel = Object.fromEntries(PAIRS.map((c) => [c.label, c]));

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

// ---- 0. the 2019 to 2024 pair from years.js is cells.js -------------------
// years.js is a separate export (analysis/11-export-explorer-years.R) with
// its own API requests. Built for 2019 and 2024 it must reproduce the cells
// the paper's pipeline exported, every field, so the explorer's default view
// cannot drift from the validated one. Tolerance: the two exports read the
// same NAEP values, so they should agree exactly; 1e-9 allows for nothing
// more than JSON round-trips.
const sameArr = (a, b, tol) => a.length === b.length && a.every((v, i) => close(v, b[i], tol));
for (const c of DATA.cells) {
  const pr = pairByLabel[c.label], tag = `${c.label} pair(2019, 2024)`;
  check(sameArr(pr.qRef, c.q2019, 1e-9), `${tag} qRef differs from cells.js q2019`);
  check(sameArr(pr.d, c.d, 1e-9), `${tag} d differs from cells.js`);
  check(sameArr(pr.gStar, c.g_star, 1e-12), `${tag} gStar differs from cells.js g_star`);
  check(close(pr.sdRef, c.sd2019, 1e-9), `${tag} sdRef differs from cells.js sd2019`);
  for (const [a, b, nm] of [[pr.qfRef, c.qf2019, "qfRef"], [pr.qfCmp, c.qf2024, "qfCmp"]])
    check(sameArr(a.pct, b.pct, 1e-9) && sameArr(a.score, b.score, 1e-9), `${tag} ${nm} points differ from cells.js`);
  check(close(pr.ed.pop, c.ed.pop, 1e-12), `${tag} ed.pop differs`);
  check(sameArr(pr.ed.share.pct, c.ed.share.pct, 1e-9) && sameArr(pr.ed.share.share, c.ed.share.share, 1e-12),
        `${tag} ED share curve differs`);
  c.ed.groups.forEach((g, i) => {
    const pg = pr.ed.groups[i];
    check(pg.id === g.id && close(pg.pop, g.pop2024, 1e-12), `${tag} ${g.id} pop differs`);
    for (const [a, b, nm] of [[pg.qfRef, g.qf2019, "qfRef"], [pg.qfCmp, g.qf2024, "qfCmp"]])
      check(sameArr(a.pct, b.pct, 1e-9) && sameArr(a.score, b.score, 1e-9), `${tag} ${g.id} ${nm} differs`);
  });
}

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
  const cell = pairByLabel[label];
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
    const res = (s, p) => s.knots.find((k) => k.p === p).remaining * cell.sdRef;
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
  const cell = pairByLabel[label];
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
  for (const g of ref) for (const [rn, key] of [["2019", "qRef"], ["2024, no program", "qCmp"]]) {
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
for (const cell of PAIRS) {
  const q2024 = cell.qCmp;
  for (const mode of ["group", "distributional"]) {
    // No program: post-program quantiles are the published 2024 knots, and
    // the remaining requirement is g*.
    const s0 = E.scenario(cell, PS, { effect: 0.2, share: 0, kPart: 0.6, kEffect: -0.6, mode }, PS);
    s0.knots.forEach((k, i) => {
      check(close(k.post_pts, q2024[i], 1e-9), `${cell.label} ${mode} zero share p${k.p}: ${k.post_pts} vs ${q2024[i]}`);
      check(close(k.remaining, cell.gStar[i], 1e-9), `${cell.label} ${mode} zero share remaining != g*`);
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
for (const cell of PAIRS) {
  for (const B of [0, 0.1, 0.3, cell.ed.pop, 0.8, 1]) {
    const pi = E.edParticipation(cell.ed, B)(E.FILL_GRID);
    check(close(E.mean(pi), Math.min(B, cell.ed.pop), 1e-3), `${cell.label} screen spends ${E.mean(pi)} at B=${B}`);
    check(pi.every((v) => v >= 0 && v <= 1 + 1e-12), `${cell.label} screen participation outside [0,1] at B=${B}`);
  }
  const B = 0.2, eff = 0.1, r = Math.min(1, B / cell.ed.pop);
  const out = E.groupScenario(cell, { effect: eff, share: B, kPart: 0.6, kEffect: 0, mode: "group", rule: "ed" }, PS);
  const ed = out.find((g) => g.id === "ED"), ned = out.find((g) => g.id === "Not ED");
  PS.forEach((p, i) => {
    check(close(ned.rows[i].post, ned.rows[i].qCmp, 1e-12), `${cell.label} screen moved not-ED students at p${p}`);
    check(close(ed.rows[i].post - ed.rows[i].qCmp, r * eff * cell.sdRef, 1e-9), `${cell.label} screen ED gain at p${p}`);
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
//   These run on every cell and year in years.js. The bin check needs the
//   bins themselves, which only tables/sim-distribution.csv carries (2019
//   and 2024); for the other years the R export built the points from the
//   same bins with the same quantile_points(), and the other checks hold.
const DIST = readCsv("tables/sim-distribution.csv");
for (const yc of YEARS.cells) {
  for (const yr of E.cellYears(yc)) {
    const key = "qf", qf = yc.years[yr].qf, knots = yc.years[yr].q, cell = yc, tag = `${yc.label} ${yr}`;
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

// ---- 6. rounds of a program (rounds.html) --------------------------------
// E.rounds has no R counterpart (no committed output covers more than one
// round), so it is checked three ways: its rounding against g* read straight
// from tables/sim-quantiles.csv, not from cells.js; its one-round step and
// its k-round totals against scenario(), which section 2 ties to R; and a
// set of edge cases and invariants.
const csvGStar = (label, p) => Number(qd.find((r) => r.cell === label && Number(r.percentile) === p).g_star);
const PRESET_C = DATA.participation.map((x) => x.c), PRESET_G = DATA.benchmarks.map((x) => x.g);
for (const cell of PAIRS) {
  const S = cell.sdRef, g10 = csvGStar(cell.label, 10), g90 = csvGStar(cell.label, 90);
  for (const c of PRESET_C) for (const g of PRESET_G) {
    const R = E.rounds(cell, PS, c, g), tag = `${cell.label} c=${c} g=${g}`;
    // Rounds to restore p10 and p90: g* / (c g), rounded up.
    check(R.rounds10 === Math.ceil(g10 / (c * g) - 1e-9), `${tag} rounds10 ${R.rounds10} vs CSV ${g10 / (c * g)}`);
    check(R.rounds90 === Math.ceil(g90 / (c * g) - 1e-9), `${tag} rounds90 ${R.rounds90} vs CSV ${g90 / (c * g)}`);
    check(close(R.perRoundPts, c * g * S, 1e-12), `${tag} perRoundPts`);
    // One round equals the group answer with c seated at every percentile
    // and gain g: the scenario's gain at p10 and p90 is c * g.
    const one = E.scenario(cell, PS, { effect: g, share: c, kPart: 0, kEffect: 0, mode: "group" }, [10, 90]);
    for (const p of [10, 90])
      check(close(one.knots.find((k) => k.p === p).gain, R.perRound, 1e-12), `${tag} one round at p${p} differs from scenario()`);
    // k rounds are a pure shift of k c g, which scenario() expresses as
    // everyone seated at effect k c g. p10 is still short of 2019 one round
    // before rounds10 and back by rounds10.
    // Each k is run once and reused (rounds10 shows up in both checks).
    const memo = new Map();
    const after = (k) => {
      if (!memo.has(k)) memo.set(k, E.scenario(cell, PS, { effect: k * c * g, share: 1, kPart: 0, kEffect: 0, mode: "group" }, [10, 90]));
      return memo.get(k);
    };
    const n = R.rounds10, left10 = (k) => after(k).knots.find((x) => x.p === 10).remaining;
    check(left10(n) <= 1e-9, `${tag} p10 not back to 2019 after ${n} rounds`);
    check(n === 0 || left10(n - 1) > 1e-9, `${tag} p10 already back after ${n - 1} rounds`);
    // The 90-10 gap is the 2024 gap after any number of rounds.
    for (const k of [0, 1, n]) {
      const gp = after(k).gap9010;
      check(close(gp.post, gp.cmp, 1e-9) && close(gp.post, R.gapCmp, 1e-9), `${tag} 90-10 gap moved after ${k} rounds`);
    }
  }
  const R = E.rounds(cell, PS, 0.5, 0.1);
  check(close(R.gStar10, g10, 1e-12) && close(R.gStar90, g90, 1e-12), `${cell.label} rounds g* differs from CSV`);
  check(R.widen.toFixed(1) === DATA.table2a[cell.label].toFixed(1), `${cell.label} rounds widen ${R.widen} vs Table 2(a)`);
  check(close(R.gapCmp, R.gapRef + R.widen, 1e-12), `${cell.label} gapCmp != gapRef + widen`);
  check(close(R.turnsPerStudent, g10 / 0.1, 1e-9), `${cell.label} turnsPerStudent`);
  check(close(R.shareUndonePerRound, 0.05 / g10, 1e-12), `${cell.label} shareUndonePerRound`);
  // Never, with no seats or no gain.
  for (const [c, g] of [[0, 0.1], [0.5, 0], [0, 0]]) {
    const Z = E.rounds(cell, PS, c, g);
    check(Z.rounds10 === null && Z.rounds90 === null, `${cell.label} c=${c} g=${g} should never restore`);
    check(Z.perRound === 0 && Z.toRestore10 === Infinity, `${cell.label} c=${c} g=${g} perRound`);
  }
  check(E.rounds(cell, PS, 0, 0.1).roundsReach === null, `${cell.label} c=0 should never reach everyone`);
  // A gain at least as big as the drop, seated for everyone, takes one round.
  check(E.rounds(cell, PS, 1, g10).rounds10 === 1 && E.rounds(cell, PS, 1, 2 * g10).rounds10 === 1,
        `${cell.label} a full-size program should take one round`);
  // Monotone: more take-up or more gain never needs more rounds.
  const cs = [...PRESET_C].sort((a, b) => a - b), gs = [...PRESET_G].sort((a, b) => a - b);
  for (const g of gs) for (let i = 1; i < cs.length; i++)
    check(E.rounds(cell, PS, cs[i], g).rounds10 <= E.rounds(cell, PS, cs[i - 1], g).rounds10, `${cell.label} not monotone in c`);
  for (const c of cs) for (let i = 1; i < gs.length; i++)
    check(E.rounds(cell, PS, c, gs[i]).rounds10 <= E.rounds(cell, PS, c, gs[i - 1]).rounds10, `${cell.label} not monotone in g`);
}
// Rounding: a ratio that is a whole number up to floating-point error is not
// bumped up a round. 0.9 / (0.3 * 0.1) computes as 30.000000000000004 and
// 0.33 / (0.3 * 0.1) as 11.000000000000002, so a plain ceil would say 31 and
// 12. A ratio genuinely past a whole number is still rounded up.
{
  const fake = (gs10) => ({ sdRef: 1, gStar: PS.map((p) => (p === 10 ? gs10 : 0.1)), d: PS.map(() => 0), qRef: PS });
  check(E.rounds(fake(0.9), PS, 0.3, 0.1).rounds10 === 30, "0.9 / (0.3 * 0.1) should be 30 rounds");
  check(E.rounds(fake(0.33), PS, 0.3, 0.1).rounds10 === 11, "0.33 / (0.3 * 0.1) should be 11 rounds");
  check(E.rounds(fake(0.3), PS, 1, 0.1).rounds10 === 3, "0.3 / 0.1 should be 3 rounds");
  check(E.rounds(fake(0.3 + 1e-6), PS, 1, 0.1).rounds10 === 4, "a ratio just over 3 should be 4 rounds");
  check(E.rounds(fake(0), PS, 1, 0.1).rounds10 === 0, "no drop should need 0 rounds");
}
// Reaching everyone once: 1 / c rounded up; the four presets give 1, 4, 6, 8.
{
  const cell = PAIRS[0];
  const want = { universal: 1, hdt_dist: 4, optin: 6, summer: 8 };
  for (const p of DATA.participation)
    check(E.rounds(cell, PS, p.c, 0.1).roundsReach === want[p.id], `${p.id} reach ${E.rounds(cell, PS, p.c, 0.1).roundsReach} != ${want[p.id]}`);
  check(E.rounds(cell, PS, 0.25, 0.1).roundsReach === 4, "c = 0.25 should reach everyone in 4 rounds");
  // A fresh random draw each round reaches 1 - (1 - c)^k.
  for (const c of [0.13, 0.187, 0.28, 1]) {
    const R = E.rounds(cell, PS, c, 0.1);
    check(R.freshDrawReached(0) === 0, `fresh draw at k = 0 should be 0 for c=${c}`);
    for (const k of [1, 2, 6, 20]) check(close(R.freshDrawReached(k), 1 - Math.pow(1 - c, k), 1e-15), `fresh draw c=${c} k=${k}`);
  }
  check(E.rounds(cell, PS, 1, 0.1).freshDrawReached(1) === 1, "c = 1 reaches everyone in one fresh draw");
  let threw = false;
  try { E.rounds(cell, [25, 50, 75], 0.5, 0.1); } catch (e) { threw = true; }
  check(threw, "rounds should refuse percentiles without p10 and p90");
}

// ---- 7. pages load matching asset versions ---------------------------------
// GitHub Pages lets browsers cache files for 10 minutes. Without a version
// tag, a new page can run against a cached old engine.js or style.css (seen
// on 2026-10-02: the new rounds page called rounds(), which the cached
// engine lacked, and stopped after drawing the controls). Every page must
// load each shared file with ?v=<tag>, and every page must use the same tag,
// so bumping it in one place and not another is caught here.
{
  const PAGES = ["docs/index.html", "docs/rounds.html", "docs/methods.html"];
  const ASSETS = ["style.css", "cells.js", "years.js", "engine.js", "charts.js"];
  const tags = new Set();
  for (const page of PAGES) {
    const html = fs.readFileSync(page, "utf8");
    for (const a of ASSETS) {
      const refs = [...html.matchAll(new RegExp(`(?:href|src)="${a.replace(".", "\\.")}(\\?v=([\\w.-]+))?"`, "g"))];
      check(refs.length === 1, `${page} references ${a} ${refs.length} times, expected 1`);
      for (const r of refs) {
        check(r[2], `${page} loads ${a} without a ?v= version tag`);
        if (r[2]) tags.add(r[2]);
      }
    }
  }
  check(tags.size === 1, `pages use different asset version tags: ${[...tags].join(", ")}`);
  // No page names 2019 or 2024 in its copy where the reader's chosen years
  // belong. Years in the copy are filled in from the chosen pair through
  // <span data-yr="ref|cmp">; what is left must be one of the deliberate
  // mentions of the paper's pair, the year range, or a citation year.
  const ALLOWED = [/2019-to-2024/, /Between 2019 and 2024/, /\b2005 to 2024\b/, /from 2019 to 2024, the pair/,
    /Only 2019 to 2024 is checked/, /^\s*2019 to 2024 has the student-record check/, /With the 2019 and 2024 data/,
    /, 2024(, p\. \d+)?\)/, /<th>2019 SD<\/th>/, /the 2024 score minus the 2019 score/];
  for (const page of PAGES) {
    let t = fs.readFileSync(page, "utf8");
    t = t.replace(/<!--[\s\S]*?-->/g, "").replace(/<span data-yr="(ref|cmp)">\d{4}<\/span>/g, "")
         .replace(/^\s*\/\/.*$/gm, "").replace(/<li id="ref-[\s\S]*?<\/li>/g, "");
    for (const line of t.split("\n")) {
      if (!/\b(2019|2024)\b/.test(line)) continue;
      check(ALLOWED.some((re) => re.test(line)), `${page}: literal year outside the allowed mentions: ${line.trim().slice(0, 90)}`);
    }
  }
  // Every page opens with the draft banner, ahead of its content.
  for (const page of PAGES) {
    const html = fs.readFileSync(page, "utf8");
    check(/<body>\s*<div class="draft-banner" role="note">DRAFT - WORK IN PROGRESS<\/div>/.test(html),
          `${page} does not open with the draft banner`);
  }
}

// ---- 8. other year pairs against R ---------------------------------------
// tables/explorer-pairs-check.csv, from analysis/11-export-explorer-years.R:
// for pairs other than 2019 to 2024 (configured in explorer-years.yaml), the
// proportional rule and the eligibility screen at several budgets, computed
// by the functions 06-seat-allocation.R uses. The engine, fed the same pair
// from years.js, must agree to TOL, so the generalized engine is checked
// against R on pairs beyond the paper's.
{
  const rows = readCsv("tables/explorer-pairs-check.csv");
  check(rows.length > 0, "tables/explorer-pairs-check.csv is missing or empty");
  const pairsSeen = new Set();
  let worst = 0;
  for (const r of rows) {
    const yc = yearsByLabel[r.cell];
    check(yc, `check pair cell '${r.cell}' is not in years.js`);
    if (!yc) continue;
    pairsSeen.add(`${r.cell} ${r.ref}-${r.cmp}`);
    check(!(r.ref === "2019" && r.cmp === "2024"), "explorer-pairs-check.csv should hold pairs other than 2019-2024");
    const cell = E.pair(yc, r.ref, r.cmp), B = Number(r.budget);
    const rule = r.rule.startsWith("Eligibility") ? "ed" : "tilt";
    const base = { effect: G, share: B, kPart: 0, kEffect: 0, rule };
    const dist = E.scenario(cell, PS, { ...base, mode: "distributional" }, [10, 90]);
    const grp  = E.scenario(cell, PS, { ...base, mode: "group" }, [10, 90]);
    const res = (sc, p) => sc.knots.find((k) => k.p === p).remaining * cell.sdRef;
    for (const [got, want, name] of [
      [res(dist, 10), Number(r.res_p10), "res_p10"],
      [res(dist, 90), Number(r.res_p90), "res_p90"],
      [res(dist, 10) - res(dist, 90), Number(r.gap_remaining), "gap_remaining"],
      [res(grp, 10) - res(grp, 90), Number(r.gap_remaining_tracked), "gap_remaining_tracked"],
    ]) {
      worst = Math.max(worst, Math.abs(got - want));
      check(close(got, want, TOL), `${r.cell} ${r.ref}-${r.cmp} ${rule} B=${B} ${name}: JS ${got} vs R ${want}`);
    }
  }
  check(pairsSeen.size >= 3, `explorer-pairs-check.csv covers ${pairsSeen.size} pairs, expected at least 3`);
  console.log(`  other pairs: ${rows.length} rows over ${pairsSeen.size} pairs, max |JS - R| = ${worst.toExponential(2)} points`);
}

// ---- 9. every cell-year and every pair in years.js -------------------------
// The year lists match the config's (grade 12 has its own), each record is
// whole, the ED shares add up, and every valid pair (reference before
// comparison) passes the invariants of section 3 and the rounds identities
// of section 6. A pair the pages could offer cannot be malformed.
{
  const yamlText = fs.readFileSync("analysis/config/explorer-years.yaml", "utf8");
  const listOf = (key) => yamlText.match(new RegExp(`${key}:\\s*\\[([^\\]]*)\\]`))[1].split(",").map(Number);
  const Y48 = listOf("grade_4_8"), Y12 = listOf("grade_12");
  check(YEARS.cells.length === DATA.cells.length, "years.js and cells.js have different cell counts");
  check(YEARS.default_pair.join() === "2019,2024", `default pair is ${YEARS.default_pair}, expected 2019,2024`);
  let nPairs = 0;
  for (const yc of YEARS.cells) {
    const want = yc.grade === 12 ? Y12 : Y48, got = E.cellYears(yc);
    check(got.join() === want.join(), `${yc.label} years ${got} differ from the config's ${want}`);
    for (const yr of got) {
      const rec = yc.years[yr], tag = `${yc.label} ${yr}`;
      check(rec.q.length === PS.length && rec.q.every((v, i) => i === 0 || v > rec.q[i - 1]), `${tag}: knots missing or not increasing`);
      check(rec.sd > 0, `${tag}: SD not positive`);
      const tot = rec.ed.groups.reduce((a, g) => a + g.pop, 0) + rec.ed.unknown;
      check(close(tot, 1, 2e-3), `${tag}: ED, not-ED, and unclassified shares sum to ${tot}, not 1`);
      check(close(rec.ed.pop, rec.ed.groups[0].pop, 1e-3), `${tag}: ED share curve pop ${rec.ed.pop} vs group pop ${rec.ed.groups[0].pop}`);
    }
    for (const ref of got) for (const cmp of got) {
      if (ref >= cmp) continue;
      nPairs++;
      const cell = E.pair(yc, ref, cmp), tag = `${yc.label} ${ref}-${cmp}`;
      for (const mode of ["group", "distributional"]) {
        const s0 = E.scenario(cell, PS, { effect: 0.2, share: 0, kPart: 0.6, kEffect: -0.6, mode }, PS);
        check(s0.knots.every((k, i) => close(k.post_pts, cell.qCmp[i], 1e-9) && close(k.remaining, cell.gStar[i], 1e-9)),
              `${tag} ${mode}: a zero program does not return the comparison knots`);
      }
      const full = E.scenario(cell, PS, { effect: 0.1, share: 1, kPart: 0, kEffect: 0, mode: "group" }, PS);
      check(full.knots.every((k) => close(k.gain, 0.1, 1e-9)), `${tag}: full uniform participation is not a pure shift`);
      const R = E.rounds(cell, PS, 0.28, 0.155);
      check(close(R.gapCmp, full.gap9010.cmp, 1e-9) && close(R.gapRef, full.gap9010.ref, 1e-9), `${tag}: rounds gaps differ from scenario`);
      check(R.rounds10 === (cell.gStar[0] <= 0 ? 0 : Math.ceil(cell.gStar[0] / (0.28 * 0.155) - 1e-9)), `${tag}: rounds10 wrong`);
    }
    // Pairs out of order are refused.
    let threw = false;
    try { E.pair(yc, got[got.length - 1], got[0]); } catch (e) { threw = true; }
    check(threw, `${yc.label}: pair() accepted a reference after the comparison`);
  }
  console.log(`  years.js: ${YEARS.cells.reduce((a, c) => a + E.cellYears(c).length, 0)} cell-years, ${nPairs} pairs checked`);
}

console.log(`${checks} checks, ${failures} failed`);
process.exit(failures ? 1 : 0);
