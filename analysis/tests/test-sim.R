#!/usr/bin/env Rscript
## Tests for the simulation pipeline. Run: Rscript analysis/tests/test-sim.R
##
## These run against the committed CSV outputs, so they need no network and no
## restricted data. They are the checks that would catch a silent regression.

source("analysis/dist-helpers.R")
source("analysis/config-helpers.R")
cfg <- load_sim_config()
## Treated effect for the group-gap and mixture checks below: the config's
## treated_effect, the same value 06-seat-allocation.R applies.
G_TREAT <- cfg_treated_g(cfg)

fails <- 0
ok <- function(cond, msg) {
  if (isTRUE(cond)) cat("  PASS  ", msg, "\n")
  else { cat("  FAIL  ", msg, "\n"); fails <<- fails + 1 }
}

qd_path <- "tables/sim-quantiles.csv"
bd_path <- "tables/sim-bottom-decile.csv"
if (!file.exists(qd_path)) stop("Run analysis/01-simulations.R first.")
qd <- read.csv(qd_path, stringsAsFactors=FALSE)
bd <- if (file.exists(bd_path)) read.csv(bd_path, stringsAsFactors=FALSE) else NULL

cat("\n1. Validation against the companion article's restricted-use analysis\n")
## The single most important test: public data must reproduce Table 2 col (a).
## If NCES revises, or a subscale/jurisdiction is wrong, this breaks first.
## Targets are read from the config, the one place they are declared. The
## config is under version control, so a target edit shows up in the diff
## rather than hiding in a second copy here.
table2a <- cfg_table2a(cfg)
ok(length(table2a) == 6, "the config declares Table 2(a) targets for all six cells")
for (cell in names(table2a)) {
  got <- unique(qd$diff_change[qd$cell == cell])
  ok(length(got) == 1 && abs(got - table2a[[cell]]) < 0.05,
     sprintf("%-12s differential change %.2f matches Table 2(a) %.1f",
             cell, if (length(got)) got[1] else NA, table2a[[cell]]))
}

cat("\n2. Internal consistency\n")
## g_star and d are written from the same computation in the same row of the
## same CSV (the data.frame 01-simulations.R builds for sim-quantiles.csv), so
## this cannot catch a wrong S or a wrong sign convention -- only file-level
## corruption (e.g. a column shift from a read.csv/write.csv mismatch). Kept
## as a cheap smoke test, not billed as validating the formula.
ok(all(abs((qd$g_star + qd$d / qd$sd2019)) < 1e-9),
   "g*(p) and d/sd2019 are consistent within the CSV (smoke test, not a formula check)")
dc <- by(qd, qd$cell, function(z) {
  a <- z$d[z$percentile == 90]; b <- z$d[z$percentile == 10]
  abs((a - b) - z$diff_change[1])
})
ok(all(unlist(dc) < 1e-9), "diff_change == D(p90) - D(p10) for every cell")
ok(all(qd$d_se > 0 & qd$d_se < 2.5), "quantile-difference SEs are positive and plausible")
ok(all(qd$sd2019 > 20 & qd$sd2019 < 60), "2019 SDs are on a plausible NAEP scale")

cat("\n2b. group_cdf: the only distributional assumption in the pipeline\n")
## Unit tests for the tail-extrapolation function, independent of the API and
## of the committed CSVs. Not previously covered at all, despite being the
## place a tied-knot input (I3) or an out-of-range cut (I2) would fail.
pc <- c("10"=150, "25"=180, "50"=210, "75"=240, "90"=265)
ok(abs(group_cdf(pc, 180) - 0.25) < 1e-12, "group_cdf returns the knot percentile at a knot")
gm <- group_cdf(pc, 195)
ok(gm > 0.25 && gm < 0.50, "group_cdf interpolates between knots")
ok(group_cdf(pc, 100) < 0.10, "group_cdf's left-tail extrapolation is below P10 at a point below P10")
ok(is.finite(group_cdf(pc, 150)), "group_cdf returns a finite value at the lower knot")
ok(inherits(tryCatch(group_cdf(pc, 300), error=function(e) e), "error"),
   "group_cdf errors (rather than silently returning 1) above the top knot")
tied <- c("10"=150, "25"=150, "50"=210, "75"=240, "90"=265)
ok(inherits(tryCatch(group_cdf(tied, 150), error=function(e) e), "error"),
   "group_cdf errors (rather than returning NaN) on tied percentile knots")

cat("\n3. Monotonicity of the quantile function\n")
mono <- by(qd, qd$cell, function(z) {
  z <- z[order(z$percentile), ]; all(diff(z$q2019) > 0)
})
ok(all(unlist(mono)), "2019 quantiles increase with percentile in every cell")

