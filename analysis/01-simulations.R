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

suppressPackageStartupMessages({library(jsonlite)})
has_yaml <- requireNamespace("yaml", quietly=TRUE)

API <- "https://www.nationsreportcard.gov/DataService/GetAdhocData.aspx"
PCT_CODE <- c("10"="PC:P1","25"="PC:P2","50"="PC:P5","75"="PC:P7","90"="PC:P9")
CODE_PCT <- setNames(as.integer(names(PCT_CODE)), PCT_CODE)

args <- commandArgs(trailingOnly=TRUE)
getarg <- function(f, d) { i <- match(f, args); if (is.na(i)) d else args[i+1] }
CACHE <- getarg("--cache", "analysis/.cache")
OUT   <- getarg("--out",   "tables")
JURIS <- getarg("--jurisdiction", "NT")
dir.create(CACHE, showWarnings=FALSE, recursive=TRUE)
dir.create(OUT,   showWarnings=FALSE, recursive=TRUE)

## ------------------------------------------------------------- API access

## Portable MD5 via base R (tools::md5sum), not a shelled-out `md5`/`md5sum`
## binary whose name differs between macOS and Linux.
cache_key_hash <- function(s) {
  tf <- tempfile(); on.exit(unlink(tf)); writeLines(s, tf)
  unname(tools::md5sum(tf))
}

## expect_rows: minimum number of result rows a response must have before it is
## trusted and cached. Without this a PARTIAL response (say, one percentile
## instead of six) would be cached permanently and silently produce an
## incomplete table on every later run.
fetch_api <- function(params, tries=3, pause=5, expect_rows=1) {
  qs <- paste0(names(params), "=",
               vapply(params, function(v) URLencode(as.character(v), reserved=TRUE),
                      character(1)), collapse="&")
  url <- paste0(API, "?", qs)
  key <- file.path(CACHE, paste0(substr(cache_key_hash(qs), 1, 16), ".json"))
  if (file.exists(key)) return(fromJSON(readLines(key, warn=FALSE), simplifyVector=FALSE))
  for (a in seq_len(tries)) {
    tmp <- tempfile()
    st <- suppressWarnings(system2("curl", c("-sS","--max-time","240","-o",tmp,shQuote(url)),
                                   stdout=TRUE, stderr=TRUE))
    if (file.exists(tmp) && file.info(tmp)$size > 0) {
      txt <- paste(readLines(tmp, warn=FALSE), collapse="")
      d <- tryCatch(fromJSON(txt, simplifyVector=FALSE), error=function(e) NULL)
      if (!is.null(d) && length(d$result) >= expect_rows && !is.character(d$result)) {
        writeLines(txt, key); unlink(tmp); return(d)
      }
      if (!is.null(d) && !is.character(d$result) &&
          length(d$result) > 0 && length(d$result) < expect_rows)
        message("    partial response (", length(d$result), " of >=", expect_rows,
                " rows); not caching, retrying")
      if (!is.null(d) && is.character(d$result))
        message("    API says: ", d$result)      # 400: bad stattype/subscale
    } else {
      message("    curl failed: ", paste(st, collapse=" "))
    }
    unlink(tmp); if (a < tries) Sys.sleep(pause)
  }
  NULL
}


## NAEP marks unusable cells three ways: a 999 sentinel, isStatDisplayable=0,
## and errorFlag. jsonlite parses JSON 0 as INTEGER, so identical(x, 0) is FALSE
## for 0L -- an earlier version of this guard was dead code for that reason.
## Compare numerically instead, and count what we drop so it is never silent.
DROPPED <- new.env(parent=emptyenv()); DROPPED$n <- 0L
usable <- function(r) {
  if (is.null(r$value)) return(FALSE)
  bad <- abs(r$value - 999) < 1e-9 ||
    (!is.null(r$isStatDisplayable) &&
       isTRUE(suppressWarnings(as.numeric(r$isStatDisplayable)) == 0)) ||
    (!is.null(r$errorFlag) &&
       isTRUE(suppressWarnings(as.numeric(r$errorFlag)) != 0))
  if (bad) DROPPED$n <- DROPPED$n + 1L
  !bad
}

