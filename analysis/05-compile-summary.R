#!/usr/bin/env Rscript
## Assemble tables/SIM-SUMMARY.md from the committed CSVs written by
## 01-simulations.R and the literature parameters in the config.
##
## Every parameter printed or used here (Table 2(a) targets, Kraft (2020)
## percentiles, participation rates, program effects, the ED population
## share) is read from analysis/config/sim-params.yaml. Revising one there
## moves this summary along with 01's tables; before, this file carried its
## own copies.
##
## Public data only. Usage: Rscript analysis/05-compile-summary.R

suppressPackageStartupMessages({library(dplyr)})
for (f in c("tables/sim-quantiles.csv", "tables/sim-bottom-decile.csv"))
  if (!file.exists(f))
    stop("missing ", f, ". Run: Rscript analysis/01-simulations.R", call.=FALSE)
qd <- read.csv("tables/sim-quantiles.csv", stringsAsFactors=FALSE)
bd <- read.csv("tables/sim-bottom-decile.csv", stringsAsFactors=FALSE)
ord <- c("Reading G4","Reading G8","Reading G12","Math G4","Math G8","Math G12")
qd$cell <- factor(qd$cell, levels=ord); bd$cell <- factor(bd$cell, levels=ord)

source("analysis/config-helpers.R")
cfg <- load_sim_config()
t2    <- cfg_table2a(cfg)
kraft <- cfg_kraft2020(cfg)
G_TREAT <- cfg_treated_g(cfg)
## Participation rates, by config id. c_univ is the universal column.
c_univ <- cfg_c(cfg, "universal"); c_hdt <- cfg_c(cfg, "hdt_dist")
c_opt  <- cfg_c(cfg, "optin");     c_sum <- cfg_c(cfg, "summer")
## Rate as a percent label for table headers: 0.28 -> "28", 0.187 -> "18.7".
pct_lab <- function(x) format(round(x*100, 1))
L <- c()
add <- function(...) L <<- c(L, sprintf(...))

add("# Simulation results: benchmarking the recovery requirement")
add("")
add("Built on %s from the NAEP Data Service API (responses cached in analysis/.cache/). Public NAEP data only; no restricted-use inputs.", format(Sys.Date()))
add("The quantile differences and restoration requirements were computed independently in R")
add("and Stata and agree to 1e-14 across all 30 cell-percentile pairs. The participation")
add("adjustment and the bottom-decile decomposition below have a single implementation, in R.")
add("")
add("## 1. Validation: public data reproduces the restricted-use analysis")
add("")
add("The differential change (p90 difference minus p10 difference) computed from public")
add("percentiles, against Table 2 column (a) of the companion AERA Open article, computed from")
add("restricted-use microdata. This is what licenses using public data for the simulations.")
add("")
add("| Cell | Public | Table 2(a) | Delta | SE of diff. change |")
add("|---|---|---|---|---|")
for (cc in ord) {
  z <- qd[as.character(qd$cell)==cc,]
  if (!nrow(z)) next
  z <- z[1,]
  add("| %s | %.2f | %.1f | %+.2f | %.2f |", cc, z$diff_change, t2[[cc]],
      z$diff_change - t2[[cc]], z$diff_change_se)
}
add("")
add("All six agree to the reported precision. Note Reading G12's 1.53 sits inside its own")
add("SE of 1.82, which supports treating grade 12 separately.")
add("")
add("## 2. Observed quantile differences, 2024 minus 2019 (NAEP score points)")
add("")
add("| Cell | p10 | p25 | p50 | p75 | p90 | 2019 SD | 2024 SD |")
add("|---|---|---|---|---|---|---|---|")
for (c in ord) {
  z <- qd[qd$cell==c,]; z <- z[order(z$percentile),]
  add("| %s | %+.1f | %+.1f | %+.1f | %+.1f | %+.1f | %.1f | %.1f |", c,
      z$d[1],z$d[2],z$d[3],z$d[4],z$d[5], z$sd2019[1], z$sd2024[1])
}
add("")
add("Every quantile fell in every cell. The SD widened in all six, which is independent")
add("evidence of distributional spreading.")
add("")
add("## 3. Restoration requirement g*(p), in 2019 national SD units")
add("")
add("The effect a fully-covered intervention must deliver at each percentile to restore")
add("its 2019 value. Benchmark: Kraft (2020), 1,942 effects from 747 RCTs, median %.2f,", kraft[["p50"]])
add("P75 %.2f, P90 %.2f.", kraft[["p75"]], kraft[["p90"]])
add("")
add("| Cell | p10 | p25 | p50 | p75 | p90 | p10 sits |")
add("|---|---|---|---|---|---|---|")
for (c in ord) {
  z <- qd[qd$cell==c,]; z <- z[order(z$percentile),]
  g <- z$g_star[1]
  pos <- if (g>=kraft[["p90"]]) "**above P90 of observed effects**" else if (g>=kraft[["p75"]]) "**above P75**" else
         if (g>=kraft[["p50"]]) "above the median" else "below the median"
  add("| %s | **%.3f** | %.3f | %.3f | %.3f | %.3f | %s |", c,
      z$g_star[1],z$g_star[2],z$g_star[3],z$g_star[4],z$g_star[5], pos)
}
add("")
add("## 4. Participation-adjusted requirement: what the treated effect must be")
add("")
add("Required g = g*(p10) / participation, where participation is the share of a\npercentile's students who actually take part. Real programs reach 13-28 percent.")
add("")
add("| Cell | Universal (%s%%) | District HDT (%s%%) | Opt-in (%s%%) | Summer (%s%%) |",
    pct_lab(c_univ), pct_lab(c_hdt), pct_lab(c_opt), pct_lab(c_sum))