cat("\n4. Bottom-decile decomposition\n")
if (!is.null(bd)) {
  ## The reconstructed mass should land near the definitional target for
  ## whichever cut is being decomposed (0.10 for the decile, 0.25 for the
  ## quartile). This is an internal consistency check, not a validation of
  ## the tail model -- see the note in 01-simulations.R.
  for (q in unique(bd$target_pct)) {
    z <- bd[bd$target_pct == q, ]
    ok(all(abs(z$reconstructed_mass - q/100) < 0.015),
       sprintf("reconstructed mass for the bottom %d%% is within 0.015 of %.2f",
               q, q/100))
  }
  s <- aggregate(share_of_tail ~ cell + year + target_pct, bd, sum)
  ok(all(abs(s$share_of_tail - 1) < 1e-6),
     "shares of the target group sum to 1 within each cell-year-target")
  ps <- aggregate(pop_share ~ cell + year + target_pct, bd, sum)
  ok(all(abs(ps$pop_share - 1) < 0.005),
     "population shares sum to 1 within each cell-year-target")
  ## p25 is a broader target, so economic disadvantage is necessarily a
  ## smaller share of it than of the bottom decile.
  w <- merge(bd[bd$target_pct==10 & grepl("^Econ",bd$group), c("cell","year","share_of_tail")],
             bd[bd$target_pct==25 & grepl("^Econ",bd$group), c("cell","year","share_of_tail")],
             by=c("cell","year"), suffixes=c("_10","_25"))
  ok(nrow(w) > 0 && all(w$share_of_tail_10 > w$share_of_tail_25),
     "ED share of the bottom decile exceeds its share of the bottom quartile")
  ed <- bd[grepl("^Econ", bd$group), ]
  ok(all(ed$share_of_tail > ed$pop_share),
     "economically disadvantaged are over-represented in the bottom decile everywhere")
  ok(all(bd$p_below_cut >= 0 & bd$p_below_cut <= 1),
     "P(below cut) is a probability in every row")
} else cat("  SKIP  no bottom-decile CSV\n")

cat("\n5. Coverage-by-percentile grid\n")
## The gradient the memo reports: at a given coverage, the required effect must
## fall monotonically as the percentile rises, and halving coverage must double
## the requirement. These are arithmetic identities, so a failure means the
## grid was built wrong rather than that the data changed.
## Grades 4 and 8 decline monotonically across the distribution. The grade 12
## cells do NOT, and that is a substantive finding rather than a defect: their
## losses are flat across the lower half, so Math G12 requires slightly more at
## p25 than at p10. Assert the pattern only where it holds, and assert the
## exception explicitly so a future change to either would be caught.
for (cc in unique(qd$cell)) {
  z <- qd[qd$cell == cc, ]
  z <- z[order(z$percentile), ]
  if (grepl("G12", cc)) {
    ok(z$g_star[z$percentile==10] > z$g_star[z$percentile==90],
       sprintf("%-12s still requires more at p10 than p90 (non-monotonic in between)", cc))
  } else {
    ok(all(diff(z$g_star) < 0),
       sprintf("%-12s requirement falls monotonically from p10 to p90", cc))
  }
}
zm <- qd[qd$cell == "Math G12", ]
ok(zm$g_star[zm$percentile==25] > zm$g_star[zm$percentile==10],
   "Math G12 requires MORE at p25 than p10 (flat loss across the lower half)")
g10 <- qd$g_star[qd$cell == "Reading G4" & qd$percentile == 10]
ok(abs((g10/0.5) - 2*g10) < 1e-12,
   "halving coverage exactly doubles the required effect")

cat("\n6. Direction of the headline result\n")
p10 <- qd[qd$percentile == 10, ]; p90 <- qd[qd$percentile == 90, ]
m <- merge(p10, p90, by="cell", suffixes=c("_10","_90"))
ok(all(m$g_star_10 > m$g_star_90),
   "restoring p10 requires more than restoring p90 in every cell")
ok(all(qd$d < 0), "every quantile declined 2019 to 2024")

