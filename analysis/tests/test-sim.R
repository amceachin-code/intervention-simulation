#!/usr/bin/env Rscript
## Tests for the simulation pipeline. Run: Rscript analysis/tests/test-sim.R
##
## These run against the committed CSV outputs, so they need no network and no
## restricted data. They are the checks that would catch a silent regression.

source("analysis/mixture.R")
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
dd_path <- "tables/sim-distribution.csv"
if (!file.exists(dd_path)) stop("Run analysis/01-simulations.R first (", dd_path, " is missing).")
dd <- read.csv(dd_path, stringsAsFactors=FALSE)
de_path <- "tables/sim-distribution-econdis.csv"
if (!file.exists(de_path)) stop("Run analysis/01-simulations.R first (", de_path, " is missing).")
de <- read.csv(de_path, stringsAsFactors=FALSE)

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

cat("\n2b. quantile_cdf: the inverse behind the ED decomposition and nat_pct\n")
## Replaced the group_cdf unit tests on 2026-09-29, when the five-percentile,
## normal-tail group CDF was retired in favour of each group's own score
## distribution. quantile_cdf inverts a quantile function; check it against
## one with a known inverse and at the ends of the scale.
Qlin <- make_quantile_fn(c(0, 50, 100), c(100, 200, 300))
ok(abs(quantile_cdf(Qlin, 200) - 0.5) < 1e-8, "quantile_cdf inverts at a point the curve passes through")
ok(max(abs(quantile_cdf(Qlin, Qlin(c(3, 37.5, 91))) - c(0.03, 0.375, 0.91))) < 1e-8,
   "quantile_cdf(Q, Q(u)) returns u")
ok(identical(quantile_cdf(Qlin, c(50, 350)), c(0, 1)),
   "quantile_cdf returns 0 and 1 beyond the ends of the scale")

cat("\n3. Monotonicity of the quantile function\n")
mono <- by(qd, qd$cell, function(z) {
  z <- z[order(z$percentile), ]; all(diff(z$q2019) > 0)
})
ok(all(unlist(mono)), "2019 quantiles increase with percentile in every cell")

