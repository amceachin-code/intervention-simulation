// Computation engine for the intervention explorer (docs/index.html).
//
// A JavaScript port of the pieces of the R pipeline the page needs:
//   makeQuantileFn     analysis/mixture.R  make_quantile_fn
//   weightedQuantile   analysis/mixture.R  weighted_quantile
//   waterFill          analysis/alloc-rules.R  water_fill
//   mixtureQuantiles   analysis/mixture.R  program_quantiles + calibration
//   groupQuantiles     analysis/06-seat-allocation.R  residual_tracked
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
  // Standard normal quantile. Acklam's rational approximation (relative
  // error about 1e-9) followed by one Halley step on the normal CDF, the
  // refinement Acklam recommends. With the double-precision CDF below this
  // reaches about 1e-15, so the tails agree with R's qnorm far below any
  // displayed digit.
  function qnorm(p) {
    if (p <= 0) return -Infinity;
    if (p >= 1) return Infinity;
    const a = [-3.969683028665376e1, 2.209460984245205e2, -2.759285104469687e2,
               1.38357751867269e2, -3.066479806614716e1, 2.506628277459239];
    const b = [-5.447609879822406e1, 1.615858368580409e2, -1.556989798598866e2,
               6.680131188771972e1, -1.328068155288572e1];
    const c = [-7.784894002430293e-3, -3.223964580411365e-1, -2.400758277161838,
               -2.549732539343734, 4.374664141464968, 2.938163982698783];
    const d = [7.784695709041462e-3, 3.224671290700398e-1, 2.445134137142996,
               3.754408661907416];
    const lo = 0.02425, hi = 1 - lo;
    let x;
    if (p < lo) {
      const q = Math.sqrt(-2 * Math.log(p));
      x = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
          ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    } else if (p <= hi) {
      const q = p - 0.5, r = q * q;
      x = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q /
          (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1);
    } else {
      const q = Math.sqrt(-2 * Math.log(1 - p));
      x = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) /
           ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1);
    }
    // One Halley refinement: u = (Phi(x) - p) / phi(x), x <- x - u / (1 + x*u/2).
    const e = pnorm(x) - p;
    const u = e * Math.sqrt(2 * Math.PI) * Math.exp(x * x / 2);
    return x - u / (1 + x * u / 2);
  }

  // Standard normal CDF, West (2005) "Better approximations to cumulative
  // normal functions" (Hart's algorithm 5666), accurate to about 1e-15. It has
  // to be that good: the Newton step in qnorm is only as accurate as this CDF.
  function pnorm(z) {
    const x = Math.abs(z);
    let c = 0;
    if (x <= 37) {
      const e = Math.exp(-x * x / 2);
      if (x < 7.07106781186547) {
        let n = 3.52624965998911e-2 * x + 0.700383064443688;
        n = n * x + 6.37396220353165; n = n * x + 33.912866078383;
        n = n * x + 112.079291497871; n = n * x + 221.213596169931;
        n = n * x + 220.206867912376;
        let d = 8.83883476483184e-2 * x + 1.75566716318264;
        d = d * x + 16.064177579207; d = d * x + 86.7807322029461;
        d = d * x + 296.564248779674; d = d * x + 637.333633378831;
        d = d * x + 793.826512519948; d = d * x + 440.413735824752;
        c = e * n / d;
      } else {
        let b = x + 0.65;
        b = x + 4 / b; b = x + 3 / b; b = x + 2 / b; b = x + 1 / b;
        c = e / b / 2.506628274631;
      }
    }
    return z > 0 ? 1 - c : c;
  }

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

  // Quantile function from published percentile knots: monotone interpolation
  // inside, normal tails outside with sigma fitted through the outer knots.
  // Port of make_quantile_fn (analysis/mixture.R). Knots must be sorted and
  // strictly increasing, which the exported data always are.
  function makeQuantileFn(pct, vals) {
    for (let i = 1; i < vals.length; i++)
      if (vals[i] <= vals[i - 1]) throw new Error("makeQuantileFn: knots must increase");
    const inner = monoHFC(pct, vals);
    const loP = pct[0], hiP = pct[pct.length - 1];
    const loV = vals[0], hiV = vals[vals.length - 1];
    const zLo = qnorm(loP / 100), zHi = qnorm(hiP / 100);
    const sig = (hiV - loV) / (zHi - zLo);
    return function (u) {
      u = Math.min(Math.max(u, 1e-6), 100 - 1e-6);
      if (u < loP) return loV + (qnorm(u / 100) - zLo) * sig;
      if (u > hiP) return hiV + (qnorm(u / 100) - zHi) * sig;
      return inner(u);
    };
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

  // Per-cell cache of what does not depend on the program: the pre-program
  // quantile function on RANK_GRID and the no-program mixture at a given set
  // of percentiles. Both are rebuilt only when the cell's knots or the
  // requested percentiles change, not on every slider move.
  const baseCache = new Map();
  function baseline(Qfn, key, probs) {
    const k = key + "|" + probs.join(",");
    if (!baseCache.has(k)) {
      const x = RANK_GRID.map(Qfn);
      const zeros = RANK_GRID.map(() => 0);
      baseCache.set(k, { x, without: rawMixture(x, zeros, zeros, probs) });
    }
    return baseCache.get(k);
  }

  // DISTRIBUTIONAL answer: whoever stands at percentile p after the program.
  // Calibrated as in calibrated_program_quantiles: the grid reproduces the
  // knots only to about 0.008 points, so the result is reported as the exact
  // pre-program quantile plus the program's change on the grid. At the knots
  // this is the R calibration exactly (Qfn passes through the knots); between
  // knots it applies the same idea at every p. `key` identifies the cell for
  // the baseline cache; any string unique to Qfn works.
  function mixtureQuantiles(Qfn, piFn, deltaFn, probs, key) {
    const { x, without } = baseline(Qfn, key, probs);
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

  // ---------------------------------------------------------------------
  // One full scenario for a cell.
  //
  // inputs: { effect (SD), share (0-1), kPart, kEffect, mode: "group"|"distributional" }
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
  // meanPart is mean participation over all ranks (equal to share by
  // construction; shown on the page as a check).
  function scenario(cell, knotsPct, inputs, probs) {
    const S = cell.sd2019;
    const q2024 = cell.q2019.map((q, i) => q + cell.d[i]);
    const Q19 = makeQuantileFn(knotsPct, cell.q2019);
    const Q24 = makeQuantileFn(knotsPct, q2024);
    const piFn = participation(inputs.share, inputs.kPart);
    const dFn = effectPoints(inputs.effect, inputs.kEffect, S);

    // One pass over the union of the chart grid and the knots: the mixture
    // quantile is pointwise in the requested percentiles, so this gives the
    // same numbers as evaluating the two sets separately at half the cost.
    const all = [...new Set([...probs, ...knotsPct])].sort((a, b) => a - b);
    const after = inputs.mode === "group"
      ? groupQuantiles(Q24, piFn, dFn, all)
      : mixtureQuantiles(Q24, piFn, dFn, all, q2024.join(","));
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

  function mean(a) { let s = 0; for (const v of a) s += v; return s / a.length; }

  // Exported: what the page uses (scenario, tilt, TILT_LEVELS) and what the
  // test checks directly (the rest).
  root.NAEPEngine = {
    scenario, tilt, TILT_LEVELS,
    qnorm, makeQuantileFn, participation, effectPoints, FILL_GRID, mean,
  };
})(globalThis);
