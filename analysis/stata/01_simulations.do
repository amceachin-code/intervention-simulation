*! Intervention simulations: benchmarking the recovery requirement.  Public NAEP data only.
*! Stata port of analysis/01-simulations.R.  No restricted-use data required.
*!
*! Pulls the 10/25/50/75/90th percentiles and SD, national, 2019 and 2024, for
*! six grade-subject cells from the public NAEP Data Service API, then computes:
*!   A. D(p) = Q2024(p) - Q2019(p) with SEs, and the differential change
*!      D(.90) - D(.10).  This reproduces the manuscript's Table 2 column (a),
*!      which came from restricted-use microdata -- the validation that licenses
*!      using public data for the simulations.
*!   B. The restoration requirement g*(p) = -D(p)/S in 2019 national SD units.
*!
*! This port covers A and B only -- the mechanical quantile-difference and
*! restoration-requirement arithmetic -- which is what it cross-validates
*! against the R script. The participation-adjusted requirement (C), the
*! benchmarked-program share of the deficit (D), and the ECONDIS bottom-decile
*! decomposition (Table E) have a single implementation, in R.
*!
*! Dependencies: none beyond base Stata.  JSON is parsed with native string
*! functions because insheetjson/libjson are not installed and are not needed
*! for a payload this regular.
*!
*! Usage:  do analysis/stata/01_simulations.do

version 17
clear all
set more off

*-------------------------------------------------------------------- settings
local API  "https://www.nationsreportcard.gov/DataService/GetAdhocData.aspx"
local JUR  "NT"                    // national public + private
local CACHE "analysis/.cache-stata"
local OUT   "tables"
capture mkdir "`CACHE'"
capture mkdir "`OUT'"

* Percentile stattype codes.  The API uses XX:YY form; colons must be
* percent-encoded as %3A in the query string.
local PCODES "PC%3AP1 PC%3AP2 PC%3AP5 PC%3AP7 PC%3AP9"
local PLABS  "10 25 50 75 90"

* Six cells.  Grade 12 mathematics is MWPCM on a 0-300 scale; MRPCM returns
* HTTP 400 there.  This is the single easiest thing to get wrong.
local NCELL 6
local c1 "reading mathematics"
local cell1 "reading 4 RRPCM Reading_G4"
local cell2 "reading 8 RRPCM Reading_G8"
local cell3 "reading 12 RRPCM Reading_G12"
local cell4 "mathematics 4 MRPCM Math_G4"
local cell5 "mathematics 8 MRPCM Math_G8"
local cell6 "mathematics 12 MWPCM Math_G12"

* Manuscript Table 2 column (a): the validation targets.
local t2_Reading_G4  8.7
local t2_Reading_G8  7.0
local t2_Reading_G12 1.5
local t2_Math_G4     7.9
local t2_Math_G8     6.4
local t2_Math_G12    4.5

*------------------------------------------------------------------- fetch
* Downloads one cell's statistics and appends parsed records to a growing file.
* Caches on disk: NAEP revises, and the API is slow (30-180s uncached).
capture program drop naep_fetch
program define naep_fetch, rclass
    syntax , SUBject(string) GRade(int) SUBscale(string) STATtypes(string) ///
             YEARs(string) VARiable(string) API(string) JUR(string) CACHE(string)

    local st = subinstr("`stattypes'", " ", ",", .)
    local url "`api'?type=data&subject=`subject'&grade=`grade'&subscale=`subscale'"
    local url "`url'&variable=`variable'&jurisdiction=`jur'&stattype=`st'"
    local url "`url'&Year=`years'&ShowDetails=true"

    local key "`cache'/`subject'_`grade'_`subscale'_`variable'.json"
    capture confirm file "`key'"
    if _rc {
        * Up to 3 attempts: the API intermittently returns an empty result.
        forvalues a = 1/3 {
            capture copy "`url'" "`key'", replace
            if _rc == 0 {
                * Reject an empty or error payload rather than caching it.
                tempname fh
                file open `fh' using "`key'", read text
                file read `fh' probe
                file close `fh'
                if strpos(`"`probe'"', `""result": []"') == 0 & ///
                   strpos(`"`probe'"', `""statusCode":400"') == 0 continue, break
                erase "`key'"
            }
            sleep 5000
        }
    }
    capture confirm file "`key'"
    if _rc {
        di as error "  FAIL  `subject' grade `grade': no data"
        return local ok = 0
        exit
    }
    return local ok = 1
    return local path "`key'"
