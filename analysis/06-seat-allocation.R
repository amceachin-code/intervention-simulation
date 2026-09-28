#!/usr/bin/env Rscript
## Seat allocation: two distinct questions about participation.
##
## Andrew's framing (2026-09-05):
##
##   SECTION 1, "How do I help a targeted group?"  A district picks a group,
##   say the bottom decile, and asks what it would take to close that group's
##   gap relative to a comparison point such as p90. Seats are treated as
##   available: the question is what the program must deliver to the group it
##   chose, not what it costs elsewhere. This is the requirements analysis in
##   figure 8, and it is the right frame for "can we fix the bottom?"
##
##   SECTION 2, "How do I help my whole district?"  The seat budget is FIXED.
##   Every seat given to a student at p50 is a seat denied to a student at p10.
##   The question is no longer what a group needs but how a scarce resource
##   should be spread, and what that does to the SHAPE of the distribution.
##   This is an allocation problem; section 1 is not.
##
## The two answer different questions and can disagree. A rule that looks
## generous to the bottom in section 1 may be unaffordable in section 2, and a
## rule that raises the mean in section 2 may widen the very gap section 1 is
## trying to close.
##
## Public data only. Usage: Rscript analysis/06-seat-allocation.R [cell]

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(scales)
})

TABLES <- "tables"; OUT <- "figures/sim"
dir.create(OUT, showWarnings=FALSE, recursive=TRUE)
for (f in c("sim-quantiles.csv", "sim-bottom-decile.csv"))
  if (!file.exists(file.path(TABLES, f)))
    stop("missing ", file.path(TABLES, f), ". Run: Rscript analysis/01-simulations.R",
         call.=FALSE)
qd <- read.csv(file.path(TABLES,"sim-quantiles.csv"), stringsAsFactors=FALSE)
bd <- read.csv(file.path(TABLES,"sim-bottom-decile.csv"), stringsAsFactors=FALSE)

CELL <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else "Reading G4"
## Fail here rather than 100 lines later with a subscript-out-of-bounds from an
## empty deficit vector.
if (!CELL %in% qd$cell)
  stop("unknown cell '", CELL, "'. Available: ",
       paste(sort(unique(qd$cell)), collapse=", "), call.=FALSE)
G    <- 0.155   # treated effect, SD: best-evidenced tutoring at national scale
z <- qd[qd$cell==CELL,]; z <- z[order(z$percentile),]
S <- z$sd2019[1]
PS <- z$percentile
deficit <- setNames(-z$d, PS)          # points needed to restore, positive

## ---------------------------------------------------------------------------
## Allocation rules. Each returns the participation rate at percentile p given
## a total seat budget B, expressed as a share of ALL students. Every rule must
## satisfy the budget: the mean participation across the distribution equals B.
##
## Defined in analysis/alloc-rules.R rather than here so that the test suite
## can load them without running this script, which writes figures and a CSV
## on source. See that file for the derivation of each rule.
## ---------------------------------------------------------------------------
source("analysis/alloc-rules.R")
source("analysis/mixture.R")

ed_curve     <- make_ed_curve(bd, CELL)
alloc_screen <- function(p, B) water_fill(ed_curve, p, B)

RULES <- list(
  "Bottom-up (lowest first)"      = alloc_bottom,
  "Proportional (untargeted)"     = alloc_uniform,
  "Opt-in gradient"               = alloc_optin_geom,
  "Eligibility screen (ECONDIS)"  = alloc_screen)

## Residual deficit at each percentile under a rule and budget: how far short
## of its 2019 value the percentile still sits once the program has run.
##
## The post-program distribution comes from analysis/mixture.R, which treats
## partial coverage as what it is, a mixture of treated and untreated students,
## rather than as a partial dose given to everyone. See that file for why the
## distinction changes the answer.
##
## Values go negative where a percentile is lifted past its 2019 level. Keep
## them: the spread calculation subtracts one percentile's residual from
## another's, so flooring at zero would understate how far a rule pushes the
## top.
## There are two defensible questions here and they do not have the same
## answer, so both are computed and both are reported.
##
##   residual()          the DISTRIBUTIONAL question. Whoever now stands at
##                       percentile p, how far below the 2019 value of that
##                       percentile are they? This is the estimand the rest of
##                       the paper uses: D(p) compares the 2019 and 2024
##                       distributions, which are different cohorts, so every
##                       comparison in the paper is already about positions
##                       rather than people.
##
##   residual_tracked()  the GROUP question. Take the students who started at
##                       percentile p and follow them. A pi(p) share gains
##                       delta and the rest gain nothing, so on average the
##                       group gains pi(p)*delta. Reshuffling is irrelevant
##                       because the group membership is fixed.
##
## The two diverge wherever a percentile holds both treated and untreated
## students, because the group's MEAN moves by pi*delta while the distribution
## the group turns into is wider than the one it came from. They agree exactly
## where participation is 0 or 1 at the percentiles being read.
##
## residual_tracked is the linear calculation this script used through
## September 2026. It was correct for the group question and mislabelled as an
## answer to the distributional one.
Q2024_fn <- make_quantile_fn(PS, z$q2019 + z$d)
after_fn <- calibrated_program_quantiles(Q2024_fn, G*S, PS, z$q2019 + z$d)
residual         <- function(fn, B) setNames(z$q2019 - after_fn(fn, B), PS)
residual_tracked <- function(fn, B) setNames(deficit - fn(PS, B) * G * S, PS)

