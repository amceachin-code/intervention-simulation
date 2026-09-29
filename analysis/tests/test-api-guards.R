#!/usr/bin/env Rscript
## Fixture tests for the input guards in analysis/api-helpers.R, the code that
## decides what 01-simulations.R trusts from the NAEP Data Service API.
## Run: Rscript analysis/tests/test-api-guards.R
##
## No network. The fixtures are the committed API responses in
## analysis/.cache/, copied to a temp directory so nothing here can write to
## the real cache, plus small synthetic truncated, partial, and flagged
## responses built from them below. Every download goes through a fake
## downloader; the real one (curl_download) is never called.
##
## Why these guards get their own tests: each one exists because a bad
## response once got through silently.
##   - the expect_rows gate: a partial response would be cached permanently
##   - usable(): jsonlite parses JSON 0 as integer, so an identical(x, 0)
##     check was dead code and flagged statistics went through
##   - the population-share guard: an ECONDIS response missing a group
##     normalized share_of_tail to ~100% for whichever group arrived

source("analysis/dist-helpers.R")
source("analysis/api-helpers.R")
source("analysis/config-helpers.R")

fails <- 0
ok <- function(cond, msg) {
  if (isTRUE(cond)) cat("  PASS  ", msg, "\n")
  else { cat("  FAIL  ", msg, "\n"); fails <<- fails + 1 }
}

## Evaluate expr, collecting its messages instead of printing them, so a test
## can assert on what the gate reported.
capture <- function(expr) {
  msgs <- character(0)
  value <- withCallingHandlers(expr, message=function(m) {
    msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage")
  })
  list(value=value, msgs=msgs)
}

## A downloader that must never be reached (the cache should answer).
no_network <- function(url, dest) stop("network access attempted: ", url)
## A downloader that serves canned bodies, one per attempt, and counts calls.
## A body of NA writes an empty file (curl producing nothing).
fake_download <- function(bodies) {
  env <- new.env(); env$calls <- 0L
  f <- function(url, dest) {
    env$calls <- env$calls + 1L
    b <- bodies[[min(env$calls, length(bodies))]]
    if (is.na(b)) file.create(dest) else writeLines(b, dest)
    "fake curl output"
  }
  list(fn=f, env=env)
}

if (!length(Sys.glob("analysis/.cache/*.json")))
  stop("analysis/.cache/ has no JSON fixtures. It is tracked in git; restore it with git checkout.")
fixture_cache <- file.path(tempdir(), "fixture-cache")
dir.create(fixture_cache, showWarnings=FALSE)
invisible(file.copy(Sys.glob("analysis/.cache/*.json"), fixture_cache, overwrite=TRUE))

cfg   <- load_sim_config()
years <- cfg_get(cfg, "years")
juris <- cfg_get(cfg, "jurisdiction")
cells <- setNames(cfg_get(cfg, "cells"), vapply(cfg_get(cfg, "cells"), `[[`, "", "label"))
TOTAL_ST <- c(unname(PCT_CODE), "SD:SD")
ECON_ST  <- c(unname(PCT_CODE), "RP:RP")
ECON_ROWS <- 3 * (length(PCT_CODE) + 1) * 2     # 01's c_of_p expect_rows: 36

## The exact query 01 issues, so the cache key matches the committed file.
query <- function(cell, variable, stattypes)
  list(type="data", subject=cell$subject, grade=cell$grade,
       subscale=cell$subscale, variable=variable, jurisdiction=juris,
       stattype=paste(stattypes, collapse=","),
       Year=paste(years, collapse=","), ShowDetails="true")
## Raw JSON text of a committed response, and a variant with some rows dropped.
fixture_text <- function(cell, variable, stattypes) {
  qs <- paste0(names(query(cell, variable, stattypes)), "=",
               vapply(query(cell, variable, stattypes),
                      function(v) URLencode(as.character(v), reserved=TRUE), ""),
               collapse="&")
  paste(readLines(file.path(fixture_cache, paste0(substr(cache_key_hash(qs), 1, 16), ".json")),
                  warn=FALSE), collapse="")
}
with_rows <- function(txt, keep) {
  d <- jsonlite::fromJSON(txt, simplifyVector=FALSE)
  d$result <- Filter(keep, d$result)
  as.character(jsonlite::toJSON(d, auto_unbox=TRUE, digits=NA, null="null"))
}

rg4 <- cells[["Reading G4"]]
tot_txt  <- fixture_text(rg4, "TOTAL",   TOTAL_ST)
econ_txt <- fixture_text(rg4, "ECONDIS", ECON_ST)