end

*------------------------------------------------------- parse one JSON file
* Reads a NAEP JSON payload and posts one observation per usable record.
* NAEP marks unusable cells three ways -- a 999 sentinel, isStatDisplayable=0,
* and errorFlag -- and all three are checked here.
capture program drop naep_parse
program define naep_parse
    syntax , PATH(string) CELL(string) POSTname(string)
    * Mata handles the parsing: Stata's macro tokenizer cannot safely carry JSON
    * containing quotes, colons and braces, and hits "invalid name" on it.
    mata: naep_parse_file("`path'", "`cell'", "`postname'")
end

mata:
mata set matastrict off
void naep_parse_file(string scalar path, string scalar cell, string scalar pname)
{
    real scalar fh, i, yr, val, se, disp, eflag, nrec
    string scalar line, json, piece, st, grp, q
    string colvector recs

    q = char(34)          // a double quote, without embedding one in source

    fh = fopen(path, "r")
    json = ""
    while ((line = fget(fh)) != J(0,0,"")) json = json + line
    fclose(fh)

    // One record per brace-delimited object.
    recs = tokens(subinstr(json, "{", "|{"), "|")'
    nrec = 0
    for (i = 1; i <= rows(recs); i++) {
        piece = recs[i]
        if (!regexm(piece, q + "stattype" + q + ":" + q + "([^" + q + "]*)" + q)) continue
        st = regexs(1)

        yr = val = se = .
        disp = 1 ; eflag = 0 ; grp = ""
        if (regexm(piece, q + "year" + q + ":([0-9]+)"))              yr    = strtoreal(regexs(1))
        if (regexm(piece, q + "value" + q + ":(-?[0-9.eE+-]+)"))      val   = strtoreal(regexs(1))
        if (regexm(piece, q + "stdError" + q + ":(-?[0-9.eE+-]+)"))   se    = strtoreal(regexs(1))
        if (regexm(piece, q + "isStatDisplayable" + q + ":([0-9]+)")) disp  = strtoreal(regexs(1))
        if (regexm(piece, q + "errorFlag" + q + ":([0-9]+)"))         eflag = strtoreal(regexs(1))
        if (regexm(piece, q + "varValueLabel" + q + ":" + q + "([^" + q + "]*)" + q)) grp = regexs(1)

        // NAEP marks unusable cells three ways: a 999 sentinel,
        // isStatDisplayable=0, and errorFlag. Check all three.
        if (val == . | abs(val - 999) < 1e-9 | disp == 0 | eflag != 0) continue

        stata("post " + pname + " (" + q + cell + q + ") (" + strofreal(yr) + ") (" +
              q + st + q + ") (" + q + grp + q + ") (" +
              strofreal(val, "%21x") + ") (" + strofreal(se, "%21x") + ")")
        nrec++
    }
    printf("        parsed %f records\n", nrec)
}
end

*------------------------------------------------------------------ collect
tempfile raw
tempname P
postfile `P' str20 cell int year str12 stattype str40 group double value double se ///
    using "`raw'", replace

di as text _n "Pulling public NAEP percentiles (API is slow when uncached)..."
local okcells ""
local failcells ""
forvalues k = 1/`NCELL' {
    local spec "`cell`k''"
    local subj  : word 1 of `spec'
    local gr    : word 2 of `spec'
    local sc    : word 3 of `spec'
    local lab   : word 4 of `spec'

    naep_fetch, subject("`subj'") grade(`gr') subscale("`sc'") ///
        stattypes("`PCODES' SD%3ASD") years("2019,2024") variable("TOTAL") ///
        api("`API'") jur("`JUR'") cache("`CACHE'")
    if "`r(ok)'" == "1" {
        di as result "  ok   `lab'"
        naep_parse, path("`r(path)'") cell("`lab'") postname(`P')
        local okcells "`okcells' `lab'"
    }
    else local failcells "`failcells' `lab'"
}
postclose `P'

use "`raw'", clear
if _N == 0 {
    di as error "No records retrieved. Check connectivity; Stata's copy uses the system proxy."
    exit 601
}

