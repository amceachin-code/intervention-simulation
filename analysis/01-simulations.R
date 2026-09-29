#!/usr/bin/env Rscript
## Intervention simulations: benchmarking the recovery requirement.
##
## Public data only. Pulls NAEP percentiles from the NAEP Data Service API and
## computes, for each grade-subject cell:
##
##   A. Observed quantile differences D(p) = Q2024(p) - Q2019(p) with SEs, and
##      the differential change D(.90) - D(.10). Reproduces Table 2 column (a)
##      of the companion AERA Open article (naep-aera-open), which came from restricted-use microdata. 
##   B. Restoration requirement g*(p) = -D(p)/S in 2019 national SD units.
##   C. Participation-adjusted requirement: required g = g*(p10)/c.
##   D. Share of the p10 deficit closed, by program and coverage.
##   E. c(p): composition of the bottom decile by economic disadvantage,
##      from published within-subgroup percentiles.
##   F. The national score distribution (percent of students in each 10-point
##      bin, NAEP stattype DP:DP) for both years, written to
##      tables/sim-distribution.csv. mixture.R builds the quantile functions
##      for the distributional results from it, anchored to the percentiles.
##
## NO restricted-use microdata is used or required. Every input is a public
## NAEP statistic or a literature parameter (see analysis/config/sim-params.yaml).
##
## Transport note: this machine intercepts TLS, so R's internal download
## methods fail certificate verification. We shell out to curl, which is
## configured for it. Failures are reported loudly rather than silently
## treated as "no data".
##
## Usage: Rscript analysis/01-simulations.R [--cache DIR] [--out DIR]
##          [--config FILE] [--jurisdiction CODE]

suppressPackageStartupMessages({library(jsonlite)})

args <- commandArgs(trailingOnly=TRUE)
getarg <- function(f, d) { i <- match(f, args); if (is.na(i)) d else args[i+1] }
CACHE <- getarg("--cache", "analysis/.cache")
OUT   <- getarg("--out",   "tables")
JURIS <- getarg("--jurisdiction", "NT")
dir.create(CACHE, showWarnings=FALSE, recursive=TRUE)
dir.create(OUT,   showWarnings=FALSE, recursive=TRUE)

## ------------------------------------------------------------- API access

## fetch_api (with the expect_rows partial-response gate), usable(),
## get_stats(), and group_composition() (the population-share guard behind
## c_of_p) live in api-helpers.R, shared with analysis/tests/test-api-guards.R
## so the guards have fixture tests that need no network. The helpers take
## the cache directory and jurisdiction as arguments; this wrapper supplies
## this run's values.
source("analysis/api-helpers.R")
get_stats_run <- function(cell, variable, stattypes, years, expect_rows=NULL)
  get_stats(cell, variable, stattypes, years, jurisdiction=JURIS, cache=CACHE,
            expect_rows=expect_rows)

## -------------------------------------------------- distribution helpers

## quantile_points, make_quantile_fn and quantile_cdf (mixture.R) build each
## ECONDIS group's quantile function from its score distribution, which is how
## group_composition gets the share of each group below a cut. Run this script
## from the repo root (as its own usage comment specifies).
source("analysis/mixture.R")

## ------------------------------------------------------------ parameters

## Parameters come from analysis/config/sim-params.yaml so that effect sizes
## and coverage rates are declared once, with their sources, rather than being
## buried in code. The loader in config-helpers.R stops (naming the yaml
## package, the file, or the key) if anything is missing. There used to be a
## built-in-defaults fallback here; it was a second, unsynchronized copy of
## the config, so it is gone.
source("analysis/config-helpers.R")
CFG <- getarg("--config", CONFIG_DEFAULT)
cfg <- load_sim_config(CFG)

cells   <- cfg_get(cfg, "cells")
## The companion article's Table 2 column (a), for the validation check.
table2a <- cfg_table2a(cfg)
benchmarks    <- lapply(cfg_get(cfg, "benchmarks"),    function(b) list(b$label, b$g))
participation <- lapply(cfg_get(cfg, "participation"), function(x) list(x$label, x$c))
PS <- as.character(unlist(cfg_get(cfg, "percentiles")))
## A --jurisdiction flag other than the default NT wins over the config.
if (identical(JURIS, "NT")) JURIS <- cfg_get(cfg, "jurisdiction")
## Kraft (2020) reference points for Table B, and the single treated effect
## Table C3 applies.
KRAFT   <- cfg_kraft2020(cfg)
G_TREAT <- cfg_treated_g(cfg)

