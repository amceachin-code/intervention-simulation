// Computation engine for the intervention explorer (docs/index.html).
//
// A JavaScript port of the pieces of the R pipeline the page needs:
//   makeQuantileFn     analysis/mixture.R  make_quantile_fn
//   weightedQuantile   analysis/mixture.R  weighted_quantile
//   waterFill          analysis/alloc-rules.R  water_fill
//   mixtureQuantiles   analysis/mixture.R  program_quantiles + calibration
//   groupQuantiles     analysis/06-seat-allocation.R  residual_tracked
//   edParticipation    analysis/alloc-rules.R  make_ed_screen
//   quantileRank       analysis/mixture.R  quantile_rank
//   groupScenario      analysis/06-seat-allocation.R  the ED / not-ED outcome table
// The comments in those files explain the modelling choices; the comments here
// say what is ported and where the port differs. analysis/tests/test-tool-engine.mjs
// checks this file against the committed R outputs in tables/.
//
// Pure functions only, no DOM, so the same file runs in the browser (loaded
// by <script src>) and in Node (loaded by the test through the vm module).
// Everything is attached to globalThis.NAEPEngine.

(function (root) {
  "use strict";

  // ---------------------------------------------------------------------
  // Monotone cubic interpolation, identical to R's splinefun(method="monoH.FC"):
  // start from averaged secant slopes, then apply the Fritsch-Carlson
  // adjustment (R's C routine monoFC_mod) and evaluate the cubic Hermite.
  function monoHFC(x, y) {
    const n = x.length;
    const dx = [], S = [];
    for (let i = 0; i < n - 1; i++) { dx.push(x[i + 1] - x[i]); S.push((y[i + 1] - y[i]) / dx[i]); }
    const m = [S[0]];
    for (let i = 1; i < n - 1; i++) m.push((S[i - 1] + S[i]) / 2);
    m.push(S[n - 2]);
    for (let k = 0; k < n - 1; k++) {
      const Sk = S[k];
      if (Sk === 0) { m[k] = m[k + 1] = 0; continue; }
      const al = m[k] / Sk, be = m[k + 1] / Sk;
      const a2b3 = 2 * al + be - 3, ab23 = al + 2 * be - 3;
      if (a2b3 > 0 && ab23 > 0 && al * (a2b3 + ab23) < a2b3 * a2b3) {
        const tauS = 3 * Sk / Math.sqrt(al * al + be * be);
        m[k] = tauS * al; m[k + 1] = tauS * be;
      }
    }
    return function (u) {
      let i = 0;
      while (i < n - 2 && u > x[i + 1]) i++;
      const h = dx[i], t = (u - x[i]) / h, t2 = t * t, t3 = t2 * t;
      return (2 * t3 - 3 * t2 + 1) * y[i] + (t3 - 2 * t2 + t) * h * m[i] +
             (-2 * t3 + 3 * t2) * y[i + 1] + (t3 - t2) * h * m[i + 1];
    };
  }

  // Quantile function through points spanning 0 to 100 percent: the score
  // distribution's bin points plus the published percentiles, built in R by
  // quantile_points (analysis/mixture.R) and exported in cells.js as qf2019
  // and qf2024. A monotone spline with a continuous slope, so no corners, and
  // no tails because the points reach the ends of the scale. Port of
  // make_quantile_fn.
  function makeQuantileFn(pct, vals) {
    if (pct[0] !== 0 || pct[pct.length - 1] !== 100)
      throw new Error("makeQuantileFn: points must run from 0 to 100 percent");
    for (let i = 1; i < vals.length; i++)
      if (vals[i] <= vals[i - 1] || pct[i] <= pct[i - 1]) throw new Error("makeQuantileFn: points must increase");
    const inner = monoHFC(pct, vals);
    return (u) => inner(Math.min(Math.max(u, 0), 100));
  }

  // ---------------------------------------------------------------------
  // Grids, the same points as the R constants (to the last bit or so; R's
  // seq() computes from + i*by) so the port reproduces the R numbers.
  //   RANK_GRID  analysis/mixture.R      0.01, 0.02, ..., 99.99
  //   FILL_GRID  analysis/alloc-rules.R  0.125, 0.375, ..., 99.875 (bin midpoints)
  // Built from integer counters so there is no floating-point drift.
  const RANK_GRID = Array.from({ length: 9999 }, (_, i) => (i + 1) / 100);
  const FILL_GRID = Array.from({ length: 400 }, (_, i) => 0.125 + i * 0.25);

  // Linear interpolation with R's approx(rule=2): flat beyond the ends.
  // xs must be sorted ascending.
  function approx(xs, ys, xout) {
    const n = xs.length;
    return xout.map(function (v) {
      if (v <= xs[0]) return ys[0];
      if (v >= xs[n - 1]) return ys[n - 1];
      let lo = 0, hi = n - 1;
      while (hi - lo > 1) { const mid = (lo + hi) >> 1; if (xs[mid] <= v) lo = mid; else hi = mid; }
      const f = (v - xs[lo]) / (xs[hi] - xs[lo]);
      return ys[lo] + f * (ys[hi] - ys[lo]);
    });
  }

  // ---------------------------------------------------------------------
  // The gradient ("tilt") in prior achievement.
  //
  // w(u) = 1 + k * (u - 50) / 40, a straight line in rank with mean 1 over
  // [0, 100]. The p90:p10 ratio is (1 + k) / (1 - k), so the five levels are
  // named by that ratio: k = +0.6 gives 4:1, k = +1/3 gives 2:1. Positive k
  // means higher-achieving students get more (more participation, or a larger
  // effect); negative k favors lower achievers. |k| <= 0.6 keeps w > 0 on the
  // whole range (the minimum is 1 - 1.25 * 0.6 = 0.25 at the end), so no
  // percentile is ever pushed below zero participation or to a negative effect.
  const TILT_LEVELS = [
    { id: "strong-neg", k: -0.6,  label: "Strong negative", ratio: "1:4" },
    { id: "mild-neg",   k: -1 / 3, label: "Mild negative",  ratio: "1:2" },
    { id: "neutral",    k: 0,     label: "Neutral",         ratio: "1:1" },
    { id: "mild-pos",   k: 1 / 3, label: "Mild positive",   ratio: "2:1" },
    { id: "strong-pos", k: 0.6,   label: "Strong positive", ratio: "4:1" },
  ];
  function tilt(k) { return (u) => 1 + k * (u - 50) / 40; }

  // Water-filling, port of water_fill (analysis/alloc-rules.R). Spreads a
  // seat budget B (share of all students) in proportion to the shape, caps
  // each percentile at 100 percent, and hands the capped excess back to the
  // uncapped percentiles until nothing is over. Solved on FILL_GRID, then read
  // off at the requested ranks by linear interpolation.
  function waterFill(shapeFn, B) {
    const w = FILL_GRID.map(shapeFn);
    const part = new Array(w.length).fill(0);
    const free = new Array(w.length).fill(true);
    let seats = B * w.length;
    for (;;) {
      let sw = 0, anyFree = false;
      for (let i = 0; i < w.length; i++) if (free[i]) { sw += w[i]; anyFree = true; }
      if (!anyFree || seats <= 0 || sw <= 0) break;
      let anyOver = false;
      for (let i = 0; i < w.length; i++) if (free[i]) {
        part[i] = seats * w[i] / sw;
        if (part[i] > 1) anyOver = true;
      }
      if (!anyOver) break;
      for (let i = 0; i < w.length; i++) if (free[i] && part[i] > 1) {
        part[i] = 1; seats -= 1; free[i] = false;
      }
    }
    const capped = part.map((v) => Math.min(1, v));
    return (ps) => approx(FILL_GRID, capped, ps);
  }

  // Participation rate at each rank: share treated B, tilted by k, conserved
  // by water-filling. Returns a function of an array of ranks.
  function participation(B, k) { return waterFill(tilt(k), B); }

  // Eligibility screen, port of make_ed_screen (analysis/alloc-rules.R).
  // Seats go at random to economically disadvantaged (ED) students, so with
  // budget B the ED treatment rate is r = min(1, B / pop) and participation at
  // rank p is r * s(p), where s(p) is the 2024 ED share at p (cells.js ed.share,
  // exported from ed_share_points). Seats beyond pop have no eligible taker
  // and go unused, which the page reports.
  function edParticipation(ed, B) {
    const r = Math.min(1, B / ed.pop);
    return (ps) => edShareAt(ed, ps).map((s) => r * s);
  }
  // s(p), the 2024 ED share at each rank in ps (an array), and the share of
  // students whose status NAEP does not know (neither group), for the pages'
  // text.
  function edShareAt(ed, ps) { return approx(ed.share.pct, ed.share.share, ps); }
  function edUnknownShare(ed) { return 1 - ed.groups.reduce((a, g) => a + g.pop2024, 0); }

  // National rank (0-100) of each score in xs, port of quantile_rank
  // (analysis/mixture.R): the inverse of Qfn read off a dense grid from 0 to
  // 100 in steps of 0.001, built as i * 0.001 the way R's seq() builds it.
  const INVERSE_GRID = Array.from({ length: 100001 }, (_, i) => i * 0.001);
  function quantileRank(Qfn, xs) { return approx(INVERSE_GRID.map(Qfn), INVERSE_GRID, xs); }

  // Treated effect at each rank, in NAEP score points. `effect` is the
  // population-average effect in 2019 SD units (the mean of w is 1, so the
  // average over all ranks is exactly `effect`); S converts to points.
  function effectPoints(effect, k, S) {
    const w = tilt(k);
    return (ps) => ps.map((u) => effect * w(u) * S);
  }

  // ---------------------------------------------------------------------
  // Weighted quantile, midpoint convention. Port of weighted_quantile
  // (analysis/mixture.R), including dropping atoms with negligible weight.
  function weightedQuantile(v, w, probs) {
    const idx = [];
    for (let i = 0; i < v.length; i++) if (w[i] > 1e-12) idx.push(i);
    idx.sort((a, b) => v[a] - v[b]);
    let tot = 0;
    for (const i of idx) tot += w[i];
    const cw = [], vs = [];
    let run = 0;
    for (const i of idx) { run += w[i]; cw.push((run - 0.5 * w[i]) / tot); vs.push(v[i]); }
    return approx(cw, vs, probs.map((p) => p / 100));
  }

  // Raw mixture quantiles on RANK_GRID. x is the pre-program quantile
  // function evaluated on the grid; at each rank u, weight 1 - pi(u) stays at
  // x(u) and weight pi(u) moves to x(u) + delta(u). Port of
  // program_quantiles, generalized so delta can vary with rank. Taking x
  // rather than the quantile function lets callers evaluate it once.
  function rawMixture(x, pr, dl, probs) {
    const v = x.concat(x.map((xi, i) => xi + dl[i]));
    const w = pr.map((p) => 1 - p).concat(pr);
    return weightedQuantile(v, w, probs);
  }

  // Caches for what does not depend on the program, rebuilt only when the
  // cell (or group) or the requested percentiles change, not on every slider
  // move: a quantile function evaluated on RANK_GRID, and the no-program
  // mixture at a set of percentiles (the calibration baseline). `key` names
  // the quantile function; any string unique to it works. Shared by the
  // national answer and the group views.
  const gridCache = new Map(), noProgCache = new Map();
  function onGrid(key, Qfn) {
    if (!gridCache.has(key)) gridCache.set(key, RANK_GRID.map(Qfn));
    return gridCache.get(key);
  }
  function withoutProgram(key, x, probs) {
    const k = key + "|" + probs.join(",");
    if (!noProgCache.has(k)) {
      const zeros = RANK_GRID.map(() => 0);
      noProgCache.set(k, rawMixture(x, zeros, zeros, probs));
    }
    return noProgCache.get(k);
  }

  // DISTRIBUTIONAL answer: whoever stands at percentile p after the program.
  // Calibrated as in calibrated_program_quantiles: the grid reproduces the
  // knots only to about 0.01 points, so the result is reported as the exact
  // pre-program quantile plus the program's change on the grid. At the knots
  // this is the R calibration exactly (Qfn passes through the knots); between
  // knots it applies the same idea at every p. `key` identifies the cell for
  // the baseline cache; any string unique to Qfn works.
  function mixtureQuantiles(Qfn, piFn, deltaFn, probs, key) {
    const x = onGrid(key, Qfn), without = withoutProgram(key, x, probs);
    const pr = piFn(RANK_GRID).map((p) => Math.min(1, Math.max(0, p)));
    const withProg = rawMixture(x, pr, deltaFn(RANK_GRID), probs);
    return probs.map((p, i) => Qfn(p) + withProg[i] - without[i]);
  }

  // GROUP answer: follow the students who started at percentile p. A pi(p)
  // share gains delta(p), so the group's mean moves by pi(p) * delta(p).
  function groupQuantiles(Qfn, piFn, deltaFn, probs) {
    const pr = piFn(probs), dl = deltaFn(probs);
    return probs.map((p, i) => Qfn(p) + pr[i] * dl[i]);
  }

  // inputs.rule is "tilt" (the default: any student may take part, tilted by
  // kPart) or "ed" (the eligibility screen; kPart is ignored).
  function participationFor(cell, inputs) {
    return inputs.rule === "ed" ? edParticipation(cell.ed, inputs.share)
                                : participation(inputs.share, inputs.kPart);
  }

  // ---------------------------------------------------------------------
  // One full scenario for a cell.
  //
  // inputs: { effect (SD), share (0-1), kPart, kEffect, mode: "group"|"distributional",
  //           rule: "tilt"|"ed" (optional; "tilt" when absent) }
  // probs:  percentiles to evaluate (the chart grid); the knots are always
  //         evaluated as well, in the same pass, for the table.
  //
  // Returns { curve, knots, gap9010, meanPart }. curve and knots hold one row
  // per percentile, in 2019 SD units unless named *_pts:
  //   gStar      restoration requirement, -(Q2024 - Q2019) / S (so D/S = -gStar)
  //   remaining  requirement left after the program, (Q2019 - post) / S
  //   gain       what the program delivered at that percentile, gStar - remaining
  //   part, effect   the participation rate and treated effect (SD) at p
  //   post_pts, q2019_pts, q2024_pts   the post-program, 2019, and 2024 scores
  // gap9010 is the 90-10 gap in NAEP points { y2019, y2024, post }, and
  // meanPart is mean participation over all ranks: equal to share under the
  // tilts by construction, and min(share, ED share) under the screen (shown
  // on the page as a check).
  function scenario(cell, knotsPct, inputs, probs) {
    const S = cell.sd2019;
    const Q19 = makeQuantileFn(cell.qf2019.pct, cell.qf2019.score);
    const Q24 = makeQuantileFn(cell.qf2024.pct, cell.qf2024.score);
    const piFn = participationFor(cell, inputs);
    const dFn = effectPoints(inputs.effect, inputs.kEffect, S);

    // One pass over the union of the chart grid and the knots: the mixture
    // quantile is pointwise in the requested percentiles, so this gives the
    // same numbers as evaluating the two sets separately at half the cost.
    const all = [...new Set([...probs, ...knotsPct])].sort((a, b) => a - b);
    const after = inputs.mode === "group"
      ? groupQuantiles(Q24, piFn, dFn, all)
      : mixtureQuantiles(Q24, piFn, dFn, all, cell.label + "|2024");
    const pr = piFn(all), ef = dFn(all);
    const rows = all.map((p, i) => {
      const q19 = Q19(p), q24 = Q24(p);
      const gStar = (q19 - q24) / S, remaining = (q19 - after[i]) / S;
      return { p, gStar, remaining, gain: gStar - remaining,
               part: pr[i], effect: ef[i] / S, post_pts: after[i],
               q2019_pts: q19, q2024_pts: q24 };
    });
    const byP = new Map(rows.map((r) => [r.p, r]));
    const curve = probs.map((p) => byP.get(p));
    const knots = knotsPct.map((p) => byP.get(p));
    const gap = (key) => byP.get(90)[key] - byP.get(10)[key];
    return {
      curve, knots,
      gap9010: { y2019: gap("q2019_pts"), y2024: gap("q2024_pts"), post: gap("post_pts") },
      meanPart: mean(piFn(FILL_GRID)),
    };
  }

  // ---------------------------------------------------------------------
  // Economically disadvantaged and other students: each group's own
  // distribution before and after the program. Port of the group section of
  // analysis/06-seat-allocation.R.
  //
  // A student at rank u of group g scores Q_g(u) and sits at national rank
  // v = F(Q_g(u)) in 2024. Under the tilt rules their chance of a seat is
  // pi(v) and their boost delta(v), both read at the NATIONAL rank, because
  // that is what the program sees. Under the screen every ED student has the
  // same chance r = min(1, B / pop) and no one else has any. The group's
  // post-program quantiles are then the same treated/untreated mixture as the
  // national answer, calibrated the same way (a zero program returns Q_g
  // exactly). In "Same students" mode the group at its own percentile p gains
  // pi(v) * delta(v) on average, as groupQuantiles does nationally.
  //
  // Returns [{ id, label, rows: [{ p, q2019, q2024, post }] }, ...], scores in
  // NAEP points, one entry per group in cells.js order (ED, then not ED).
  const groupCache = new Map();
  function groupBase(cell, g) {
    const k = cell.label + "|" + g.id;
    if (!groupCache.has(k)) {
      const Q24 = makeQuantileFn(cell.qf2024.pct, cell.qf2024.score);
      const Q19g = makeQuantileFn(g.qf2019.pct, g.qf2019.score);
      const Q24g = makeQuantileFn(g.qf2024.pct, g.qf2024.score);
      const x = onGrid(k, Q24g);
      const v = quantileRank(Q24, x);   // national rank, fixed across programs
      groupCache.set(k, { Q24, Q19g, Q24g, x, v });
    }
    return groupCache.get(k);
  }
  function groupScenario(cell, inputs, probs) {
    const S = cell.sd2019;
    const dFn = effectPoints(inputs.effect, inputs.kEffect, S);
    const piNat = inputs.rule === "ed" ? null : participation(inputs.share, inputs.kPart);
    const r = Math.min(1, inputs.share / cell.ed.pop);
    return cell.ed.groups.map((g) => {
      const b = groupBase(cell, g);
      // Every rule already returns a rate in [0, 1] (tested); no clamp.
      const chance = (vs) => inputs.rule === "ed" ? vs.map(() => (g.id === "ED" ? r : 0)) : piNat(vs);
      let post;
      if (inputs.mode === "group") {
        const vp = quantileRank(b.Q24, probs.map(b.Q24g));
        const pr = chance(vp), dl = dFn(vp);
        post = probs.map((p, i) => b.Q24g(p) + pr[i] * dl[i]);
      } else {
        const without = withoutProgram(cell.label + "|" + g.id, b.x, probs);
        const withProg = rawMixture(b.x, chance(b.v), dFn(b.v), probs);
        post = probs.map((p, i) => b.Q24g(p) + withProg[i] - without[i]);
      }
      return { id: g.id, label: g.label,
               rows: probs.map((p, i) => ({ p, q2019: b.Q19g(p), q2024: b.Q24g(p), post: post[i] })) };
    });
  }

  function mean(a) { let s = 0; for (const v of a) s += v; return s / a.length; }

  // Exported: what the pages use (scenario, groupScenario, tilt, TILT_LEVELS,
  // edShareAt, edUnknownShare; the methods page also calls participation) and
  // what the test checks directly (the rest).
  root.NAEPEngine = {
    scenario, groupScenario, tilt, TILT_LEVELS, edShareAt, edUnknownShare,
    makeQuantileFn, participation, edParticipation, effectPoints, FILL_GRID, mean,
  };
})(globalThis);
