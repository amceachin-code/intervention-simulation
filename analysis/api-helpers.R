## NAEP Data Service API access and the input guards on what comes back.
## Shared by 01-simulations.R and analysis/tests/test-api-guards.R. Extracted
## (the same pattern as dist-helpers.R) so the guards that keep a bad response
## out of the pipeline have tests of their own that need no network:
##
##   response_status()     the partial-response gate: a response is cached only
##                         if it carries at least expect_rows result rows
##   fetch_api()           cache lookup, download, gate, cache write
##   usable()              drops suppressed/flagged statistics
##   get_stats()           query + parse into year||group -> stattype -> value/se
##   group_composition()   the bottom-decile decomposition behind c_of_p, with
##                         the population-share guard
##
## Nothing here reads a global set by 01. The cache directory, jurisdiction,
## and years are arguments, and the downloader is injectable, so a test can
## feed the gate a truncated or partial response without touching NCES.
##
## Transport note: this machine intercepts TLS, so R's internal download
## methods fail certificate verification. curl_download() shells out to curl,
## which is configured for it.

suppressPackageStartupMessages({library(jsonlite)})

API <- "https://www.nationsreportcard.gov/DataService/GetAdhocData.aspx"
PCT_CODE <- c("10"="PC:P1","25"="PC:P2","50"="PC:P5","75"="PC:P7","90"="PC:P9")
CODE_PCT <- setNames(as.integer(names(PCT_CODE)), PCT_CODE)

## Portable MD5 via base R (tools::md5sum), not a shelled-out `md5`/`md5sum`
## binary whose name differs between macOS and Linux.
cache_key_hash <- function(s) {
  tf <- tempfile(); on.exit(unlink(tf)); writeLines(s, tf)
  unname(tools::md5sum(tf))
}

## The production downloader: fetch `url` into `dest` with curl, returning
## curl's captured stdout/stderr (used only in the failure message).
curl_download <- function(url, dest)
  suppressWarnings(system2("curl", c("-sS","--max-time","240","-o",dest,shQuote(url)),
                           stdout=TRUE, stderr=TRUE))

## Classify a parsed response. d is the fromJSON result, or NULL if the body
## did not parse (for example, a truncated download).
##   "ok"        at least expect_rows result rows: trust and cache it
##   "partial"   some rows but fewer than expect_rows: retry, never cache
##   "api_error" the API put an error string in `result` (HTTP 400 style:
##               bad stattype or subscale)
##   "invalid"   unparseable, or no result rows at all
## Kept as one function so the gate that decides what gets cached is a single
## testable rule rather than three interleaved conditions in fetch_api.
response_status <- function(d, expect_rows) {
  if (is.null(d)) return("invalid")
  if (is.character(d$result)) return("api_error")
  n <- length(d$result)
  if (n >= expect_rows) return("ok")
  if (n > 0) return("partial")
  "invalid"
}

## expect_rows: minimum number of result rows a response must have before it is
## trusted and cached. Without this a PARTIAL response (say, one percentile
## instead of six) would be cached permanently and silently produce an
## incomplete table on every later run.
##
## A cache hit is returned without re-checking expect_rows, as before the
## extraction: only responses that passed the gate were ever written.
fetch_api <- function(params, cache, tries=3, pause=5, expect_rows=1,
                      download=curl_download, api=API) {
  qs <- paste0(names(params), "=",
               vapply(params, function(v) URLencode(as.character(v), reserved=TRUE),
                      character(1)), collapse="&")
  url <- paste0(api, "?", qs)
  key <- file.path(cache, paste0(substr(cache_key_hash(qs), 1, 16), ".json"))
  if (file.exists(key)) return(fromJSON(readLines(key, warn=FALSE), simplifyVector=FALSE))
  for (a in seq_len(tries)) {
    tmp <- tempfile()
    st <- download(url, tmp)
    if (file.exists(tmp) && file.info(tmp)$size > 0) {
      txt <- paste(readLines(tmp, warn=FALSE), collapse="")
      d <- tryCatch(fromJSON(txt, simplifyVector=FALSE), error=function(e) NULL)
      status <- response_status(d, expect_rows)
      if (status == "ok") {
        writeLines(txt, key); unlink(tmp); return(d)
      }
      if (status == "partial")
        message("    partial response (", length(d$result), " of >=", expect_rows,
                " rows); not caching, retrying")
      if (status == "api_error")
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

## Parse a response's result rows into year||group -> stattype -> c(value, se),
## skipping rows usable() rejects. Split from get_stats so the tests can run
## it on a cached fixture.
parse_stats <- function(d) {
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

get_stats <- function(cell, variable, stattypes, years, jurisdiction, cache,
                      expect_rows=NULL, ...) {
  ## TOTAL yields exactly one group, so the default (one grid's worth) is
  ## exact. Subgroup variables yield more than one group; callers that know
  ## the group count (e.g. ECONDIS has 3) should pass it via expect_rows so a
  ## response missing a whole group is rejected rather than cached.
  need <- if (!is.null(expect_rows)) expect_rows else length(stattypes) * length(years)
  d <- fetch_api(list(type="data", subject=cell$subject, grade=cell$grade,
                      subscale=cell$subscale, variable=variable,
                      jurisdiction=jurisdiction, stattype=paste(stattypes, collapse=","),
                      Year=paste(years, collapse=","), ShowDetails="true"),
                 cache=cache, expect_rows=need, ...)
  if (is.null(d)) return(NULL)
  parse_stats(d)
}

## Composition of the population below a cut, by group, from parsed subgroup
## statistics (`raw`, as returned by get_stats for a subgroup variable such as
## ECONDIS). `obs` supplies the cut: the reference-year quantile at cut_pct,
## and for the comparison year that quantile plus D(cut_pct). `years` is
## c(reference, comparison). Needs group_cdf() from dist-helpers.R.
##
## The body of 01's c_of_p, split out so the population-share guard can be
## tested on a synthetic response with a group missing.
group_composition <- function(raw, obs, cut_pct, years, label) {
  years <- as.character(years)
  res <- list()
  for (yr in years) {
    cut <- if (yr == years[1]) obs$Q19[[cut_pct]]
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
    ## Belt-and-suspenders on top of the expect_rows gate in fetch_api: if
    ## population shares don't sum close to 1, a group silently dropped out
    ## somewhere between the API and here, and share_of_tail would be
    ## computed over a partial population.
    pop_sum <- sum(vapply(rows, function(r) r$share, numeric(1)))
    if (abs(pop_sum - 1) > 0.02) {
      message("  !! ", label, " ", yr, ": ECONDIS population shares sum to ",
              round(pop_sum, 3), ", not ~1 -- skipping (a group likely dropped out)")
      next
    }
    for (i in seq_along(rows)) rows[[i]]$share_of_tail <- rows[[i]]$mass/total
    res[[yr]] <- list(cut=cut, rows=rows, reconstructed_mass=total)
  }
  if (length(res)) res else NULL
}