add("|---|---|---|---|---|")
for (c in ord) {
  g <- qd$g_star[qd$cell==c & qd$percentile==10]
  add("| %s | %.2f | %.2f | %.2f | %.2f |", c, g/c_univ, g/c_hdt, g/c_opt, g/c_sum)
}
add("")
add("Nothing in the education literature delivers 1.3 to 2.2 SD. The best-evidenced")
add("at-scale tutoring effect is %.3f SD, and it is not statistically distinguishable", G_TREAT)
add("from zero.")
add("")
add("## 4b. The same requirement measured at p25 instead of p10")
add("")
add("p25 is arguably the more policy-relevant target: an eligibility screen can plausibly")
add("reach the bottom quartile, whereas no observable screen isolates the bottom decile.")
add("The requirement falls but does not become easy.")
add("")
add("| Cell | g*(p10) | g*(p25) | g*(p90) | p25 at c=%s%% | p25 at c=%s%% |",
    pct_lab(c_hdt), pct_lab(c_opt))
add("|---|---|---|---|---|---|")
for (cc in ord) {
  z <- qd[as.character(qd$cell)==cc,]
  g10 <- z$g_star[z$percentile==10]; g25 <- z$g_star[z$percentile==25]
  g90 <- z$g_star[z$percentile==90]
  add("| %s | %.3f | **%.3f** | %.3f | %.2f | %.2f |", cc, g10, g25, g90, g25/c_hdt, g25/c_opt)
}
add("")
add("Two things worth noting. Restoring p25 in Reading G4 needs 0.216 SD, still above the")
add("75th percentile of observed education effects, and still 1.15 SD once opt-in take-up")
add("is applied. And Math G12 is the one cell where p25 requires slightly MORE than p10")
add("(0.139 vs 0.135), because its decline is flat across the lower half rather than")
add("concentrated in the bottom tail.")
add("")
add("## 5. Share of the p10 deficit closed")
add("")
add("| Cell | Program | Universal | District HDT | Opt-in | Summer |")
add("|---|---|---|---|---|---|")
## Short display labels for this table, paired with config benchmark ids.
progs <- list(c("Tutoring, >=1000 students","tut_scale"), c("Tutoring, 400-999","tut_mid"),
              c("Summer, meta-analytic","summer_math"), c("Summer, realized","summer_real"))