cat("\n1. response_status: the rule that decides what gets cached\n")
full <- jsonlite::fromJSON(tot_txt, simplifyVector=FALSE)
ok(identical(response_status(full, 12), "ok"), "a complete TOTAL response (12 rows) is ok at expect_rows=12")
half <- full; half$result <- half$result[1:6]
ok(identical(response_status(half, 12), "partial"), "6 of 12 rows is partial")
ok(identical(response_status(list(result=list()), 12), "invalid"), "zero rows is invalid, not partial")
ok(identical(response_status(NULL, 12), "invalid"), "an unparseable body (NULL) is invalid")
ok(identical(response_status(list(result="Invalid subscale"), 1), "api_error"),
   "a string in `result` (the API's 400 style) is api_error, never ok")

cat("\n2. fetch_api / get_stats against the committed cache\n")
raw_tot <- get_stats(rg4, "TOTAL", TOTAL_ST, years, jurisdiction=juris,
                     cache=fixture_cache, download=no_network)
ok(!is.null(raw_tot) && length(raw_tot) == 2,
   "a cached TOTAL response is read with no network (two year groups)")
ok(all(vapply(raw_tot, function(x) setequal(names(x), TOTAL_ST), logical(1))),
   "each year carries all five percentiles and the SD")
raw_econ <- get_stats(rg4, "ECONDIS", ECON_ST, years, jurisdiction=juris,
                      cache=fixture_cache, expect_rows=ECON_ROWS, download=no_network)
ok(!is.null(raw_econ) && length(raw_econ) == 6,
   "a cached ECONDIS response is read with no network (3 groups x 2 years)")

cat("\n3. The expect_rows gate on fresh downloads\n")
## Each case gets its own empty cache so a pass cannot come from a cache hit.
fresh <- function() { d <- tempfile("cache-"); dir.create(d); d }
fetch_with <- function(bodies, expect_rows, tries=3) {
  cache <- fresh(); fk <- fake_download(bodies)
  r <- capture(fetch_api(query(rg4, "ECONDIS", ECON_ST), cache=cache, tries=tries,
                         pause=0, expect_rows=expect_rows, download=fk$fn))
  list(value=r$value, msgs=r$msgs, calls=fk$env$calls,
       cached=list.files(cache, pattern="\\.json$"))
}

## A response missing one whole ECONDIS group: 24 of the 36 rows. This is the
## case the ECONDIS-specific expect_rows exists for.
two_groups <- with_rows(econ_txt, function(r) r$varValueLabel != "Not economically disadvantaged")
r <- fetch_with(list(two_groups), ECON_ROWS)
ok(is.null(r$value) && !length(r$cached),
   "an ECONDIS response missing a group (24 of 36 rows) is rejected and not cached")
ok(r$calls == 3 && sum(grepl("partial response \\(24 of >=36 rows\\)", r$msgs)) == 3,
   "the partial response is retried and reported on every attempt")

r <- fetch_with(list(substr(econ_txt, 1, 2000)), ECON_ROWS)
ok(is.null(r$value) && !length(r$cached), "a truncated (unparseable) body is rejected and not cached")

r <- fetch_with(list(NA), ECON_ROWS)
ok(is.null(r$value) && any(grepl("^    curl failed", r$msgs)), "an empty download is reported as a curl failure")

r <- fetch_with(list('{"status":400,"result":"Invalid subscale"}'), 1)
ok(is.null(r$value) && !length(r$cached) && any(grepl("API says: Invalid subscale", r$msgs)),
   "an API error string is surfaced, not cached, and never treated as data")

r <- fetch_with(list(two_groups, econ_txt), ECON_ROWS)
ok(!is.null(r$value) && length(r$value$result) == 36 && length(r$cached) == 1 && r$calls == 2,
   "a partial response followed by a complete one returns and caches the complete one")

## A complete response is cached under the same key 01 would look up, so a
## second call is answered from the cache without the network.
cache <- fresh(); fk <- fake_download(list(econ_txt))
first  <- fetch_api(query(rg4, "ECONDIS", ECON_ST), cache=cache, pause=0,
                    expect_rows=ECON_ROWS, download=fk$fn)
second <- fetch_api(query(rg4, "ECONDIS", ECON_ST), cache=cache, pause=0,
                    expect_rows=ECON_ROWS, download=no_network)
ok(fk$env$calls == 1 && identical(first, second),
   "a complete response is cached and the next call is served from the cache")