budgets <- seq(0.05, 1.00, by=0.01)
grid <- bind_rows(lapply(names(RULES), function(rn)
  bind_rows(lapply(budgets, function(B) {
    r <- residual(RULES[[rn]], B)
    tibble(rule=rn, budget=B,
           res_p10=r[PS==10], res_p90=r[PS==90],
           differential = r[PS==90] - r[PS==10],
           ## Same quantity on the memo's sign convention, where a larger
           ## number is a wider gap. Carried explicitly so a reader of the CSV
           ## does not have to infer which way the sign runs.
           gap_remaining = -(r[PS==90] - r[PS==10]),
           ## The group-tracking estimand alongside it, same sign convention.
           gap_remaining_tracked = local({
             rt <- residual_tracked(RULES[[rn]], B); -(rt[PS==90] - rt[PS==10]) }))
  }))))
grid$rule <- factor(grid$rule, levels=names(RULES))

obs_diff <- deficit[["90"]] - deficit[["10"]]   # negative: p10 deficit is larger

## ---- Figure 13: what a fixed seat budget does to the 90-10 spread ----------
f13 <- ggplot(grid, aes(budget, -differential, colour=rule)) +
  geom_hline(yintercept=-obs_diff, linetype="dashed", colour="grey45") +
  annotate("text", x=0.62, y=-obs_diff, hjust=0.5, vjust=1.5, size=3, colour="grey35",
           label=sprintf("no program: %.1f points", -obs_diff)) +
  geom_hline(yintercept=0, colour="grey70", linewidth=0.3) +
  geom_line(linewidth=0.95) +
  scale_x_continuous("Seat budget: share of ALL students who can be served",
                     labels=percent_format(accuracy=1)) +
  scale_y_continuous("Remaining 90-10 gap after the program (NAEP points)") +
  scale_colour_brewer(palette="Dark2") +
  labs(title=sprintf("Helping the whole district: where the seats go decides the shape (%s)", CELL),
       subtitle=paste("Every rule spends the SAME number of seats and delivers the same 0.155 SD to whoever takes them.",
                      "\nOnly the allocation differs. Lower is a narrower gap; the dashed line is doing nothing."),
       caption=paste("Every curve meets the no-program line at full coverage, because a budget that reaches everyone",
                     "\nleaves the shape alone whoever it was aimed at. Below that, note where the PROPORTIONAL curve sits: it targets",
                     "\nnobody and still widens the gap, because partial coverage splits each percentile into treated and",
                     "\nuntreated students and a distribution split that way is wider than the one it started as. That curve,",
                     "\nnot the dashed line, is the bar a targeted rule has to beat. Bottom-up is the only rule that clears it,",
                     "\nand only once the budget overshoots the percentile being moved: at exactly 10 percent of seats the",
                     "\ntreated bottom decile leapfrogs the untreated students above it and the new bottom decile refills from",
                     "\nstudents the program never touched. Public NAEP Data Service API; treated effect from Kraft, Schueler",
                     "\nand Falken (2024); take-up gradient from Robinson et al. (2025); mixture outcome model, see analysis/mixture.R."),
       colour=NULL) +
  theme_minimal(base_size=11) +
  theme(panel.grid.minor=element_blank(), legend.position="top",
        plot.title=element_text(face="bold", size=13),
        plot.subtitle=element_text(colour="grey30", size=9.5),
        plot.caption=element_text(colour="grey45", size=7.5, hjust=0))
fn13 <- file.path(OUT, sprintf("fig13-seat-allocation-%s.png",
                               gsub("[^A-Za-z0-9]+","-",tolower(CELL))))
ggsave(fn13, f13, width=9.2, height=6.2, dpi=200)
message("wrote ", fn13)

## ---- Figure 14: the residual QD curve at a realistic budget ----------------
B0 <- 0.13    # Callen et al.: 12.7 percent of all students attended summer school
curves <- bind_rows(lapply(names(RULES), function(rn)
  tibble(rule=rn, percentile=PS, residual=residual(RULES[[rn]], B0)))) %>%
  bind_rows(tibble(rule="No program", percentile=PS, residual=as.numeric(deficit)))
