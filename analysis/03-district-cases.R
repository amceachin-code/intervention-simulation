#!/usr/bin/env Rscript
## Simulation extension: four case-study districts.
##
## The setup (Andrew, 2026-09-04): assume four districts share the SAME shape of
## the 2024 population distribution as the nation, and differ only in where
## their median sits -- offsets of -0.2, -0.1, +0.1 and +0.2 national SD.
## Each district is asked to restore ITS OWN 2019 distribution, so the size of
## the loss is held constant and the only thing varying is WHERE the district
## sits. That isolates the effect of position from the effect of loss.
##
## The point is not that a real district looks like this. It is that if two
## districts suffer an identical decline, the requirement facing each is
## identical in SD units and identical in score points -- but what that requires
## of a targeted program is NOT the same, because the students needing help sit
## at different places in the national distribution and so are reached by
## different screens.
##
## Public data only. Reads tables/sim-quantiles.csv.
## Usage: Rscript analysis/03-district-cases.R

suppressPackageStartupMessages({library(dplyr)})

IN <- "tables"; OUT <- "tables"
if (!file.exists(file.path(IN, "sim-quantiles.csv")))
  stop("missing ", file.path(IN, "sim-quantiles.csv"),
       ". Run: Rscript analysis/01-simulations.R", call.=FALSE)
qd <- read.csv(file.path(IN, "sim-quantiles.csv"), stringsAsFactors=FALSE)

## Featured cell. G4 reading anchors the paper's narrative.
CELL <- "Reading G4"
z <- qd[qd$cell == CELL, ]
z <- z[order(z$percentile), ]
S  <- z$sd2019[1]

## District median offsets, in national SD units.
districts <- tibble(
  name   = c("District A", "District B", "District C", "District D"),
  offset = c(-0.2, -0.1, 0.1, 0.2))

## Same distributional SHAPE means every percentile shifts by the same amount,
## so each district's 2019 and 2024 quantiles are the national ones plus the
## offset, and the DIFFERENCE D(p) is identical across districts by construction.
## The requirement in SD units is therefore also identical. What differs is
## where those students sit in the NATIONAL distribution, which is what a
## screen or a program actually sees.

## Map a district score onto its national percentile: the inverse of the
## national 2019 quantile function, built (quantile_points, mixture.R) from the
## 2019 score distribution and the published percentiles. The distribution
## reaches the ends of the scale, so no tail is assumed; this replaced linear
## interpolation between the five percentiles with fitted normal tails on
## 2026-09-29.
source("analysis/mixture.R")
dd <- read.csv(file.path("tables", "sim-distribution.csv"), stringsAsFactors=FALSE)
q19_pts <- quantile_points(dd[dd$cell == CELL & dd$year == 2019, ], z$percentile,
                           z$q2019, paste(CELL, 2019))
Q19_fn <- make_quantile_fn(q19_pts$pct, q19_pts$score)
nat_pct <- function(x) 100 * quantile_cdf(Q19_fn, x)

L <- c()
add <- function(...) L <<- c(L, sprintf(...))

add("# Four case-study districts: same decline, different starting points")
add("")
add("Cell: %s. National 2019 SD = %.1f score points.", CELL, S)
add("")
add("Four hypothetical districts share the national shape of the 2024 score")
add("distribution and differ only in where their median sits: %s national SD.",
    paste(sprintf("%+.1f", districts$offset), collapse=", "))