get_stats <- function(cell, variable, stattypes, years, expect_rows=NULL) {
  ## TOTAL yields exactly one group, so the default (one grid's worth) is
  ## exact. Subgroup variables yield more than one group; callers that know
  ## the group count (e.g. ECONDIS has 3) should pass it via expect_rows so a
  ## response missing a whole group is rejected rather than cached.
  need <- if (!is.null(expect_rows)) expect_rows else length(stattypes) * length(years)
  d <- fetch_api(list(type="data", subject=cell$subject, grade=cell$grade,
                      subscale=cell$subscale, variable=variable,
                      jurisdiction=JURIS, stattype=paste(stattypes, collapse=","),
                      Year=paste(years, collapse=","), ShowDetails="true"),
                 expect_rows=need)
  if (is.null(d)) return(NULL)
  out <- list()
  for (r in d$result) {
    if (!usable(r)) next
    grp <- if (is.null(r$varValueLabel)) "TOTAL" else r$varValueLabel
    k <- paste(r$year, grp, sep="||")
    if (is.null(out[[k]])) out[[k]] <- list()
    out[[k]][[r$stattype]] <- c(value=r$value,
                                se=if (is.null(r$stdError)) NA_real_ else r$stdError)
  }
  out
}

## -------------------------------------------------- distribution helpers

## group_cdf lives in dist-helpers.R, shared with analysis/tests/test-sim.R so
## it has unit tests independent of the API and the committed CSVs. Run this
## script from the repo root (as its own usage comment specifies).
source("analysis/dist-helpers.R")

## ---------------------------------------------------------- the analysis