curves$rule <- factor(curves$rule, levels=c("No program", names(RULES)))

f14 <- ggplot(curves, aes(percentile, -residual, colour=rule, linetype=rule)) +
  geom_hline(yintercept=0, colour="grey40") +
  geom_line(linewidth=0.9) + geom_point(size=1.9) +
  scale_x_continuous("Percentile", breaks=PS) +
  scale_y_continuous("Remaining shortfall vs 2019 (NAEP points)") +
  scale_colour_manual(values=c("No program"="grey35", "Bottom-up (lowest first)"="#1B9E77",
                               "Proportional (untargeted)"="#D95F02",
                               "Opt-in gradient"="#7570B3",
                               "Eligibility screen (ECONDIS)"="#E7298A")) +
  scale_linetype_manual(values=c("No program"="dashed", "Bottom-up (lowest first)"="solid",
                                 "Proportional (untargeted)"="solid",
                                 "Opt-in gradient"="solid",
                                 "Eligibility screen (ECONDIS)"="solid")) +
  labs(title=sprintf("The same seats, spent four ways (%s)", CELL),
       subtitle=sprintf(paste("Seat budget fixed at %.0f percent of all students, the rate Callen et al. observed for summer school.",
                              "\nTreated effect 0.155 SD. Closer to zero is better."), B0*100),
       caption=paste("Bottom-up allocation concentrates the entire budget below the 13th percentile, cutting the p10",
                     "shortfall\nfrom 10.0 to 4.0 points while leaving every other percentile untouched. Proportional allocation",
                     "offers\nevery percentile the same rate and still leaves the bottom further behind than the top, because at",
                     "partial\ncoverage the treated and untreated split apart within each percentile. The opt-in gradient lifts the",
                     "top\nmost, which the evidence suggests is the most likely outcome in practice."),
       colour=NULL, linetype=NULL) +
  theme_minimal(base_size=11) +
  theme(panel.grid.minor=element_blank(), legend.position="top",
        plot.title=element_text(face="bold", size=13),
        plot.subtitle=element_text(colour="grey30", size=9.5),
        plot.caption=element_text(colour="grey45", size=7.5, hjust=0))
fn14 <- file.path(OUT, sprintf("fig14-seats-four-ways-%s.png",
                               gsub("[^A-Za-z0-9]+","-",tolower(CELL))))
ggsave(fn14, f14, width=9.2, height=6.2, dpi=200)
message("wrote ", fn14)

## ---- console summary -------------------------------------------------------
cat(sprintf("\n%s: 90-10 gap remaining after a program, by rule and seat budget\n", CELL))
cat(sprintf("(no program: %.1f points)\n\n", -obs_diff))
cat(sprintf("%-30s", "rule")); for (B in c(0.10,0.13,0.25,0.50,1.00)) cat(sprintf("%9s", percent(B, accuracy=1))); cat("\n")
for (rn in names(RULES)) {
  cat(sprintf("%-30s", rn))
  for (B in c(0.10,0.13,0.25,0.50,1.00)) {
    r <- residual(RULES[[rn]], B); cat(sprintf("%9.1f", -(r[PS==90]-r[PS==10])))
  }
  cat("\n")
}
cat("\nSame rules read as a group question: how the STUDENTS who started at p10\n")
cat("and p90 fared on average, which ignores reshuffling.\n\n")
cat(sprintf("%-30s%9s%9s%9s%9s\n", "rule", "13% grp", "13% dist", "50% grp", "50% dist"))
for (rn in names(RULES)) {
  cat(sprintf("%-30s", rn))
  for (B in c(0.13, 0.50)) {
    rt <- residual_tracked(RULES[[rn]], B); r <- residual(RULES[[rn]], B)
    cat(sprintf("%9.1f%9.1f", -(rt[PS==90]-rt[PS==10]), -(r[PS==90]-r[PS==10])))
  }
  cat("\n")
}
write.csv(grid, file.path(TABLES, sprintf("sim-seat-allocation-%s.csv",
          gsub("[^A-Za-z0-9]+","-",tolower(CELL)))), row.names=FALSE)

## ---- Figure 15: the allocation rules themselves, pi(p) vs p ----------------
## Distinct from figures 13/14, which show what a rule DOES to the score
## distribution. This shows the mechanism: what share of each percentile
## actually holds a seat. Three of the four rules depend on percentile and
## budget only, but the eligibility screen follows the CELL's measured ECONDIS
## shares, so the figure is cell-specific and the filename carries the cell
## like figures 13 and 14 do. A single unsuffixed file here would silently
## show whichever cell ran last under a caption naming another.
CURVE_BUDGETS <- c(0.13, 0.25, 0.50, 0.75)
pgrid <- 1:99
curve_grid <- bind_rows(lapply(names(RULES), function(rn)
  bind_rows(lapply(CURVE_BUDGETS, function(B)
    tibble(rule=rn, budget=B, percentile=pgrid, pi=RULES[[rn]](pgrid, B))))))