cat("\n4. usable(): suppressed and flagged statistics\n")
base_row <- full$result[[1]]
n0 <- DROPPED$n
ok(all(vapply(full$result, usable, logical(1))), "every row of the committed TOTAL fixture is usable")
ok(DROPPED$n == n0, "usable() counts nothing as dropped on clean rows")
## Built through the JSON parser, not as R literals, because the historical
## bug was specific to how jsonlite types JSON 0 (as integer 0L).
flagged <- function(field, json_value) {
  row <- base_row; row[[field]] <- NULL
  txt <- sub("}$", paste0(',"', field, '":', json_value, "}"),
             as.character(jsonlite::toJSON(row, auto_unbox=TRUE, digits=NA)))
  jsonlite::fromJSON(txt, simplifyVector=FALSE)
}
ok(is.integer(flagged("isStatDisplayable", "0")$isStatDisplayable),
   "fixture check: jsonlite parses JSON 0 as integer (the case the numeric comparison exists for)")
n0 <- DROPPED$n
ok(!usable(flagged("isStatDisplayable", "0")),   "isStatDisplayable = 0 (integer from JSON) is dropped")
ok(!usable(flagged("isStatDisplayable", '"0"')), "isStatDisplayable = \"0\" (string) is dropped")
ok(!usable(flagged("errorFlag", "1")),           "errorFlag = 1 is dropped")
ok(!usable(flagged("value", "999")),             "the 999 sentinel is dropped")
ok(DROPPED$n == n0 + 4, "each dropped row is counted, so drops are never silent")
ok(usable(flagged("errorFlag", "0")) && usable(flagged("isStatDisplayable", "1")),
   "errorFlag = 0 and isStatDisplayable = 1 are kept")
ok(!usable(flagged("value", "null")), "a row with no value is not usable")
sentinel <- with_rows(tot_txt, function(r) TRUE)
sentinel <- sub('"value":[0-9.]+', '"value":999', sentinel)   # first row only
parsed <- parse_stats(jsonlite::fromJSON(sentinel, simplifyVector=FALSE))
ok(sum(lengths(parsed)) == 11, "parse_stats drops the one 999 row and keeps the other 11")

cat("\n5. group_composition: the population-share guard behind c_of_p\n")
## obs for Reading G4, built from the TOTAL fixture the way 01's observed()
## builds it (only the p10 and p25 entries group_composition reads).
yr <- as.character(years)
pv <- function(y, code) unname(raw_tot[[paste(y, "All students", sep="||")]][[code]]["value"])
obs <- list(Q19=list("10"=pv(yr[1], "PC:P1"), "25"=pv(yr[1], "PC:P2")),
            D=list("10"=c(d=pv(yr[2], "PC:P1") - pv(yr[1], "PC:P1")),
                   "25"=c(d=pv(yr[2], "PC:P2") - pv(yr[1], "PC:P2"))))
comp <- capture(group_composition(raw_econ, obs, "10", years, "Reading G4"))$value
ok(!is.null(comp) && setequal(names(comp), yr), "a complete ECONDIS fixture decomposes in both years")
## Against the committed output: the decomposition from the fixture must be
## the one in tables/sim-bottom-decile.csv (written with 15 significant digits).
bd <- read.csv("tables/sim-bottom-decile.csv", stringsAsFactors=FALSE)
want <- bd[bd$cell == "Reading G4" & bd$target_pct == 10, ]
got <- do.call(rbind, lapply(names(comp), function(y) do.call(rbind, lapply(comp[[y]]$rows, function(r)
  data.frame(year=as.integer(y), group=r$group, share_of_tail=r$share_of_tail)))))
m <- merge(want, got, by=c("year", "group"))
ok(nrow(m) == nrow(want) && nrow(m) > 0 && max(abs(m$share_of_tail.x - m$share_of_tail.y)) < 1e-9,
   "share_of_tail from the fixture matches tables/sim-bottom-decile.csv")
ok(all(vapply(comp, function(y) abs(sum(vapply(y$rows, `[[`, 0, "share_of_tail")) - 1) < 1e-12, logical(1))),
   "shares of the tail sum to 1 within each year")

## Synthetic: the "Not economically disadvantaged" group missing in the
## reference year only. The gate in fetch_api would stop this response; the
## guard is the second line if a group is lost after parsing.
drop_ref <- raw_econ[names(raw_econ) != paste(yr[1], "Not economically disadvantaged", sep="||")]
r <- capture(group_composition(drop_ref, obs, "10", years, "Reading G4"))
ok(!is.null(r$value) && identical(names(r$value), yr[2]),
   "a year with a group missing is skipped; the complete year is kept")
