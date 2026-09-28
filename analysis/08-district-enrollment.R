#!/usr/bin/env Rscript
## District enrollment distributions, school year 2023-24, from the NCES
## Common Core of Data (CCD). Context for the district scenarios.
##
## Three questions, in order of importance for the paper:
##   1. What is the distribution of K-5 enrollment (kindergarten through grade 5)
##      across districts? This is the target distribution for the district scenarios.
##   2. What is the distribution of grade 4 enrollment across districts?
##   3. What is the distribution of total district enrollment across the US?
##
## Each is answered two ways, because they give different pictures:
##   - District-weighted: the district is the unit. "The median district has X
##     students." Dominated by the thousands of small rural districts.
##   - Student-weighted: the student is the unit. "The median student attends a
##     district of X." Dominated by the few very large urban districts.
##
## Inputs (public, no student records):
##   district-enrollment-data/ccd_lea_052_2324_l_1a_073124/*.csv   LEA membership (long)
##   district-enrollment-data/ccd_lea_029_2324_w_1a_073124/*.csv   LEA directory (wide)
## The directory file supplies LEA type and operational status. If it is missing
## the script downloads it from NCES with curl (see the transport note in
## 01-simulations.R: R's internal download methods fail on this machine).
##
## Universe definitions (reported in every output so a reader can pick):
##   all_lea          every LEA with a reported, positive membership total in
##                    the 50 states and DC
##   regular          LEA_TYPE 1 or 2 (regular public school districts, whether
##                    or not part of a supervisory union), operational, 50 states
##                    and DC, positive membership. This is the headline universe:
##                    what people mean by "a school district."
##   regular_charter  regular plus LEA_TYPE 7 (independent charter districts)
## Excluded everywhere: outlying areas (PR, GU, VI, AS, MP), the Bureau of Indian
## Education, and LEAs whose total is missing, not reported, or suppressed.
## "Operational" means SY_STATUS in Open, New, Added, Changed Boundary/Agency, or
## Reopened; Closed, Inactive, and Future LEAs are dropped.
##
## Outputs:
##   tables/district-enrollment-2324-percentiles.csv
##   tables/district-enrollment-2324-bins.csv
##   tables/district-enrollment-2324.md
##   tables/district-enrollment-2324-manifest.txt
##   figures/district-enrollment/fig-d1-k5-enrollment.png
##   figures/district-enrollment/fig-d2-grade4-enrollment.png
##   figures/district-enrollment/fig-d3-total-enrollment.png
##
## Usage: Rscript analysis/08-district-enrollment.R

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

## ----------------------------------------------------------------- paths

DATA_DIR <- "district-enrollment-data"
MEM_CSV  <- file.path(DATA_DIR, "ccd_lea_052_2324_l_1a_073124",
                      "ccd_lea_052_2324_l_1a_073124.csv")
DIR_DIR  <- file.path(DATA_DIR, "ccd_lea_029_2324_w_1a_073124")
DIR_CSV  <- file.path(DIR_DIR, "ccd_lea_029_2324_w_1a_073124.csv")
DIR_URL  <- "https://nces.ed.gov/ccd/Data/zip/ccd_lea_029_2324_w_1a_073124.zip"
OUT_TAB  <- "tables"
OUT_FIG  <- file.path("figures", "district-enrollment")
dir.create(OUT_TAB, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_FIG, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(MEM_CSV)) {
  stop("Membership file not found at ", MEM_CSV,
       "\nDownload 'ccd_lea_052_2324_l_1a_073124.zip' from https://nces.ed.gov/ccd/files.asp",
       " and unzip it into ", DATA_DIR, "/.")
}

## The directory file is small (8 MB) and public; fetch it if it is absent so the
## script is reproducible from the membership file alone.
if (!file.exists(DIR_CSV)) {
  message("Directory file missing; downloading from NCES ...")
  dir.create(DIR_DIR, showWarnings = FALSE, recursive = TRUE)
  zip <- tempfile(fileext = ".zip")
  status <- system2("curl", c("-sSL", "-o", shQuote(zip), shQuote(DIR_URL)))
  if (status != 0 || !file.exists(zip)) stop("curl failed to download ", DIR_URL)
  unzip(zip, files = basename(DIR_CSV), exdir = DIR_DIR)
  if (!file.exists(DIR_CSV)) stop("Directory CSV not found inside the downloaded zip.")
}

