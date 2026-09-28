#!/usr/bin/env Rscript
## Effect-size benchmarks by grade, subject, and study size, from the Kraft
## (2023) effect-size database in kraft-2023-data/.
##
## Replicates the sample-size columns of Kraft (2023) Table 1 within grade and
## subject, restricted to broad standardized tests, on three of Kraft's study
## size bins (251 to 500, 501 to 2,000, more than 2,000). Those are the same
## bins used for the district K-5 enrollment distribution in
## 08-district-enrollment.R, so a district's enrollment can be read against the
## effects that evaluated interventions of that scale delivered.
##
## Definitions:
##   grade      "4" and "8": the study's sample included that grade (Kraft's
##              grade indicators are not mutually exclusive; a multi-grade study
##              enters every grade it covers). "3 to 5": any of grades 3, 4, 5.
##   subject    Reading or Math, as coded by Kraft.
##   broad      Narrow test / subtest == 0 (composite subject measures only).
##   size bin   Kraft's study sample size (treatment plus control), his bins.
##              "All sizes" pools every broad effect for the cell, including
##              studies of 250 or fewer and those with no sample size.
##   weighted mean  weights are the study sample size, as in Kraft's table.
##   percentiles    type-7 quantiles of the raw effect sizes, one per effect.
##
## Inputs:  kraft-2023-data/kraft2023effectsize.xls   (public; 3,426 effects)
##          tables/sim-quantiles.csv                    (optional; g* reference lines)
##          tables/district-enrollment-2324-bins.csv    (optional; K-5 share labels)
## Outputs: tables/kraft-2023-benchmarks-by-grade-size.csv
##          tables/kraft-2023-benchmarks-manifest.txt
##          figures/kraft/fig-k1-benchmarks-by-size.png       (reference line g*(p10))
##          figures/kraft/fig-k2-benchmarks-by-size-p25.png   (g*(p25))
##          figures/kraft/fig-k3-benchmarks-by-size-p50.png   (g*(p50), the median)
##          figures/kraft/fig-k4-benchmarks-by-size-p75.png   (g*(p75))
##          figures/kraft/fig-k5-benchmarks-by-size-p90.png   (g*(p90))
##          tables/kraft-2023-benchmarks-vs-requirement.csv    (share of effects below each g*(p), effect- and
##                                                              study-weighted, and at g* +/- 1.96 SE; g_star is
##                                                              stored rounded to 3 decimals but shares use the
##                                                              unrounded value; when sim-quantiles.csv exists)
##          tables/kraft-2023-benchmarks-by-target.csv         (when studies/coding.csv exists)
##          figures/kraft/fig-k6-benchmarks-by-target.png      (same design, dodged by target code; g*(p10) line)
##
## Shared definitions (grade rules, size bins, the cell filter, the file reader)
## live in analysis/kraft-helpers.R, also sourced by naep-aera-open's 20-rq3-robustness.R.
##
## Usage: Rscript analysis/09-kraft-benchmarks.R

suppressPackageStartupMessages(library(ggplot2))
source(file.path("analysis", "kraft-helpers.R"))

OUT_TAB <- "tables"
OUT_FIG <- file.path("figures", "kraft")
dir.create(OUT_TAB, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_FIG, showWarnings = FALSE, recursive = TRUE)

## ----------------------------------------------------------------- read

raw <- kraft_read()

## Reproduce Kraft's Table 1 overall column before trusting the file. These
## are the published values; a mismatch means the wrong file or a bad read.
overall <- raw[, .(k = .N,
                   p30 = quantile(es, .30), p50 = quantile(es, .50), p70 = quantile(es, .70),
                   share_lt_05 = mean(es < 0.05))]
check_t1 <- overall$k == 3426 &&
  abs(overall$p30 - 0.02) < 0.005 && abs(overall$p50 - 0.10) < 0.005 &&
  abs(overall$p70 - 0.21) < 0.005 && abs(overall$share_lt_05 - 0.36) < 0.005
if (!check_t1) stop("The file does not reproduce Kraft (2023) Table 1; refusing to continue.")

## ----------------------------------------------------------------- cells

## GRADES, SUBJECTS, BINS, and PROBS come from kraft-helpers.R.

