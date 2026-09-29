# intervention-simulation

Working folder for a paper on what it would take to undo the 2019-to-2024 NAEP score decline across the whole achievement distribution, not just at the mean. The paper asks two linked questions. First, what treated effect, at each percentile, would return the 2024 NAEP score distribution to its 2019 shape? Second, given a fixed budget of program seats, how do universal, targeted, and opt-in programs change the distribution, and in particular the 90-10 gap?

The analysis is built entirely on public data: percentiles and standard deviations from the NAEP Data Service API for six grade-subject cells (reading and mathematics at grades 4, 8, and 12), effect sizes from the intervention literature, the Kraft (2023) database of RCT effect sizes, and the NCES Common Core of Data (CCD) district enrollment files for 2023-24. No restricted-use license is needed to run any of it.

## Provenance

This project was spun out of [`naep-aera-open`](../naep-aera-open) (a journal article for *AERA Open* on the 2019-to-2024 NAEP decline) at commit `f644941` on 2026-09-28. In that repository the work here was called "RQ3", the third research question. On 2026-09-18 the article's RQ3 was redirected to a narrative analysis on public inputs, and the simulation pipeline was kept intact as the seed of a separate second paper. This folder is that second paper.

What changed in the move:

- Every `rq3-*` name became `sim-*` (tables, figures, the parameters file, the test suite).
- The scripts were renumbered from `05-` through `13-` to `01-` through `09-`. The mapping is in the table under [Analysis scripts](#analysis-scripts).
- The article-only scripts stayed behind: the Kraft study-coding pipeline (`14-` to `18-`), the narrative exhibits (`19-`), and the narrative robustness check (`20-`).
- `kraft-2023-data/` and `district-enrollment-data/` are copies of the folders shared with the article. The raw CCD membership and directory files and the retrieved study PDFs and text under `kraft-2023-data/studies/` stay local and are git-ignored. If either folder is corrected here, the fix is logged in `TODO.md` so it can be mirrored in the article's copy.

History in this repository: `0f70131` (the spin-out), `30d0343` (record the initial commit SHA in the run manifests), `d8033df` (point the validation references at the companion article and fix spin-out leftovers), `84d1602` (refresh the manifest SHA), `22e51b3` (the data science review pass), and `e85adf1` (refresh the run manifests with a clean SHA). The review pass in `22e51b3` moved every literature parameter into the config with a shared loader (`config-helpers.R`), extracted the NAEP API code into `api-helpers.R` with its own fixture tests, added a regeneration test and a test runner, began tracking the NAEP API caches, and made the run manifests record package versions and a dirty check that covers the helpers and the config.

## The method in brief

1. **Quantile differences.** For each cell, pull the 2019 and 2024 scores at the 10th, 25th, 50th, 75th, and 90th percentiles and compute D(p), the 2024 score minus the 2019 score at percentile p, with standard errors. The differential change D(90) minus D(10) summarizes how the spread moved.
2. **Restoration requirement.** g\*(p) = -D(p)/S, where S is the 2019 national standard deviation. It is the treated effect, in 2019 SD units, that would return percentile p to its 2019 score if every student at that percentile were treated.
3. **Participation adjustment.** Programs do not reach everyone. The participation-adjusted requirement scales g\*(p) by the share of students at p who actually take part, which shows how quickly the needed effect climbs past anything the literature has observed.
4. **Seat allocation.** A fixed seat budget is spent under four rules that deliver the same treated effect and differ only in who gets a seat: bottom-up (fill from the lowest scorer upward), proportional (the same rate everywhere), opt-in gradient (take-up rising with achievement, a stylized geometric ramp), and an economic-disadvantage screen. Rules that would ask for more than 100 percent participation at some percentile are water-filled: capped at full participation, with the freed seats redistributed to percentiles still under the cap, so the budget is conserved.
5. **Outcome model.** A program reaching 13 percent of students gives the full effect to 13 percent and nothing to the rest. The post-program population is therefore a mixture of treated and untreated students, read off a quantile function rebuilt from the five published percentiles (monotone interpolation between the knots, normal tails outside them). This is why proportional allocation widens the 90-10 gap rather than leaving it unchanged.
6. **District cases.** Hypothetical districts that share the national shape of the 2024 distribution but sit at different medians, first restoring their own 2019 distribution and then catching up to the national one.
7. **Robustness and context.** A lower-tail sensitivity check on the bottom-up case, Kraft (2023) benchmarks by grade, subject, and study size set against g\*(p), CCD district size distributions to give the study-size bins a real-world frame, and an independent Stata port of the core quantile computations.

The validation that licenses the public-data approach: the differential change computed from public percentiles reproduces Table 2 column (a) of the restricted-use analysis in the companion AERA Open article (`naep-aera-open`) in all six cells (8.7, 7.0, 1.5, 7.9, 6.4, 4.5). `analysis/tests/test-sim.R` asserts this, so a NAEP revision or a wrong subscale or jurisdiction code breaks the tests instead of quietly changing the results. The R pipeline and the independent Stata port agree to 1e-14 on the quantile differences, g\*(p), and the 2019 SDs.

## Setup

1. Install R (4.x; the committed outputs were produced with R 4.5.1) and the packages the scripts load:

   ```r
   install.packages(c("jsonlite", "yaml", "dplyr", "tidyr", "ggplot2",
                      "scales", "ggrepel", "data.table", "readxl"))
   ```

   `yaml` is required, not optional. Every script that uses a literature parameter reads `analysis/config/sim-params.yaml` through `analysis/config-helpers.R`, and there are no fallback defaults: a missing `yaml` package, config file, or key stops the script with a message naming what is missing.
2. Make sure `curl` and `git` are on `PATH`. API fetches and the CCD directory download shell out to `curl`, because R's internal download methods fail certificate verification on a machine that intercepts TLS. `git` supplies the commit SHA (with a dirty flag) written into each manifest.
3. Install pandoc 3.0 or newer for `manuscript/render-section.sh`. If the system pandoc is older, put a current release at `~/.local/bin/pandoc`; the script falls back to it.
4. Optional: Stata (base Stata only, no user-written packages) to run the cross-implementation check in `analysis/stata/`. On this machine the GUI binary cannot run batch mode, so run it through the stata-mcp server.
5. No network is needed for the NAEP inputs. The API responses are cached in `analysis/.cache/` (R, 12 JSON files) and `analysis/.cache-stata/` (Stata, 6 JSON files), about 150 KB of public JSON, and both caches are tracked in git, so a fresh clone reproduces every table offline. Delete a cache to force a refresh from the live API, then review the refreshed responses in the git diff.
6. For `08-district-enrollment.R`, the raw CCD 2023-24 LEA membership file must be present in `district-enrollment-data/ccd_lea_052_2324_l_1a_073124/` (about 650 MB, too large to commit). The directory file is downloaded with `curl` if missing. `09-kraft-benchmarks.R` reads `kraft-2023-data/kraft2023effectsize.xls`, which is tracked.

## Usage

Run everything from the project root; every path is root-relative. `01-simulations.R` is the root of the pipeline and must run first: scripts 02 to 07 and 09 read `tables/sim-quantiles.csv` (02, 05, 06, and the tests also read `tables/sim-bottom-decile.csv`), and 02 to 07 stop with an instruction to run 01 if it is missing.

```bash
Rscript analysis/01-simulations.R            # NAEP percentiles, D(p), g*(p), participation requirements, bottom decile
Rscript analysis/02-figures.R                # figures/sim/fig8 (requirements), fig9 (QD curves), fig10 (targeting screen)
Rscript analysis/03-district-cases.R         # tables/sim-district-cases.md, fig11
for c in "Reading G4" "Reading G8" "Math G4" "Math G8"; do
  Rscript analysis/04-district-requirements.R "$c"   # fig12 per cell
  Rscript analysis/06-seat-allocation.R "$c"         # fig13 to fig15 and the seat CSVs per cell
done
Rscript analysis/05-compile-summary.R        # tables/SIM-SUMMARY.md
Rscript analysis/07-tail-sensitivity.R       # tables/sim-tail-sensitivity.csv
Rscript analysis/08-district-enrollment.R    # CCD district size distributions (needs the raw CCD membership file)
Rscript analysis/09-kraft-benchmarks.R       # Kraft (2023) benchmarks by grade, subject, study size
```

`04-district-requirements.R` and `06-seat-allocation.R` take a cell name as a positional argument (defaults `"Math G8"` and `"Reading G4"`). `01-simulations.R` accepts `--cache DIR` (default `analysis/.cache`), `--out DIR` (default `tables`), `--config FILE` (default `analysis/config/sim-params.yaml`), and `--jurisdiction CODE` (default `NT`, the nation). Only 01 takes `--config`; the other scripts always read the default path, so to try a changed parameter across the pipeline, edit the yaml itself and revert it afterwards.

01, 08, and 09 each write a run manifest (`tables/sim-manifest.txt`, `district-enrollment-2324-manifest.txt`, `kraft-2023-benchmarks-manifest.txt`) with the timestamp, git SHA, R version, and the versions of the packages the script loaded. In 01's manifest the SHA carries a `-dirty` suffix listing the files with uncommitted changes, and the check covers the script, the helpers it sources (`api-helpers.R`, `dist-helpers.R`, `config-helpers.R`), and the config.

The Stata port, from the Stata command line or the stata-mcp server:

```stata
do analysis/stata/01_simulations.do
```

It writes `tables/sim-quantiles-stata.csv` and `tables/sim-manifest-stata.txt`, reading its API responses from `analysis/.cache-stata/`. It keeps its own copies of the cells, jurisdiction, and validation targets rather than reading the yaml, on purpose, because it is an independent implementation. If either implementation is edited, rerun both and let `test-sim.R` compare them.

To render the memo to APA author-date form:

```bash
manuscript/render-section.sh manuscript/simulation-memo.md        # writes simulation-memo.rendered.md
manuscript/render-section.sh manuscript/simulation-memo.md docx   # also writes simulation-memo.docx
```

## Interactive tool

A static, browser-only page under `docs/` lets a reader explore the restoration requirement without running R. It uses no libraries and needs no build step. The tool is live at <https://amceachin-code.github.io/intervention-simulation/>, served by GitHub Pages from the `/docs` folder of the `main` branch of the private repository `github.com/amceachin-code/intervention-simulation`.

The page is written in plain language for a general audience. An introduction explains NAEP, percentiles, the 90-10 gap, and standard deviations before the controls. The reader sets:

- the NAEP cell;
- the program effect, in 2019 SD units, as a population average;
- the share of students treated;
- a participation gradient and an effect gradient by prior achievement, five levels each (a linear tilt with p90:p10 ratios of 1:4, 1:2, 1:1, 2:1, and 4:1);
- how the outcome is read: on the distribution (whoever stands at p afterward, the treated and untreated mixture in `analysis/mixture.R`) or on the group (students who started at p, followed through).

The main chart plots the decline D(p)/S (2024 minus 2019, in 2019 SD units, negative where scores fell) from p10 to p90, before the program (dashed) and after it (solid). Zero is the 2019 level. The restoration requirement g\*(p) = -D(p)/S is the same curve with its sign flipped. Two small charts show participation and effect by percentile, and tables give the results at the five percentiles plus the 90-10 gap. The settings are stored in the URL hash, so a configuration can be shared as a link; values are clamped to the controls' ranges and unknown keys are ignored.

The tool's files:

- `docs/index.html`: the explorer page, its controls, charts, and tables.
- `docs/methods.html`: the methods page, reached from the explorer's "Show me the details" button and from small links beside each control. It has ten sections: the data, the drop, effect presets, participation presets, who takes part, who gains the most (including the thin evidence on effects by prior achievement and a Kraft (2023) comparison of studies of low achievers with studies of everyone), two ways to count, the checks, the limits, and references. Its tables and charts read `docs/cells.js` and `docs/engine.js`, so it cannot disagree with the explorer. Its source claims were checked against the PDFs on 2026-09-28.
- `docs/style.css`: styles shared by both pages (moved out of `index.html`).
- `docs/charts.js`: SVG chart helpers (`NAEPCharts`) and shared page helpers (`NAEPShared`: formats, preset names, tilt labels, config lookup, and the provenance line) used by both pages.
- `docs/engine.js`: the calculation engine, kept apart from the page so it can be tested on its own. It ports `make_quantile_fn`, `weighted_quantile`, and the calibrated program quantiles from `analysis/mixture.R`, and `water_fill` from `analysis/alloc-rules.R`. A render takes about 2 ms.
- `docs/cells.js`: the per-cell NAEP inputs, plus each preset's `cite` field, the Kraft (2020) percentiles, the Table 2(a) validation targets, and the Kraft (2023) all-sizes rows for grades 4 and 8 (low achievers, everyone, all studies). It is generated by `analysis/10-export-tool-data.R` from `tables/sim-quantiles.csv`, `tables/kraft-2023-benchmarks-by-target.csv`, and the config rather than edited by hand. It records the MD5 of each source instead of a date, so a rerun on unchanged inputs is byte-identical.
- `docs/README.md`: a short guide to the tool, including GitHub Pages setup.
- `analysis/tests/test-tool-engine.mjs`: a Node test of the engine and data (2117 checks). It matches the R seat-allocation CSVs for the Proportional rule, both estimands, to about 1.7e-13 NAEP points, checks the Kraft (2023) rows in `cells.js` against the CSV, and checks the Table 2(a) targets against the differential change computed from the cells.

To regenerate the data file and test the engine (10 needs the outputs of both 01 and 09):

```bash
Rscript analysis/10-export-tool-data.R     # writes docs/cells.js
node analysis/tests/test-tool-engine.mjs   # checks docs/engine.js
```

To try the tool locally, open `docs/index.html` in a browser or serve the folder (`python3 -m http.server -d docs`). The hosted copy uses the repository's Pages source setting of the `main` branch, `/docs` folder, so a push to `main` that changes `docs/` updates the live page.

## Testing

```bash
bash analysis/tests/run-all.sh --regen
```

`run-all.sh` runs every `analysis/tests/test-*.R`, then every `analysis/tests/test-*.mjs` when `node` is installed (it prints SKIP for them otherwise), prints PASS or FAIL for each with a summary, and exits non-zero on any failure; a new `test-*.R` or `test-*.mjs` file is picked up with no change to the runner. `--regen` adds `test-regen.sh` after those tests. Without `--regen` the suite is fast and needs no network and no raw data.

| Test | What it checks |
|---|---|
| `test-sim.R` | The Table 2(a) validation, R/Stata agreement, property tests of the allocation rules, and checks on the mixture model. |
| `test-api-guards.R` | The input guards in `api-helpers.R`, driven offline through a fake downloader with the committed cache as fixtures: the `expect_rows` partial-response gate (truncated, partial, API-error, and empty responses), `usable()`, and the population-share guard. |
| `test-district-enrollment.R` | The committed district-enrollment CSVs (no CCD files needed). |
| `test-kraft-benchmarks.R` | The committed `tables/kraft-2023-benchmarks-by-grade-size.csv`. |
| `test-kraft-target.R` | The Kraft target-population coding and the by-target benchmarks. |
| `test-tool-engine.mjs` | The interactive tool's engine (`docs/engine.js`) and data (`docs/cells.js`): 2117 checks, including agreement with the R seat-allocation CSVs for the Proportional rule (both estimands) to about 1.7e-13 points, the Kraft (2023) rows against `tables/kraft-2023-benchmarks-by-target.csv`, and the Table 2(a) targets against the differential change from the cells. `run-all.sh` runs it when `node` is installed and skips it otherwise. |
| `test-regen.sh` | Reruns 01 to 07 and 09 (04 and 06 for all four featured cells) from the committed API cache, plus 08 when the raw CCD membership file is present (SKIP otherwise), then `cmp`s every `tables/*.csv` byte for byte against a copy taken first. |

The R tests are plain `Rscript` files, not testthat, and they check the committed outputs. `test-regen.sh` closes the remaining gap by proving the committed code produces those outputs. It refuses to run if `analysis/.cache/` is empty rather than querying the live API. It overwrites `tables/` and `figures/` in place, as a normal run would, and restores nothing; figures are not compared (PNG bytes are not stable across runs), and the Markdown and manifest files carry run dates and SHAs, so inspect them with `git diff tables/` and discard with `git checkout tables/`.

## Folder structure

```
intervention-simulation/
├── README.md
├── CLAUDE.md                 project guidelines for Claude sessions (and a quick orientation for humans)
├── PROGRESS.md               running progress log
├── TODO.md                   open items
├── .gitignore
├── tasks/
│   └── lessons.md            session lessons, written as rules
├── analysis/
│   ├── README.md             deeper technical notes on the pipeline
│   ├── 01-simulations.R ... 09-kraft-benchmarks.R
│   ├── 10-export-tool-data.R writes docs/cells.js for the interactive tool
│   ├── config-helpers.R, api-helpers.R
│   ├── alloc-rules.R, mixture.R, dist-helpers.R, kraft-helpers.R
│   ├── config/sim-params.yaml
│   ├── stata/01_simulations.do
│   ├── tests/                run-all.sh, test-regen.sh, five test-*.R files, and test-tool-engine.mjs
│   ├── .cache/               NAEP API responses for R (tracked)
│   ├── .cache-stata/         NAEP API responses for Stata (tracked)
│   ├── design-public-data.md
│   └── appendix-district-variation.md
├── tables/                   sim-*, SIM-SUMMARY.md, district-enrollment-2324-*, kraft-2023-benchmarks-*
├── figures/
│   ├── sim/                  fig8 to fig15
│   ├── district-enrollment/  fig-d1 to fig-d3
│   └── kraft/                fig-k1 to fig-k6
├── docs/                     interactive tool, served by GitHub Pages
│   ├── index.html            the explorer page
│   ├── methods.html          the methods page
│   ├── style.css             styles shared by both pages
│   ├── charts.js             SVG chart and shared page helpers
│   ├── engine.js             calculation engine (port of mixture.R and water_fill)
│   ├── cells.js              per-cell NAEP inputs (generated by analysis/10-export-tool-data.R)
│   └── README.md             short guide, including GitHub Pages setup
├── manuscript/
│   ├── simulation-memo.md
│   ├── render-section.sh
│   ├── reference.docx
│   └── ai-use-log.md         raw material for the AI-use disclosure
├── references/
│   ├── references.bib        the subset of the article's bibliography this paper cites
│   └── apa.csl
├── kraft-2023-data/          Kraft (2023) effect-size database and study coding (retrieved study PDFs and text local-only)
└── district-enrollment-data/ CCD 2023-24 LEA files (raw CSV and SAS files local-only)
```

## File listing

### Analysis scripts

| Script | Was (in `naep-aera-open`) | What it does |
|---|---|---|
| `analysis/01-simulations.R` | `05-simulations.R` | The pipeline's root. Pulls 2019 and 2024 percentiles and SDs for the six cells from the NAEP Data Service API; computes D(p) with standard errors, the differential change, g\*(p), the participation-adjusted requirement, the share of the p10 deficit each benchmarked program would close, and the economic-disadvantage composition of the bottom decile. API access goes through `api-helpers.R` and parameters through `config-helpers.R`. Writes `tables/sim-results.md`, `sim-quantiles.csv`, `sim-bottom-decile.csv`, `sim-results.rds` (git-ignored), and `sim-manifest.txt` (timestamp, git SHA with dirty check, R and package versions, config path, API endpoint). |
| `analysis/02-figures.R` | `06-figures.R` | The requirements figure (coverage against treated effect, with iso-restoration contours and real programs at their evidenced coverage and effect), quantile-difference curves for all six cells, and the targeting screen. |
| `analysis/03-district-cases.R` | `07-district-cases.R` | Four hypothetical districts that share the national 2024 shape and differ only in where their median sits (offsets of -0.2, -0.1, +0.1, +0.2 national SD), each restoring its own 2019 distribution. Isolates position from size of loss. |
| `analysis/04-district-requirements.R` | `08-district-requirements.R` | The same districts with the target set to the national 2019 percentile, which turns recovery into catch-up and makes the requirements diverge. Takes a cell name (default `Math G8`). |
| `analysis/05-compile-summary.R` | `09-compile-summary.R` | Assembles `tables/SIM-SUMMARY.md` from the committed CSVs: validation, observed quantile differences, requirements, and the bottom-decile decomposition. |
| `analysis/06-seat-allocation.R` | `10-seat-allocation.R` | The fixed-seat-budget comparison of the four allocation rules on the post-program 90-10 gap, over budgets from 5 to 100 percent. Writes `tables/sim-seat-allocation-<cell>.csv`, `sim-allocation-shares-<cell>.csv`, and figures. Takes a cell name (default `Reading G4`) and validates its inputs before doing any work. |
| `analysis/07-tail-sensitivity.R` | `11-tail-sensitivity.R` | Recomputes the bottom-up case at 10 percent of seats under four lower-tail specifications (normal from the p10-to-p90 span, normal from the local p10-to-p25 slope, logistic, linear) and reports how far the answer moves. Writes `tables/sim-tail-sensitivity.csv`. |
| `analysis/08-district-enrollment.R` | `12-district-enrollment.R` | K-5, grade 4, and total enrollment distributions for 2023-24 from the CCD membership and directory files, for three LEA universes, each district-weighted and student-weighted. Writes `tables/district-enrollment-2324-*` and `figures/district-enrollment/`. |
| `analysis/09-kraft-benchmarks.R` | `13-kraft-benchmarks.R` | Effect-size benchmarks by grade, subject, and study size from the Kraft (2023) database, broad tests only, on the same size bins as the district K-5 distribution. Refuses to run unless the file reproduces Kraft's Table 1. Writes `tables/kraft-2023-benchmarks-*` (including the share of effects below each g\*(p)) and `figures/kraft/`. |
| `analysis/10-export-tool-data.R` | (new) | Exports the per-cell inputs, preset citations, Kraft (2020) percentiles, Table 2(a) targets, and Kraft (2023) all-sizes rows the interactive tool needs into `docs/cells.js`, so the tool never hand-copies a number. Reads the outputs of 01 and 09. |

### Helpers, configuration, and tests

| Path | What it is |
|---|---|
| `analysis/config-helpers.R` | `load_sim_config()` and the key lookups (`cfg_get`, `cfg_g`, `cfg_c`, `cfg_treated_g`, `cfg_kraft2020`, `cfg_table2a`). Sourced by 01, 02, 04, 05, 06, 07, `test-sim.R`, and `test-api-guards.R`. Stops on a missing package, file, or key; there are no fallback defaults, because a silent fallback is a second copy of the config that nothing keeps in sync. |
| `analysis/api-helpers.R` | NAEP Data Service API access and its input guards, extracted from 01: `fetch_api()` with the `expect_rows` partial-response gate, `usable()`, `get_stats()`, and `group_composition()` with the population-share guard. Takes the cache, jurisdiction, and downloader as arguments so the tests can drive it offline. |
| `analysis/alloc-rules.R` | The four allocation rules and the water-filling solver. Every rule keeps mean participation equal to the seat budget and participation within 0 and 1. Held apart from `06-` so the tests can load it without writing figures. |
| `analysis/mixture.R` | The outcome model: rebuilds a quantile function from five percentiles and forms the post-program treated/untreated mixture. Kept separate from `alloc-rules.R` on purpose: one decides who gets a seat, the other how the effect reaches the distribution. |
| `analysis/dist-helpers.R` | `group_cdf()` and related helpers behind the bottom-decile decomposition: the pipeline's one distributional assumption (linear interpolation between percentiles, normal tails). |
| `analysis/kraft-helpers.R` | Shared Kraft definitions: grade rules, size bins, the benchmark cell filter, the file reader, and the SMD variance approximation. |
| `analysis/config/sim-params.yaml` | Percentiles, cells, jurisdiction, years, effect-size benchmarks, participation rates, the treated effect, program points for figures 8 and 12, the economic-disadvantage population share, Kraft (2020) percentiles, and the Table 2(a) validation targets, each with its source. Every benchmark and participation entry also has a `cite` field, the readable citation shown on the tool's methods page. Two entries are flagged as unconfirmed (see `TODO.md`). |
| `analysis/stata/01_simulations.do` | Independent base-Stata port of the quantile-difference and restoration-requirement arithmetic. JSON is parsed in Mata. Keeps its own parameters on purpose. |
| `analysis/.cache/`, `analysis/.cache-stata/` | Cached public NAEP API responses (12 and 6 JSON files, about 150 KB), tracked in git so a fresh clone reproduces without the live API, which NCES can revise or take down. `test-regen.sh` and `test-api-guards.R` depend on them. |
| `analysis/tests/run-all.sh` | Runs every `test-*.R`, every `test-*.mjs` when `node` is installed, and, with `--regen`, `test-regen.sh`; prints a summary and exits non-zero on any failure. |
| `analysis/tests/test-regen.sh` | Regeneration test: reruns the pipeline from the committed cache and byte-compares every `tables/*.csv`. |
| `analysis/tests/test-sim.R` | Core checks: the Table 2(a) validation, R/Stata agreement, property tests of the allocation rules, and checks on the mixture model. |
| `analysis/tests/test-api-guards.R` | Fixture tests for the guards in `api-helpers.R`, with no network. |
| `analysis/tests/test-district-enrollment.R` | Checks on the committed district-enrollment CSVs. |
| `analysis/tests/test-kraft-benchmarks.R` | Checks on the committed Kraft benchmark CSV. |
| `analysis/tests/test-kraft-target.R` | Checks on the Kraft target-population coding and the by-target benchmarks. |
| `analysis/tests/test-tool-engine.mjs` | Node test of the interactive tool's engine (`docs/engine.js`) and data (`docs/cells.js`): 2117 checks, including agreement with the R seat-allocation CSVs to about 1.7e-13 points, the Kraft (2023) rows, and the Table 2(a) targets. |
| `analysis/design-public-data.md` | Design rationale for the public-data approach and the log of review findings. |
| `analysis/appendix-district-variation.md` | District-variation appendix material. |
| `analysis/README.md` | Deeper technical notes, including environment quirks and Stata porting gotchas. |

### Outputs, manuscript, and project files

| Path | What it is |
|---|---|
| `tables/` | `sim-*.csv` and `sim-*.md` (machine-readable and formatted results), `SIM-SUMMARY.md`, `sim-quantiles-stata.csv`, `district-enrollment-2324-*`, `kraft-2023-benchmarks-*`, and the run manifests (`*-manifest*.txt`). The CSVs are the authoritative tracked artifacts; `sim-results.rds` is git-ignored. |
| `figures/sim/`, `figures/district-enrollment/`, `figures/kraft/` | Generated figures (PNG). |
| `manuscript/simulation-memo.md` | The results memo that seeds the paper. `simulation-memo.rendered.md` is its rendered copy; the rendered `.docx` is git-ignored. |
| `manuscript/render-section.sh` | Wraps `pandoc --citeproc` with `references/references.bib` and `references/apa.csl`; `==text==` becomes Word highlighting, and `.docx` output takes its styles from `reference.docx`. |
| `manuscript/reference.docx` | Word style template (12 point Times New Roman, double spaced, 1 inch margins). |
| `manuscript/ai-use-log.md` | Raw material for a journal AI-use disclosure, including rows imported from the article. |
| `references/references.bib`, `references/apa.csl` | The subset of the article's bibliography this paper cites, and the APA 7 citation style. |
| `kraft-2023-data/` | Copy of the Kraft (2023) effect-size spreadsheet (`kraft2023effectsize.xls`), the paper and its read-me (PDF), `CODEBOOK.md`, `SUMMARY.md`, and the study target-population coding in `studies/` (built by the article's scripts 14 to 18 and copied here as data). The retrieved study PDFs, extracted text, and WWC export under `studies/` are local-only. |
| `district-enrollment-data/` | Copy of the CCD 2023-24 LEA material shared with the article: `SUMMARY.md` and the data-notes and membership-companion spreadsheets are tracked; the raw membership (CSV and SAS) and directory CSVs are local-only. |
| `docs/` | The interactive tool (`index.html`, `methods.html`, `style.css`, `charts.js`, `engine.js`, the generated `cells.js`, and `README.md`), hosted on GitHub Pages from `/docs`. See [Interactive tool](#interactive-tool). |
| `CLAUDE.md`, `PROGRESS.md`, `TODO.md`, `tasks/lessons.md` | Project guidelines, progress log, open items, and session lessons. |

## Dependencies

- **R 4.x** (outputs produced with 4.5.1): `jsonlite` (01, `api-helpers.R`, `test-api-guards.R`), `yaml` (`config-helpers.R`), `dplyr`, `tidyr`, `ggplot2`, `scales`, and `ggrepel` (02 to 06; 08 and 09 also use `ggplot2` and `scales`), and `data.table` and `readxl` (08, `kraft-helpers.R` and therefore 09, and the district and Kraft tests). `tools` ships with R.
- **System**: `curl`, `git`, pandoc 3.0 or newer.
- **Optional**: Stata (base only) for the cross-implementation check.
- **Optional**: Node.js, needed only to run `analysis/tests/test-tool-engine.mjs` (`run-all.sh` skips it when `node` is absent). The tool itself runs in any modern browser with no build step.

## Data security

NAEP restricted-use data never enters this folder or its repository: no microdata, no extracts, and no intermediate file containing student records. Nothing in this project needs it. Every input is public (the NAEP Data Service API, published literature, the Kraft database, and the CCD). `.gitignore` blocks common data formats (including `*.csv` outside `tables/`, `*.rds`, `*.dta`, `*.sas7bdat`, and `data/` folders) as a backstop, not as a substitute for care. Do not weaken it: the CSVs in `tables/` are the tracked outputs, and `*.rds` stays ignored. It also keeps the large raw CCD files and the retrieved Kraft study PDFs and text out of version control. The tracked API caches under `analysis/.cache/` and `analysis/.cache-stata/` hold only public, aggregate NAEP Data Service JSON.
