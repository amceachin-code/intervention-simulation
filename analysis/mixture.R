## Outcome model for the seat-allocation analysis: what a program does to the
## score distribution, as distinct from who it reaches.
##
## There are two questions one can ask of a program, and they have different
## answers. Take the students who started at percentile p and follow them: a
## pi(p) share gains delta and the rest gain nothing, so the group gains
## pi(p)*delta on average and reshuffling is irrelevant because the group is
## fixed. That is the GROUP question, and Q(p) + pi(p)*delta answers it
## exactly. It is what analysis/06-seat-allocation.R computes in
## residual_tracked(), and it is what this pipeline computed everywhere
## through September 2026.
##
## The other question is DISTRIBUTIONAL: whoever now stands at percentile p,
## where are they? Here reshuffling is the whole story. A program reaching 13
## percent of students delivers the full effect to 13 percent and nothing to
## the other 87, so the post-program population is a two-component mixture,
## and mixing a distribution with a shifted copy of itself spreads it, because
## treated students move past untreated neighbors who stay where they were.
## The group mean moves by pi*delta; the percentile position does not.
##
## This file answers the second question, which is the one the rest of the
## paper asks: D(p) compares two different cohorts, so nothing in the paper
## tracks a student. For Reading G4 the difference is 0.25 points under
## proportional allocation at half coverage, where the group answer is exactly
## no change and the distributional answer is a wider gap. Under bottom-up
## allocation at 10 percent of seats the group answer is 2.69 and the
## distributional answer is 5.79, because the treated bottom decile leapfrogs
## the untreated students above it and the percentile refills from behind.
## (With the five-percentile quantile function used before 2026-09-28 these
## were 1.17 and 5.96; its normal tail met the spline at p90 with a corner
## that inflated the spreading. See quantile_points below.)
##
## What is computed here instead: at each rank u, weight (1 - pi(u)) stays at
## Q(u) and weight pi(u) moves to Q(u) + delta. Post-program quantiles are the
## weighted quantiles of that combined population. This is the large-population
## limit of independent assignment at rate pi(u), so it is deterministic and
## carries no Monte Carlo term to report. Where pi is 0 or 1, as under
## bottom-up allocation, it reduces to exact rank-preserving assignment, so all
## four rules share one code path rather than needing a deterministic branch
## and a stochastic one.
##
## Two assumptions come with it, both stated in the memo:
##
##   1. Within a percentile, who takes part is independent of how much they
##      would gain. The rules already carry selection ACROSS percentiles, which
##      is the whole point of the opt-in gradient; this is the further claim
##      that there is no selection on gains within a percentile. No source in
##      the tutoring literature pins that down in either direction.
##   2. The tested population is large enough that the realized distribution
##      equals its expectation. NAEP grade-level samples run to six figures, so
##      the sampling term here is negligible next to the modelling choices.

## Rank grid representing the population, equally weighted so that a plain mean
## over it is a population mean. Cell midpoints of 0.01-percent bins would be
## the textbook choice; the grid keeps its original points (0.01 to 99.99) so
## that results stay comparable with earlier runs. The ends of the quantile
## function carry almost no weight, so the choice does not move any result.
RANK_GRID <- seq(0.01, 99.99, by=0.01)

