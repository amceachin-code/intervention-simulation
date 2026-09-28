## Shared definitions for the Kraft (2023) effect-size analyses.
## Sourced by 09-kraft-benchmarks.R (benchmark tables and figures) and
## 20-rq3-robustness.R in naep-aera-open (not in this project: study-weighted ranks, empirical Bayes check,
## meta-regression), so every script filters the effect sizes the same way.
##
## Definitions (see 09-kraft-benchmarks.R header for the full rationale):
##   grade      "4" and "8": the study's sample included that grade (Kraft's
##              grade indicators are not mutually exclusive). "3 to 5": any of
##              grades 3, 4, 5.
##   subject    Reading or Math, as coded by Kraft.
##   broad      Narrow test / subtest == 0.
##   size bin   Kraft's study sample size (treatment plus control), his bins;
##              "All sizes" pools every broad effect for the cell.

suppressPackageStartupMessages({
  library(data.table)
  library(readxl)
})

KRAFT_XLS <- file.path("kraft-2023-data", "kraft2023effectsize.xls")

GRADES <- list(
  "4"      = quote(grade4 == 1),
  "8"      = quote(grade8 == 1),
  "3 to 5" = quote(grade3 == 1 | grade4 == 1 | grade5 == 1)
)
SUBJECTS <- c("Reading", "Math")
## Bins are [lower, upper]; the labels match 08-district-enrollment.R exactly so
## the two tables join on size_bin.
BINS <- list(
  "251 to 500"      = quote(!is.na(n) & n >= 251  & n <= 500),
  "501 to 2,000"    = quote(!is.na(n) & n >= 501  & n <= 2000),
  "More than 2,000" = quote(!is.na(n) & n > 2000),
  "All sizes"       = quote(TRUE)
)
PLOT_BINS <- setdiff(names(BINS), "All sizes")
PROBS <- c(0.10, 0.25, 0.50, 0.75, 0.90)

## The four NAEP cells featured in the manuscript, in panel order.
CELLS_FEAT <- c("Reading G4", "Math G4", "Reading G8", "Math G8")
cell_grade   <- function(cl) sub(".* G", "", cl)
cell_subject <- function(cl) sub(" G.*", "", cl)

## Read the Kraft file with short column names. Stops if the file is missing
## or does not have the published 3,426 effects.
kraft_read <- function(path = KRAFT_XLS) {
  if (!file.exists(path)) stop("Kraft data not found at ", path)
  raw <- as.data.table(read_xls(path))
  setnames(raw, c("Effect size", "Academic subject", "Sample size",
                  "Narrow test / subtest", "Unique Study ID"),
           c("es", "subject", "n", "narrow", "study_id"))
  raw[, es := as.numeric(es)]
  raw[, n := as.numeric(n)]
  stopifnot(nrow(raw) == 3426, all(!is.na(raw$es)))
  raw
}

## The broad-test effects for one grade rule, subject, and size bin. Argument
## names differ from the column names on purpose: inside a data.table filter a
## bare `subject` would refer to the column, not the argument.
kraft_cell <- function(d, grade_rule, subj, bin) {
  d[eval(GRADES[[grade_rule]]) & subject == subj & narrow == 0 & eval(BINS[[bin]])]
}

## Approximate sampling variance of a standardized mean difference from a
## two-group trial with total sample size n split evenly:
## v = 4/n + d^2 / (2n). Kraft's file carries no standard errors, so this is
## the only variance available. It ignores clustering, so it understates the
## variance of cluster-randomized trials; any shrinkage built on it is too weak
## rather than too strong.
smd_var <- function(es, n) 4 / n + es^2 / (2 * n)