cat("\n4. Bottom-decile decomposition\n")
if (!is.null(bd)) {
  ## The two measured groups (ED and not ED, from their own histograms) must
  ## account for most but not more than all of the students below the cut;
  ## "Information not available" takes the remainder. A measured mass above
  ## the cut would mean the group histograms disagree with the national
  ## percentiles, which group_composition refuses.
  for (q in unique(bd$target_pct)) {
    z <- bd[bd$target_pct == q, ]
    ok(all(z$measured_mass <= q/100 + 1e-9 & z$measured_mass > 0.85 * q/100),
       sprintf("measured groups account for 85 to 100 percent of the bottom %d%%", q))
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
## at high budgets, and the first, water-filled eligibility screen (retired
## 2026-09-29) capped correctly but then under-spent its budget. The screen
## that replaced it under-spends on purpose, since it seats only eligible
## students; that is a definition, not a bug, and it is tested separately.
source("analysis/alloc-rules.R")

## The budget-spending rules. The eligibility screen is tested on its own in
## section 11: it spends min(B, ED share), not B, by design.
rules <- list("bottom-up"=alloc_bottom, "proportional"=alloc_uniform,
              "opt-in"=alloc_optin_geom)
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

## 7. Grid independence for the water-filled rule (the opt-in gradient, at
##    budgets past its saturation point, where the cap binds).
fine <- local({
  FILL_GRID <- seq(0.005, 99.995, by=0.01)
  sapply(c(0.6,0.8,0.95), function(B) water_fill(geomtakeup_line, c(10,25,50,75,90), B))
})
coarse <- sapply(c(0.6,0.8,0.95), function(B) water_fill(geomtakeup_line, c(10,25,50,75,90), B))
ok(max(abs(fine - coarse)) < 1e-3,
   sprintf("water_fill is insensitive to the grid step (max difference %.1e)",
           max(abs(fine - coarse))))

## 8. The regression test for the silent-degradation bug: a cell with no
##    ECONDIS distribution must error, not quietly become the proportional rule.
ok(inherits(tryCatch(ed_share_points(dd, de, "No Such Cell", 2024), error=function(e) e), "error"),
   "ed_share_points errors on a cell with no ECONDIS distribution rather than falling back")

cat("\n9. Mixture outcome model (analysis/mixture.R)\n")
## The model that replaced the linear shift. What is asserted here is that the
## reconstruction is faithful, that the mixture reduces to the cases where the
## right answer is known independently, and that the grid does not drive it.
source("analysis/mixture.R")

zr <- qd[qd$cell=="Reading G4", ]; zr <- zr[order(zr$percentile), ]
PSr <- zr$percentile; q24 <- zr$q2019 + zr$d
Sr <- zr$sd2019[1]; deltar <- G_TREAT * Sr
ptsr <- quantile_points(dd[dd$cell=="Reading G4" & dd$year==2024, ], PSr, q24, "Reading G4 2024")
Qr <- make_quantile_fn(ptsr$pct, ptsr$score)
none <- function(p, B) rep(0, length(p))
all1 <- function(p, B) rep(1, length(p))
afterr <- calibrated_program_quantiles(Qr, deltar, PSr, q24)

## 1. The reconstruction passes through the published percentiles. Uncalibrated
##    it is out by about 0.01 points, a grid artifact; calibrated it is exact,
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
screen_rg4 <- make_ed_screen(ed_share_points(dd, de, "Reading G4", 2024))
rules2 <- list("bottom-up"=alloc_bottom, "proportional"=alloc_uniform,
               "opt-in"=alloc_optin_geom, "screen"=screen_rg4)
## The screen is left out of the full-coverage check: at B = 1 it still seats
## only ED students, so it does not treat everyone.
ok(max(sapply(rules2[names(rules2) != "screen"], function(f) abs(gap_after(f, 1) - obs_gap))) < 1e-9,
   "every budget-spending rule returns the no-program gap at full coverage under the mixture")
ok(max(sapply(rules2, function(f) abs(gap_after(f, 0) - obs_gap))) < 1e-9,
   "every rule returns the no-program gap at zero budget")

## 3. The finding that motivated the rebuild: partial coverage spreads the
##    distribution even when every percentile is treated at the same rate, so
##    the proportional rule is NOT the arithmetic identity the linear model
##    made it look like. Asserted so a regression back to the linear shift,
##    which would return exactly obs_gap here, fails loudly.
##
##    How much it widens has a rough closed form. Treating half of every
##    percentile with a shift of delta adds 0.25 * delta^2 to the variance, so
##    for a near-normal distribution the 90-10 gap grows by about
##    gap * 0.125 * (delta / SD)^2: 0.3 points for Reading G4. The
##    five-percentile quantile function this replaced gave 1.17, most of it
##    from the corner where its normal tail met the spline at p90. The bounds
##    below keep the widening near the closed form and would catch that
##    corner coming back.
prop_mid <- gap_after(alloc_uniform, 0.5)
ok(prop_mid > obs_gap + 0.1 && prop_mid < obs_gap + 0.6,
   sprintf("proportional coverage widens the DISTRIBUTIONAL gap at 50 percent by %.2f (%.2f vs %.2f), near the closed form",
           prop_mid - obs_gap, prop_mid, obs_gap))

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

cat("\n10. Quantile functions from the score distribution (quantile_points)\n")
## Every cell and year: the published histogram is complete, the points
## reproduce it and the published percentiles, and the curve has no corners.
## Also the data-consistency check that licenses anchoring: a spline through
## the bin points ALONE lands within 0.15 points of every published
## percentile (0.11 at worst on 2026-09-28), so the histogram and the
## percentiles describe the same distribution.
for (lab in unique(qd$cell)) for (yr in c(2019, 2024)) {
  z <- qd[qd$cell==lab, ]; z <- z[order(z$percentile), ]
  kv <- if (yr == 2019) z$q2019 else z$q2019 + z$d
  h  <- dd[dd$cell==lab & dd$year==yr, ]; h <- h[order(h$bin), ]
  tag <- paste(lab, yr)
  ok(nrow(h) > 0 && abs(sum(h$pct) - 100) < 0.01 && identical(h$bin, seq_len(nrow(h))) &&
       all(h$hi - h$lo == 10),
     sprintf("%s: histogram has contiguous 10-point bins summing to 100 (%d bins)", tag, nrow(h)))
  pts <- quantile_points(h, z$percentile, kv, tag)
  Q <- make_quantile_fn(pts$pct, pts$score)
  ok(max(abs(Q(pts$pct) - pts$score)) < 1e-9 &&
       max(abs(Q(z$percentile) - kv)) < 1e-9,
     sprintf("%s: quantile function passes through all %d points and the published percentiles", tag, nrow(pts)))
  ok(all(diff(Q(RANK_GRID)) > 0), sprintf("%s: quantile function strictly increases on RANK_GRID", tag))
  slope_ratio <- function(p, eps=0.01) {
    l <- (Q(p) - Q(p - eps)) / eps; r <- (Q(p + eps) - Q(p)) / eps; max(l, r) / min(l, r) }
  worst <- max(vapply(seq(10, 90, by=0.5), slope_ratio, numeric(1)))
  ok(worst < 1.1, sprintf("%s: no corner in p10 to p90 (largest left/right slope ratio %.3f)", tag, worst))
  bins_only <- quantile_points(h, numeric(0), numeric(0), tag)
  Qb <- make_quantile_fn(bins_only$pct, bins_only$score)
  ok(max(abs(Qb(z$percentile) - kv)) < 0.15,
     sprintf("%s: histogram alone reproduces the published percentiles (max %.3f pts)",
             tag, max(abs(Qb(z$percentile) - kv))))
}
ok(inherits(tryCatch(make_quantile_fn(c(10, 50, 90), c(1, 2, 3)), error=function(e) e), "error"),
   "make_quantile_fn refuses points that do not span 0 to 100 percent (no silent tails)")
bad <- dd[dd$cell=="Reading G4" & dd$year==2024, ]
ok(inherits(tryCatch(quantile_points(bad, c(10, 50), c(300, 200), "bad"), error=function(e) e), "error"),
   "quantile_points stops when the histogram and the percentiles disagree in order")

cat("\n11. Economic disadvantage: the ED share curve, the screen, and group outcomes\n")
## s(p), the ED share at each national percentile, from the ECONDIS score
## distributions (ed_share_points, alloc-rules.R); the eligibility screen built
## on it (make_ed_screen); and the ED / not-ED outcome tables from
## 06-seat-allocation.R.
wide <- merge(de[grepl("^Econ", de$group), c("cell","year","bin","pct","pop_share")],
              de[grepl("^Not", de$group), c("cell","year","bin","pct","pop_share")],
              by=c("cell","year","bin"), suffixes=c("_ed","_ned"))
wide <- merge(wide, dd[, c("cell","year","bin","pct")], by=c("cell","year","bin"))
wide <- wide[wide$pct > 0, ]
cover <- (wide$pop_share_ed * wide$pct_ed + wide$pop_share_ned * wide$pct_ned) / wide$pct
ok(nrow(wide) > 0 && all(cover <= 1 + 1e-3),
   sprintf("ED plus not-ED students never exceed the national count in a score bin (max %.4f)", max(cover)))
ok(all(!tapply(de$group, paste(de$cell, de$year), function(g) any(grepl("^Info", g)))),
   "\"Information not available\" is not pulled (its bins can be flagged); it is the remainder")
for (lab in unique(qd$cell)) {
  pts <- ed_share_points(dd, de, lab, 2024)
  sc  <- make_ed_screen(pts)
  s_grid <- approx(pts$pct, pts$share, xout=FILL_GRID, rule=2)$y
  ok(all(pts$share >= 0 & pts$share <= 1) && abs(mean(s_grid) - pts$pop) < 1e-3,
     sprintf("%s: ED share stays in [0, 1] and averages to the ED population share (%.4f vs %.4f)",
             lab, mean(s_grid), pts$pop))
  spent <- sapply(c(0.1, 0.3, pts$pop, 0.8, 1), function(B) mean(sc(FILL_GRID, B)))
  ok(max(abs(spent - pmin(c(0.1, 0.3, pts$pop, 0.8, 1), pts$pop))) < 1e-3,
     sprintf("%s: the screen spends min(B, ED share) and leaves the rest unused", lab))
  ok(max(abs(sc(FILL_GRID, 0.2) - (0.2 / pts$pop) * s_grid)) < 1e-12 &&
       max(abs(sc(FILL_GRID, 0.9) - s_grid)) < 1e-12,
     sprintf("%s: screen participation is r * s(p) with r = min(1, B / ED share)", lab))
  ## The same quantity two ways: the average of s(p) over the bottom decile,
  ## from the binned shares, against the ED share of the bottom decile in
  ## sim-bottom-decile.csv, from each group's spline inverted at the cut.
  tail_avg <- mean(s_grid[FILL_GRID < 10])
  bd_ed <- bd$share_of_tail[bd$cell == lab & bd$year == 2024 & bd$target_pct == 10 & grepl("^Econ", bd$group)]
  ok(length(bd_ed) == 1 && abs(tail_avg - bd_ed) < 0.002,
     sprintf("%s: bottom-decile ED share agrees across the two routes (%.3f vs %.3f)", lab, tail_avg, bd_ed))
}
go <- Sys.glob("tables/sim-group-outcomes-*.csv")
ok(length(go) == 4, sprintf("an ED / not-ED outcome table exists for each of the four seat-allocation cells (%d)", length(go)))
cell_S <- function(f) {
  lab <- tools::toTitleCase(sub("-g", " G", sub(".*outcomes-(.*)\\.csv", "\\1", f)))
  qd$sd2019[qd$cell == lab][1]
}
PCOL <- paste0("p", c(10, 25, 50, 75, 90))
for (f in go) {
  g <- read.csv(f, stringsAsFactors=FALSE); tag <- basename(f); dS <- G_TREAT * cell_S(f)
  none <- g[g$rule == "2024, no program", ]
  scr  <- g[g$rule == "Eligibility screen (ECONDIS)", ]
  nn   <- none[none$group == "Not ED", PCOL]
  ok(max(abs(sweep(as.matrix(scr[scr$group == "Not ED", PCOL]), 2, unlist(nn)))) < 1e-9,
     sprintf("%s: the screen leaves not-ED students exactly where they were", tag))
  lab_f <- tools::toTitleCase(sub("-g", " G", sub(".*outcomes-(.*)\\.csv", "\\1", f)))
  pop_f <- de$pop_share[de$cell == lab_f & de$year == 2024 & grepl("^Econ", de$group)][1]
  ed_full <- scr[scr$group == "ED" & scr$budget >= pop_f, PCOL]
  ok(max(abs(sweep(as.matrix(ed_full), 2, unlist(none[none$group == "ED", PCOL]) + dS))) < 1e-9,
     sprintf("%s: once every ED student is seated, every ED percentile rises by exactly the treated effect", tag))
  prop <- g[g$rule == "Proportional (untargeted)" & abs(g$budget - 1) < 1e-9, ]
  ok(max(abs(as.matrix(prop[, PCOL]) - (as.matrix(none[match(prop$group, none$group), PCOL]) + dS))) < 1e-9,
     sprintf("%s: full proportional coverage shifts both groups by the treated effect", tag))
  ok(all(g$p10 < g$p25 & g$p25 < g$p50 & g$p50 < g$p75 & g$p75 < g$p90),
     sprintf("%s: group percentiles are ordered in every row", tag))
}

cat(sprintf("\n%s: %d failure(s)\n", if (fails == 0) "ALL TESTS PASSED" else "TESTS FAILED", fails))
quit(status = if (fails == 0) 0 else 1)