summarise_cell <- function(d, grade, subject, size_bin) {
  w <- d$n
  wm <- if (all(is.na(w))) NA_real_ else sum(d$es * w, na.rm = TRUE) / sum(w[!is.na(d$es)], na.rm = TRUE)
  q <- if (nrow(d) > 0) quantile(d$es, PROBS, type = 7) else rep(NA_real_, length(PROBS))
  data.table(grade = grade, subject = subject, size_bin = size_bin,
             k = nrow(d), studies = uniqueN(d$study_id[!is.na(d$study_id)]),
             mean = mean(d$es), weighted_mean = wm,
             share_below_005 = mean(d$es < 0.05),
             p10 = q[1], p25 = q[2], p50 = q[3], p75 = q[4], p90 = q[5])
}

rows <- list()
for (g in names(GRADES)) for (s in SUBJECTS) for (b in names(BINS)) {
  d <- kraft_cell(raw, g, s, b)
  rows[[length(rows) + 1]] <- summarise_cell(d, g, s, b)
}
bench <- rbindlist(rows)
num_cols <- c("mean", "weighted_mean", "share_below_005", "p10", "p25", "p50", "p75", "p90")
bench[, (num_cols) := lapply(.SD, round, 3), .SDcols = num_cols]
## Cells with fewer than 10 studies are kept in the table but flagged so a
## reader does not quote them (grade 8 math, 251 to 500, has six).
bench[, thin := studies < 10]

fwrite(bench, file.path(OUT_TAB, "kraft-2023-benchmarks-by-grade-size.csv"))

## ----------------------------------------------------------------- figure

## Dot-and-interval small multiples: one panel per grade-subject cell, study
## size on x, effect size on y. The thin line spans P10 to P90, the thick line
## P25 to P75, the point is the median. Dotted horizontal lines mark the
## restoration requirement g*(p10) for the matching NAEP cell when the simulation
## quantiles file exists. Under each bin, the share of K-5 students in
## districts of that size, from the CCD distribution, when that file exists.
plot_bins <- PLOT_BINS
fig <- bench[grade %in% c("4", "8") & size_bin %in% plot_bins]
fig[, cell := paste(subject, paste0("G", grade))]
fig[, cell := factor(cell, levels = CELLS_FEAT)]
fig[, size_bin := factor(size_bin, levels = plot_bins)]

req_path <- file.path(OUT_TAB, "sim-quantiles.csv")
req_all <- if (file.exists(req_path)) fread(req_path)[cell %in% CELLS_FEAT, .(cell, percentile, g_star, g_star_se)] else NULL

k5_path <- file.path(OUT_TAB, "district-enrollment-2324-bins.csv")
k5 <- if (file.exists(k5_path)) {
  fread(k5_path)[universe == "regular" & measure == "k5" & bin %in% plot_bins,
                 .(size_bin = factor(bin, levels = plot_bins), share_students)]
} else NULL
x_labels <- if (!is.null(k5)) {
  setNames(sprintf("%s\n(%s of K-5\nstudents)", plot_bins,
                   scales::percent(k5[match(plot_bins, as.character(size_bin)), share_students], accuracy = 1)),
           plot_bins)
} else setNames(plot_bins, plot_bins)

theme_k <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        plot.subtitle = element_text(colour = "grey30", size = 10),
        plot.caption = element_text(colour = "grey45", size = 8, hjust = 0),
        strip.text = element_text(face = "bold"))

## g*(p) for one percentile, as a data.table with cell as a factor in panel
## order, for the reference lines in fig-k1 to fig-k6. NULL when the simulation
## quantiles file is absent.
req_at <- function(pctl) {
  if (is.null(req_all)) return(NULL)
  r <- req_all[percentile == pctl, .(cell, g_star)]
  r[, cell := factor(cell, levels = CELLS_FEAT)]
  r
}

