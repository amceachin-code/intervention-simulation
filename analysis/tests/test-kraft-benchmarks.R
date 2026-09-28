#!/usr/bin/env Rscript
## Checks on the committed output of analysis/09-kraft-benchmarks.R.
## Runs against tables/ only: no spreadsheet read, no network.
##
## Usage: Rscript analysis/tests/test-kraft-benchmarks.R

suppressPackageStartupMessages(library(data.table))

b <- fread("tables/kraft-2023-benchmarks-by-grade-size.csv")

fails <- 0L; checks <- 0L
check <- function(ok, msg) {
  checks <<- checks + 1L
  if (!isTRUE(ok)) { fails <<- fails + 1L; cat("FAIL:", msg, "\n") } else cat("ok:  ", msg, "\n")
}

## 1. Structure: 3 grade rules x 2 subjects x 4 size bins.
check(nrow(b) == 3 * 2 * 4, "24 cells")
check(setequal(unique(b$size_bin), c("251 to 500", "501 to 2,000", "More than 2,000", "All sizes")),
      "four size bins present, labels match the district bins")
check(setequal(unique(b$subject), c("Reading", "Math")), "two subjects")

## 2. Percentiles ordered within each cell.
check(all(b$p10 <= b$p25 & b$p25 <= b$p50 & b$p50 <= b$p75 & b$p75 <= b$p90), "percentiles ordered")
check(all(b$share_below_005 >= 0 & b$share_below_005 <= 1), "shares within [0, 1]")

## 3. "All sizes" pools the three bins plus the studies they exclude, so its k
##    is at least the sum of the three binned k's.
s <- b[, .(binned = sum(k[size_bin != "All sizes"]), all = k[size_bin == "All sizes"]), by = .(grade, subject)]
check(all(s$all >= s$binned), "All sizes k >= sum of the three bins")

## 4. Grades 3 to 5 contain grade 4, so every grade 3-to-5 cell has at least as
##    many effects as the matching grade 4 cell.
g <- dcast(b, subject + size_bin ~ grade, value.var = "k")
check(all(g[["3 to 5"]] >= g[["4"]]), "grade 3 to 5 k >= grade 4 k")

## 5. The size gradient Kraft reports: within grade and subject, the median in
##    the largest bin is no higher than in the smallest bin, and the share below
##    0.05 is no lower. Skips the thin grade 8 math cell.
gr <- b[!(thin) & size_bin %in% c("251 to 500", "More than 2,000")]
gr <- dcast(gr, grade + subject ~ size_bin, value.var = c("p50", "share_below_005"))
gr <- gr[complete.cases(gr)]
check(all(gr[["p50_More than 2,000"]] <= gr[["p50_251 to 500"]]), "median falls from smallest to largest bin")
check(all(gr[["share_below_005_More than 2,000"]] >= gr[["share_below_005_251 to 500"]]),
      "share below 0.05 rises from smallest to largest bin")

## 6. Thin flag matches the study count.
check(all(b$thin == (b$studies < 10)), "thin flag consistent with studies < 10")

## 7. Values that the summary document quotes for grade 4 reading, >2,000.
r <- b[grade == "4" & subject == "Reading" & size_bin == "More than 2,000"]
check(r$k == 65 && abs(r$p50 - 0.02) < 0.005 && abs(r$p90 - 0.11) < 0.005, "grade 4 reading, >2,000: k=65, p50=0.02, p90=0.11")

cat(sprintf("\n%d checks, %d failures\n", checks, fails))
if (fails > 0) quit(status = 1)