add("Each is asked to restore its OWN 2019 distribution, so every district")
add("suffers the identical national decline. This holds the loss constant and")
add("varies only position.")
add("")
add("## 1. The requirement is identical everywhere. That is the point.")
add("")
add("| District | Median offset | Median, points | D(p10) | D(p25) | g*(p10) | g*(p25) |")
add("|---|---|---|---|---|---|---|")
med <- z$q2019[z$percentile==50]
for (i in seq_len(nrow(districts))) {
  o <- districts$offset[i]
  add("| %s | %+.1f SD | %.1f | %+.1f | %+.1f | %.3f | %.3f |",
      districts$name[i], o, med + o*S,
      z$d[z$percentile==10], z$d[z$percentile==25],
      z$g_star[z$percentile==10], z$g_star[z$percentile==25])
}
add("")
add("By construction the decline, and therefore the restoration requirement, is")
add("the same in every district. A district-level analysis that stopped here")
add("would conclude that position does not matter.")
add("")
add("## 2. But the same students sit at very different national percentiles")
add("")
add("| District | Its p10 sits at national pctile | Its p25 sits at national pctile | Its median sits at |")
add("|---|---|---|---|")
for (i in seq_len(nrow(districts))) {
  o <- districts$offset[i]
  p10 <- nat_pct(z$q2019[z$percentile==10] + o*S)
  p25 <- nat_pct(z$q2019[z$percentile==25] + o*S)
  p50 <- nat_pct(med + o*S)
  add("| %s | %.1f | %.1f | %.1f |", districts$name[i], p10, p25, p50)
}
add("")
add("This is where position bites. Even with medians only 0.4 SD apart end to")
add("end, District A\'s own bottom decile sits near the national 7th percentile")
add("while District D\'s sits near the national 14th -- twice as high. District")
add("D\'s own bottom quartile sits above the national 30th percentile, so a rule")
add("written on the national 25th reaches only part of it (Section 3 quantifies")
add("how much).")
add("")
add("## 3. What a nationally targeted program delivers in each district")
add("")
add("Suppose a program is offered to students below the NATIONAL 25th percentile")
add("-- a plausible eligibility rule -- and delivers the best-evidenced at-scale")
add("tutoring effect of 0.155 SD to those it reaches.")
add("")
natp25 <- z$q2019[z$percentile==25]
add("| District | Share of its students eligible | Share of its p25 target covered |")
add("|---|---|---|")
for (i in seq_len(nrow(districts))) {
  o <- districts$offset[i]
  ## share of the district below the national p25 cut = national percentile of
  ## (cut - offset), because the district is the national shape shifted by offset
  elig <- nat_pct(natp25 - o*S)
  covered <- min(100, elig/25*100)
  add("| %s | %.1f%% | %.0f%% |", districts$name[i], elig, covered)
}
add("")
add("A rule written on the national distribution is not a neutral instrument.")
add("It sends systematically more resource per student to low-median districts")
add("and less to high-median ones, regardless of how much each district lost.")
add("With these modest offsets the effect is graded rather than dramatic, which")
add("is itself the useful finding: a 0.4 SD spread in district medians already")
add("produces a meaningful difference in who a national rule reaches.")
add("Whether that is desirable depends on whether the goal is recovery")
add("(restoring each district's own 2019 level) or equity (bringing every")
add("student to a common national standard). The two goals are not the same,")
add("and this table is the clearest way to show it.")
add("")
add("## Caveats")
add("")
add("- These districts are hypothetical. Real districts differ in the SHAPE of")
add("  their distributions, not only in location, and they did not all suffer")
add("  the national decline. Fahle et al. (2023) find districts differed sharply")
add("  from one another in how much they lost.")
add("- The offsets are deliberately modest. Real district medians span a far wider")
add("  range, so the contrasts below are conservative.")
add("- National percentiles outside the published 10th-90th range are")
add("  extrapolated with a fitted normal and should be read as approximate.")

writeLines(L, file.path(OUT, "sim-district-cases.md"))
cat(paste(L, collapse="\n"), "\n")

## ---- Figure: the four districts against the national distribution ----------
if (requireNamespace("ggplot2", quietly=TRUE)) {
  suppressPackageStartupMessages({library(ggplot2); library(tidyr)})
  dir.create("figures/sim", showWarnings=FALSE, recursive=TRUE)

  ## Each district's own 2019 quantile function, plus where those values sit in
  ## the national distribution.
  gd <- do.call(rbind, lapply(seq_len(nrow(districts)), function(i) {
    o <- districts$offset[i]
    data.frame(district=sprintf("%s (%+.1f SD)", districts$name[i], o),
               offset=o, percentile=z$percentile,
               own=z$q2019 + o*S,
               natl=vapply(z$q2019 + o*S, nat_pct, numeric(1)),
               stringsAsFactors=FALSE)
  }))
  gd$district <- factor(gd$district, levels=unique(gd$district))

  f <- ggplot(gd, aes(percentile, natl, colour=district, group=district)) +
    geom_abline(slope=1, intercept=0, linetype="dashed", colour="grey55") +
    annotate("text", x=62, y=55, label="national distribution\n(no offset)",
             colour="grey45", size=3, hjust=0) +
    geom_line(linewidth=0.9) + geom_point(size=2.2) +
    scale_x_continuous("Percentile WITHIN the district", breaks=z$percentile,
                       limits=c(0,100)) +
    scale_y_continuous("Where that student sits in the NATIONAL distribution",
                       breaks=seq(0,100,20), limits=c(0,100)) +
    scale_colour_brewer(palette="RdYlBu", direction=-1) +
    labs(title="Same decline, same requirement, very different students",
         subtitle=sprintf(paste("Four districts sharing the national shape of the score distribution,",
                        "differing only in\nwhere their median sits (-0.2 to +0.2 SD). Each faces",
                        "an identical %.3f SD requirement to\nrestore its own 10th percentile --",
                        "but a nationally written eligibility rule sees them differently."),
                        z$g_star[z$percentile==10]),
         caption=sprintf(paste("%s, national 2019 SD = %.1f. Hypothetical districts.",
                       "Percentiles outside the published\n10th-90th range are extrapolated",
                       "with a fitted normal. Public NAEP Data Service API."),
                       CELL, S),
         colour=NULL) +
    theme_minimal(base_size=11) +
    theme(panel.grid.minor=element_blank(), legend.position="top",
          plot.title=element_text(face="bold", size=13),
          plot.subtitle=element_text(colour="grey30", size=9.5),
          plot.caption=element_text(colour="grey45", size=8, hjust=0))
  ggsave("figures/sim/fig11-district-cases.png", f, width=8.6, height=6.2, dpi=200)
  message("wrote figures/sim/fig11-district-cases.png")
}