## ----------------------------------------------------------------- read

## Only the columns we need, and only the total and grade-4 subtotal rows. The
## long file has 3.8 million rows; the rows we keep number about 37 thousand.
message("Reading membership file (this takes a minute) ...")
mem <- fread(MEM_CSV,
             select = c("ST", "LEAID", "LEA_NAME", "GRADE", "STUDENT_COUNT",
                        "TOTAL_INDICATOR", "DMS_FLAG"),
             colClasses = list(character = c("LEAID", "ST", "LEA_NAME", "GRADE",
                                             "TOTAL_INDICATOR", "DMS_FLAG")),
             showProgress = FALSE)

totals <- mem[TOTAL_INDICATOR == "Education Unit Total",
              .(ST, LEAID, LEA_NAME, total = STUDENT_COUNT, total_flag = DMS_FLAG)]
## Grade subtotals for kindergarten through grade 5. A count is usable when its
## flag is Reported, Derived, or Manual adjustment (the three flags NCES attaches
## to actual numbers); Missing, Not reported, and Suppressed rows carry NA.
K5_GRADES <- c("Kindergarten", "Grade 1", "Grade 2", "Grade 3", "Grade 4", "Grade 5")
USABLE    <- c("Reported", "Derived", "Manual adjustment")
gsub_rows <- mem[TOTAL_INDICATOR == "Subtotal 4 - By Grade" & GRADE %in% K5_GRADES,
                 .(LEAID, GRADE, count = fifelse(DMS_FLAG %in% USABLE, STUDENT_COUNT, NA_real_))]
rm(mem); invisible(gc())

grade4 <- gsub_rows[GRADE == "Grade 4", .(LEAID, g4 = count)]
## K-5 is the sum over the six grades of the usable counts. A district with no
## usable K-5 row at all gets NA; one with some usable rows gets the sum of those.
k5 <- gsub_rows[, .(k5 = if (all(is.na(count))) NA_real_ else sum(count, na.rm = TRUE),
                    k5_grades_reported = sum(!is.na(count))), by = LEAID]

stopifnot(!anyDuplicated(totals$LEAID), !anyDuplicated(grade4$LEAID), !anyDuplicated(k5$LEAID))

dir <- fread(DIR_CSV, encoding = "Latin-1",
             select = c("LEAID", "LEA_TYPE", "LEA_TYPE_TEXT", "SY_STATUS_TEXT",
                        "G_4_OFFERED", "CHARTER_LEA_TEXT"),
             colClasses = "character", showProgress = FALSE)
stopifnot(!anyDuplicated(dir$LEAID))

lea <- merge(totals, grade4, by = "LEAID", all.x = TRUE)
lea <- merge(lea, k5, by = "LEAID", all.x = TRUE)
lea <- merge(lea, dir, by = "LEAID", all.x = TRUE)

## ----------------------------------------------------------------- universes

OUTLYING    <- c("PR", "GU", "VI", "AS", "MP", "BI")
OPERATIONAL <- c("Open", "New", "Added", "Changed Boundary/Agency", "Reopened")

lea[, in_states := !(ST %in% OUTLYING)]
lea[, operational := SY_STATUS_TEXT %in% OPERATIONAL]
lea[, total_ok := total_flag == "Reported" & !is.na(total) & total > 0]
lea[, g4_ok := !is.na(g4) & g4 > 0]
lea[, k5_ok := !is.na(k5) & k5 > 0]

universes <- list(
  all_lea         = quote(in_states & total_ok),
  regular         = quote(in_states & total_ok & operational & LEA_TYPE %in% c("1", "2")),
  regular_charter = quote(in_states & total_ok & operational & LEA_TYPE %in% c("1", "2", "7"))
)

## ----------------------------------------------------------------- helpers

PROBS <- c(0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99)

## Student-weighted quantile of district size: the size of the district that the
## student at the p-th percentile of the student population attends. Sort
## districts by size, accumulate students, and read off the first district where
## the cumulative share reaches p.
wquantile <- function(x, p) {
  o <- order(x); x <- x[o]
  cs <- cumsum(x) / sum(x)
  vapply(p, function(pp) x[which(cs >= pp)[1]], numeric(1))
}

