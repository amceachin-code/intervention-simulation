#!/usr/bin/env Rscript
## Export the data the interactive explorer (docs/index.html) needs.
##
## The explorer is a static page meant for GitHub Pages, so it cannot read the
## CSVs or the yaml at run time through R. This script copies what it needs out
## of the committed outputs and the config into one JavaScript file, so the page
## carries no hand-typed numbers (the project rule is that parameters live in
## analysis/config/sim-params.yaml and results in tables/). Rerun it whenever
## either source changes; analysis/tests/test-tool-engine.mjs checks that the
## exported file still matches tables/sim-quantiles.csv.
##
## Why a .js file rather than .json: a page opened straight from disk
## (file://) is not allowed to fetch() a sibling JSON file in most browsers,
## but it can load a <script src>. Assigning to globalThis keeps it usable
## from Node as well, which is how the test loads it.
##
## Reads:  tables/sim-quantiles.csv, tables/sim-distribution.csv,
##         tables/kraft-2023-benchmarks-by-target.csv, analysis/config/sim-params.yaml
## Writes: docs/cells.js (read by docs/index.html and docs/methods.html)
## Usage:  Rscript analysis/10-export-tool-data.R   (from the project root)

source("analysis/config-helpers.R")
source("analysis/mixture.R")   # quantile_points: the explorer gets the same points R uses
source("analysis/alloc-rules.R")   # ed_share_points: the screen's ED share, as 06 uses it

IN     <- "tables/sim-quantiles.csv"
DIST   <- "tables/sim-distribution.csv"
ECON   <- "tables/sim-distribution-econdis.csv"
KRAFT  <- "tables/kraft-2023-benchmarks-by-target.csv"
OUT    <- "docs/cells.js"
for (f in c(IN, DIST, ECON))
  if (!file.exists(f))
    stop("missing ", f, ". Run: Rscript analysis/01-simulations.R", call. = FALSE)
if (!file.exists(KRAFT))
  stop("missing ", KRAFT, ". Run: Rscript analysis/09-kraft-benchmarks.R", call. = FALSE)
if (!requireNamespace("jsonlite", quietly = TRUE))
  stop("package 'jsonlite' is required. Install it with install.packages(\"jsonlite\").",
       call. = FALSE)

cfg <- load_sim_config()
qd  <- read.csv(IN, stringsAsFactors = FALSE)
dd  <- read.csv(DIST, stringsAsFactors = FALSE)
de  <- read.csv(ECON, stringsAsFactors = FALSE)
PS  <- as.integer(cfg_get(cfg, "percentiles"))

## Cells in the config's order, which is the order the menu shows them. Each
## cell's rows are put in percentile order explicitly rather than trusting the
## CSV's row order, because the engine pairs the i-th knot with PS[i].
cell_labels <- vapply(cfg_get(cfg, "cells"), function(x) x$label, character(1))
cells <- lapply(cell_labels, function(lab) {
  z <- qd[qd$cell == lab, ]
  if (nrow(z) == 0) stop("cell '", lab, "' is in the config but not in ", IN, call. = FALSE)
  z <- z[match(PS, z$percentile), ]
  if (anyNA(z$percentile))
    stop("cell '", lab, "' is missing a percentile in ", IN, call. = FALSE)
  ## S is constant within a cell; check rather than take the first row on faith.
  if (length(unique(z$sd2019)) != 1)
    stop("cell '", lab, "' has more than one sd2019 in ", IN, call. = FALSE)
  ## The points each year's quantile function passes through: the score
  ## distribution's bin points plus the published percentiles, built by the
  ## same quantile_points() that 06-seat-allocation.R uses, so the explorer's
  ## curve is the R pipeline's curve. The engine only draws the spline.
  qf <- function(yr, knots) {
    pts <- quantile_points(dd[dd$cell == lab & dd$year == yr, ], PS, knots, paste(lab, yr))
    list(pct = pts$pct, score = pts$score)
  }
  ## Economic disadvantage, the same objects 06-seat-allocation.R builds:
  ## the 2024 ED share at each 2024 percentile (ed_share_points, which the
  ## eligibility screen reads), and each group's quantile points in both
  ## years, through its score distribution alone (no knots), for the ED and
  ## not-ED outcome views.
  ed_pts <- ed_share_points(dd, de, lab, 2024)
  group <- function(g, id) {
    gq <- function(yr) {
      pts <- group_quantile_points(de, lab, yr, g)   # mixture.R, shared with 06
      list(pct = pts$pct, score = pts$score)
    }
    list(id = id, label = g,
         pop2024 = de$pop_share[de$cell == lab & de$year == 2024 & de$group == g][1],
         qf2019 = gq(2019), qf2024 = gq(2024))
  }
  list(label       = lab,
       q2019       = z$q2019,
       d           = z$d,
       g_star      = z$g_star,
       sd2019      = z$sd2019[1],
       qf2019      = qf(2019, z$q2019),
       qf2024      = qf(2024, z$q2019 + z$d),
       ed          = list(pop = ed_pts$pop,
                          share = list(pct = ed_pts$pct, share = ed_pts$share),
                          groups = list(group("Economically disadvantaged", "ED"),
                                        group("Not economically disadvantaged", "Not ED"))))
})