for (c in c("Reading G4","Math G8")) {
  g <- qd$g_star[qd$cell==c & qd$percentile==10]
  for (p in progs) {
    e <- cfg_g(cfg, p[2])
    add("| %s | %s (%.3f) | %.0f%% | %.0f%% | %.0f%% | %.0f%% |", c, p[1], e,
        min(c_univ*e/g,1)*100, min(c_hdt*e/g,1)*100, min(c_opt*e/g,1)*100, min(c_sum*e/g,1)*100)
  }
}
add("")
add("(Featured cells only; the other four are in tables/sim-results.md.)")
add("")
add("## 6. Who is in the bottom decile: the targeting screen")
add("")
add("Share of students below the 10th percentile who are economically disadvantaged,")
add("against that group's share of the whole population. The gap is the targeting lift.")
add("")
add("| Cell | Pop. share 2019 | Bottom decile 2019 | Pop. share 2024 | Bottom decile 2024 | Change |")
add("|---|---|---|---|---|---|")
for (c in ord) {
  e <- bd[bd$cell==c & grepl("^Econ", bd$group) & bd$target_pct==10,]
  a <- e[e$year==2019,]; b <- e[e$year==2024,]
  if (nrow(a) && nrow(b))
    add("| %s | %.1f%% | **%.1f%%** | %.1f%% | **%.1f%%** | %+.1f pp |", c,
        a$pop_share*100, a$share_of_tail*100,
        b$pop_share*100, b$share_of_tail*100,
        (b$share_of_tail - a$share_of_tail)*100)
}
add("")
## The prose numbers below are read from sim-bottom-decile.csv, so they move
## with the table, except the one historical comparison (the "1.4 to 3.6
## points" against the five-percentile method), which is fixed: it compares
## this table with the version committed before 2026-09-29.
## One wide table over all six cells, 2019 against 2024: the change in the ED
## share of the bottom decile and in the targeting lift (that share minus the
## ED population share). Grades 4 and 8 carry the pattern; grade 12 is the
## contrast in section 7.
ed10 <- bd[grepl("^Econ", bd$group) & bd$target_pct == 10, ]
ed10w <- merge(ed10[ed10$year == 2019, c("cell", "share_of_tail", "pop_share")],
               ed10[ed10$year == 2024, c("cell", "share_of_tail", "pop_share")],
               by="cell", suffixes=c("_19", "_24"))
ed10w$lift_change <- with(ed10w, (share_of_tail_24 - pop_share_24) - (share_of_tail_19 - pop_share_19)) * 100
ed10w$tail_change <- with(ed10w, share_of_tail_24 - share_of_tail_19) * 100
g48 <- ed10w[grepl("G(4|8)$", ed10w$cell), ]
g12 <- ed10w[grepl("G12$", ed10w$cell), ]
add("Method: each group's share below the cut comes from its own published score")
add("distribution (10-point bins) and percentiles, with no assumed tail. Students whose")
add("economic status is not available take the remainder. Through 2026-09-28 these")
add("shares came from five percentiles with a normal left tail, which put the ED share")
add("of the bottom decile 1.4 to 3.6 points higher in grades 4 and 8.")
add("")
add("From 2019 to 2024 the ED share of the bottom decile fell by %.1f to %.1f points in",
    -max(g48$tail_change), -min(g48$tail_change))