summarise_measure <- function(x, universe, measure) {
  x <- x[!is.na(x)]
  data.table(
    universe   = universe,
    measure    = measure,
    weighting  = rep(c("district", "student"), each = length(PROBS)),
    percentile = rep(PROBS * 100, 2),
    value      = c(unname(quantile(x, PROBS, type = 7)), wquantile(x, PROBS)),
    n_districts = length(x),
    students    = sum(x),
    mean        = mean(x),
    max         = max(x)
  )
}

bin_measure <- function(x, universe, measure, breaks, labels) {
  x <- x[!is.na(x)]
  b <- cut(x, breaks = breaks, labels = labels, right = FALSE)
  d <- data.table(bin = b, x = x)[, .(n_districts = .N, students = sum(x)), by = bin]
  d <- d[data.table(bin = factor(labels, levels = labels)), on = "bin"]
  d[is.na(n_districts), `:=`(n_districts = 0L, students = 0)]
  d[, `:=`(share_districts = n_districts / sum(n_districts),
           share_students  = students / sum(students),
           cum_share_districts = cumsum(n_districts) / sum(n_districts),
           cum_share_students  = cumsum(students) / sum(students))]
  cbind(universe = universe, measure = measure, d)
}

## One set of size bins for all three measures, matching the sample-size
## categories in Table 1 of Kraft (2023), so a district's K-5, grade 4, or total
## enrollment can be read against the study sizes in his effect-size
## distribution. cut() with right = FALSE uses [lower, upper) intervals, so the
## breaks sit one above each of Kraft's upper bounds.
SIZE_BREAKS <- c(0, 101, 251, 501, 2001, Inf)
SIZE_LABELS <- c("100 or fewer", "101 to 250", "251 to 500", "501 to 2,000", "More than 2,000")

## ----------------------------------------------------------------- compute

pct_rows <- list(); bin_rows <- list()
for (u in names(universes)) {
  sub <- lea[eval(universes[[u]])]
  pct_rows[[length(pct_rows) + 1]] <- summarise_measure(sub$total, u, "total")
  bin_rows[[length(bin_rows) + 1]] <- bin_measure(sub$total, u, "total", SIZE_BREAKS, SIZE_LABELS)
  g4sub <- sub[g4_ok == TRUE]
  pct_rows[[length(pct_rows) + 1]] <- summarise_measure(g4sub$g4, u, "grade4")
  bin_rows[[length(bin_rows) + 1]] <- bin_measure(g4sub$g4, u, "grade4", SIZE_BREAKS, SIZE_LABELS)
  k5sub <- sub[k5_ok == TRUE]
  pct_rows[[length(pct_rows) + 1]] <- summarise_measure(k5sub$k5, u, "k5")
  bin_rows[[length(bin_rows) + 1]] <- bin_measure(k5sub$k5, u, "k5", SIZE_BREAKS, SIZE_LABELS)
}
pct <- rbindlist(pct_rows); bins <- rbindlist(bin_rows)

## Round to whole students; shares to four decimals.
pct[, c("value", "mean", "max") := lapply(.SD, round), .SDcols = c("value", "mean", "max")]
bins[, c("share_districts", "share_students", "cum_share_districts", "cum_share_students") :=
       lapply(.SD, round, 4),
     .SDcols = c("share_districts", "share_students", "cum_share_districts", "cum_share_students")]

fwrite(pct,  file.path(OUT_TAB, "district-enrollment-2324-percentiles.csv"))
fwrite(bins, file.path(OUT_TAB, "district-enrollment-2324-bins.csv"))

## ----------------------------------------------------------------- figures

## Two series per figure (share of districts, share of students), fixed colours
## matching the RdBu pair already used in 02-figures.R. Direct labels on bars,
## legend on top, recessive grid.
theme_de <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
        plot.subtitle = element_text(colour = "grey30", size = 10),
        plot.caption = element_text(colour = "grey45", size = 8, hjust = 0),
        legend.position = "top", legend.title = element_blank(),
        axis.text.x = element_text(size = 10))