## Kraft (2023) effect sizes by the population a study served, for the
## methods page's comparison of programs aimed at low achievers with programs
## for everyone. Only the all-sizes rows for grades 4 and 8 (the grades the
## explorer's cells share with Kraft's file) and the three groups the page
## compares. The comparison is descriptive: targeted studies standardize on a
## narrower sample, so their SD effects are not on the same scale as
## universal ones (see kraft-2023-data/CODEBOOK.md, section 1).
KRAFT_TARGETS <- c("universal", "targeted_low", "pooled")
kt <- read.csv(KRAFT, stringsAsFactors = FALSE, check.names = FALSE)
kt <- kt[kt$grade %in% c("4", "8") & kt$size_bin == "All sizes" & kt$target %in% KRAFT_TARGETS, ]
## One row per grade x subject x group, or the page would show duplicates or gaps.
if (nrow(kt) != 2 * 2 * length(KRAFT_TARGETS) || anyDuplicated(kt[c("grade", "subject", "target")]))
  stop(KRAFT, " does not have exactly one all-sizes row per grade 4/8, subject, and target", call. = FALSE)
kt <- kt[order(kt$grade, kt$subject, match(kt$target, KRAFT_TARGETS)), ]
kraft_target <- lapply(seq_len(nrow(kt)), function(i) with(kt[i, ], list(
  grade = as.integer(grade), subject = subject, target = target, studies = studies,
  p50 = p50, thin = as.logical(thin))))

## Presets for the effect and participation controls, with their sources, so
## the page can show where each chip comes from.
strip <- function(recs, fields) lapply(recs, function(r) r[fields])
## Provenance is an MD5 of each source file rather than a run date, so
## rerunning the script on unchanged inputs writes a byte-identical file and
## git shows a change only when the data did.
srcs <- c(IN, DIST, ECON, KRAFT, attr(cfg, "path"))
payload <- list(
  sources        = lapply(srcs, function(f) list(path = f, md5 = unname(tools::md5sum(f)))),
  percentiles    = PS,
  cells          = cells,
  benchmarks     = strip(cfg_get(cfg, "benchmarks"),    c("id", "g", "label", "source", "cite")),
  participation  = strip(cfg_get(cfg, "participation"), c("id", "c", "label", "source", "cite")),
  treated_effect = cfg_get(cfg, "treated_effect"),
  ## For the methods page: where the presets sit among education RCT effects
  ## (Kraft 2020), the validation targets the pipeline reproduces, and the
  ## targeted versus universal comparison above.
  kraft2020      = cfg_get(cfg, "kraft2020_effect_percentiles"),
  table2a        = cfg_get(cfg, "table2a_diff_change"),
  kraft_target   = kraft_target
)

dir.create(dirname(OUT), showWarnings = FALSE, recursive = TRUE)
## digits = NA writes full double precision, so the page and the test see
## exactly the values in the CSV.
json <- jsonlite::toJSON(payload, auto_unbox = TRUE, digits = NA, pretty = TRUE)
writeLines(c("// Generated by analysis/10-export-tool-data.R. Do not edit by hand.",
             paste0("globalThis.TOOL_DATA = ", json, ";")), OUT)
cat("wrote", OUT, "(", length(cells), "cells )\n")