## years: c(reference, comparison). Everything below computes comparison minus
## reference. The CSV column names (q2019, sd2019, sd2024) are a fixed schema
## the downstream scripts read, so they do not follow this setting.
YEARS <- cfg_get(cfg, "years")
if (length(YEARS) != 2 || YEARS[1] >= YEARS[2])
  stop("config 'years' must be [reference, comparison] with reference first; got ",
       paste(YEARS, collapse=", "), call.=FALSE)
REF_YR <- as.character(YEARS[1]); CMP_YR <- as.character(YEARS[2])

## ---------------------------------------------------------- the analysis

observed <- function(cell) {
  raw <- get_stats_run(cell, "TOTAL", c(unname(PCT_CODE), "SD:SD"), YEARS)
  if (is.null(raw) || !length(raw)) return(NULL)
  q <- list()
  for (k in names(raw)) {
    yr <- strsplit(k, "\\|\\|")[[1]][1]
    for (code in names(raw[[k]])) {
      val <- raw[[k]][[code]]
      lbl <- if (code == "SD:SD") "SD" else as.character(CODE_PCT[[code]])
      if (is.null(q[[yr]])) q[[yr]] <- list()
      q[[yr]][[lbl]] <- val
    }
  }
  if (is.null(q[[REF_YR]]) || is.null(q[[CMP_YR]])) return(NULL)
  D <- list(); Q19 <- list()
  for (p in names(PCT_CODE)) {
    a <- q[[REF_YR]][[p]]; b <- q[[CMP_YR]][[p]]
    if (is.null(a) || is.null(b)) next
    ## Independent samples across administrations, per NCES convention for
    ## cross-year comparisons. Shared scale linking induces a small positive
    ## covariance, so this is conservative (SEs slightly too wide).
    ## No na.rm here: a missing published SE must propagate as NA. With
    ## na.rm=TRUE a single missing SE halves the variance and two missing SEs
    ## give exactly 0.000, which would be published as a hard zero.
    D[[p]]   <- c(d=unname(b["value"]-a["value"]),
                  se=sqrt(unname(a["se"])^2 + unname(b["se"])^2))
    Q19[[p]] <- unname(a["value"])
  }
  list(S=unname(q[[REF_YR]][["SD"]]["value"]),
       S2024=unname(q[[CMP_YR]][["SD"]]["value"]),
       D=D, Q19=Q19,
       diff_change=if (!is.null(D[["90"]]) && !is.null(D[["10"]]))
         unname(D[["90"]]["d"] - D[["10"]]["d"]) else NA_real_,
       ## SE on the differential change. p10 and p90 within the same year are
       ## positively correlated, so treating them as independent OVERSTATES
       ## this SE; it is a conservative bound, not an exact standard error.
       diff_change_se=if (!is.null(D[["90"]]) && !is.null(D[["10"]]))
         unname(sqrt(D[["90"]]["se"]^2 + D[["10"]]["se"]^2)) else NA_real_)
}

## g*(p) = -D(p)/S. S is treated as fixed: its delta-method contribution is
## second-order (under 5% of variance at p10, far less elsewhere).
requirements <- function(obs)
  lapply(obs$D, function(x) c(g=unname(-x["d"]/obs$S), se=unname(x["se"]/obs$S)))

## Composition of the bottom decile by economic disadvantage.
## ECONDIS returns THREE groups (disadvantaged, not, and "information not
## available"), not the single TOTAL group get_stats' generic expect_rows
## assumes. Passing the generic count let a response missing one whole group
## pass the "trusted, cache it" gate: with only 2 of 3 groups, the total mass
## is computed over a smaller population, so share_of_tail can be silently
## normalized to ~100% for whichever group happened to arrive.
## The decomposition itself, with its population-share guard, is
## group_composition() in api-helpers.R.
## `raw` is the cell's parsed ECONDIS statistics (econ_stats) and `gd` its
## ECONDIS score distributions, list(<year>=list(<group>=histogram)); both are
## pulled once per cell in section F2 below. ECON_HIST_GROUPS (the groups with
## histograms) is in api-helpers.R.
c_of_p <- function(cell, obs, raw, gd, cut_pct="10") {
  if (is.null(raw) || !length(raw)) return(NULL)
  group_composition(raw, gd, obs, cut_pct, YEARS, cell$label)
}
econ_stats <- function(cell, n_groups=3)
  get_stats_run(cell, "ECONDIS", c(unname(PCT_CODE), "RP:RP"), YEARS,
                expect_rows=n_groups * (length(PCT_CODE) + 1) * 2)

