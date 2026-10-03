#!/usr/bin/env Rscript
## Export every year the explorer lets a reader compare, 2005 to 2024.
##
## The paper's pipeline (01-10) compares 2024 with 2019 only, and stays that
## way. This script is the explorer's own export: it pulls each cell's
## published percentiles, SD, score distribution, and economic-disadvantage
## breakdown for every year in analysis/config/explorer-years.yaml, and
## writes them to docs/years.js, one record per cell and year. The pages pick
## a reference year and a later comparison year and build the pair in the
## browser (NAEPEngine.pair in docs/engine.js), so nothing pair-specific is
## stored here.
##
## Nothing is reimplemented. The fetch, cache, and response guards are
## api-helpers.R's (get_stats, get_distribution); the quantile-function
## points are mixture.R's (quantile_points, group_quantile_points); the
## eligibility screen's ED share is alloc-rules.R's (ed_share_points). So a
## cell-year here is built exactly as 01 and 10 build 2019 and 2024, and the
## engine test checks that the 2019 and 2024 records reproduce docs/cells.js.
##
## It also writes tables/explorer-pairs-check.csv: for the check_pairs in the
## years config, the seat-allocation results for the proportional rule and
## the eligibility screen at a few budgets, computed by the same functions
## 06-seat-allocation.R uses. The JavaScript engine must reproduce them, which
## checks the generalized engine against R on pairs other than 2019 to 2024.
##
## Reads:  analysis/config/sim-params.yaml (cells, percentiles, jurisdiction,
##         treated effect), analysis/config/explorer-years.yaml, the NAEP Data
##         Service through the cache in analysis/.cache/
## Writes: docs/years.js, tables/explorer-pairs-check.csv
## Usage:  Rscript analysis/11-export-explorer-years.R [--cache DIR]
##         (from the project root; network only for responses not yet cached)

suppressPackageStartupMessages({library(jsonlite)})
source("analysis/config-helpers.R")
source("analysis/api-helpers.R")
source("analysis/mixture.R")
source("analysis/alloc-rules.R")

args   <- commandArgs(trailingOnly = TRUE)
getarg <- function(f, d) { i <- match(f, args); if (is.na(i)) d else args[i + 1] }
CACHE  <- getarg("--cache", "analysis/.cache")
EYCFG  <- "analysis/config/explorer-years.yaml"
OUT_JS <- "docs/years.js"
OUT_CK <- "tables/explorer-pairs-check.csv"
dir.create(CACHE, showWarnings = FALSE, recursive = TRUE)

cfg   <- load_sim_config()
ey    <- yaml::read_yaml(EYCFG)
cells <- cfg_get(cfg, "cells")
PS    <- as.integer(cfg_get(cfg, "percentiles"))
JURIS <- cfg_get(cfg, "jurisdiction")
G     <- cfg_treated_g(cfg)
## The bin-to-percentile gap below which a bin point is dropped (see
## quantile_points in mixture.R and the years config).
GAP   <- as.numeric(ey$min_bin_knot_gap)

## The years a cell offers. Grade 12 has its own list (see the config).
years_for <- function(cell)
  as.integer(if (cell$grade == 12) ey$years$grade_12 else ey$years$grade_4_8)

## The ECONDIS groups: the two with score distributions, plus the share NAEP
## could not classify, which the pages report as a caveat.
UNKNOWN <- "Information not available"
## parse_stats keys results "year||group label"; the TOTAL variable's one
## group is labelled "All students", so grp = "TOTAL" means that group.
stat <- function(raw, yr, grp, code) {
  if (identical(grp, "TOTAL")) grp <- "All students"
  v <- raw[[paste(yr, grp, sep = "||")]][[code]]
  if (is.null(v)) stop("no ", code, " for ", yr, " ", grp, call. = FALSE)
  unname(v["value"])
}

## ------------------------------------------------------------- the pull
message("Pulling NAEP statistics for every explorer year (cached responses are reused)...")
pulled <- lapply(cells, function(cell) {
  lab <- cell$label; yrs <- years_for(cell)
  ## One request per variable with all of the cell's years, as 01 does for
  ## its two. TOTAL: the five percentiles and SD. ECONDIS: the same five
  ## percentiles and each group's population share (RP:RP), three groups.
  tot <- get_stats(cell, "TOTAL", c(unname(PCT_CODE), "SD:SD"), yrs,
                   jurisdiction = JURIS, cache = CACHE)
  eco <- get_stats(cell, "ECONDIS", c(unname(PCT_CODE), "RP:RP"), yrs,
                   jurisdiction = JURIS, cache = CACHE,
                   expect_rows = 3 * (length(PCT_CODE) + 1) * length(yrs))
  if (is.null(tot) || is.null(eco))
    stop("statistics unavailable for ", lab, "; rerun, or check the API", call. = FALSE)
  ## Score distributions, one request per year (get_distribution explains why).
  dist <- do.call(rbind, lapply(yrs, function(yr) {
    h <- get_distribution(cell, yr, jurisdiction = JURIS, cache = CACHE)
    if (is.null(h)) stop("score distribution unavailable for ", lab, " ", yr, call. = FALSE)
    data.frame(cell = lab, year = yr, h, stringsAsFactors = FALSE)
  }))
  edist <- do.call(rbind, lapply(yrs, function(yr) {
    h <- get_distribution(cell, yr, jurisdiction = JURIS, cache = CACHE,
                          variable = "ECONDIS", groups = ECON_HIST_GROUPS)
    if (is.null(h)) stop("ECONDIS score distribution unavailable for ", lab, " ", yr, call. = FALSE)
    do.call(rbind, lapply(names(h), function(g)
      data.frame(cell = lab, year = yr, group = g,
                 pop_share = stat(eco, yr, g, "RP:RP") / 100, h[[g]],
                 stringsAsFactors = FALSE)))
  }))
  message("  ok   ", lab, " (", length(yrs), " years)")
  list(cell = cell, years = yrs, tot = tot, eco = eco, dist = dist, edist = edist)
})
names(pulled) <- vapply(cells, function(x) x$label, character(1))

