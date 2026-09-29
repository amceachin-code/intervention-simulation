## Config loader shared by every script that uses a literature parameter.
##
## analysis/config/sim-params.yaml declares each effect size, participation
## rate, benchmark, and validation target once, with its source. Before this
## file existed only 01-simulations.R read the yaml; the other scripts carried
## their own copies of the same numbers, so revising a parameter in the config
## silently changed some outputs and not others. Every script now reads the
## values through the functions below.
##
## Deliberately NO fallback to built-in defaults. A missing yaml package, a
## missing file, or a missing key stops the script with a message that names
## what is missing. A silent fallback is how the duplication crept in: the
## defaults were a second copy of the config that nothing kept in sync.
##
## Source from the project root, like every other helper here.

CONFIG_DEFAULT <- "analysis/config/sim-params.yaml"

## Parse the config. `path` is the yaml file (01-simulations.R passes its
## --config flag through; everything else uses the default).
load_sim_config <- function(path = CONFIG_DEFAULT) {
  if (!requireNamespace("yaml", quietly = TRUE))
    stop("package 'yaml' is required to read ", path,
         ". Install it with install.packages(\"yaml\").", call. = FALSE)
  if (!file.exists(path))
    stop("config file not found: ", path, ". Run from the project root.",
         call. = FALSE)
  cfg <- yaml::read_yaml(path)
  attr(cfg, "path") <- path
  cfg
}

## Fetch a (possibly nested) key, stopping if it is absent. cfg_get(cfg, "a",
## "b") returns cfg$a$b. A key that is present with a null value is also an
## error: none of the scalar parameters has a meaningful "no value".
cfg_get <- function(cfg, ...) {
  keys <- c(...); x <- cfg
  where <- if (is.null(attr(cfg, "path"))) "the config" else attr(cfg, "path")
  for (i in seq_along(keys)) {
    if (!is.list(x) || !keys[i] %in% names(x) || is.null(x[[keys[i]]]))
      stop("config key '", paste(keys[seq_len(i)], collapse = "."),
           "' is missing from ", where, call. = FALSE)
    x <- x[[keys[i]]]
  }
  x
}

## Look up one field of the entry with a given id in a list-of-records section
## (benchmarks, participation). Matching on id rather than position means
## reordering the yaml cannot silently swap two parameters.
cfg_by_id <- function(cfg, section, id, field) {
  recs <- cfg_get(cfg, section)
  hit <- Filter(function(r) identical(r$id, id), recs)
  if (length(hit) != 1)
    stop("config section '", section, "' has ", length(hit), " entries with id '",
         id, "' (need exactly 1) in ", attr(cfg, "path"), call. = FALSE)
  v <- hit[[1]][[field]]
  if (is.null(v))
    stop("config entry ", section, "[id=", id, "] has no '", field, "' in ",
         attr(cfg, "path"), call. = FALSE)
  v
}

## Shorthands for the two lookups every script needs.
cfg_g <- function(cfg, id) cfg_by_id(cfg, "benchmarks",    id, "g")
cfg_c <- function(cfg, id) cfg_by_id(cfg, "participation", id, "c")

## The treated effect used wherever a single program effect is applied (01
## Table C3, 06, 07, and the tests): the benchmark named by treated_effect.
cfg_treated_g <- function(cfg) cfg_g(cfg, cfg_get(cfg, "treated_effect"))

## Kraft (2020) effect-size percentiles as a named numeric vector, in the
## order requested (default: the three reference lines the figures draw).
cfg_kraft2020 <- function(cfg, which = c("p50", "p75", "p90"))
  setNames(vapply(which, function(k) as.numeric(cfg_get(cfg, "kraft2020_effect_percentiles", k)),
                  numeric(1)), which)

## Table 2 column (a) validation targets as a named numeric vector.
cfg_table2a <- function(cfg) unlist(cfg_get(cfg, "table2a_diff_change"))

## Resolve one numeric field of a plotted program point. A point names either
## a config id (`<field>_id`, looked up in `section`) or a literal value
## (`<field>`); a literal written as null means "not reported" and becomes NA.
## One of the two keys must be present, so a typo cannot quietly become NA.
cfg_point_value <- function(cfg, pt, field, section) {
  idk <- paste0(field, "_id")
  if (!is.null(pt[[idk]]))
    return(cfg_by_id(cfg, section, pt[[idk]], if (section == "benchmarks") "g" else "c"))
  if (!field %in% names(pt))
    stop("program point '", pt$label, "' has neither '", field, "' nor '", idk,
         "' in ", attr(cfg, "path"), call. = FALSE)
  if (is.null(pt[[field]])) NA_real_ else as.numeric(pt[[field]])
}

## The --cell argument shared by 04-district-requirements.R and
## 06-seat-allocation.R: --flag value pairs, like 01- and 02-. A bare
## positional cell name (the convention before 2026-09-29) is refused rather
## than ignored, so an old command line cannot silently run the default cell,
## and an unknown cell stops here with the list of valid ones instead of
## failing later on an empty subset.
parse_cell_arg <- function(default, available, args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) && !startsWith(args[1], "--"))
    stop("positional cell names are no longer accepted; use --cell \"", args[1], "\"",
         call. = FALSE)
  i <- match("--cell", args)
  cell <- if (is.na(i)) default else args[i + 1]
  if (is.na(cell) || !cell %in% available)
    stop("unknown cell '", cell, "'. Available: ",
         paste(sort(unique(available)), collapse = ", "), call. = FALSE)
  cell
}