## ------------------------------------------------------------------ main

message("Pulling public NAEP percentiles (API is slow; 30-180s per cell)...\n")
res <- list(); failed <- character(0)
for (cell in cells) {
  o <- observed(cell)
  if (is.null(o)) { message("  FAIL ", cell$label); failed <- c(failed, cell$label); next }
  res[[cell$label]] <- list(cell=cell, obs=o, req=requirements(o))
  message("  ok   ", cell$label)
}
if (!length(res)) stop("No cells retrieved. Check network/TLS: the script shells out to curl.")
if (length(failed)) message("\n  !! failed cells: ", paste(failed, collapse=", "))

## F. Score distributions, one request per cell and year (see get_distribution
## in api-helpers.R for why the years are not combined). A cell whose
## percentiles came back but whose histogram did not is a hard stop, not a
## silent gap: every distributional result downstream needs both years.
message("\nPulling score distributions (DP:DP)...")
dist <- do.call(rbind, lapply(names(res), function(lab) {
  cell <- res[[lab]]$cell
  do.call(rbind, lapply(c(REF_YR, CMP_YR), function(yr) {
    h <- get_distribution(cell, yr, jurisdiction=JURIS, cache=CACHE)
    if (is.null(h)) stop("score distribution unavailable for ", lab, " ", yr,
                         "; rerun, or check the API", call.=FALSE)
    message("  ok   ", lab, " ", yr, " (", nrow(h), " bins)")
    data.frame(cell=lab, year=as.integer(yr), h, stringsAsFactors=FALSE)
  }))
}))

## F2. Score distributions by economic disadvantage, same one-request-per-year
## rule. They feed the bottom-decile decomposition (Table E), the eligibility
## screen's ED share by percentile, and the ED / not-ED outcome views (06 and
## the explorer). pop_share is the group's RP:RP from the ECONDIS percentile
## pull, carried on every row so a reader needs one file, not two.
message("\nPulling score distributions by economic disadvantage (DP:DP x ECONDIS)...")
## First pull, then flatten: econ_stats and econ_dist are what c_of_p reads
## below, and edist is the flat table written to sim-distribution-econdis.csv.
econ_st <- list(); econ_dist <- list()
for (lab in names(res)) {
  cell <- res[[lab]]$cell
  econ_st[[lab]] <- econ_stats(cell)
  for (yr in c(REF_YR, CMP_YR)) {
    h <- get_distribution(cell, yr, jurisdiction=JURIS, cache=CACHE,
                          variable="ECONDIS", groups=ECON_HIST_GROUPS)
    if (is.null(h)) stop("ECONDIS score distribution unavailable for ", lab, " ", yr,
                         "; rerun, or check the API", call.=FALSE)
    econ_dist[[lab]][[yr]] <- h
    message("  ok   ", lab, " ", yr)
  }
}
edist <- do.call(rbind, lapply(names(econ_dist), function(lab)
  do.call(rbind, lapply(names(econ_dist[[lab]]), function(yr) {
    h <- econ_dist[[lab]][[yr]]
    do.call(rbind, lapply(names(h), function(g) {
      rp <- econ_st[[lab]][[paste(yr, g, sep="||")]][["RP:RP"]]
      if (is.null(rp)) stop("no RP:RP for ", lab, " ", yr, " ", g, call.=FALSE)
      data.frame(cell=lab, year=as.integer(yr), group=g,
                 pop_share=unname(rp["value"]) / 100, h[[g]], stringsAsFactors=FALSE)
    }))
  }))))
message("  rows dropped as suppressed/flagged: ", DROPPED$n)

L <- c("# Simulation outputs: benchmarking the recovery requirement", "",
       "Generated by `analysis/01-simulations.R`. **Public NAEP data only** -",
       "no restricted-use microdata is used or required.", "",
       sprintf("## Table A. Observed quantile differences, %s minus %s", CMP_YR, REF_YR), "",
       "Validation: the differential change should reproduce Table 2 column (a)",
       "of the companion AERA Open article, computed from restricted-use microdata.", "",
       paste0("| Cell | ", paste(sprintf("D(p%s)", PS), collapse=" | "),
              sprintf(" | Diff. change | Table 2(a) | %s SD | %s SD |", REF_YR, CMP_YR)),
       paste0("|---|", strrep("---|", 8)))