curve_grid$rule <- factor(curve_grid$rule, levels=names(RULES))
curve_grid$budget_lab <- factor(percent(curve_grid$budget, accuracy=1),
                                levels=percent(CURVE_BUDGETS, accuracy=1))

f15 <- ggplot(curve_grid, aes(percentile, pi, colour=rule)) +
  geom_hline(yintercept=1, colour="grey85", linewidth=0.3) +
  geom_line(linewidth=0.9) +
  facet_wrap(~budget_lab, nrow=1) +
  scale_x_continuous("Percentile", breaks=c(10,25,50,75,90)) +
  scale_y_continuous("Participation rate (share of students at that percentile)",
                     labels=percent_format(accuracy=1), limits=c(0,1)) +
  scale_colour_manual(values=c("Bottom-up (lowest first)"="#1B9E77",
                               "Proportional (untargeted)"="#D95F02",
                               "Opt-in gradient"="#7570B3",
                               "Eligibility screen (ECONDIS)"="#E7298A")) +
  labs(title="How each rule spends the same seat budget",
       subtitle="Participation rate by percentile, at four example budgets. Panels share the same seat total; only the shape differs.",
       caption=paste("Bottom-up fills from the lowest percentile and is a step function: 1 below the budget's cutoff, 0 above.",
                     "\nProportional is flat by construction. The opt-in gradient rises with achievement, doubling every 40",
                     "\npercentile points (10% at p10, 20% at p50, 40% at p90), and is capped and water-filled once a percentile",
                     "\nwould exceed 100 percent participation, which is visible as the curve flattening at high budgets. The",
                     sprintf("\neligibility screen follows the measured ECONDIS share (cell-specific; shown here for %s)", CELL),
                     "\nand is also water-filled. Every curve's mean over the population equals the budget shown at the top of",
                     "\nits panel."),
       colour=NULL) +
  theme_minimal(base_size=11) +
  theme(panel.grid.minor=element_blank(), legend.position="top",
        plot.title=element_text(face="bold", size=13),
        plot.subtitle=element_text(colour="grey30", size=9),
        plot.caption=element_text(colour="grey45", size=7.5, hjust=0),
        strip.text=element_text(face="bold"))
fn15 <- file.path(OUT, sprintf("fig15-allocation-curves-%s.png",
                               gsub("[^A-Za-z0-9]+","-",tolower(CELL))))
ggsave(fn15, f15, width=11.5, height=4.6, dpi=200)
message("wrote ", fn15)

## ---- Table: participation share at the five target percentiles ------------
## One row per rule x budget, columns p10/p25/p50/p75/p90. This is the table
## version of figure 15 -- the numbers behind the curves, at the same example
## budgets the memo's gap tables already use (10, 13, 25, 50, 75, 100 percent).
TABLE_BUDGETS <- c(0.10, 0.13, 0.25, 0.50, 0.75, 1.00)
TARGET_PS <- c(10, 25, 50, 75, 90)
share_tbl <- bind_rows(lapply(names(RULES), function(rn)
  bind_rows(lapply(TABLE_BUDGETS, function(B) {
    v <- RULES[[rn]](TARGET_PS, B)
    as_tibble(setNames(as.list(v), paste0("p", TARGET_PS))) %>%
      mutate(cell=CELL, rule=rn, budget=B, .before=1)
  }))))
fn_shares <- file.path(TABLES, sprintf("sim-allocation-shares-%s.csv",
                                       gsub("[^A-Za-z0-9]+","-",tolower(CELL))))
write.csv(share_tbl, fn_shares, row.names=FALSE)
message("wrote ", fn_shares)

cat("\nParticipation share (%) at the five target percentiles, by rule and budget\n")
cat(sprintf("(cell-independent except the eligibility screen, shown for %s)\n\n", CELL))
for (B in TABLE_BUDGETS) {
  cat(sprintf("-- %s of seats --\n", percent(B, accuracy=1)))
  cat(sprintf("%-30s", "rule")); for (p in TARGET_PS) cat(sprintf("%7s", paste0("p",p))); cat("\n")
  for (rn in names(RULES)) {
    v <- RULES[[rn]](TARGET_PS, B)
    cat(sprintf("%-30s", rn)); for (x in v) cat(sprintf("%7.1f", x*100)); cat("\n")
  }
  cat("\n")
}