## Bar labels: whole percents, except that a positive share that rounds to zero
## reads "<1%" rather than "0%", since the bin is not empty.
pct_label <- function(x) {
  lab <- scales::percent(x, accuracy = 1)
  ifelse(x > 0 & x < 0.005, "<1%", lab)
}

plot_bins <- function(d, title, subtitle, caption, fn) {
  long <- melt(d[, .(bin, `Share of districts` = share_districts,
                     `Share of students` = share_students)],
               id.vars = "bin", variable.name = "series", value.name = "share")
  ## Re-level on this measure's own bin order. rbindlist unioned the factor
  ## levels across measures, so a label shared between measures (grade 4's
  ## "1,000 to 2,499" also exists in the total bins) would otherwise sort first.
  long[, bin := factor(as.character(bin), levels = unique(as.character(d$bin)))]
  p <- ggplot(long, aes(bin, share, fill = series)) +
    geom_col(position = position_dodge(width = 0.8), width = 0.72) +
    geom_text(aes(label = pct_label(share)),
              position = position_dodge(width = 0.8), vjust = -0.35, size = 2.7,
              colour = "grey20") +
    scale_fill_manual(values = c("#2166AC", "#B2182B")) +
    scale_y_continuous(labels = scales::percent, expand = expansion(mult = c(0, 0.10))) +
    labs(title = title, subtitle = subtitle, x = NULL, y = NULL,
         caption = paste(strwrap(caption, width = 150), collapse = "\n")) +
    theme_de
  ggsave(fn, p, width = 8.2, height = 5.2, dpi = 200)
}

reg_total <- bins[universe == "regular" & measure == "total"]
reg_g4    <- bins[universe == "regular" & measure == "grade4"]
reg_k5    <- bins[universe == "regular" & measure == "k5"]
n_reg     <- pct[universe == "regular" & measure == "total", n_districts][1]
n_reg_g4  <- pct[universe == "regular" & measure == "grade4", n_districts][1]
n_reg_k5  <- pct[universe == "regular" & measure == "k5", n_districts][1]

plot_bins(reg_total,
          "Total enrollment of regular public school districts, 2023-24",
          sprintf("%s districts in the 50 states and DC; each district counted once (blue) or by its students (red)",
                  format(n_reg, big.mark = ",")),
          "Source: NCES Common Core of Data, LEA membership and directory files, SY 2023-24. Regular districts are LEA types 1 and 2, operational, with reported positive membership. Size bins follow the study sample-size categories in Kraft (2023), Table 1.",
          file.path(OUT_FIG, "fig-d3-total-enrollment.png"))

plot_bins(reg_g4,
          "Grade 4 enrollment of regular public school districts, 2023-24",
          sprintf("%s districts with grade 4 students; each district counted once (blue) or by its grade 4 students (red)",
                  format(n_reg_g4, big.mark = ",")),
          "Source: NCES Common Core of Data, LEA membership and directory files, SY 2023-24. Regular districts are LEA types 1 and 2, operational, with a positive grade 4 subtotal. Size bins follow the study sample-size categories in Kraft (2023), Table 1.",
          file.path(OUT_FIG, "fig-d2-grade4-enrollment.png"))

plot_bins(reg_k5,
          "K-5 enrollment of regular public school districts, 2023-24",
          sprintf("%s districts with K-5 students; each district counted once (blue) or by its K-5 students (red)",
                  format(n_reg_k5, big.mark = ",")),
          "Source: NCES Common Core of Data, LEA membership and directory files, SY 2023-24. K-5 is the sum of the kindergarten through grade 5 subtotals. Regular districts are LEA types 1 and 2, operational. Size bins follow the study sample-size categories in Kraft (2023), Table 1.",
          file.path(OUT_FIG, "fig-d1-k5-enrollment.png"))

## ----------------------------------------------------------------- markdown summary