for (lab in names(res)) {
  o <- res[[lab]]$obs
  ds <- paste(vapply(PS, function(p) if (!is.null(o$D[[p]]))
    sprintf("%+.1f", o$D[[p]]["d"]) else "--", character(1)), collapse=" | ")
  L <- c(L, sprintf("| %s | %s | %+.1f | %.1f | %.1f | %.1f |", lab, ds,
                    o$diff_change, table2a[[lab]], o$S, o$S2024))
}

L <- c(L, "", sprintf("## Table B. Restoration requirement g*(p), in %s national SD units", REF_YR), "",
       "The effect a fully-covered intervention must deliver at each percentile to",
       sprintf("restore its %s value. Kraft (2020), 1,942 effects from 747 RCTs:", REF_YR),
       sprintf("median %.2f, P75 %.2f, P90 %.2f.", KRAFT[["p50"]], KRAFT[["p75"]], KRAFT[["p90"]]), "",
       paste0("| Cell | ", paste(sprintf("g*(p%s)", PS), collapse=" | "),
              " | p10 vs observed-effect distribution |"),
       paste0("|---|", strrep("---|", 6)))
for (lab in names(res)) {
  r <- res[[lab]]
  gs <- paste(vapply(PS, function(p) if (!is.null(r$req[[p]]))
    sprintf("%.3f", r$req[[p]]["g"]) else "--", character(1)), collapse=" | ")
  g10 <- if (!is.null(r$req[["10"]])) unname(r$req[["10"]]["g"]) else NA
  pos <- if (is.na(g10)) "--" else if (g10 >= KRAFT[["p90"]]) "**above P90 of observed effects**" else
         if (g10 >= KRAFT[["p75"]]) "**above P75**" else if (g10 >= KRAFT[["p50"]]) "above the median" else
         "below the median"
  L <- c(L, sprintf("| %s | %s | %s |", lab, gs, pos))
}

L <- c(L, "", "## Table C. Participation-adjusted requirement to restore p10", "",
       "Required treated effect g = g*(p10) / participation rate.", "",
       paste0("| Cell | ", paste(vapply(participation, function(x)
         sprintf("%s (%.3f)", x[[1]], x[[2]]), character(1)), collapse=" | "), " |"),
       paste0("|---|", strrep("---|", length(participation))))
for (lab in names(res)) {
  g10 <- res[[lab]]$req[["10"]]["g"]; if (is.na(g10)) next
  L <- c(L, sprintf("| %s | %s |", lab, paste(vapply(participation, function(x)
    sprintf("%.2f", g10/x[[2]]), character(1)), collapse=" | ")))
}

## Full coverage-by-percentile grids for the featured cells. Reporting only p10
## hides the gradient: the same program can restore the median while closing a
## fraction of the deficit at the bottom, which is the section's central point.
for (lab in names(res)) {
  if (!lab %in% c("Reading G4","Math G8")) next
  r <- res[[lab]]
  L <- c(L, "", sprintf("## Table C2. %s: required effect by percentile and participation", lab), "",
         paste0("| Participation | ", paste(sprintf("p%s", PS), collapse=" | "), " |"),
         paste0("|---|", strrep("---|", length(PS))))
  for (cv in participation) {
    ## Named `row_cells` rather than `cells`: the grade-subject list is also
    ## called `cells` in this scope, and a bare `cells <-` here would clobber
    ## it. Harmless today (the main loop has already run and nothing reads it
    ## afterward) but a trap for any code added below.
    row_cells <- vapply(PS, function(p) {
      g <- if (!is.null(r$req[[p]])) unname(r$req[[p]]["g"]) else NA_real_
      if (is.na(g)) "--" else sprintf("%.2f", g/cv[[2]])
    }, character(1))
    L <- c(L, sprintf("| %s (%.3f) | %s |", cv[[1]], cv[[2]], paste(row_cells, collapse=" | ")))
  }
  L <- c(L, "", sprintf("## Table C3. %s: share of the deficit closed by a %.3f SD program", lab, G_TREAT), "",
         paste0("| Participation | ", paste(sprintf("p%s", PS), collapse=" | "), " |"),
         paste0("|---|", strrep("---|", length(PS))))
  for (cv in participation) {
    row_cells <- vapply(PS, function(p) {
      g <- if (!is.null(r$req[[p]])) unname(r$req[[p]]["g"]) else NA_real_
      if (is.na(g) || g <= 0) "--" else sprintf("%.0f%%", min(cv[[2]]*G_TREAT/g, 1)*100)
    }, character(1))
    L <- c(L, sprintf("| %s (%.3f) | %s |", cv[[1]], cv[[2]], paste(row_cells, collapse=" | ")))
  }
}