cat("\n7. R / Stata cross-validation\n")
## The .do file is an INDEPENDENT implementation of Tables A and B only (the
## quantile differences and g* = -D/S), so agreement there is real evidence
## against a coding error in either one. It does NOT cover the participation
## adjustment, the benchmarked-program shares, or the ECONDIS bottom-decile
## decomposition -- those have a single implementation, in R. Nothing checked
## even this narrower claim automatically before, so it rested on a comparison
## someone ran by hand once.
## Note the label convention differs by design: Stata writes "Reading_G4"
## because spaces are awkward in its locals, R writes "Reading G4". Normalize
## before joining rather than changing either script's output format.
st_path <- "tables/sim-quantiles-stata.csv"
if (file.exists(st_path)) {
  st <- read.csv(st_path, stringsAsFactors=FALSE)
  names(st)[names(st) == "pct"] <- "percentile"
  st$cell <- gsub("_", " ", st$cell)
  shared <- c("q2019","d","d_se","g_star","g_star_se","sd2019","sd2024","diff_change")
  m <- merge(qd[, c("cell","percentile",shared)],
             st[, c("cell","percentile",shared)],
             by=c("cell","percentile"), suffixes=c(".r",".s"))
  ok(nrow(m) == nrow(qd),
     sprintf("every R row (%d) has a Stata counterpart (%d matched)", nrow(qd), nrow(m)))
  if (nrow(m) > 0) {
    ## 1e-6 is far looser than the ~1e-14 actually observed, but it is the
    ## tolerance that matters: anything below it cannot move a published
    ## figure, which is quoted to three decimals at most.
    for (v in shared) {
      dmax <- max(abs(m[[paste0(v,".r")]] - m[[paste0(v,".s")]]), na.rm=TRUE)
      ok(is.finite(dmax) && dmax < 1e-6,
         sprintf("%-13s agrees between R and Stata (max diff %.1e)", v, dmax))
    }
  }
} else cat("  SKIP  no Stata output CSV\n")

cat("\n8. Seat-allocation rules (analysis/alloc-rules.R)\n")
## Nothing above this point touches the allocation rules. Both bugs found in
## September 2026 were violations of the two invariants asserted here: the
## since-removed observed opt-in rule returned participation above 100 percent
## at high budgets, and the eligibility screen capped correctly but then
## under-spent its budget.
source("analysis/alloc-rules.R")

ed_ok <- !is.null(bd) && nrow(bd[bd$cell=="Reading G4" & grepl("^Econ", bd$group) &
                                bd$year==2019, ]) > 0
rules <- list("bottom-up"=alloc_bottom, "proportional"=alloc_uniform,
              "opt-in"=alloc_optin_geom)
if (ed_ok) {
  edc <- make_ed_curve(bd, "Reading G4")
  rules[["screen"]] <- function(p, B) water_fill(edc, p, B)
}
Bs <- seq(0, 1, by=0.01)

## 1. Budget conservation. The invariant that makes the rules comparable at
##    equal cost, and the one both September 2026 bugs broke.
##
##    All rules hold to machine precision: every capped rule water-fills,
##    which conserves the budget exactly. (The since-removed observed opt-in
##    rule needed a looser tolerance while it used a closed-form reflected
##    cap, whose plateau edge fell between bin midpoints.)
for (rn in names(rules)) {
  err <- max(sapply(Bs, function(B) abs(mean(rules[[rn]](FILL_GRID, B)) - B)))
  ok(err < 1e-9, sprintf("%-12s mean participation equals the budget (max error %.2g)",
                         rn, err))
}

## 2. Range. Participation is a rate. This is the class of bug fixed twice.
for (rn in names(rules)) {
  v <- unlist(lapply(Bs, function(B) rules[[rn]](FILL_GRID, B)))
  ok(all(v >= -1e-12 & v <= 1 + 1e-12),
     sprintf("%-12s participation stays within [0, 1] (observed %.3f to %.3f)",
             rn, min(v), max(v)))
}

## 3. Endpoints. At B = 1 every student holds a seat, so every rule must treat
##    everyone and therefore leave the spread exactly where it started. At
##    B = 0 nobody is treated. The memo states the B = 1 collapse as a result;
##    assert it rather than trusting the transcription.
for (rn in names(rules)) {
  ok(all(abs(rules[[rn]](FILL_GRID, 1) - 1) < 1e-9) &&
     all(abs(rules[[rn]](FILL_GRID, 0)) < 1e-9),
     sprintf("%-12s treats everyone at B=1 and nobody at B=0", rn))
}

## 4. Monotone in the budget: no percentile may lose ground when seats are
##    added. Catches a future cap-handling change that redistributes wrongly.
for (rn in names(rules)) {
  m <- sapply(seq(0, 1, by=0.02), function(B) rules[[rn]](c(10,25,50,75,90), B))
  ok(all(apply(m, 1, function(r) all(diff(r) >= -1e-9))),
     sprintf("%-12s participation is non-decreasing in the budget at every percentile", rn))
}