fmt <- function(x) format(round(x), big.mark = ",")
pct_table <- function(u, m) {
  d <- pct[universe == u & measure == m]
  w <- dcast(d, percentile ~ weighting, value.var = "value")
  paste0(c("| Percentile | District-weighted | Student-weighted |",
           "|---|---|---|",
           sprintf("| %g | %s | %s |", w$percentile, fmt(w$district), fmt(w$student))),
         collapse = "\n")
}
bin_table <- function(u, m) {
  d <- bins[universe == u & measure == m]
  paste0(c("| Size | Districts | Share of districts | Students | Share of students |",
           "|---|---|---|---|---|",
           sprintf("| %s | %s | %s | %s | %s |", d$bin, fmt(d$n_districts),
                   scales::percent(d$share_districts, accuracy = 0.1),
                   fmt(d$students), scales::percent(d$share_students, accuracy = 0.1))),
         collapse = "\n")
}
head_line <- function(u, m) {
  d <- pct[universe == u & measure == m][1]
  sprintf("%s districts, %s students, mean %s, largest %s.",
          fmt(d$n_districts), fmt(d$students), fmt(d$mean), fmt(d$max))
}

md <- c(
  "<!-- generated by analysis/08-district-enrollment.R; do not edit by hand -->",
  "# District enrollment distributions, school year 2023-24",
  "",
  "Source: NCES Common Core of Data, LEA membership (052) and directory (029) files, SY 2023-24, final release 1a. Fifty states and DC. Whole students.",
  "",
  "K-5 enrollment is the target distribution for the district scenarios; grade 4 and total enrollment are reported for context.",
  "",
  "Two weightings are reported. District-weighted treats each district as one observation (the median district). Student-weighted treats each student as one observation (the district size the median student experiences).",
  "",
  "## Regular public school districts (headline universe)",
  "",
  "LEA types 1 and 2, operational, positive reported membership.",
  "",
  "### K-5 enrollment (target distribution; districts with positive kindergarten through grade 5 subtotals)", "",
  head_line("regular", "k5"), "", pct_table("regular", "k5"), "",
  bin_table("regular", "k5"), "",
  "### Grade 4 enrollment (districts with a positive grade 4 subtotal)", "",
  head_line("regular", "grade4"), "", pct_table("regular", "grade4"), "",
  bin_table("regular", "grade4"), "",
  "### Total enrollment", "", head_line("regular", "total"), "", pct_table("regular", "total"), "",
  bin_table("regular", "total"), "",
  "## Regular districts plus independent charter districts", "",
  "Adds LEA type 7.", "",
  "### K-5 enrollment", "", head_line("regular_charter", "k5"), "", pct_table("regular_charter", "k5"), "",
  "### Grade 4 enrollment", "", head_line("regular_charter", "grade4"), "", pct_table("regular_charter", "grade4"), "",
  "### Total enrollment", "", head_line("regular_charter", "total"), "", pct_table("regular_charter", "total"), "",
  "## All LEAs with reported membership", "",
  "Every LEA type, including service agencies, state-operated agencies, and supervisory unions; any operational status.", "",
  "### K-5 enrollment", "", head_line("all_lea", "k5"), "", pct_table("all_lea", "k5"), "",
  "### Grade 4 enrollment", "", head_line("all_lea", "grade4"), "", pct_table("all_lea", "grade4"), "",
  "### Total enrollment", "", head_line("all_lea", "total"), "", pct_table("all_lea", "total"), ""
)
writeLines(md, file.path(OUT_TAB, "district-enrollment-2324.md"))

## ----------------------------------------------------------------- manifest

sha <- tryCatch(system("git rev-parse --short HEAD", intern = TRUE), error = function(e) "unknown")
writeLines(c(
  sprintf("generated: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  sprintf("git: %s", sha),
  sprintf("R: %s", R.version.string),
  sprintf("membership file: %s", MEM_CSV),
  sprintf("directory file: %s", DIR_CSV),
  sprintf("LEAs with a total row: %d", nrow(totals)),
  sprintf("LEAs matched to directory: %d", sum(!is.na(lea$LEA_TYPE))),
  sprintf("regular districts (universe): %d", n_reg),
  sprintf("regular districts with grade 4: %d", n_reg_g4),
  sprintf("regular districts with K-5: %d", n_reg_k5)
), file.path(OUT_TAB, "district-enrollment-2324-manifest.txt"))

message("Done. Regular districts: ", n_reg, "; with grade 4: ", n_reg_g4, "; with K-5: ", n_reg_k5)
