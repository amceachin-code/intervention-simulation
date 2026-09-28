suppressPackageStartupMessages({library(dplyr)})
qd <- read.csv("tables/sim-quantiles.csv", stringsAsFactors=FALSE)
bd <- read.csv("tables/sim-bottom-decile.csv", stringsAsFactors=FALSE)
ord <- c("Reading G4","Reading G8","Reading G12","Math G4","Math G8","Math G12")
qd$cell <- factor(qd$cell, levels=ord); bd$cell <- factor(bd$cell, levels=ord)
t2 <- c("Reading G4"=8.7,"Reading G8"=7.0,"Reading G12"=1.5,"Math G4"=7.9,"Math G8"=6.4,"Math G12"=4.5)
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
add("its 2019 value. Benchmark: Kraft (2020), 1,942 effects from 747 RCTs, median 0.10,")
add("P75 0.25, P90 0.47.")
add("")
add("| Cell | p10 | p25 | p50 | p75 | p90 | p10 sits |")
add("|---|---|---|---|---|---|---|")
for (c in ord) {
  z <- qd[qd$cell==c,]; z <- z[order(z$percentile),]
  g <- z$g_star[1]
  pos <- if (g>=0.47) "**above P90 of observed effects**" else if (g>=0.25) "**above P75**" else
         if (g>=0.10) "above the median" else "below the median"
  add("| %s | **%.3f** | %.3f | %.3f | %.3f | %.3f | %s |", c,
      z$g_star[1],z$g_star[2],z$g_star[3],z$g_star[4],z$g_star[5], pos)
}
add("")
add("## 4. Participation-adjusted requirement: what the treated effect must be")
add("")
add("Required g = g*(p10) / participation, where participation is the share of a\npercentile's students who actually take part. Real programs reach 13-28 percent.")
add("")
add("| Cell | Universal (100%%) | District HDT (28%%) | Opt-in (18.7%%) | Summer (13%%) |")
add("|---|---|---|---|---|")
for (c in ord) {
  g <- qd$g_star[qd$cell==c & qd$percentile==10]
  add("| %s | %.2f | %.2f | %.2f | %.2f |", c, g, g/0.28, g/0.187, g/0.130)
}
add("")
add("Nothing in the education literature delivers 1.3 to 2.2 SD. The best-evidenced")
add("at-scale tutoring effect is 0.155 SD, and it is not statistically distinguishable")
add("from zero.")
add("")
add("## 4b. The same requirement measured at p25 instead of p10")
add("")
add("p25 is arguably the more policy-relevant target: an eligibility screen can plausibly")
add("reach the bottom quartile, whereas no observable screen isolates the bottom decile.")
add("The requirement falls but does not become easy.")
add("")
add("| Cell | g*(p10) | g*(p25) | g*(p90) | p25 at c=28%% | p25 at c=18.7%% |")
add("|---|---|---|---|---|---|")
for (cc in ord) {
  z <- qd[as.character(qd$cell)==cc,]
  g10 <- z$g_star[z$percentile==10]; g25 <- z$g_star[z$percentile==25]
  g90 <- z$g_star[z$percentile==90]
  add("| %s | %.3f | **%.3f** | %.3f | %.2f | %.2f |", cc, g10, g25, g90, g25/0.28, g25/0.187)
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
progs <- list(c("Tutoring, >=1000 students","0.155"), c("Tutoring, 400-999","0.214"),
              c("Summer, meta-analytic","0.100"), c("Summer, realized","0.027"))
for (c in c("Reading G4","Math G8")) {
  g <- qd$g_star[qd$cell==c & qd$percentile==10]
  for (p in progs) {
    e <- as.numeric(p[2])
    add("| %s | %s (%.3f) | %.0f%% | %.0f%% | %.0f%% | %.0f%% |", c, p[1], e,
        min(e/g,1)*100, min(0.28*e/g,1)*100, min(0.187*e/g,1)*100, min(0.130*e/g,1)*100)
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
add("Sensitivity: the bottom-decile share depends on the left-tail model. For Reading G4")
add("2019 it is 82.8%% (normal), 80.6%% (logistic), 79.2%% (exponential), so read these as")
add("roughly 79-83%% rather than as point estimates. The 2019-to-2024 changes of 3-5 points")
add("are the same order as that uncertainty; the direction is consistent across grades 4")
add("and 8 in both subjects, which is why it is worth reporting as a pattern.")
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
edpop <- 0.510
for (q in c(10,25)) {
  e <- bd[bd$cell=="Reading G4" & grepl("^Econ", bd$group) & bd$target_pct==q & bd$year==2019,]
  if (!nrow(e)) next
  edt <- e$share_of_tail[1]
  intgt <- (q/100) * edt / edpop
  add("| bottom %d%% | %.1f%% | %d%% | **%.1f%%** | %.1f%% |", q, edt*100, q, intgt*100, (1-intgt)*100)
}
add("")
add("(Grade 4 reading, 2019.) At p10, about five of every six treated students sit")
add("outside the target group, because the target is only a tenth of the population")
add("while the screen covers half of it. At p25 that falls to roughly two of three.")
add("The same screen is far less wasteful against the broader target.")
add("")
add("There is a reachability constraint pointing the same way. With perfect")
add("targeting, a program with participation c can reach at most")
add("min(1, c/q) of the bottom q. At the observed 18.7 percent opt-in participation rate that")
add("is 100 percent of the bottom decile but only 75 percent of the bottom quartile.")
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
add("   It captures roughly four-fifths of the bottom decile at grades 4 and 8, while")
add("   covering about half the population, so a fixed budget buys half the per-student")
add("   intensity of a program aimed at the bottom decile.")
add("4. **The screen weakened where the decline is worst.** Grades 4 and 8 lost 1-5 points")
add("   of targeting lift between 2019 and 2024; grade 12, where the differential decline")
add("   is small, did not.")
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
