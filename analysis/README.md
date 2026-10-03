# analysis/

R code for the intervention simulations, plus an independent Stata port of the core computation. **No restricted-use data.** Everything comes from the public NAEP Data Service API, the literature parameters in `config/sim-params.yaml`, the Kraft (2023) database in `../kraft-2023-data/`, and the CCD files in `../district-enrollment-data/`.

Run every script from the project root.

## Run order

```
Rscript analysis/01-simulations.R            # ~2 min cold, instant cached; root of the pipeline
Rscript analysis/02-figures.R                # figures/sim/fig8, fig9, fig10
Rscript analysis/03-district-cases.R         # tables/sim-district-cases.md, fig11
for c in "Reading G4" "Reading G8" "Math G4" "Math G8"; do
  Rscript analysis/04-district-requirements.R --cell "$c" # fig12 per cell
  Rscript analysis/06-seat-allocation.R --cell "$c"       # fig13-15 and seat CSVs per cell
done
Rscript analysis/05-compile-summary.R        # tables/SIM-SUMMARY.md
Rscript analysis/08-district-enrollment.R    # needs the raw CCD membership file (local-only)
Rscript analysis/09-kraft-benchmarks.R       # needs kraft-2023-data/kraft2023effectsize.xls
Rscript analysis/10-export-tool-data.R       # docs/cells.js for the explorer and methods page (rerun after 01, 09, or a config change)
Rscript analysis/11-export-explorer-years.R  # docs/years.js and tables/explorer-pairs-check.csv (about 1 s from cache)

bash analysis/tests/run-all.sh               # every tests/test-*.R (and test-*.mjs when node is installed); exits non-zero on any failure
bash analysis/tests/run-all.sh --regen       # the same, plus test-regen.sh (reruns 01 to 09, cmp's tables/*.csv)
```

Individual tests:

```
Rscript analysis/tests/test-sim.R            # simulation pipeline, incl. Table 2(a) validation and R/Stata agreement
Rscript analysis/tests/test-api-guards.R     # API input guards on fixture responses (no network)
Rscript analysis/tests/test-district-enrollment.R
Rscript analysis/tests/test-kraft-benchmarks.R
Rscript analysis/tests/test-kraft-target.R
node analysis/tests/test-tool-engine.mjs     # explorer engine (docs/engine.js) against the committed seat-allocation and explorer-pairs CSVs
bash analysis/tests/test-regen.sh            # regeneration: rerun from the committed cache, byte-compare tables/*.csv
```

Scripts 02 to 06 and 09 read `tables/sim-quantiles.csv` (02, 05, and the tests also read `tables/sim-bottom-decile.csv`; 03, 06, 10, and the tests also read `tables/sim-distribution.csv`; 06, 10, and the tests also read `tables/sim-distribution-econdis.csv`), so `01-simulations.R` must have run at least once; 02 to 06 stop with that instruction if it has not. `01-` accepts `--cache DIR`, `--out DIR`, `--config FILE`, and `--jurisdiction CODE` (default `NT`, national). `04-` and `06-` take `--cell CELL` (defaults: Math G8 and Reading G4) and refuse a bare positional cell name.

**The paper's pipeline is fixed at 2019 to 2024.** Scripts 01 to 10, `tables/sim-*`, the Stata port, and the Table 2(a) validation compare those two years only. Script 11 is the explorer's own export: it lets the pages compare any reference year with any later NAEP year from 2005 to 2024, reads its years from `config/explorer-years.yaml` rather than `sim-params.yaml`, and changes no input or output of 01 to 10 (`run-all.sh --regen` stays byte-identical). It reimplements nothing: it calls `get_stats` and `get_distribution` (`api-helpers.R`), `quantile_points` and `group_quantile_points` (`mixture.R`), and `ed_share_points`, `make_ed_screen`, `alloc_uniform`, and `calibrated_program_quantiles`. It passes `min_gap = 0.02` to `quantile_points` (see `mixture.R` below); 01 to 10 keep the default.

**The config drives every script.** 01, 02, 04, 05, 06, 10, and `tests/test-sim.R` read their literature parameters (effect sizes, participation rates, Kraft (2020) percentiles, the treated effect, Table 2(a) targets, program points) from `config/sim-params.yaml` through `config-helpers.R`. There is no fallback: a missing `yaml` package, config file, or key stops the script and names what is missing. Only 01 takes `--config`; the others always read the default path, so to try a changed parameter across the pipeline, edit the yaml itself (and revert it). One entry is flagged in the yaml as unconfirmed: the "Opt-in tutoring (ITT)" pairing in `district_requirements_points` (see `../TODO.md`). The economically disadvantaged population share is no longer a config value; 05 reads the measured share from `tables/sim-bottom-decile.csv`.