## One figure per reference percentile. The dotted line is g*(p) for the
## chosen p: the effect that would return the 2024 p-th percentile to its 2019
## value. Called for p10, p25, p50, p75, and p90.
plot_benchmarks <- function(pctl, fn) {
  req <- req_at(pctl)
  pname <- switch(as.character(pctl), "10" = "10th percentile", "25" = "25th percentile",
                  "50" = "median", paste0(pctl, "th percentile"))
  plabel <- switch(as.character(pctl), "50" = "restore the median", paste0("restore p", pctl))
  p <- ggplot(fig, aes(size_bin, p50)) +
    geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.4) +
    geom_linerange(aes(ymin = p10, ymax = p90), colour = "#2166AC", linewidth = 0.6) +
    geom_linerange(aes(ymin = p25, ymax = p75), colour = "#2166AC", linewidth = 2.2) +
    geom_point(colour = "#2166AC", fill = "white", shape = 21, size = 2.8, stroke = 1) +
    geom_text(aes(y = p10, label = sprintf("k = %d\n(%d studies)", k, studies)), vjust = 1.3, size = 2.4,
              lineheight = 0.9, colour = "grey35") +
    { if (!is.null(req)) geom_hline(data = req, aes(yintercept = g_star), linetype = "dotted", colour = "#B2182B") } +
    { if (!is.null(req)) geom_text(data = req, aes(x = 3.45, y = g_star, label = paste("effect needed to", plabel)),
                                   hjust = 1, vjust = -0.5, size = 2.6, colour = "#B2182B") } +
    facet_wrap(~ cell, ncol = 2) +
    scale_x_discrete(labels = x_labels) +
    scale_y_continuous(breaks = seq(-0.2, 1.2, 0.2)) +
    coord_cartesian(ylim = c(-0.27, 1.15)) +
    labs(title = paste("Effects of evaluated interventions by study size, against the effect needed to restore the", pname) |>
           strwrap(width = 85) |> paste(collapse = "\n"),
         subtitle = paste(strwrap("Kraft (2023) RCT effect sizes on broad tests from studies covering the grade; median (point), P25 to P75 (thick), P10 to P90 (thin); k is the number of effect sizes, with the number of studies beneath it", width = 130), collapse = "\n"),
         caption = paste(strwrap(paste(
           "Effect sizes in SD units from Kraft (2023), broad standardized tests only. k is the number of effect sizes, not studies; a study contributes one effect per outcome and grade it reports, so the study count is shown beneath it. Grade means the study sample included that grade.",
           sprintf("Study size bins follow Kraft's Table 1. Dotted red line is the effect needed to return the 2024 %s to its 2019 value.", pname),
           "Percent labels: share of K-5 students in regular districts of that size, CCD 2023-24.",
           "Grade 8 math, 251 to 500 rests on six studies."), width = 160), collapse = "\n"),
         x = NULL, y = "Effect size (SD)") +
    theme_k
  ggsave(fn, p, width = 8.6, height = 7.2, dpi = 200)
}

plot_benchmarks(10, file.path(OUT_FIG, "fig-k1-benchmarks-by-size.png"))
plot_benchmarks(25, file.path(OUT_FIG, "fig-k2-benchmarks-by-size-p25.png"))
plot_benchmarks(50, file.path(OUT_FIG, "fig-k3-benchmarks-by-size-p50.png"))
plot_benchmarks(75, file.path(OUT_FIG, "fig-k4-benchmarks-by-size-p75.png"))
plot_benchmarks(90, file.path(OUT_FIG, "fig-k5-benchmarks-by-size-p90.png"))

## ----------------------------------------------------------------- requirement vs benchmark

## Where does each restoration requirement fall in the distribution of
## evaluated effects? For every featured NAEP cell, size bin, and percentile p,
## the share of Kraft effect sizes (same grade, subject, broad-test, and size
## filters as the benchmark table) that are smaller than g*(p). A share of 0.95
## means the effect needed exceeds 95 percent of the effects that RCTs of that
## size delivered. This is a rank, not a ratio: it stays interpretable when the
## bin median is near zero (grade 4 math, more than 2,000 students, P50 = 0.01).
##
## Two weightings. share_effects_below counts every effect size once, so a study
## that reports many outcomes counts many times. share_studies_below gives each
## study a total weight of one (each of its effects weighs 1 / its count in the
## cell), so the rank describes studies rather than outcomes. The _lo and _hi
## columns repeat the effect-weighted share at g* - 1.96 SE and g* + 1.96 SE,
## carrying the NAEP sampling uncertainty in g* into the rank.
share_below <- function(es, x, w = rep(1, length(es))) sum(w * (es < x)) / sum(w)
req_rank <- NULL
if (!is.null(req_all)) {
  rank_rows <- list()
  for (cl in CELLS_FEAT) {
    g <- cell_grade(cl)
    s <- cell_subject(cl)
    r <- req_all[cell == cl]
    for (b in names(BINS)) {
      d <- kraft_cell(raw, g, s, b)
      w_study <- 1 / d[, .N, by = study_id][match(d$study_id, study_id), N]
      rank_rows[[length(rank_rows) + 1]] <- data.table(
        cell = cl, grade = g, subject = s, size_bin = b, percentile = r$percentile,
        g_star = round(r$g_star, 3), k = nrow(d), studies = uniqueN(d$study_id[!is.na(d$study_id)]),
        share_effects_below = round(vapply(r$g_star, function(x) share_below(d$es, x), numeric(1)), 3),
        share_studies_below = round(vapply(r$g_star, function(x) share_below(d$es, x, w_study), numeric(1)), 3),
        share_effects_below_lo = round(vapply(r$g_star - 1.96 * r$g_star_se, function(x) share_below(d$es, x), numeric(1)), 3),
        share_effects_below_hi = round(vapply(r$g_star + 1.96 * r$g_star_se, function(x) share_below(d$es, x), numeric(1)), 3))
    }
  }
  req_rank <- rbindlist(rank_rows)
  fwrite(req_rank, file.path(OUT_TAB, "kraft-2023-benchmarks-vs-requirement.csv"))
}