L <- c(L, "", "## Table D. Share of the p10 deficit closed", "",
       paste0("| Cell | Program (g) | ", paste(vapply(participation, function(x)
         sprintf("%s", x[[1]]), character(1)), collapse=" | "), " |"),
       paste0("|---|---|", strrep("---|", length(participation))))
for (lab in names(res)) {
  g10 <- res[[lab]]$req[["10"]]["g"]; if (is.na(g10)) next
  for (b in benchmarks)
    L <- c(L, sprintf("| %s | %s (%.3f) | %s |", lab, b[[1]], b[[2]],
                      paste(vapply(participation, function(x)
                        sprintf("%.0f%%", min(x[[2]]*b[[2]]/g10, 1)*100),
                        character(1)), collapse=" | ")))
}

L <- c(L, "", "## Table E. Composition of the bottom decile, by economic disadvantage", "",
       "From each group's published score distribution (10-point bins) and its",
       "own percentiles: a monotone spline through both, inverted at the cut. No",
       "tail is assumed. The cut is the national p10, so 10 percent of students",
       "fall below it by definition; \"Information not available\" (no usable",
       "histogram) takes whatever the two measured groups leave. The measured-mass",
       "column is what the two measured groups account for.", "",
       "| Cell | Year | Group | Pop. share | P(below p10 cut) | Share of bottom decile | Measured mass |",
       paste0("|---|", strrep("---|", 6)))
## Compute the composition of BOTH the bottom decile and the bottom quartile.
## p25 matters because it is the target an eligibility screen can plausibly
## reach: the bottom decile is 10 percent of students, so a program covering
## 18.7 percent could in principle cover all of it, whereas the bottom quartile
## is 25 percent and cannot be fully covered at that take-up.
cps <- list(); cps25 <- list()
for (lab in names(res)) {
  cp <- c_of_p(res[[lab]]$cell, res[[lab]]$obs, econ_st[[lab]], econ_dist[[lab]])
  if (is.null(cp)) { message("  -- c(p) unavailable for ", lab); next }
  cps[[lab]] <- cp
  cp25 <- c_of_p(res[[lab]]$cell, res[[lab]]$obs, econ_st[[lab]], econ_dist[[lab]], cut_pct="25")
  if (!is.null(cp25)) cps25[[lab]] <- cp25
  for (yr in names(cp)) {
    rows <- cp[[yr]]$rows
    rows <- rows[order(vapply(rows, function(r) -r$share_of_tail, numeric(1)))]
    for (r in rows)
      L <- c(L, sprintf("| %s | %s | %s | %.1f%% | %.1f%% | **%.1f%%** | %.3f |",
                        lab, yr, r$group, r$share*100, r$p_below*100,
                        r$share_of_tail*100, cp[[yr]]$measured_mass))
  }
  message("  ok   c(p) ", lab)
}

md <- file.path(OUT, "sim-results.md")
writeLines(L, md)

## Machine-readable outputs.
## .rds is convenient but .gitignore excludes *.rds as a restricted-data
## backstop (correctly - do not weaken that rule). So the authoritative,
## version-controlled artefact is a flat CSV, which 02-figures.R reads.
## The CSV contains only published aggregate statistics: no student records,
## no cell counts, nothing requiring disclosure review.
saveRDS(list(results=res, c_of_p=cps), file.path(OUT, "sim-results.rds"))