The R tests check the committed outputs, need no network, and exit non-zero on failure. They are plain `Rscript` files, not testthat. `test-regen.sh` is the exception: it reruns the pipeline in place from the committed API cache (it overwrites `tables/` and `figures/`, as a normal run would, and restores nothing), then `cmp`s every `tables/*.csv` (and `sim-results.rds`, when a local copy exists) against a copy taken first. It runs 08 only if the raw CCD membership file is present and prints SKIP otherwise. Figures are not compared, because PNG bytes are not stable across runs. Markdown and manifest files carry run dates and git SHAs, so inspect those with `git diff tables/`.

## Files

| Path | Old name (naep-aera-open) | Role |
|---|---|---|
| `01-simulations.R` | `05-simulations.R` | Pulls 2019 and 2024 percentiles and SDs for six cells; computes D(p), g\*(p), coverage requirements, and the bottom-decile economic-disadvantage decomposition; pulls the national score distribution (DP:DP, 10-point bins) for both years, one request per year. Writes `tables/sim-results.md`, `sim-quantiles.csv`, `sim-bottom-decile.csv`, `sim-distribution.csv`, `sim-results.rds` (gitignored), `sim-manifest.txt` |
| `02-figures.R` | `06-figures.R` | Figures 8 (requirements vs participation), 9 (QD curves), 10 (targeting screen) |
| `03-district-cases.R` | `07-district-cases.R` | Four hypothetical districts (A to D) that share the national 2024 shape and differ in where their median sits |
| `04-district-requirements.R` | `08-district-requirements.R` | The requirements figure replicated across the district cases, per cell |
| `05-compile-summary.R` | `09-compile-summary.R` | Assembles `tables/SIM-SUMMARY.md` from the committed CSVs |
| `06-seat-allocation.R` | `10-seat-allocation.R` | Fixed seat budget: four allocation rules compared on the post-program 90-10 gap, per cell. Writes `sim-seat-allocation-<cell>.csv`, `sim-allocation-shares-<cell>.csv`, fig13 to fig15 |
| (07, retired) | `11-tail-sensitivity.R` | Retired 2026-09-28. It varied the assumed lower tail of the five-percentile quantile function; the quantile functions now come from the published score distribution (`tables/sim-distribution.csv`), so no tail is assumed. The script is in git history |
| `08-district-enrollment.R` | `12-district-enrollment.R` | CCD 2023-24 district size distributions (total, grade 4, K-5), district- and student-weighted. Downloads the directory file with curl if missing |
| `09-kraft-benchmarks.R` | `13-kraft-benchmarks.R` | Kraft (2023) effect-size benchmarks by grade, subject, and study size, with g\* reference lines. Refuses to run unless the file reproduces Kraft's Table 1 |
| `10-export-tool-data.R` | (new) | Copies `tables/sim-quantiles.csv`, the quantile-function points built from `tables/sim-distribution.csv`, the Kraft (2023) all-sizes rows from `tables/kraft-2023-benchmarks-by-target.csv`, and the config presets into `docs/cells.js` for the explorer and its methods page |
| `11-export-explorer-years.R` | (new) | The explorer's multi-year export. Pulls percentiles, SD, the DP:DP score distribution, and the ECONDIS breakdown for every cell and year in `config/explorer-years.yaml` (52 cell-years) and writes `docs/years.js` (`globalThis.TOOL_YEARS`, about 201 KB). Also writes `tables/explorer-pairs-check.csv` (36 rows: Math G8 2013-2024, Reading G4 2005-2019, and Math G12 2005-2015, for the proportional rule and the eligibility screen at six budgets), which the engine test must reproduce. Takes `--cache DIR` |
| `config-helpers.R` | new | `load_sim_config()` and the key lookups (`cfg_get`, `cfg_g`, `cfg_c`, `cfg_treated_g`, `cfg_kraft2020`, `cfg_table2a`). Stops on a missing package, file, or key |
| `api-helpers.R` | new (from 01) | NAEP API access and its input guards: `fetch_api` with the `expect_rows` partial-response gate, `usable()`, `get_stats`, `get_distribution()`/`parse_distribution()` (the DP:DP score distribution, one request per year, refused unless every bin is present and they sum to 100), and `group_composition()` with the population-share guard behind 01's `c_of_p`. Takes cache, jurisdiction, and downloader as arguments so the tests can drive it offline |
| `alloc-rules.R` | same | The four allocation rules and the water-filling cap, kept apart from 06 so the tests can load them without writing files |
| `mixture.R` | same | The outcome model: the post-program quantile function as an exact treated/untreated mixture. `quantile_points()` builds each pre-program quantile function's points from the score distribution plus the published percentiles; `make_quantile_fn()` is a monotone spline through them, with no assumed tails. `quantile_points()` takes `min_gap` (default 1e-9, the original exact-match rule): a bin point closer than that to a published percentile is dropped. Script 11 passes 0.02, because in Reading G8 2017 the 310-point bin edge lands 0.011 percentile points from the published p90 and made a corner; only that one curve changes (Andrew approved, 2026-10-03) |
| `kraft-helpers.R` | same | Shared Kraft (2023) filters and size bins |
| `config/sim-params.yaml` | `rq3-params.yaml` | Cells, years, effect sizes, participation rates, the treated effect, program points for figures 8 and 12, the ED population share, Kraft (2020) percentiles, validation targets, each with its source. (`optin_takeup` was removed: no script read it, and the opt-in gradient in `alloc-rules.R` is a stylized doubling shape, not those two rates) |
| `config/explorer-years.yaml` | new | Read only by 11. The explorer's year lists (grades 4 and 8: 2005, 2007, 2009, 2011, 2013, 2015, 2017, 2019, 2022, 2024; grade 12: 2005, 2009, 2013, 2015, 2019, 2024), the default pair (2019, 2024), `min_bin_knot_gap` (0.02), the three check pairs, and the check budgets. Kept apart from `sim-params.yaml` so the paper's pipeline cannot change |
| `stata/01_simulations.do` | `05_simulations.do` | Base-Stata port of the quantile differences and g\* (Tables A and B only). Writes `tables/sim-quantiles-stata.csv`. Keeps its own locals (cells, jurisdiction, validation targets) rather than reading the yaml, deliberately: it is an independent implementation, so its Table 2(a) targets are a second copy on purpose |
| `tests/test-sim.R` | `test-rq3.R` | Simulation tests, including the Table 2(a) validation and the R/Stata cross-check |
| `tests/test-api-guards.R` | new | Fixture tests for `api-helpers.R`: the partial-response gate (truncated, partial, API-error, and empty responses through a fake downloader), `usable()`, and the population-share guard. Also the DP:DP guards (missing, flagged, and mis-summed bins; wrong scale; truncated response). Uses the committed cache as fixtures; no network |
| `tests/test-regen.sh` | new | Reruns 01 to 06, 08, and 09 from the committed cache and byte-compares every `tables/*.csv` |
| `tests/run-all.sh` | new | Runs every `tests/test-*.R` (plus `test-regen.sh` with `--regen`) and prints a summary |
| `tests/test-district-enrollment.R`, `test-kraft-benchmarks.R`, `test-kraft-target.R` | same | Checks on the district and Kraft outputs |
| `design-public-data.md` | `RQ3-public-data-design.md` | Design rationale for the public-data approach and the review log |
| `appendix-district-variation.md` | `RQ3-appendix-district-variation.md` | District-variation appendix material |
| `.cache/`, `.cache-stata/` | same | Cached public API responses (128 and 6 JSON files, about 5.5 MB; 92 of the R files were added by 11), **tracked in git** so a fresh clone reproduces without the live API, which NCES can revise. Delete to force a refresh; the refreshed responses then show in the diff |