## Points the quantile function passes through, for one cell and year.
##
## `dist` is that year's score distribution from tables/sim-distribution.csv
## (NAEP DP:DP: percent of students in each 10-point bin, columns lo, hi,
## pct). Each non-empty bin contributes the point (cumulative percent at its
## top, its upper edge), and the bottom of the first non-empty bin anchors 0
## percent. The published percentiles (`knots_pct`, `knots_val`) are added as
## points too, so the function reproduces them exactly: D(p), g*(p), and the
## Table 2(a) validation are read off the percentiles and must not move.
##
## Why the histogram: with only the five percentiles, everything beyond p10
## and p90 had to be an assumed tail, and the normal tail used until
## 2026-09-28 met the spline at p90 with a slope 1.4 to 1.8 times the
## spline's. The mixture inherited that corner as a visible kink once treated
## students passed the p90 score. The histogram puts 30 to 40 published
## points under the curve, bounded by the scale's own bin edges, so no tail is
## assumed anywhere. A monotone spline through the bin points alone
## reproduces the published percentiles to within about 0.1 point
## (analysis/tests/test-sim.R), so anchoring to them bends the curve only
## slightly.
##
## Cumulative shares are rescaled so the top point is exactly 100 (the bins
## sum to 100 within 0.01, checked when they are pulled). A bin point that
## lands on a published percentile is dropped in favor of the percentile.
## Pass no percentiles (numeric(0)) for the histogram-only curve the tests use
## as a data-consistency check. Returns data.frame(pct, score, source),
## strictly increasing in both pct and score.
##
## If a bin point and a published percentile are out of order, this stops
## rather than dropping the bin point (Andrew, 2026-09-28): the two sources
## agree to about 0.1 point today, so a conflict would mean the data changed
## and a person should look. The closest pairs on 2026-09-28 were 0.05
## percentile points apart (Math G4 2024 at p50; Reading G8 2019 at p25).
quantile_points <- function(dist, knots_pct, knots_val, label="") {
  dist <- dist[order(dist$lo), ]
  cum  <- cumsum(dist$pct) / sum(dist$pct) * 100
  used <- dist$pct > 0
  first <- which(used)[1]
  bins <- data.frame(pct=c(0, cum[used]), score=c(dist$lo[first], dist$hi[used]),
                     source="bin")
  bins$pct[nrow(bins)] <- 100
  near_knot <- vapply(bins$pct, function(p) any(abs(p - knots_pct) < 1e-9), logical(1))
  pts <- rbind(bins[!near_knot, ],
               data.frame(pct=knots_pct, score=knots_val, source=rep("knot", length(knots_pct))))
  pts <- pts[order(pts$pct), ]
  rownames(pts) <- NULL
  if (any(diff(pts$pct) <= 0) || any(diff(pts$score) <= 0))
    stop("quantile_points: ", label, " histogram and published percentiles are not ",
         "jointly increasing; check tables/sim-distribution.csv against sim-quantiles.csv",
         call.=FALSE)
  pts
}

## Quantile function through points that span the whole distribution (pct
## from 0 to 100, as quantile_points returns): a monotone cubic
## (Fritsch-Carlson) spline, which has a continuous slope everywhere, so the
## curve has no corners. No tails are needed because the points reach the
## ends of the scale.
make_quantile_fn <- function(pct, vals) {
  o <- order(pct); pct <- pct[o]; vals <- vals[o]
  if (pct[1] != 0 || pct[length(pct)] != 100)
    stop("make_quantile_fn: points must run from 0 to 100 percent (use quantile_points)")
  if (any(diff(pct) <= 0) || any(diff(vals) <= 0))
    stop("make_quantile_fn: points must strictly increase")
  inner <- splinefun(pct, vals, method="monoH.FC")
  function(u) inner(pmin(pmax(u, 0), 100))
}

## Weighted quantile, midpoint convention. The midpoint removes the half-bin
## bias a step lookup carries, which matters here because the two mixture
## components interleave and the crossing can fall between grid atoms.
## Atoms carrying negligible weight are dropped rather than kept: at a budget
## near full coverage the untreated weight (1 - pi) goes to roughly 1e-16, and
## a run of those makes the cumulative weight tie in floating point, which
## approx() would warn about and silently collapse.
weighted_quantile <- function(v, w, probs) {
  keep <- w > 1e-12
  v <- v[keep]; w <- w[keep]
  o <- order(v); v <- v[o]; w <- w[o]
  cw <- (cumsum(w) - 0.5 * w) / sum(w)
  approx(cw, v, xout = probs/100, rule = 2)$y
}

## Post-program quantiles at `probs` under participation rule `pifn` and seat
## budget `B`. Qfn is the pre-program quantile function, delta the treated
## effect in score points.
program_quantiles <- function(Qfn, pifn, B, delta, probs) {
  u  <- RANK_GRID
  x  <- Qfn(u)
  pr <- pmin(1, pmax(0, pifn(u, B)))
  weighted_quantile(c(x, x + delta), c(1 - pr, pr), probs)
}

## The same thing, anchored so that a zero budget reproduces the published
## percentiles exactly.
##
## Reading the untreated population off RANK_GRID recovers the knots to about
## 0.01 points at the default step, an artifact of grid resolution that
## shrinks linearly as the grid refines. Every quantity reported from this
## model is a change from the no-program baseline, so pinning that baseline to
## the published percentiles removes the artifact from every comparison rather
## than letting a systematic 0.01 ride along in each one. Returns a function
## of (participation rule, budget).
calibrated_program_quantiles <- function(Qfn, delta, probs, published) {
  no_program <- function(p, B) rep(0, length(p))
  offset <- published - program_quantiles(Qfn, no_program, 0, delta, probs)
  function(pifn, B) program_quantiles(Qfn, pifn, B, delta, probs) + offset
}
