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
##      B, so no rule may quietly spend more or less than another. The one
##      deliberate exception is the eligibility screen, which cannot seat more
##      students than are eligible: it spends min(B, ED share) and leaves the
##      rest of the budget unused (see make_ed_screen).
##   2. Range. Participation is a rate, so it stays within [0, 1].
##
## Both bugs found in September 2026 were violations of one of these: the
## since-removed observed opt-in rule returned participation above 100 percent
## at high budgets, and the first, water-filled eligibility screen (retired
## 2026-09-29) capped correctly but then under-spent its budget. The screen
## that replaced it under-spends on purpose, since it seats only eligible
## students; that is a definition, not a bug, and it is tested separately.

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
## and quietly loses those seats: applied to the retired water-filled
## eligibility screen at B = 1 it spent only 84 percent of the budget. Today
## only the opt-in gradient needs it, above geom_saturation(). Solved on FILL_GRID so the answer does
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

## ---------------------------------------------------------------------------
## Eligibility screen: seats go only to economically disadvantaged (ED)
## students, at random among them.
##
## The ingredient is s(p), the ED share of students at national percentile p.
## It comes straight from the published score distributions: in each 10-point
## bin b, s_b = pop_ED * pct_ED,b / pct_TOTAL,b (the ED students in the bin
## over all students in it). Each bin's share is placed at the national rank
## of the bin's midpoint and interpolated linearly between midpoints, flat
## beyond the outermost ones. No tail and no invented knots. On 2026-09-29 the
## curve averaged to within 0.0005 of pop_ED in every cell, which is how close
## the screen comes to spending min(B, pop_ED) exactly.
##
## Replaced make_ed_curve (2026-09-29), a four-point line through the ED
## share of everyone below p10 and below p25, which are tail averages, not
## shares AT p10 and p25, with made-up anchors at p50 and p90.
##
## dist and edist are the rows of tables/sim-distribution.csv and
## tables/sim-distribution-econdis.csv. `year` should be the year the program
## acts on, 2024: the screen seats 2024 students, so it is their ED share at
## each 2024 percentile that matters. Returns list(pct, share, pop).
ed_share_points <- function(dist, edist, cell, year) {
  t <- dist[dist$cell == cell & dist$year == year, ]
  e <- edist[edist$cell == cell & edist$year == year & grepl("^Econ", edist$group), ]
  if (!nrow(t) || !nrow(e))
    stop("no score distribution for '", cell, "' ", year, " in ",
         if (!nrow(t)) "sim-distribution.csv" else "sim-distribution-econdis.csv",
         ". The eligibility screen needs both; run analysis/01-simulations.R.",
         call.=FALSE)
  t <- t[order(t$bin), ]; e <- e[order(e$bin), ]
  if (!identical(t$bin, e$bin))
    stop("ed_share_points: ", cell, " ", year, " national and ED bins differ", call.=FALSE)
  pop  <- e$pop_share[1]
  cum  <- cumsum(t$pct) / sum(t$pct) * 100
  mid  <- (c(0, head(cum, -1)) + cum) / 2
  keep <- t$pct > 0
  ## Clamp: in the handful of extreme bins holding under 0.003 percent of
  ## students, rounding in the published percentages can put s a hair above 1.
  share <- pmin(1, pmax(0, pop * e$pct[keep] / t$pct[keep]))
  list(pct=mid[keep], share=share, pop=pop)
}

## The screen as an allocation rule. With budget B the ED treatment rate is
## r = min(1, B / pop_ED), and participation at percentile p is r * s(p):
## exactly what random assignment among ED students produces at each score.
## Seats beyond pop_ED have no eligible taker and go unused. The rule is a
## pure function of (p, B), like the others; `pop` is attached so callers can
## report the unused seats without reaching back into the data.
make_ed_screen <- function(pts) {
  rule <- function(p, B)
    min(1, B / pts$pop) * approx(pts$pct, pts$share, xout=p, rule=2)$y
  attr(rule, "pop") <- pts$pop
  rule
}