ok(any(grepl(paste0("Reading G4 ", yr[1], ": ECONDIS population shares sum to"), r$msgs)),
   "the skip is reported, naming the cell and year")
drop_both <- raw_econ[!grepl("\\|\\|Not economically disadvantaged$", names(raw_econ))]
r <- capture(group_composition(drop_both, obs, "10", years, "Reading G4"))
ok(is.null(r$value) && sum(grepl("population shares sum to", r$msgs)) == 2,
   "with the group missing in both years the decomposition returns NULL")
## Without the guard this is what would have been published: the surviving
## group's share of the tail normalized to about 100 percent.
ok(max(vapply(r$msgs, function(s) as.numeric(sub(".*sum to ([0-9.]+),.*", "\\1", s)), 0)) < 0.98,
   "the rejected population shares are far from 1 (the guard is not firing on rounding)")

cat("\n6. The score distribution (DP:DP): parse_distribution and its gate\n")
## The committed histogram fixture for Reading G4 2019, fetched by the exact
## query get_distribution issues (one year per request).
dist_query <- function(cell, year)
  list(type="data", subject=cell$subject, grade=cell$grade, subscale=cell$subscale,
       variable="TOTAL", jurisdiction=juris, stattype=DIST_STAT,
       Year=as.character(year), ShowDetails="true")
dist_txt <- local({
  q <- dist_query(rg4, years[1])
  qs <- paste0(names(q), "=", vapply(q, function(v) URLencode(as.character(v), reserved=TRUE), ""),
               collapse="&")
  paste(readLines(file.path(fixture_cache, paste0(substr(cache_key_hash(qs), 1, 16), ".json")),
                  warn=FALSE), collapse="")
})
dist_d <- jsonlite::fromJSON(dist_txt, simplifyVector=FALSE)
h <- parse_distribution(dist_d, rg4$scale_max, "Reading G4 2019")
## (Bin edges are inferred from the bin number, so they are not checked here;
## test-sim.R checks that they reproduce the published percentiles.)
ok(nrow(h) == 50 && identical(h$bin, 1:50) && abs(sum(h$pct) - 100) < 0.01,
   "the committed DP:DP fixture parses to 50 contiguous bins summing to 100")
ok(length(dist_d$result) == dist_rows_expected(rg4$scale_max),
   sprintf("the fixture has exactly the rows the gate expects (%d: 50 bins + 6 summary rows)",
           dist_rows_expected(rg4$scale_max)))
ok(identical(get_distribution(rg4, years[1], jurisdiction=juris, cache=fixture_cache), h),
   "get_distribution reads the committed fixture from cache (no network)")
## What must be refused: a missing bin, a flagged bin, bins that do not sum to
## 100, and the wrong scale (Math G12's 30 bins read as a 0-500 scale).
refuses <- function(d, scale_max=500) inherits(tryCatch(parse_distribution(d, scale_max, "t"),
                                                        error=function(e) e), "error")
drop_bin <- dist_d; drop_bin$result <- Filter(function(r) r$stattype != "DP:D25", drop_bin$result)
ok(refuses(drop_bin), "a histogram missing a bin is refused (it would shift every share above it)")
flag_bin <- dist_d
flag_bin$result <- lapply(flag_bin$result, function(r) { if (r$stattype == "DP:D25") r$errorFlag <- 257L; r })
ok(refuses(flag_bin), "a histogram with a flagged bin is refused, not silently dropped")
off_sum <- dist_d
off_sum$result <- lapply(off_sum$result, function(r) { if (r$stattype == "DP:D25") r$value <- r$value + 1; r })
ok(refuses(off_sum), "a histogram whose bins do not sum to 100 is refused")
ok(refuses(dist_d, scale_max=300), "a 50-bin histogram is refused for a 0-300 scale")
## The fetch gate: a truncated DP:DP response (half the rows) is not cached.
half <- with_rows(dist_txt, local({ i <- 0; function(r) { i <<- i + 1; i <= 28 } }))
cache <- fresh(); fk <- fake_download(list(half))
r <- capture(fetch_api(dist_query(rg4, years[1]), cache=cache, tries=1, pause=0,
                       expect_rows=dist_rows_expected(rg4$scale_max), download=fk$fn))
ok(is.null(r$value) && !length(list.files(cache, pattern="\\.json$")),
   "a truncated DP:DP response (28 of 56 rows) is rejected and not cached")

cat(sprintf("\n%s: %d failure(s)\n", if (fails == 0) "ALL TESTS PASSED" else "TESTS FAILED", fails))
quit(status = if (fails == 0) 0 else 1)
