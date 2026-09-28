## Tests for the target-population coding of the Kraft (2023) benchmark
## studies (stages 5 and 6). Run from the project root:
##   Rscript analysis/tests/test-kraft-target.R
## Checks the merged coding file against the study list, the codebook's
## allowed values, and the by-target benchmark table written by
## analysis/09-kraft-benchmarks.R. Prints one line per check and a summary;
## exits non-zero on any failure.

suppressPackageStartupMessages(library(data.table))

fails <- 0L; checks <- 0L
check <- function(ok, msg) {
  checks <<- checks + 1L
  if (isTRUE(ok)) cat("ok   ", msg, "\n") else { fails <<- fails + 1L; cat("FAIL ", msg, "\n") }
}

sl  <- fread("kraft-2023-data/studies/study-list.csv", colClasses = list(character = "study_id"))
res <- fread("kraft-2023-data/studies/resolution.csv", colClasses = list(character = "study_id"))
cod <- fread("kraft-2023-data/studies/coding.csv", colClasses = "character")

## ---- coverage
check(nrow(sl) == 254, "study list has 254 studies")
check(all(sl$study_id %in% res$study_id), "every study has a resolution row")
check(all(res$resolution_status %in% c("auto", "manual", "override", "unresolved")), "resolution statuses valid")
check(all(sl$study_id %in% cod$study_id), sprintf("every study has a coding row (%d of %d)", sum(sl$study_id %in% cod$study_id), nrow(sl)))
check(!any(duplicated(cod$study_id)), "no duplicated study_id in coding.csv")

## ---- allowed values
check(all(cod$code %in% c("universal", "targeted_low", "targeted_other", "unclear")), "codes in allowed set")
check(all(cod$level %in% c("student", "school", "both", "none", "unclear")), "levels in allowed set")
check(all(cod$confidence %in% c("high", "medium", "low")), "confidence in allowed set")
check(all(cod$opt_in %in% c("0", "1")) && all(cod$mixed_samples %in% c("0", "1")), "opt_in and mixed_samples are 0/1")
has_source <- nzchar(cod$source_used)
check(all(nzchar(cod$evidence_quote[has_source])), "every row with a source has an evidence quote")
check(all(nzchar(cod$evidence_location[nzchar(cod$evidence_quote)])), "every quote has a location")
check(!any(cod$confidence == "high" & cod$source_used %in% c("abstract", "wwc-page")), "abstract or WWC sources never high confidence")
check(all(cod$code[cod$code != "unclear"] != "" ), "non-unclear codes non-empty")
unclear_share <- mean(cod$code == "unclear")
cat(sprintf("     unclear share: %.2f\n", unclear_share))
if (unclear_share > 0.35) cat("WARN unclear share above 0.35\n")
check(!any(grepl("—", do.call(paste, cod))), "no em dashes in coding.csv")

## ---- twins get identical codes
twins <- list(c("322", "323"), c("339", "341"), c("600", "601"))
for (tw in twins) {
  r <- cod[study_id %in% tw]
  check(nrow(r) == 2 && uniqueN(r$code) == 1, sprintf("twin rows %s share a code", paste(tw, collapse = "/")))
}

## ---- by-target table, if the benchmarks script has been rerun
bt_path <- "tables/kraft-2023-benchmarks-by-target.csv"
if (file.exists(bt_path)) {
  bt <- fread(bt_path)
  main <- fread("tables/kraft-2023-benchmarks-by-grade-size.csv")
  check(all(bt$target %in% c("universal", "targeted_low", "targeted_other", "unclear", "not_coded", "pooled")), "target values valid")
  pooled <- bt[target == "pooled"]
  m <- merge(pooled, main, by = c("grade", "subject", "size_bin"), suffixes = c(".bt", ".main"))
  check(nrow(m) == nrow(main), "pooled rows cover every main-table cell")
  check(all(m$k.bt == m$k.main) && all(abs(m$p50.bt - m$p50.main) < 1e-9), "pooled rows equal the main table (k and p50)")
  parts <- bt[target != "pooled", .(k = sum(k)), by = .(grade, subject, size_bin)]
  m2 <- merge(parts, main, by = c("grade", "subject", "size_bin"))
  check(all(m2$k.x == m2$k.y), "per cell, k summed over codes plus not_coded equals the main table")
} else {
  cat("     (by-target table not found; rerun analysis/09-kraft-benchmarks.R after the merge)\n")
}

## ---- WWC agreement, if both files exist
wwc_path <- "kraft-2023-data/studies/wwc-codes.csv"
if (file.exists(wwc_path)) {
  w <- fread(wwc_path, colClasses = "character")
  o <- merge(cod[code != "unclear", .(study_id, code)], w[wwc_code != "unclear", .(study_id, wwc_code)], by = "study_id")
  agree <- if (nrow(o)) mean(o$code == o$wwc_code) else NA
  cat(sprintf("     WWC agreement where neither is unclear: %s on %d studies\n", ifelse(is.na(agree), "NA", sprintf("%.2f", agree)), nrow(o)))
  if (!is.na(agree) && agree < 0.7) cat("WARN WWC agreement below 0.7; review reliability-report.md\n")
}

cat(sprintf("\n%d checks, %d failures\n", checks, fails))
if (fails > 0) quit(status = 1)
