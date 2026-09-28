## Seat-allocation rules for the simulations, held apart from analysis/06-seat-allocation.R
## so that tests can load them without triggering that script's figure and CSV
## writes.
##
## Every rule has the signature alloc(p, B) and returns the participation rate
## at percentile p given a seat budget B expressed as a share of ALL students.
## Two properties make the rules comparable at equal cost, and both are
## asserted in analysis/tests/test-sim.R:
##
##   1. Budget conservation. Mean participation across the distribution equals
##      B, so no rule may quietly spend more or less than another.
##   2. Range. Participation is a rate, so it stays within [0, 1].
##
## Both bugs found in September 2026 were violations of one of these: the
## since-removed observed opt-in rule returned participation above 100 percent
## at high budgets, and the eligibility screen capped correctly but then
## under-spent its budget.

## Grid on which the budget constraint is enforced for rules with no closed
## form. Fine enough not to matter at the reported percentiles: against a much
## finer step the largest participation difference is under 1e-3, which is
## 0.005 NAEP points.
##
## These are bin midpoints, not endpoints. A grid running 0, 0.25, ..., 100
## would carry both p=0 and p=100, each of which has measure zero in the
## continuum but a full share of the weight on the grid. That biases the mean
## for any rule with a step in it: bottom-up would treat the single point p=0
## even at a budget of zero, and its mean participation would overshoot the
## budget by half a bin at every level. Midpoints make the discrete mean an
## unbiased midpoint-rule estimate of the continuous one.
FILL_GRID <- seq(0.125, 99.875, by=0.25)

## Bottom-up: fill from the lowest scorer upward until seats run out. With
## budget B, everyone below the Bth percentile is treated and nobody above.
## The round() guards against floating-point error in a seq()-generated
## budget, which can leave B*100 a hair below an integer percentile and drop
## that percentile out of the treated set.
alloc_bottom <- function(p, B) as.numeric(p <= round(B*100, 9))

## Proportional: every percentile gets the same rate. The untargeted offer.
alloc_uniform <- function(p, B) rep(B, length(p))

## ---------------------------------------------------------------------------
## Opt-in gradient
##
## Voluntary take-up rising with achievement. The shape is stylized, not an
## estimate of any one program; its empirical motivation is the roughly 2:1
## take-up contrast Robinson, Bisht and Loeb (2025) report between students
## who passed all fall 2020 courses and students who received a D or F, when
## both groups were offered the same tutoring platform.
##
## The anchors below are a stylized shape, not those take-up rates: the config
## used to carry them (optin_takeup: 0.116 struggling, 0.227 passing) but no
## script read them, and GEOM_LO = 0.10 with an exact doubling is not derived
## from them. Only the shape matters (see below), so wiring 0.116/0.227 in
## would change results rather than document them. The key was removed.
##
## Anchored at three points: 10 percent take-up at p10, doubling to 20 percent
## at p50, doubling again to 40 percent at p90. A constant doubling distance
## implies constant proportional growth per percentile point, i.e. an
## exponential, not a line -- a line through the same three points would need
## two different slopes (0.25 pts/percentile below p50, 0.50 above) and would
## carry an unmotivated kink at p50. The exponential has none: it is smooth
## everywhere and its growth RATE, not its growth amount, is what is constant.
##
## GEOM_SPAN is the percentile distance over which the rate doubles once; two
## spans (here, p10-to-p50 and p50-to-p90) take the rate from GEOM_LO to
## 4*GEOM_LO. Only the shape matters, not the level: water_fill allocates in
## proportion to the shape, so rescaling all three anchors together leaves
## participation unchanged.
GEOM_LO   <- 0.10   # take-up at p10
GEOM_SPAN <- 40     # percentile points per doubling
## Take-up at p90 is DERIVED, not free: the ramp spans 80 percentile points,
## which is 80/GEOM_SPAN doublings. Storing it as an independent constant
## would let a sensitivity run change GEOM_SPAN and leave geom_saturation()
## silently computing against the stale top rate.
GEOM_HI   <- GEOM_LO * 2^(80/GEOM_SPAN)

## Raw take-up shape. Flat below p10 and above p90: nothing in the doubling
## relationship was anchored outside [p10, p90], so nothing licenses
## extrapolating it there. clamp() keeps the exponent bounded so the flat
## regions are exact, not merely close.
##
## Named geomtakeup_line, not geom_line: this file is sourced alongside
## ggplot2 (analysis/06-seat-allocation.R, analysis/02-figures.R), and
## ggplot2::geom_line is a function every one of those scripts calls. A local
## geom_line() masks it silently -- no error until a geom_line(...) call sites
## further down the script resolves to this file's definition instead and
## fails on an argument ggplot2 would have accepted.
geomtakeup_line <- function(p) {
  e <- pmin(90, pmax(10, p))
  GEOM_LO * 2^((e - 10) / GEOM_SPAN)
}