## 5. The proportional identity, which is real but belongs to ONE of the two
##    estimands. Read as a group question, treating every percentile at the
##    same rate leaves the distance between the p10 and p90 groups exactly
##    where it was, because both groups gain the same pi*delta on average.
##    That is what is asserted here, and the arithmetic below is the
##    group-tracking calculation. Section 9 asserts the opposite for the
##    DISTRIBUTIONAL estimand, where the same program widens the gap by 1.2
##    points at half coverage. Both are correct and they are not in conflict:
##    a group mean and a percentile position are different quantities. See
##    analysis/06-seat-allocation.R for the two residual functions.
zr <- qd[qd$cell=="Reading G4", ]; zr <- zr[order(zr$percentile), ]
defr <- setNames(-zr$d, zr$percentile); Sr <- zr$sd2019[1]
spread <- function(fn, B) {
  r <- defr - fn(zr$percentile, B) * G_TREAT * Sr
  -(r[["90"]] - r[["10"]])
}
base <- -(defr[["90"]] - defr[["10"]])
ok(max(sapply(Bs, function(B) abs(spread(alloc_uniform, B) - base))) < 1e-9,
   "proportional allocation leaves the 90-10 GROUP gap unchanged at every budget")
ok(max(sapply(names(rules), function(rn) abs(spread(rules[[rn]], 1) - base))) < 1e-6,
   "every rule returns the no-program group gap at full coverage")

## 6. Opt-in gradient (analysis/alloc-rules.R): anchor values, saturation
##    threshold, and continuity across it. Below the saturation threshold
##    nothing is capped, so the rule must reduce to the plain rescaled
##    take-up curve. Every budget the memo reports sits in this region, which
##    is why the choice of cap convention does not reach any published number.
ok(isTRUE(all.equal(geomtakeup_line(c(10,50,90)), c(GEOM_LO, GEOM_LO*2, GEOM_LO*4))),
   "geomtakeup_line doubles from p10 to p50 and again from p50 to p90")
ok(abs(geomtakeup_line(5) - GEOM_LO) < 1e-12 && abs(geomtakeup_line(95) - GEOM_HI) < 1e-12,
   "geomtakeup_line is flat outside [p10, p90]")
sat <- geom_saturation()
plain_geom <- function(p, B) geomtakeup_line(p) * B / geomtakeup_mean()
## Tolerance is 1e-4 rather than machine precision: geomtakeup_line is
## curved, so linear interpolation between FILL_GRID midpoints carries real
## (if tiny) curvature error -- still far inside the 0.005-NAEP-point
## tolerance FILL_GRID was sized for. (Piecewise-linear shapes interpolate
## exactly between knots and get 1e-9 elsewhere in this file.)
ok(max(sapply(c(0.05,0.13,0.25,sat*0.9),
              function(B) max(abs(alloc_optin_geom(FILL_GRID,B) - plain_geom(FILL_GRID,B))))) < 1e-4,
   "below saturation alloc_optin_geom is within grid tolerance of the rescaled geometric line")
ok(max(abs(alloc_optin_geom(FILL_GRID, sat-1e-6) - alloc_optin_geom(FILL_GRID, sat+1e-6))) < 1e-3,
   "alloc_optin_geom is continuous in the budget across the saturation threshold")

## 7. Grid independence for the water-filled rule.
if (ed_ok) {
  fine <- local({
    FILL_GRID <- seq(0, 100, by=0.01)
    sapply(c(0.25,0.5,0.9), function(B) water_fill(edc, c(10,25,50,75,90), B))
  })
  coarse <- sapply(c(0.25,0.5,0.9), function(B) water_fill(edc, c(10,25,50,75,90), B))
  ok(max(abs(fine - coarse)) < 1e-3,
     sprintf("water_fill is insensitive to the grid step (max difference %.1e)",
             max(abs(fine - coarse))))
}

## 8. The regression test for the silent-degradation bug: a cell with no
##    ECONDIS rows must error, not quietly become the proportional rule.
ok(inherits(tryCatch(make_ed_curve(bd, "No Such Cell"), error=function(e) e), "error"),
   "make_ed_curve errors on a cell with no ECONDIS rows rather than falling back")

cat("\n9. Mixture outcome model (analysis/mixture.R)\n")
## The model that replaced the linear shift. What is asserted here is that the
## reconstruction is faithful, that the mixture reduces to the cases where the
## right answer is known independently, and that the grid does not drive it.
source("analysis/mixture.R")