## The published percentiles of one cell-year, in PS order.
knots <- function(p, yr)
  vapply(PS, function(pc) stat(p$tot, yr, "TOTAL", PCT_CODE[[as.character(pc)]]), numeric(1))

## ----------------------------------------------------------- docs/years.js
## One record per cell and year: the published percentiles and SD, the
## quantile-function points (bins plus percentiles), and the ED breakdown
## (the screen's ED share curve and population share, each group's own
## quantile points, and the unclassified share). Built exactly as 10 builds
## the 2019 and 2024 fields of cells.js.
pts <- function(x) list(pct = x$pct, score = x$score)
year_record <- function(p, yr) {
  lab <- p$cell$label; q <- knots(p, yr)
  ed  <- ed_share_points(p$dist, p$edist, lab, yr)
  group <- function(g, id) list(
    id = id, label = g,
    pop = p$edist$pop_share[p$edist$year == yr & p$edist$group == g][1],
    qf = pts(group_quantile_points(p$edist, lab, yr, g)))
  list(q  = q,
       sd = stat(p$tot, yr, "TOTAL", "SD:SD"),
       qf = pts(quantile_points(p$dist[p$dist$year == yr, ], PS, q, paste(lab, yr), min_gap = GAP)),
       ed = list(pop = ed$pop,
                 unknown = stat(p$eco, yr, UNKNOWN, "RP:RP") / 100,
                 share = list(pct = ed$pct, share = ed$share),
                 groups = list(group("Economically disadvantaged", "ED"),
                               group("Not economically disadvantaged", "Not ED"))))
}
years_cells <- lapply(pulled, function(p) {
  recs <- lapply(p$years, function(yr) year_record(p, yr))
  names(recs) <- as.character(p$years)
  list(label = p$cell$label, grade = p$cell$grade, years = recs)
})
names(years_cells) <- NULL

## Provenance: the two configs by MD5, so a rerun on the same cache writes a
## byte-identical file, as 10 does for cells.js.
payload <- list(
  sources      = lapply(c(attr(cfg, "path"), EYCFG),
                        function(f) list(path = f, md5 = unname(tools::md5sum(f)))),
  percentiles  = PS,
  default_pair = as.integer(ey$default_pair),
  cells        = years_cells)
json <- jsonlite::toJSON(payload, auto_unbox = TRUE, digits = NA)
writeLines(c("// Generated by analysis/11-export-explorer-years.R. Do not edit by hand.",
             paste0("globalThis.TOOL_YEARS = ", json, ";")), OUT_JS)
cat("wrote", OUT_JS, "(", sum(lengths(lapply(pulled, `[[`, "years"))), "cell-years )\n")

## ------------------------------------------- tables/explorer-pairs-check.csv
## For each check pair: whoever stands at p10 and p90 after the program
## (distributional) and the students who started there (group), for the
## proportional rule and the eligibility screen, at each check budget. Same
## code path as 06-seat-allocation.R: the comparison year's quantile function
## through its bins and percentiles, calibrated program quantiles, and the
## ED screen built from the comparison year's ED share.
check <- do.call(rbind, lapply(ey$check_pairs, function(cp) {
  p <- pulled[[cp$cell]]
  if (is.null(p)) stop("check pair cell '", cp$cell, "' is not a configured cell", call. = FALSE)
  if (!all(c(cp$ref, cp$cmp) %in% p$years) || cp$ref >= cp$cmp)
    stop("check pair ", cp$cell, " ", cp$ref, "-", cp$cmp, " is not a valid explorer pair", call. = FALSE)
  qr <- knots(p, cp$ref); qc <- knots(p, cp$cmp)
  S  <- stat(p$tot, cp$ref, "TOTAL", "SD:SD")
  qcp <- quantile_points(p$dist[p$dist$year == cp$cmp, ], PS, qc, paste(cp$cell, cp$cmp), min_gap = GAP)
  after <- calibrated_program_quantiles(make_quantile_fn(qcp$pct, qcp$score), G * S, PS, qc)
  screen <- make_ed_screen(ed_share_points(p$dist, p$edist, cp$cell, cp$cmp))
  rules <- list("Proportional (untargeted)" = alloc_uniform, "Eligibility screen (ECONDIS)" = screen)
  do.call(rbind, lapply(names(rules), function(rn) do.call(rbind, lapply(ey$check_budgets, function(B) {
    r  <- setNames(qr - after(rules[[rn]], B), PS)           # distributional residual
    rt <- setNames((qr - qc) - rules[[rn]](PS, B) * G * S, PS)  # group residual
    data.frame(cell = cp$cell, ref = cp$ref, cmp = cp$cmp, rule = rn, budget = B,
               res_p10 = r[["10"]], res_p90 = r[["90"]],
               gap_remaining = -(r[["90"]] - r[["10"]]),
               gap_remaining_tracked = -(rt[["90"]] - rt[["10"]]),
               stringsAsFactors = FALSE)
  }))))
}))
write.csv(check, OUT_CK, row.names = FALSE)
cat("wrote", OUT_CK, "(", nrow(check), "rows )\n")