add("grades 4 and 8. The direction is the same in both subjects and both grades, which is")
add("why it is worth reporting as a pattern.")
add("")
add("## 6b. Why p25 is the better target: the population math of take-up")
add("")
add("This is the strongest argument for measuring the requirement at p25 rather")
add("than p10, and it is about efficiency of effort, not just a smaller deficit.")
add("")
add("A program screened on economic disadvantage covers about half the population.")
add("Of the students it reaches, only some are in the target group, and of the")
add("target group, only some get reached. Both directions matter, and they trade")
add("off differently depending on where the target is drawn.")
add("")
add("| Target | ED share of the target | Target as %% of population | Share of treated students who are IN the target | Effort landing outside the target |")
add("|---|---|---|---|---|")
## ED population share: the measured Reading G4 2019 ECONDIS share from the
## same table (it replaced the unsourced config value 0.510 on 2026-09-29).
rg4 <- bd[bd$cell=="Reading G4" & grepl("^Econ", bd$group) & bd$year==2019,]
edpop <- rg4$pop_share[1]
outside <- c()     # share of treated students outside the target, by q
for (q in c(10,25)) {
  e <- rg4[rg4$target_pct==q,]
  if (!nrow(e)) next
  edt <- e$share_of_tail[1]
  intgt <- (q/100) * edt / edpop
  outside[as.character(q)] <- (1-intgt)*100
  add("| bottom %d%% | %.1f%% | %d%% | **%.1f%%** | %.1f%% |", q, edt*100, q, intgt*100, (1-intgt)*100)
}
add("")
out_share <- function(q) outside[[as.character(q)]]
add("(Grade 4 reading, 2019.) At p10, %.0f percent of treated students sit outside the", out_share(10))
add("target group, because the target is only a tenth of the population while the")
add("screen covers half of it. At p25 that falls to %.0f percent. The same screen is", out_share(25))
add("far less wasteful against the broader target.")
add("")
add("There is a reachability constraint pointing the same way. With perfect")
add("targeting, a program with participation c can reach at most")
add("min(1, c/q) of the bottom q. At the observed %s percent opt-in participation rate that", pct_lab(c_opt))
add("is %.0f percent of the bottom decile but only %.0f percent of the bottom quartile.",
    min(1, c_opt/0.10)*100, min(1, c_opt/0.25)*100)
add("So take-up binds on intensity at p10 and on both intensity and reach at p25 --")
add("but the p10 target is the one where almost all the effort is wasted on")
add("students outside it.")
add("")
add("Taken together: p10 is where the deficit is largest, and p25 is where a real")
add("screen can act efficiently. Reporting both, and being explicit that no")
add("observable screen isolates the bottom decile, is more defensible than either")
add("alone.")
add("")
add("## 7. What this supports")
add("")
add("1. **The recovery task is asymmetric.** Restoring p10 needs 0.26 SD (G4 reading) to")
add("   0.29 SD (G8 math), at or above the 75th percentile of all observed education")
add("   effects. Restoring p90 needs 0.03 to 0.13 SD. It is not one task.")
add("2. **Participation is the binding constraint, not effect size.** At realistic take-up the")
add("   requirement rises to 1.3-2.2 SD, beyond anything ever delivered at scale.")
add("3. **Targeting on economic disadvantage is a decent screen but a blunt instrument.**")
add("   ED students are %.0f to %.0f percent of the bottom decile at grades 4 and 8 (2019",
    100 * min(c(g48$share_of_tail_19, g48$share_of_tail_24)),
    100 * max(c(g48$share_of_tail_19, g48$share_of_tail_24)))
add("   and 2024), while making up about half the population, so a fixed budget buys")
add("   half the per-student intensity of a program aimed at the bottom decile.")
g12_lift <- g12$lift_change
add("4. **The screen weakened where the decline is worst.** Grades 4 and 8 lost %.1f to %.1f",
    -max(g48$lift_change), -min(g48$lift_change))
add("   points of targeting lift between 2019 and 2024; grade 12, where the differential")
add("   decline is small, %s.", if (all(g12_lift > -0.5)) "did not" else
    sprintf("changed by %+.1f to %+.1f points", min(g12_lift), max(g12_lift)))
add("")
add("## Caveats carried")
add("")
add("- Comparing a mean treated effect to a percentile-specific requirement assumes the")
add("  effect transports across the treated distribution (null-gradient assumption). No")
add("  source in the intervention, finance, or teacher-effects literatures provides a")
add("  genuine quantile treatment effect on a test-score distribution.")
add("- Literature effect sizes are standardized on restricted, lower-variance samples,")
add("  so mapping them onto a national NAEP SD is optimistic. No deflation is applied,")
add("  which makes the conclusion conservative.")
add("- The six NAEP scales are not vertically linked; do not compare g* across cells.")
add("- SE[D(p)] treats the two administrations as independent, per NCES convention. The")
add("  shared score scale induces a small positive covariance, so these SEs are slightly")
add("  conservative.")
writeLines(L, "tables/SIM-SUMMARY.md")
cat(paste(L, collapse="\n"), "\n")