observed <- function(cell) {
  raw <- get_stats(cell, "TOTAL", c(unname(PCT_CODE), "SD:SD"), c(2019, 2024))
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
  if (is.null(q[["2019"]]) || is.null(q[["2024"]])) return(NULL)
  D <- list(); Q19 <- list()
  for (p in names(PCT_CODE)) {
    a <- q[["2019"]][[p]]; b <- q[["2024"]][[p]]
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
  list(S=unname(q[["2019"]][["SD"]]["value"]),
       S2024=unname(q[["2024"]][["SD"]]["value"]),
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
## pass the "trusted, cache it" gate: with only 2 of 3 groups, `total` in the
## loop below is computed over a smaller population, so share_of_tail can be
## silently normalized to ~100% for whichever group happened to arrive.
c_of_p <- function(cell, obs, cut_pct="10", n_groups=3) {
  raw <- get_stats(cell, "ECONDIS", c(unname(PCT_CODE), "RP:RP"), c(2019, 2024),
                    expect_rows=n_groups * (length(PCT_CODE) + 1) * 2)
  if (is.null(raw) || !length(raw)) return(NULL)
  res <- list()
  for (yr in c("2019", "2024")) {
    cut <- if (yr == "2019") obs$Q19[[cut_pct]]
           else obs$Q19[[cut_pct]] + unname(obs$D[[cut_pct]]["d"])
    rows <- list(); total <- 0
    for (k in names(raw)) {
      kk <- strsplit(k, "\\|\\|")[[1]]
      if (kk[1] != yr) next
      st <- raw[[k]]
      share <- if (!is.null(st[["RP:RP"]])) unname(st[["RP:RP"]]["value"]) else NA
      pcts <- c()
      for (code in names(st)) if (code %in% names(CODE_PCT))
        pcts[as.character(CODE_PCT[[code]])] <- unname(st[[code]]["value"])
      if (is.na(share) || length(pcts) < 2) next
      below <- group_cdf(pcts, cut); mass <- share/100 * below
      rows[[length(rows)+1]] <- list(group=kk[2], share=share/100,
                                     p_below=below, mass=mass)
      total <- total + mass
    }
    if (!length(rows) || total <= 0) next
    ## Belt-and-suspenders on top of the expect_rows fix above: if population
    ## shares don't sum close to 1, a group silently dropped out somewhere
    ## between the API and here, and share_of_tail would be computed over a
    ## partial population.
    pop_sum <- sum(vapply(rows, function(r) r$share, numeric(1)))
    if (abs(pop_sum - 1) > 0.02) {
      message("  !! ", cell$label, " ", yr, ": ECONDIS population shares sum to ",
              round(pop_sum, 3), ", not ~1 -- skipping (a group likely dropped out)")
      next
    }
    for (i in seq_along(rows)) rows[[i]]$share_of_tail <- rows[[i]]$mass/total
    res[[yr]] <- list(cut=cut, rows=rows, reconstructed_mass=total)
  }
  if (length(res)) res else NULL
}

## ------------------------------------------------------------------ main

## Parameters come from analysis/config/sim-params.yaml so that effect sizes
## and coverage rates are declared once, with their sources, rather than being
## buried in code. Falls back to the documented defaults if yaml is missing.
CFG <- getarg("--config", "analysis/config/sim-params.yaml")
cfg <- if (has_yaml && file.exists(CFG)) yaml::read_yaml(CFG) else NULL
if (is.null(cfg)) message("NOTE: config not read (", CFG,
                          "); using built-in defaults.")

cells <- if (!is.null(cfg$cells)) cfg$cells else list(
  list(subject="reading",     grade=4,  subscale="RRPCM", label="Reading G4"),
  list(subject="reading",     grade=8,  subscale="RRPCM", label="Reading G8"),
  list(subject="reading",     grade=12, subscale="RRPCM", label="Reading G12"),
  list(subject="mathematics", grade=4,  subscale="MRPCM", label="Math G4"),
  list(subject="mathematics", grade=8,  subscale="MRPCM", label="Math G8"),
  ## grade 12 math is MWPCM on a 0-300 scale; MRPCM returns HTTP 400 there
  list(subject="mathematics", grade=12, subscale="MWPCM", label="Math G12"))

## The companion article's Table 2 column (a), for the validation check.
table2a <- if (!is.null(cfg$table2a_diff_change)) unlist(cfg$table2a_diff_change) else
  c("Reading G4"=8.7, "Reading G8"=7.0, "Reading G12"=1.5,
    "Math G4"=7.9,    "Math G8"=6.4,    "Math G12"=4.5)

benchmarks <- if (!is.null(cfg$benchmarks))
  lapply(cfg$benchmarks, function(b) list(b$label, b$g)) else
  list(list("Tutoring, >=1000 students", 0.155),
       list("Tutoring, 400-999 students", 0.214),
       list("Summer, meta-analytic (math)", 0.100),
       list("Summer, realized post-COVID", 0.027))

participation <- if (!is.null(cfg$participation))
  lapply(cfg$participation, function(x) list(x$label, x$c)) else
  list(list("Universal, full", 1.000), list("District HDT", 0.280),
       list("Opt-in take-up", 0.187),  list("Summer reach", 0.130))

PS <- if (!is.null(cfg$percentiles)) as.character(unlist(cfg$percentiles)) else
  c("10","25","50","75","90")
if (!is.null(cfg$jurisdiction) && identical(JURIS, "NT")) JURIS <- cfg$jurisdiction

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
message("  rows dropped as suppressed/flagged: ", DROPPED$n)

L <- c("# Simulation outputs: benchmarking the recovery requirement", "",
       "Generated by `analysis/01-simulations.R`. **Public NAEP data only** -",
       "no restricted-use microdata is used or required.", "",
       "## Table A. Observed quantile differences, 2024 minus 2019", "",
       "Validation: the differential change should reproduce Table 2 column (a)",
       "of the companion AERA Open article, computed from restricted-use microdata.", "",
       paste0("| Cell | ", paste(sprintf("D(p%s)", PS), collapse=" | "),
              " | Diff. change | Table 2(a) | 2019 SD | 2024 SD |"),
       paste0("|---|", strrep("---|", 8)))
for (lab in names(res)) {
  o <- res[[lab]]$obs
  ds <- paste(vapply(PS, function(p) if (!is.null(o$D[[p]]))
    sprintf("%+.1f", o$D[[p]]["d"]) else "--", character(1)), collapse=" | ")
  L <- c(L, sprintf("| %s | %s | %+.1f | %.1f | %.1f | %.1f |", lab, ds,
                    o$diff_change, table2a[[lab]], o$S, o$S2024))
}

L <- c(L, "", "## Table B. Restoration requirement g*(p), in 2019 national SD units", "",
       "The effect a fully-covered intervention must deliver at each percentile to",
       "restore its 2019 value. Kraft (2020), 1,942 effects from 747 RCTs:",
       "median 0.10, P75 0.25, P90 0.47.", "",
       paste0("| Cell | ", paste(sprintf("g*(p%s)", PS), collapse=" | "),
              " | p10 vs observed-effect distribution |"),
       paste0("|---|", strrep("---|", 6)))
for (lab in names(res)) {
  r <- res[[lab]]
  gs <- paste(vapply(PS, function(p) if (!is.null(r$req[[p]]))
    sprintf("%.3f", r$req[[p]]["g"]) else "--", character(1)), collapse=" | ")
  g10 <- if (!is.null(r$req[["10"]])) unname(r$req[["10"]]["g"]) else NA
  pos <- if (is.na(g10)) "--" else if (g10 >= 0.47) "**above P90 of observed effects**" else
         if (g10 >= 0.25) "**above P75**" else if (g10 >= 0.10) "above the median" else
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
  L <- c(L, "", sprintf("## Table C3. %s: share of the deficit closed by a 0.155 SD program", lab), "",
         paste0("| Participation | ", paste(sprintf("p%s", PS), collapse=" | "), " |"),
         paste0("|---|", strrep("---|", length(PS))))
  for (cv in participation) {
    row_cells <- vapply(PS, function(p) {
      g <- if (!is.null(r$req[[p]])) unname(r$req[[p]]["g"]) else NA_real_
      if (is.na(g) || g <= 0) "--" else sprintf("%.0f%%", min(cv[[2]]*0.155/g, 1)*100)
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
       "From published within-subgroup percentiles. Each group's left tail below",
       "its own P10 is extrapolated with a normal fitted through P10 and P25.",
       "",
       "The reconstructed-mass column is an INTERNAL CONSISTENCY check only: it",
       "sums the group masses against the definitional 0.100. It is largely",
       "INSENSITIVE to the tail shape (it moves ~0.002 while the estimand moves",
       "~4 points), and its excess over 0.100 comes from linear interpolation",
       "between percentile knots sitting above the true CDF. Do not read it as",
       "validating the tail assumption. Sensitivity to that assumption is",
       "reported separately: the ED share is 79-83% across normal, logistic and",
       "exponential left tails, so the substantive conclusion is robust.", "",
       "| Cell | Year | Group | Pop. share | P(below p10 cut) | Share of bottom decile | Recon. mass |",
       paste0("|---|", strrep("---|", 6)))
## Compute the composition of BOTH the bottom decile and the bottom quartile.
## p25 matters because it is the target an eligibility screen can plausibly
## reach: the bottom decile is 10 percent of students, so a program covering
## 18.7 percent could in principle cover all of it, whereas the bottom quartile
## is 25 percent and cannot be fully covered at that take-up.
cps <- list(); cps25 <- list()
for (lab in names(res)) {
  cp <- c_of_p(res[[lab]]$cell, res[[lab]]$obs)
  if (is.null(cp)) { message("  -- c(p) unavailable for ", lab); next }
  cps[[lab]] <- cp
  cp25 <- c_of_p(res[[lab]]$cell, res[[lab]]$obs, cut_pct="25")
  if (!is.null(cp25)) cps25[[lab]] <- cp25
  for (yr in names(cp)) {
    rows <- cp[[yr]]$rows
    rows <- rows[order(vapply(rows, function(r) -r$share_of_tail, numeric(1)))]
    for (r in rows)
      L <- c(L, sprintf("| %s | %s | %s | %.1f%% | %.1f%% | **%.1f%%** | %.3f |",
                        lab, yr, r$group, r$share*100, r$p_below*100,
                        r$share_of_tail*100, cp[[yr]]$reconstructed_mass))
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
          reconstructed_mass=ci$reconstructed_mass, cut=ci$cut,
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
git_dirty <- suppressWarnings(system2("git", c("status","--porcelain",
                                               "analysis/01-simulations.R"),
                                      stdout=TRUE, stderr=FALSE))
if (!identical(git_sha, "not-a-repo") && length(git_dirty) > 0)
  git_sha <- paste0(git_sha, "-dirty (analysis/01-simulations.R has uncommitted changes)")
writeLines(c(
  "# Simulation run manifest",
  paste("generated:", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  paste("script:", "analysis/01-simulations.R"),
  paste("git_sha:", git_sha),
  paste("R:", R.version.string),
  paste("jurisdiction:", JURIS),
  paste("api:", API),
  paste("cells_ok:", paste(names(res), collapse=", ")),
  paste("cells_failed:", if (length(failed)) paste(failed, collapse=", ") else "none"),
  paste("cache_dir:", CACHE, "(delete to force refresh)"),
  "inputs: public NAEP Data Service API only; NO restricted-use data"
), file.path(OUT, "sim-manifest.txt"))

message("\nWrote ", md)
cat(paste(L, collapse="\n"), "\n")