zr <- qd[qd$cell=="Reading G4", ]; zr <- zr[order(zr$percentile), ]
PSr <- zr$percentile; q24 <- zr$q2019 + zr$d
Sr <- zr$sd2019[1]; deltar <- G_TREAT * Sr
Qr <- make_quantile_fn(PSr, q24)
none <- function(p, B) rep(0, length(p))
all1 <- function(p, B) rep(1, length(p))
afterr <- calibrated_program_quantiles(Qr, deltar, PSr, q24)

## 1. The reconstruction passes through the published percentiles. Uncalibrated
##    it is out by about 0.008 points, a grid artifact; calibrated it is exact,
##    which is what every reported change is measured against.
raw <- program_quantiles(Qr, none, 0, deltar, PSr)
ok(max(abs(raw - q24)) < 0.02,
   sprintf("uncalibrated reconstruction recovers the published knots (max %.4f pts)",
           max(abs(raw - q24))))
ok(max(abs(afterr(none, 0) - q24)) < 1e-9,
   "calibrated no-program baseline reproduces the published percentiles exactly")

## 2. Universal coverage is the one case with a known closed form: if everyone
##    is treated, every quantile moves by exactly delta and the spread cannot
##    change. This is the check the linear model also passed, kept so the
##    rebuild cannot lose it.
ok(max(abs(afterr(all1, 1) - (q24 + deltar))) < 1e-9,
   "at full coverage every percentile shifts by exactly the treated effect")
base_spread <- zr$q2019[PSr==90] - zr$q2019[PSr==10]
gap_after <- function(fn, B) {
  a <- afterr(fn, B); (a[PSr==90] - a[PSr==10]) - base_spread
}
obs_gap <- (q24[PSr==90] - q24[PSr==10]) - base_spread
source("analysis/alloc-rules.R")
edc2 <- make_ed_curve(bd, "Reading G4")
rules2 <- list("bottom-up"=alloc_bottom, "proportional"=alloc_uniform,
               "opt-in"=alloc_optin_geom,
               "screen"=function(p,B) water_fill(edc2,p,B))
ok(max(sapply(rules2, function(f) abs(gap_after(f, 1) - obs_gap))) < 1e-9,
   "every rule returns the no-program gap at full coverage under the mixture")
ok(max(sapply(rules2, function(f) abs(gap_after(f, 0) - obs_gap))) < 1e-9,
   "every rule returns the no-program gap at zero budget")

## 3. The finding that motivated the rebuild: partial coverage spreads the
##    distribution even when every percentile is treated at the same rate, so
##    the proportional rule is NOT the arithmetic identity the linear model
##    made it look like. Asserted so a regression back to the linear shift,
##    which would return exactly obs_gap here, fails loudly.
prop_mid <- gap_after(alloc_uniform, 0.5)
ok(prop_mid > obs_gap + 0.5,
   sprintf("proportional coverage widens the DISTRIBUTIONAL gap at 50 percent (%.2f vs %.2f)",
           prop_mid, obs_gap))

## 4. Bottom-up at a budget equal to the evaluation percentile is the cell the
##    linear model got wrong, by reading a step function at its jump. The
##    mixture must not reproduce the old 2.69.
ok(gap_after(alloc_bottom, 0.10) > 5,
   sprintf("bottom-up at 10 percent of seats gives %.2f, not the linearized 2.69",
           gap_after(alloc_bottom, 0.10)))

## 5. Grid independence. RANK_GRID is a modelling convenience, not a parameter.
coarse <- sapply(c(0.13,0.25,0.5), function(B) gap_after(alloc_optin_geom, B))
fine <- local({
  RANK_GRID <<- seq(0.002, 100-0.002, by=0.002)
  af <- calibrated_program_quantiles(Qr, deltar, PSr, q24)
  v <- sapply(c(0.13,0.25,0.5), function(B) {
    a <- af(alloc_optin_geom, B); (a[PSr==90] - a[PSr==10]) - base_spread })
  RANK_GRID <<- seq(0.01, 99.99, by=0.01); v
})
ok(max(abs(coarse - fine)) < 0.05,
   sprintf("mixture results are insensitive to the rank grid (max %.4f pts)",
           max(abs(coarse - fine))))

## 6. Monotone: a bigger budget cannot leave any percentile lower.
ok(all(sapply(rules2, function(f)
       all(diff(sapply(seq(0,1,by=0.05), function(B) afterr(f,B)[PSr==10])) >= -1e-9))),
   "p10 is non-decreasing in the seat budget under every rule")

cat(sprintf("\n%s: %d failure(s)\n", if (fails == 0) "ALL TESTS PASSED" else "TESTS FAILED", fails))
quit(status = if (fails == 0) 0 else 1)