## The validation that licenses public data

The differential change computed from public percentiles reproduces Table 2 column (a) of the naep-aera-open article's restricted-use analysis in all six cells: 8.7, 7.0, 1.5, 7.9, 6.4, 4.5. `test-sim.R` asserts it, so an NCES revision or a wrong subscale or jurisdiction code breaks the tests rather than silently changing results.

The R and Stata pipelines agree to 1e-14 on all 30 cell-percentile pairs for `d`, `g_star`, and `sd2019`. The Stata port covers the quantile differences and g\* only; the participation adjustment, the bottom-decile decomposition, and the seat allocation have a single implementation, in R. If either implementation is edited, rerun both and let `test-sim.R` compare them.

## Tracked outputs

`.gitignore` excludes `*.rds` and most CSVs as a restricted-data backstop, with `tables/**/*.csv` allowed back in. The CSVs in `tables/` are therefore the authoritative tracked outputs, and downstream scripts read them rather than the `.rds`. Do not weaken this.

The API caches (`.cache/`, `.cache-stata/`) are tracked as inputs: public NAEP JSON only, no rule in `.gitignore` matches them, and `test-regen.sh` relies on them to reproduce `tables/` offline.

## Known environment quirk

This machine intercepts TLS, so R's internal download methods fail certificate verification. The scripts shell out to `curl`. An earlier Python implementation silently reported "no data" for all six cells because it swallowed the SSL exception; the R version reports failures loudly and names the failed cells.

## Stata gotchas

- Do not embed double quotes in Mata regex literals. Build them with `char(34)`; the do-file parser reports "mismatched quotes" otherwise.
- Do not use `tokenize ... parse("|")` on JSON. It hits "invalid name" on content with quotes and colons. Mata's `tokens()` is safe.
- The GUI `stata` binary here cannot run `-b do` batch mode ("Unable to load main nib file"). Use the stata-mcp server, and write a log to a file, because the MCP transport truncates long console output.
- Percentile stattypes must be percent-encoded (`PC%3AP1`, not `PC:P1`) in the URL, though Stata's `copy` tolerates either.