## ----------------------------------------------------------------- by target population

## When the Stage 6 coding file exists, split every cell by whom the study
## served (universal, targeted_low, targeted_other, unclear; see
## kraft-2023-data/CODEBOOK.md). Effects whose study is outside the 254 coded
## studies get not_coded; a pooled row per cell must equal the main table.
coding_path <- file.path("kraft-2023-data", "studies", "coding.csv")
by_target <- NULL
if (file.exists(coding_path)) {
  coding <- fread(coding_path, colClasses = "character")[, .(study_id = as.numeric(study_id), target = code)]
  raw_t <- merge(raw, coding, by = "study_id", all.x = TRUE)
  raw_t[is.na(target), target := "not_coded"]
  TARGETS <- c("universal", "targeted_low", "targeted_other", "unclear", "not_coded")
  rows_t <- list()
  for (g in names(GRADES)) for (s in SUBJECTS) for (b in names(BINS)) {
    d <- kraft_cell(raw_t, g, s, b)
    for (t in c(TARGETS, "pooled")) {
      dd <- if (t == "pooled") d else d[target == t]
      r <- summarise_cell(dd, g, s, b)
      r[, target := t]
      rows_t[[length(rows_t) + 1]] <- r
    }
  }
  by_target <- rbindlist(rows_t)
  by_target[, (num_cols) := lapply(.SD, round, 3), .SDcols = num_cols]
  by_target[, thin := studies < 10]
  setcolorder(by_target, c("grade", "subject", "size_bin", "target"))
  ## The pooled rows must reproduce the main table exactly.
  chk <- merge(by_target[target == "pooled"], bench, by = c("grade", "subject", "size_bin"))
  stopifnot(all(chk$k.x == chk$k.y), all(chk$p50.x == chk$p50.y))
  fwrite(by_target, file.path(OUT_TAB, "kraft-2023-benchmarks-by-target.csv"))

  ## Figure k6: the same dot-and-interval design as k1 to k5, with the four
  ## target codes dodged within each size bin. not_coded is left out of the
  ## figure (it is in the table). One fixed hue per code, checked with the
  ## dataviz palette validator; the point shape also encodes the code so
  ## identity is never color alone.
  TARGET_COLS <- c(universal = "#2166AC", targeted_low = "#B2182B", targeted_other = "#762A83", unclear = "#1B7837")
  TARGET_LABS <- c(universal = "Universal", targeted_low = "Targeted: low achievers",
                   targeted_other = "Targeted: other group", unclear = "Unclear")
  fig_t <- by_target[grade %in% c("4", "8") & size_bin %in% plot_bins & target %in% names(TARGET_COLS) & k > 0]
  fig_t[, cell := factor(paste(subject, paste0("G", grade)), levels = CELLS_FEAT)]
  fig_t[, size_bin := factor(size_bin, levels = plot_bins)]
  fig_t[, target := factor(target, levels = names(TARGET_COLS))]
  pd <- position_dodge(width = 0.7)
  ## Same g*(p10) reference line as fig-k1, drawn without inheriting the
  ## target aesthetics so it does not enter the legend.
  req10 <- req_at(10)
  p6 <- ggplot(fig_t, aes(size_bin, p50, colour = target, shape = target, group = target)) +
    geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.4) +
    { if (!is.null(req10)) geom_hline(data = req10, aes(yintercept = g_star), linetype = "dotted",
                                      colour = "#B2182B") } +
    { if (!is.null(req10)) geom_text(data = req10, aes(x = 3.45, y = g_star, label = "effect needed to restore p10"),
                                     hjust = 1, vjust = -0.5, size = 2.6, colour = "#B2182B", inherit.aes = FALSE) } +
    geom_linerange(aes(ymin = p10, ymax = p90), linewidth = 0.6, position = pd) +
    geom_linerange(aes(ymin = p25, ymax = p75), linewidth = 2.2, position = pd) +
    geom_point(fill = "white", size = 2.6, stroke = 1, position = pd) +
    geom_text(aes(y = p10, label = k), vjust = 1.4, size = 2.2, position = pd, colour = "grey35", show.legend = FALSE) +
    facet_wrap(~ cell, ncol = 2) +
    scale_colour_manual(values = TARGET_COLS, labels = TARGET_LABS, name = NULL) +
    scale_shape_manual(values = c(universal = 21, targeted_low = 24, targeted_other = 22, unclear = 23), labels = TARGET_LABS, name = NULL) +
    scale_x_discrete(labels = x_labels) +
    scale_y_continuous(breaks = seq(-0.2, 1.2, 0.2)) +
    coord_cartesian(ylim = c(-0.27, 1.15)) +
    labs(title = "Effects of evaluated interventions by study size and by whom the study served",
         subtitle = paste(strwrap("Kraft (2023) RCT effect sizes on broad tests from studies covering the grade, split by the sample's eligibility rule; median (point), P25 to P75 (thick), P10 to P90 (thin); the number under each interval is k, the count of effect sizes", width = 130), collapse = "\n"),
         caption = paste(strwrap(paste(
           "Effect sizes in SD units from Kraft (2023), broad standardized tests only. Target population hand-coded from each study's sample description (kraft-2023-data/CODEBOOK.md): universal means no eligibility rule beyond grade or site; targeted low achievers means selection on prior achievement; targeted other means selection on another characteristic such as English learner status, disability, or school poverty; unclear means the source does not say.",
           "Effects from studies outside the 254 coded studies are omitted here and reported as not_coded in the table. Intervals resting on fewer than 10 studies are flagged thin in the table.",
           "Dotted red line is the effect needed to return the 2024 10th percentile to its 2019 value."), width = 160), collapse = "\n"),
         x = NULL, y = "Effect size (SD)") +
    theme_k + theme(legend.position = "top")
  ggsave(file.path(OUT_FIG, "fig-k6-benchmarks-by-target.png"), p6, width = 8.6, height = 7.6, dpi = 200)
}

