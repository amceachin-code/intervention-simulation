#!/usr/bin/env Rscript
## Robustness: how much does the fitted lower tail move the boundary case?
##
## The headline disagreement between the baseline-distribution question and the
## post-intervention-distribution question is bottom-up allocation at 10 percent
## of seats (6.0 versus 2.7 in Reading G4). That number lives below p25, where
## the quantile function is reconstructed from only two published percentiles
## plus a fitted lower tail. analysis/mixture.R fits that tail as a normal with
## sigma taken from the full p10-to-p90 span. This script recomputes the
## bottom-up column under alternative lower-tail specifications and reports how
## far the answer moves. The upper tail and the interior monotone spline are
## held at the baseline specification throughout, so any movement is
## attributable to the lower tail alone.
##
## Tail variants:
##   normal_span   baseline: normal, sigma from the p10-p90 span (mixture.R)
##   normal_local  normal, sigma from the local p10-p25 slope (matches the
##                 left-tail assumption in analysis/dist-helpers.R group_cdf)
##   logistic_span logistic, scale from the p10-p90 span (heavier tail)
##   linear_local  straight-line extension of the p10-p25 segment (thinner,
##                 bounded tail)
##
## Public data only. Usage: Rscript analysis/07-tail-sensitivity.R

source("analysis/mixture.R")

## Bottom-up allocation, restated here rather than sourced from
## analysis/alloc-rules.R so this script has no dependency on the
## bottom-decile CSV that the eligibility screen needs.
alloc_bottom <- function(p, B) as.numeric(p <= round(B * 100, 9))

## Quantile function with a swappable lower tail. Everything at or above the
## bottom knot is identical to make_quantile_fn in analysis/mixture.R; only the
## u < lo_p branch changes with `tail`.
make_quantile_fn_tail <- function(pct, vals, tail = "normal_span") {
  o <- order(pct); pct <- pct[o]; vals <- vals[o]
  if (any(diff(vals) <= 0)) stop("make_quantile_fn_tail: knots must increase")
  inner <- splinefun(pct, vals, method = "monoH.FC")
  lo_p <- pct[1]; hi_p <- pct[length(pct)]
  lo_v <- vals[1]; hi_v <- vals[length(vals)]
  p2_p <- pct[2];  p2_v <- vals[2]
  ## Baseline scale parameters, from the full span (as in mixture.R).
  sig_span <- (hi_v - lo_v) / (qnorm(hi_p / 100) - qnorm(lo_p / 100))
  ## Local alternatives, from the p10-p25 segment only.
  sig_local <- (p2_v - lo_v) / (qnorm(p2_p / 100) - qnorm(lo_p / 100))
  s_logis   <- (hi_v - lo_v) / (qlogis(hi_p / 100) - qlogis(lo_p / 100))
  slope_lin <- (p2_v - lo_v) / (p2_p - lo_p)
  lower <- switch(tail,
    normal_span   = function(u) lo_v + (qnorm(u / 100)  - qnorm(lo_p / 100))  * sig_span,
    normal_local  = function(u) lo_v + (qnorm(u / 100)  - qnorm(lo_p / 100))  * sig_local,
    logistic_span = function(u) lo_v + (qlogis(u / 100) - qlogis(lo_p / 100)) * s_logis,
    linear_local  = function(u) lo_v + (u - lo_p) * slope_lin,
    stop("unknown tail spec: ", tail))
  function(u) {
    u <- pmin(pmax(u, 1e-6), 100 - 1e-6)
    ifelse(u < lo_p, lower(u),
    ifelse(u > hi_p, hi_v + (qnorm(u / 100) - qnorm(hi_p / 100)) * sig_span,
           inner(u)))
  }
}

qd <- read.csv("tables/sim-quantiles.csv", stringsAsFactors = FALSE)
G  <- 0.155  # treated effect in SD, as in analysis/06-seat-allocation.R

CELLS   <- c("Reading G4", "Math G8")
TAILS   <- c("normal_span", "normal_local", "logistic_span", "linear_local")
BUDGETS <- c(0.08, 0.10, 0.13)

rows <- list()
for (cell in CELLS) {
  z  <- qd[qd$cell == cell, ]; z <- z[order(z$percentile), ]
  PS <- z$percentile
  S  <- z$sd2019[1]
  q2024 <- z$q2019 + z$d
  for (tail in TAILS) {
    Qfn      <- make_quantile_fn_tail(PS, q2024, tail)
    after_fn <- calibrated_program_quantiles(Qfn, G * S, PS, q2024)
    for (B in BUDGETS) {
      r   <- setNames(z$q2019 - after_fn(alloc_bottom, B), PS)
      ## Remaining 90-10 gap, post-intervention-distribution question, matching
      ## the memo tables: the p10 residual minus the p90 residual.
      gap <- unname(r["10"] - r["90"])
      rows[[length(rows) + 1]] <- data.frame(
        cell = cell, tail = tail, budget = B, gap = round(gap, 2))
    }
  }
}
out <- do.call(rbind, rows)

## Self-check: the baseline specification must reproduce the memo's numbers
## (Reading G4: 6.0 at 10 percent, 2.7 at 13 percent; Math G8: 4.0 and 0.8)
## before any alternative is worth reading.
chk <- function(cell, B, want) {
  got <- out$gap[out$cell == cell & out$tail == "normal_span" & out$budget == B]
  if (abs(got - want) > 0.05)
    stop("baseline check failed: ", cell, " B=", B, " got ", got, " want ", want)
}
chk("Reading G4", 0.10, 6.0); chk("Reading G4", 0.13, 2.7)
chk("Math G8",    0.10, 4.0); chk("Math G8",    0.13, 0.8)

write.csv(out, "tables/sim-tail-sensitivity.csv", row.names = FALSE)
print(reshape(out, idvar = c("cell", "tail"), timevar = "budget",
              direction = "wide"), row.names = FALSE)
cat("\nWrote tables/sim-tail-sensitivity.csv\n")