*------------------------------------------------------------------ reshape
* Map stattype codes to percentile numbers.
gen int pct = .
replace pct = 10 if stattype == "PC:P1"
replace pct = 25 if stattype == "PC:P2"
replace pct = 50 if stattype == "PC:P5"
replace pct = 75 if stattype == "PC:P7"
replace pct = 90 if stattype == "PC:P9"
gen byte issd = (stattype == "SD:SD")

* The 2019 SD is the denominator of every requirement, so keep it per cell.
preserve
    keep if issd & year == 2019
    keep cell value
    rename value sd2019
    tempfile sds
    save "`sds'", replace
restore
preserve
    keep if issd & year == 2024
    keep cell value
    rename value sd2024
    tempfile sds24
    save "`sds24'", replace
restore

keep if !missing(pct)
keep cell year pct value se
reshape wide value se, i(cell pct) j(year)

merge m:1 cell using "`sds'",   nogen
merge m:1 cell using "`sds24'", nogen

gen double d    = value2024 - value2019
* Independent samples across administrations, per NCES convention for
* cross-year comparisons.  The shared score scale induces a small positive
* covariance, so this is conservative.  No missing-value suppression: a
* missing published SE must propagate rather than silently become zero.
gen double d_se = sqrt(se2019^2 + se2024^2)
gen double g_star    = -d / sd2019
gen double g_star_se = d_se / sd2019
rename value2019 q2019

* Differential change and a conservative SE for it. d[_N]-d[1] is p90 minus
* p10 only when sorting on pct puts exactly the 5 published percentiles in
* order with none missing; assert that rather than silently computing the
* wrong pair (e.g. p75 minus p10) if a cell came back with a partial set.
sort cell
by cell: assert _N == 5
bysort cell (pct): gen double diff_change = d[_N] - d[1]
bysort cell (pct): gen double diff_change_se = sqrt(d_se[_N]^2 + d_se[1]^2)

order cell pct q2019 d d_se g_star g_star_se sd2019 sd2024 diff_change diff_change_se
sort cell pct
label var g_star "Restoration requirement, 2019 national SD"

*------------------------------------------------------------- validation
di as text _n "{hline 78}"
di as text "Table A. Validation against the manuscript's restricted-use analysis"
di as text "{hline 78}"
di as text %-14s "Cell" %12s "Diff.change" %10s "Table 2(a)" %10s "Delta" %10s "SE"
local nbad = 0
levelsof cell, local(cells)
foreach c of local cells {
    quietly summarize diff_change if cell == "`c'", meanonly
    local got = r(mean)
    quietly summarize diff_change_se if cell == "`c'", meanonly
    local gse = r(mean)
    local tgt = `t2_`c''
    local del = `got' - `tgt'
    di as result %-14s "`c'" %12.2f `got' %10.1f `tgt' %10.2f `del' %10.2f `gse'
    if abs(`del') > 0.05 local ++nbad
}
if `nbad' == 0 di as result _n "  All cells reproduce Table 2 column (a) to the reported precision."
else di as error _n "  `nbad' cell(s) DEVIATE by more than 0.05 -- investigate before using."

*------------------------------------------------------------------- export
export delimited using "`OUT'/sim-quantiles-stata.csv", replace
di as text _n "Wrote `OUT'/sim-quantiles-stata.csv"

* Provenance.  NAEP revises published statistics, so the retrieval context
* matters as much as the numbers.
file open mf using "`OUT'/sim-manifest-stata.txt", write replace text
file write mf "# Simulation run manifest (Stata)" _n
file write mf "generated: " "`c(current_date)' `c(current_time)'" _n
file write mf "script: analysis/stata/01_simulations.do" _n
file write mf "stata: `c(stata_version)' `c(flavor)' `c(os)'" _n
file write mf "jurisdiction: `JUR'" _n
file write mf "api: `API'" _n
file write mf "cells_ok:`okcells'" _n
file write mf "cells_failed:`failcells'" _n
file write mf "cache: `CACHE' (delete to force refresh)" _n
file write mf "inputs: public NAEP Data Service API only; NO restricted-use data" _n
file close mf
di as text "Wrote `OUT'/sim-manifest-stata.txt"