## ----------------------------------------------------------------- manifest

sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) "unknown")
## Package versions next to the R version, so a changed output can be traced
## to a package upgrade (a readxl or data.table release that parses a column
## differently would otherwise leave no trace here).
pkg_versions <- paste(vapply(c("data.table", "readxl", "ggplot2", "scales"), function(p)
  paste(p, as.character(packageVersion(p))), character(1)), collapse = ", ")
writeLines(c(
  sprintf("generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("git: %s", sha),
  sprintf("R: %s", R.version.string),
  sprintf("packages: %s", pkg_versions),
  sprintf("input: %s (%d effect sizes)", KRAFT_XLS, nrow(raw)),
  sprintf("Table 1 reproduction: k=%d p30=%.2f p50=%.2f p70=%.2f share<0.05=%.2f (published: 3426, 0.02, 0.10, 0.21, 0.36)",
          overall$k, overall$p30, overall$p50, overall$p70, overall$share_lt_05),
  sprintf("g* reference lines: %s", if (is.null(req_all)) "absent (tables/sim-quantiles.csv not found)" else "from tables/sim-quantiles.csv (p10 to p90)"),
  sprintf("K-5 share labels: %s", if (is.null(k5)) "absent" else "from tables/district-enrollment-2324-bins.csv"),
  sprintf("requirement ranks: %s", if (is.null(req_rank)) "absent" else
    sprintf("kraft-2023-benchmarks-vs-requirement.csv, %d rows", nrow(req_rank))),
  sprintf("by-target table: %s", if (is.null(by_target)) "absent (kraft-2023-data/studies/coding.csv not found)" else
    sprintf("kraft-2023-benchmarks-by-target.csv, %d rows; coded studies %d", nrow(by_target), uniqueN(coding$study_id)))
), file.path(OUT_TAB, "kraft-2023-benchmarks-manifest.txt"))

message("Done: ", nrow(bench), " cells written; Table 1 reproduced.")
