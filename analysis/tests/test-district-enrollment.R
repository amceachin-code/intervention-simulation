#!/usr/bin/env Rscript
## Checks on the committed outputs of analysis/08-district-enrollment.R.
## Runs against tables/ only: no CCD files and no network needed.
##
## Usage: Rscript analysis/tests/test-district-enrollment.R

suppressPackageStartupMessages(library(data.table))

pct  <- fread("tables/district-enrollment-2324-percentiles.csv")
bins <- fread("tables/district-enrollment-2324-bins.csv")

fails <- 0L; checks <- 0L
check <- function(ok, msg) {
  checks <<- checks + 1L
  if (!isTRUE(ok)) { fails <<- fails + 1L; cat("FAIL:", msg, "\n") } else cat("ok:  ", msg, "\n")
}

## 1. Structure: three universes, two measures, two weightings, eight percentiles.
check(setequal(unique(pct$universe), c("all_lea", "regular", "regular_charter")), "three universes present")
check(setequal(unique(pct$measure), c("total", "grade4", "k5")), "three measures present")
check(nrow(pct) == 3 * 3 * 2 * 8, "percentile table has 144 rows")

## 2. Percentiles are non-decreasing within each universe, measure, weighting.
mono <- pct[order(percentile), .(ok = !is.unsorted(value)), by = .(universe, measure, weighting)]
check(all(mono$ok), "percentiles non-decreasing in every series")

## 3. Student weighting never sits below district weighting at the same
##    percentile: larger districts hold more students, so the student
##    distribution of district size stochastically dominates.
w <- dcast(pct, universe + measure + percentile ~ weighting, value.var = "value")
check(all(w$student >= w$district), "student-weighted >= district-weighted at every percentile")

## 4. Universe nesting: regular is a subset of regular_charter, which is a subset of all_lea.
n <- unique(pct[, .(universe, measure, n_districts, students)])
nt <- n[measure == "total"]
check(nt[universe == "regular", n_districts] <= nt[universe == "regular_charter", n_districts] &
      nt[universe == "regular_charter", n_districts] <= nt[universe == "all_lea", n_districts],
      "district counts nest across universes")
check(nt[universe == "regular", students] <= nt[universe == "regular_charter", students] &
      nt[universe == "regular_charter", students] <= nt[universe == "all_lea", students],
      "student counts nest across universes")

## 5. Grade 4 districts are a subset of total districts, and grade 4 students are
##    fewer than total students, within each universe.
ng <- dcast(n, universe ~ measure, value.var = c("n_districts", "students"))
check(all(ng$n_districts_grade4 <= ng$n_districts_total), "grade 4 district count <= total district count")
check(all(ng$students_grade4 < ng$students_total), "grade 4 students < total students")
check(all(ng$students_grade4 < ng$students_k5) && all(ng$students_k5 < ng$students_total), "grade 4 < K-5 < total students")
check(all(ng$n_districts_grade4 <= ng$n_districts_k5), "grade 4 district count <= K-5 district count")

## 6. Bins: shares sum to one, cumulative shares end at one, counts add up to
##    the percentile table's totals.
bs <- bins[, .(sd = sum(share_districts), ss = sum(share_students),
               cd = last(cum_share_districts), cs = last(cum_share_students),
               nd = sum(n_districts), st = sum(students)), by = .(universe, measure)]
check(all(abs(bs$sd - 1) < 1e-3) && all(abs(bs$ss - 1) < 1e-3), "bin shares sum to one")
check(all(abs(bs$cd - 1) < 1e-3) && all(abs(bs$cs - 1) < 1e-3), "cumulative shares end at one")
bs <- merge(bs, n, by = c("universe", "measure"))
check(all(bs$nd == bs$n_districts), "bin district counts match percentile table")
check(all(abs(bs$st - bs$students) < 1), "bin student totals match percentile table")

## 7. Sanity bounds on the headline universe. The US has on the order of 13,000
##    regular districts and 47 to 50 million public school students.
reg <- nt[universe == "regular"]
check(reg$n_districts > 10000 && reg$n_districts < 15000, "regular district count in a plausible range")
check(reg$students > 40e6 && reg$students < 52e6, "regular district student total in a plausible range")

cat(sprintf("\n%d checks, %d failures\n", checks, fails))
if (fails > 0) quit(status = 1)
