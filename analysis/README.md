# analysis/

R code for the intervention simulations, plus an independent Stata port of the core computation. **No restricted-use data.** Everything comes from the public NAEP Data Service API, the literature parameters in `config/sim-params.yaml`, the Kraft (2023) database in `../kraft-2023-data/`, and the CCD files in `../district-enrollment-data/`.

Run every script from the project root.

## Run order

```
Rscript analysis/01-simulations.R            # ~2 min cold, instant cached; root of the pipeline
Rscript analysis/02-figures.R                # figures/sim/fig8, fig9, fig10
Rscript analysis/03-district-cases.R         # tables/sim-district-cases.md, fig11
for c in "Reading G4" "Reading G8" "Math G4" "Math G8"; do
  Rscript analysis/04-district-requirements.R "$c"   # fig12 per cell
  Rscript analysis/06-seat-allocation.R "$c"         # fig13-15 and seat CSVs per cell
done
Rscript analysis/05-compile-summary.R        # tables/SIM-SUMMARY.md
Rscript analysis/07-tail-sensitivity.R       # tables/sim-tail-sensitivity.csv
Rscript analysis/08-district-enrollment.R    # needs the raw CCD membership file (local-only)
Rscript analysis/09-kraft-benchmarks.R       # needs kraft-2023-data/kraft2023effectsize.xls

Rscript analysis/tests/test-sim.R            # simulation pipeline, incl. Table 2(a) validation and R/Stata agreement
Rscript analysis/tests/test-district-enrollment.R
Rscript analysis/tests/test-kraft-benchmarks.R
Rscript analysis/tests/test-kraft-target.R
```

Scripts 02 to 07 and 09 read `tables/sim-quantiles.csv` (02, 06, and the tests also read `tables/sim-bottom-decile.csv`), so `01-simulations.R` must have run at least once. `01-` accepts `--cache DIR`, `--out DIR`, `--config FILE`, and `--jurisdiction CODE` (default `NT`, national). `04-` and `06-` take a cell name as a positional argument (defaults: Math G8 and Reading G4).

The tests check the committed outputs, need no network, and exit non-zero on failure. They are plain `Rscript` files, not testthat.

## Files

| Path | Old name (naep-aera-open) | Role |
|---|---|---|
| `01-simulations.R` | `05-simulations.R` | Pulls 2019 and 2024 percentiles and SDs for six cells; computes D(p), g\*(p), coverage requirements, and the bottom-decile economic-disadvantage decomposition. Writes `tables/sim-results.md`, `sim-quantiles.csv`, `sim-bottom-decile.csv`, `sim-results.rds` (gitignored), `sim-manifest.txt` |
| `02-figures.R` | `06-figures.R` | Figures 8 (requirements vs participation), 9 (QD curves), 10 (targeting screen) |
| `03-district-cases.R` | `07-district-cases.R` | Four hypothetical districts (A to D) that share the national 2024 shape and differ in where their median sits |
| `04-district-requirements.R` | `08-district-requirements.R` | The requirements figure replicated across the district cases, per cell |
| `05-compile-summary.R` | `09-compile-summary.R` | Assembles `tables/SIM-SUMMARY.md` from the committed CSVs |
| `06-seat-allocation.R` | `10-seat-allocation.R` | Fixed seat budget: four allocation rules compared on the post-program 90-10 gap, per cell. Writes `sim-seat-allocation-<cell>.csv`, `sim-allocation-shares-<cell>.csv`, fig13 to fig15 |
| `07-tail-sensitivity.R` | `11-tail-sensitivity.R` | Recomputes the bottom-up boundary case under alternative lower-tail specifications |
| `08-district-enrollment.R` | `12-district-enrollment.R` | CCD 2023-24 district size distributions (total, grade 4, K-5), district- and student-weighted. Downloads the directory file with curl if missing |
| `09-kraft-benchmarks.R` | `13-kraft-benchmarks.R` | Kraft (2023) effect-size benchmarks by grade, subject, and study size, with g\* reference lines. Refuses to run unless the file reproduces Kraft's Table 1 |
| `alloc-rules.R` | same | The four allocation rules and the water-filling cap, kept apart from 06 so the tests can load them without writing files |
| `mixture.R` | same | The outcome model: the post-program quantile function as an exact treated/untreated mixture |
| `dist-helpers.R` | same | `group_cdf()`, the pipeline's one distributional assumption (linear interpolation between percentiles, normal tails) |
| `kraft-helpers.R` | same | Shared Kraft (2023) filters and size bins |
| `config/sim-params.yaml` | `rq3-params.yaml` | Cells, effect sizes, participation rates, opt-in take-up, validation targets, each with its source |
| `stata/01_simulations.do` | `05_simulations.do` | Base-Stata port of the quantile differences and g\* (Tables A and B only). Writes `tables/sim-quantiles-stata.csv` |
| `tests/test-sim.R` | `test-rq3.R` | Simulation tests, including the Table 2(a) validation and the R/Stata cross-check |
| `tests/test-district-enrollment.R`, `test-kraft-benchmarks.R`, `test-kraft-target.R` | same | Checks on the district and Kraft outputs |
| `design-public-data.md` | `RQ3-public-data-design.md` | Design rationale for the public-data approach and the review log |
| `appendix-district-variation.md` | `RQ3-appendix-district-variation.md` | District-variation appendix material |
| `.cache/`, `.cache-stata/` | same | Cached API responses (gitignored); delete to force a refresh |

## The validation that licenses public data

The differential change computed from public percentiles reproduces Table 2 column (a) of the naep-aera-open article's restricted-use analysis in all six cells: 8.7, 7.0, 1.5, 7.9, 6.4, 4.5. `test-sim.R` asserts it, so an NCES revision or a wrong subscale or jurisdiction code breaks the tests rather than silently changing results.

The R and Stata pipelines agree to 1e-14 on all 30 cell-percentile pairs for `d`, `g_star`, and `sd2019`. The Stata port covers the quantile differences and g\* only; the participation adjustment, the bottom-decile decomposition, and the seat allocation have a single implementation, in R. If either implementation is edited, rerun both and let `test-sim.R` compare them.

## Tracked outputs

`.gitignore` excludes `*.rds` and most CSVs as a restricted-data backstop, with `tables/**/*.csv` allowed back in. The CSVs in `tables/` are therefore the authoritative tracked outputs, and downstream scripts read them rather than the `.rds`. Do not weaken this.

## Known environment quirk

This machine intercepts TLS, so R's internal download methods fail certificate verification. The scripts shell out to `curl`. An earlier Python implementation silently reported "no data" for all six cells because it swallowed the SSL exception; the R version reports failures loudly and names the failed cells.

## Stata gotchas

- Do not embed double quotes in Mata regex literals. Build them with `char(34)`; the do-file parser reports "mismatched quotes" otherwise.
- Do not use `tokenize ... parse("|")` on JSON. It hits "invalid name" on content with quotes and colons. Mata's `tokens()` is safe.
- The GUI `stata` binary here cannot run `-b do` batch mode ("Unable to load main nib file"). Use the stata-mcp server, and write a log to a file, because the MCP transport truncates long console output.
- Percentile stattypes must be percent-encoded (`PC%3AP1`, not `PC:P1`) in the URL, though Stata's `copy` tolerates either.