flat <- do.call(rbind, lapply(names(res), function(lab) {
  o <- res[[lab]]$obs; r <- res[[lab]]$req
  do.call(rbind, lapply(names(o$D), function(p) data.frame(
    cell=lab, percentile=as.integer(p), q2019=unname(o$Q19[[p]]),
    d=unname(o$D[[p]]["d"]), d_se=unname(o$D[[p]]["se"]),
    g_star=unname(r[[p]]["g"]), g_star_se=unname(r[[p]]["se"]),
    sd2019=o$S, sd2024=o$S2024, diff_change=o$diff_change,
    diff_change_se=o$diff_change_se,
    stringsAsFactors=FALSE)))
}))
write.csv(flat, file.path(OUT, "sim-quantiles.csv"), row.names=FALSE)
## The histograms, one row per cell x year x bin: published aggregate
## percentages only, like the percentiles above.
write.csv(dist, file.path(OUT, "sim-distribution.csv"), row.names=FALSE)
write.csv(edist, file.path(OUT, "sim-distribution-econdis.csv"), row.names=FALSE)

cflat <- NULL
for (tgt in list(list(10, cps), list(25, cps25))) {
  qq <- tgt[[1]]; obj <- tgt[[2]]
  for (lab in names(obj)) {
    for (yr in names(obj[[lab]])) {
      ci <- obj[[lab]][[yr]]
      for (r in ci$rows) {
        cflat <- rbind(cflat, data.frame(
          cell=lab, year=as.integer(yr), target_pct=qq, group=r$group,
          pop_share=r$share, p_below_cut=r$p_below,
          share_of_tail=r$share_of_tail,
          measured_mass=ci$measured_mass, cut=ci$cut,
          stringsAsFactors=FALSE))
      }
    }
  }
}
if (!is.null(cflat))
  write.csv(cflat, file.path(OUT, "sim-bottom-decile.csv"), row.names=FALSE)

## Provenance: without this a reader cannot tell when the API was queried or
## with what code. NAEP revises; the retrieval date matters.
## system2() does not throw on a non-zero exit (git outside a repo, or `git`
## missing) -- it warns and returns the captured output with a `status`
## attribute -- so tryCatch(error=) here never fires. Check the status
## explicitly, and flag an uncommitted tree, since a bare SHA would otherwise imply a correspondence
## between the recorded commit and the code that actually ran that does not
## exist.
git_sha <- suppressWarnings(system2("git", c("rev-parse","--short","HEAD"),
                                    stdout=TRUE, stderr=FALSE))
git_sha <- if (!is.null(attr(git_sha, "status")) && attr(git_sha, "status") != 0)
  "not-a-repo" else git_sha
## The dirty check covers every file whose content can change this script's
## output: the script, the helpers it sources, and the config. Checking only
## the script let an edited helper or parameter ride under a clean SHA.
## (The config is the default path even under --config, which is recorded
## separately below.)
DIRTY_FILES <- c("analysis/01-simulations.R", "analysis/api-helpers.R",
                 "analysis/mixture.R", "analysis/config-helpers.R",
                 "analysis/config/sim-params.yaml")
git_dirty <- suppressWarnings(system2("git", c("status","--porcelain", DIRTY_FILES),
                                      stdout=TRUE, stderr=FALSE))
if (!identical(git_sha, "not-a-repo") && length(git_dirty) > 0)
  git_sha <- paste0(git_sha, "-dirty (uncommitted changes in: ",
                    paste(sub("^.. ", "", git_dirty), collapse=", "), ")")
## Package versions, next to the R version: a jsonlite change in how JSON
## integers parse is exactly the kind of thing usable() has been bitten by.
PKGS <- c("jsonlite", "yaml")
pkg_versions <- paste(vapply(PKGS, function(p) paste(p, as.character(packageVersion(p))),
                             character(1)), collapse=", ")
writeLines(c(
  "# Simulation run manifest",
  paste("generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  paste("script:", "analysis/01-simulations.R"),
  paste("git_sha:", git_sha),
  paste("R:", R.version.string),
  paste("packages:", pkg_versions),
  paste("config:", CFG),
  paste("jurisdiction:", JURIS),
  paste("api:", API),
  paste("statistics:", paste(c(unname(PCT_CODE), "SD:SD", "RP:RP (ECONDIS)",
                               paste(DIST_STAT, "(TOTAL and ECONDIS, one request per year)")), collapse=", ")),
  paste("cells_ok:", paste(names(res), collapse=", ")),
  paste("cells_failed:", if (length(failed)) paste(failed, collapse=", ") else "none"),
  paste("cache_dir:", CACHE, "(delete to force refresh)"),
  "inputs: public NAEP Data Service API only; NO restricted-use data"
), file.path(OUT, "sim-manifest.txt"))

message("\nWrote ", md)
cat(paste(L, collapse="\n"), "\n")
