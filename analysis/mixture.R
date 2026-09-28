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
## tracks a student. For Reading G4 the difference is 1.17 points under
## proportional allocation at half coverage, where the group answer is exactly
## no change and the distributional answer is a wider gap. Under bottom-up
## allocation at 10 percent of seats the group answer is 2.69 and the
## distributional answer is 5.96, because the treated bottom decile leapfrogs
## the untreated students above it and the percentile refills from behind.
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
## over it is a population mean. The exact endpoints are excluded because a
## normal tail is unbounded there.
RANK_GRID <- seq(0.01, 99.99, by=0.01)

## Quantile function rebuilt from published percentile knots: monotone
## interpolation between them, normal tails outside, matched at the boundary
## knots so the function is continuous. The tails carry no reported quantity.
## They exist so that the mixture bookkeeping has somewhere to put students who
## move past the top knot or start below the bottom one.
make_quantile_fn <- function(pct, vals) {
  o <- order(pct); pct <- pct[o]; vals <- vals[o]
  if (any(diff(vals) <= 0)) stop("make_quantile_fn: knots must increase")
  inner <- splinefun(pct, vals, method="monoH.FC")
  lo_p <- pct[1]; hi_p <- pct[length(pct)]
  lo_v <- vals[1]; hi_v <- vals[length(vals)]
  sig  <- (hi_v - lo_v) / (qnorm(hi_p/100) - qnorm(lo_p/100))
  function(u) {
    u <- pmin(pmax(u, 1e-6), 100 - 1e-6)
    ifelse(u < lo_p, lo_v + (qnorm(u/100) - qnorm(lo_p/100)) * sig,
    ifelse(u > hi_p, hi_v + (qnorm(u/100) - qnorm(hi_p/100)) * sig,
           inner(u)))
  }
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
## 0.008 points at the default step, an artifact of grid resolution that
## shrinks linearly as the grid refines. Every quantity reported from this
## model is a change from the no-program baseline, so pinning that baseline to
## the published percentiles removes the artifact from every comparison rather
## than letting a systematic 0.008 ride along in each one. Returns a function
## of (participation rule, budget).
calibrated_program_quantiles <- function(Qfn, delta, probs, published) {
  no_program <- function(p, B) rep(0, length(p))
  offset <- published - program_quantiles(Qfn, no_program, 0, delta, probs)
  function(pifn, B) program_quantiles(Qfn, pifn, B, delta, probs) + offset
}