## geomtakeup_line is not symmetric about p50 (2^x is convex), so its mean is
## not just the midpoint value. GEOM_GRID is fine enough that the mean is
## stable to well under the 1e-3-participation / 0.005-NAEP-point tolerance
## FILL_GRID was built to hit elsewhere in this file; reusing FILL_GRID
## directly would tie this rule's precision to a grid sized for the
## piecewise-linear shapes the other rules use.
GEOM_GRID <- seq(0.05, 99.95, by = 0.1)
geomtakeup_mean <- function() mean(geomtakeup_line(GEOM_GRID))

## Water-fill the raw shape. No explicit rescaling to the budget is needed:
## water_fill is scale-invariant in its shape function (it allocates seats in
## proportion to w/sum(w)), so below saturation the result is identical to
## dividing by geomtakeup_mean() first, and above saturation the fill handles
## the cap. Saturation arrives at B = mean/peak; see geom_saturation() below
## rather than hand-computing it.
alloc_optin_geom <- function(p, B) water_fill(geomtakeup_line, p, B)

## Budget at which the rescaled curve first touches 100 percent at its peak,
## p90. Exposed so callers (and the tests) can check where the water-filling
## in alloc_optin_geom starts to matter instead of hand-copying the threshold.
## Reads the curve itself rather than GEOM_HI so a sensitivity run that
## reassigns GEOM_SPAN after sourcing still gets the right threshold.
geom_saturation <- function() geomtakeup_mean() / geomtakeup_line(90)

## ---------------------------------------------------------------------------
## Water-filling, the general way to respect the cap without losing seats.
##
## Scale the shape to the budget, cap whatever exceeds 100 percent, hand the
## freed seats back to the percentiles still under the cap in proportion to
## their share of the shape, and repeat. Naive clipping skips the hand-back
## and quietly loses those seats: applied to the eligibility screen at B = 1 it
## spent only 84 percent of the budget. Solved on FILL_GRID so the answer does
## not depend on which percentiles the caller happens to ask about.
water_fill <- function(shape_fn, p, B) {
  w     <- shape_fn(FILL_GRID)
  part  <- rep(0, length(w))
  free  <- rep(TRUE, length(w))
  seats <- B * length(w)
  repeat {
    if (!any(free) || seats <= 0 || sum(w[free]) <= 0) break
    part[free] <- seats * w[free] / sum(w[free])
    over <- free & part > 1
    if (!any(over)) break
    part[over] <- 1
    seats <- seats - sum(over)
    free[over] <- FALSE
  }
  approx(FILL_GRID, pmin(1, part), xout=p, rule=2)$y
}

## Eligibility screen: seats go only to economically disadvantaged students,
## who are about 51 percent of students but 83 percent of the bottom decile.
##
## Returns a closure so the knots are read once and the resulting shape is a
## pure function of p, which is what makes it testable in isolation. It stops
## rather than falling back to a flat shape: a flat shape water-fills to
## uniform participation, which would draw the screen as an exact copy of the
## proportional curve while still carrying its own label and color. That
## failure is reachable, because 01-simulations.R skips a cell whose
## decomposition is unavailable, so a cell can appear in sim-quantiles.csv and
## be absent from sim-bottom-decile.csv.
make_ed_curve <- function(bd, cell) {
  e   <- bd[bd$cell==cell & grepl("^Econ", bd$group) & bd$year==2019,]
  d10 <- e$share_of_tail[e$target_pct==10]
  if (!length(d10))
    stop("no ECONDIS rows for cell '", cell, "' in sim-bottom-decile.csv. ",
         "The eligibility-screen rule would degrade into the proportional ",
         "rule while keeping its own label, so refusing to run.", call.=FALSE)
  d25 <- e$share_of_tail[e$target_pct==25]
  pop <- e$pop_share[e$target_pct==10]
  ## ED share falls as we move up, crossing the population share at p50 and
  ## continuing down to 2*pop-d25 at p90.
  knots_y <- c(d10, d25, pop, max(0.05, 2*pop - d25))
  function(p) approx(x=c(10,25,50,90), y=knots_y, xout=p, rule=2)$y
}
