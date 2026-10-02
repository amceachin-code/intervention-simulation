# intervention-simulation

Working folder for a paper on what it would take to undo the 2019-to-2024 NAEP score decline across the whole achievement distribution, not just at the mean. The paper asks two linked questions. First, what treated effect, at each percentile, would return the 2024 NAEP score distribution to its 2019 shape? Second, given a fixed budget of program seats, how do universal, targeted, and opt-in programs change the distribution, and in particular the 90-10 gap?

The analysis is built entirely on public data: percentiles, standard deviations, and score distributions (percent of students in each 10-point score bin, nationally and separately for economically disadvantaged and not economically disadvantaged students) from the NAEP Data Service API for six grade-subject cells (reading and mathematics at grades 4, 8, and 12), effect sizes from the intervention literature, the Kraft (2023) database of RCT effect sizes, and the NCES Common Core of Data (CCD) district enrollment files for 2023-24. No restricted-use license is needed to run any of it.

## Provenance

This project was spun out of [`naep-aera-open`](../naep-aera-open) (a journal article for *AERA Open* on the 2019-to-2024 NAEP decline) at commit `f644941` on 2026-09-28. In that repository the work here was called "RQ3", the third research question. On 2026-09-18 the article's RQ3 was redirected to a narrative analysis on public inputs, and the simulation pipeline was kept intact as the seed of a separate second paper. This folder is that second paper.

What changed in the move:

- Every `rq3-*` name became `sim-*` (tables, figures, the parameters file, the test suite).
- The scripts were renumbered from `05-` through `13-` to `01-` through `09-`. The mapping is in the table under [Analysis scripts](#analysis-scripts).
- The article-only scripts stayed behind: the Kraft study-coding pipeline (`14-` to `18-`), the narrative exhibits (`19-`), and the narrative robustness check (`20-`).
- `kraft-2023-data/` and `district-enrollment-data/` are copies of the folders shared with the article. The raw CCD membership and directory files and the retrieved study PDFs and text under `kraft-2023-data/studies/` stay local and are git-ignored. If either folder is corrected here, the fix is logged in `TODO.md` so it can be mirrored in the article's copy.

History in this repository: `0f70131` (the spin-out), `30d0343` (record the initial commit SHA in the run manifests), `d8033df` (point the validation references at the companion article and fix spin-out leftovers), `84d1602` (refresh the manifest SHA), `22e51b3` (the data science review pass), and `e85adf1` (refresh the run manifests with a clean SHA). The review pass in `22e51b3` moved every literature parameter into the config with a shared loader (`config-helpers.R`), extracted the NAEP API code into `api-helpers.R` with its own fixture tests, added a regeneration test and a test runner, began tracking the NAEP API caches, and made the run manifests record package versions and a dirty check that covers the helpers and the config. Later commits added the interactive explorer under `docs/` (`5057e5f`), rewrote it in plain language with an introduction (`784d489`), added its methods page (`58525ca`), rebuilt the quantile functions from NAEP's DP:DP score distribution and retired `07-tail-sensitivity.R` (`2ae29bd`), refreshed the run manifests with a clean SHA (`fdc920b`), added the economic-disadvantage breakdown to the pipeline and the explorer (`3affa50`, with a manifest refresh in `c26e976`).

## The method in brief

1. **Quantile differences.** For each cell, pull the 2019 and 2024 scores at the 10th, 25th, 50th, 75th, and 90th percentiles and compute D(p), the 2024 score minus the 2019 score at percentile p, with standard errors. The differential change D(90) minus D(10) summarizes how the spread moved.
2. **Restoration requirement.** g\*(p) = -D(p)/S, where S is the 2019 national standard deviation. It is the treated effect, in 2019 SD units, that would return percentile p to its 2019 score if every student at that percentile were treated.
3. **Participation adjustment.** Programs do not reach everyone. The participation-adjusted requirement scales g\*(p) by the share of students at p who actually take part, which shows how quickly the needed effect climbs past anything the literature has observed.
4. **Seat allocation.** A fixed seat budget is spent under four rules that deliver the same treated effect and differ only in who gets a seat: bottom-up (fill from the lowest scorer upward), proportional (the same rate everywhere), opt-in gradient (take-up rising with achievement, a stylized geometric ramp), and an economic-disadvantage screen. The screen seats economically disadvantaged (ED) students at random: participation at percentile p is min(1, B / ED share) times s(p), the 2024 ED share at that percentile, read off the ED and national score distributions. Seats beyond the ED share have no eligible taker and go unused, so the screen spends min(B, ED share) rather than B. The other rules that would ask for more than 100 percent participation at some percentile are water-filled: capped at full participation, with the freed seats redistributed to percentiles still under the cap, so the budget is conserved.
5. **Outcome model.** A program reaching 13 percent of students gives the full effect to 13 percent and nothing to the rest. The post-program population is therefore a mixture of treated and untreated students, read off a quantile function rebuilt for each year from NAEP's published score distribution (DP:DP, the percent of students in each 10-point bin) together with the five published percentiles: a monotone Fritsch-Carlson spline through the cumulative percent at each bin edge and through the percentiles, with no assumed tails. The curve passes through the published percentiles exactly, so D(p) and g\*(p) do not depend on it. This is why proportional allocation widens the 90-10 gap rather than leaving it unchanged. The same construction, applied to each group's own score distribution and percentiles, gives the ED and not-ED quantile functions: inverting them at the national cut decomposes the bottom decile by group, and following them through a program gives each group's percentiles after it.
6. **District cases.** Hypothetical districts that share the national shape of the 2024 distribution but sit at different medians, first restoring their own 2019 distribution and then catching up to the national one.
7. **Robustness and context.** Kraft (2023) benchmarks by grade, subject, and study size set against g\*(p), CCD district size distributions to give the study-size bins a real-world frame, and an independent Stata port of the core quantile computations.

The validation that licenses the public-data approach: the differential change computed from public percentiles reproduces Table 2 column (a) of the restricted-use analysis in the companion AERA Open article (`naep-aera-open`) in all six cells (8.7, 7.0, 1.5, 7.9, 6.4, 4.5). `analysis/tests/test-sim.R` asserts this, so a NAEP revision or a wrong subscale or jurisdiction code breaks the tests instead of quietly changing the results. The R pipeline and the independent Stata port agree to 1e-14 on the quantile differences, g\*(p), and the 2019 SDs.

## Setup

1. Install R (4.x; the committed outputs were produced with R 4.5.1) and the packages the scripts load:

   ```r
   install.packages(c("jsonlite", "yaml", "dplyr", "tidyr", "ggplot2",
                      "scales", "ggrepel", "data.table", "readxl"))
   ```

   `yaml` is required, not optional. Every script that uses a literature parameter reads `analysis/config/sim-params.yaml` through `analysis/config-helpers.R`, and there are no fallback defaults: a missing `yaml` package, config file, or key stops the script with a message naming what is missing.
2. Make sure `curl` and `git` are on `PATH`. API fetches and the CCD directory download shell out to `curl`, because R's internal download methods fail certificate verification on a machine that intercepts TLS. `git` supplies the commit SHA (with a dirty flag) written into each manifest.
3. Install pandoc 3.0 or newer for `manuscript/render-section.sh`. The script uses the first pandoc on `PATH` that runs and reports version 3 or newer, then tries `~/.local/bin/pandoc`; if the system pandoc is older, put a current release there.
4. Optional: Stata (base Stata only, no user-written packages) to run the cross-implementation check in `analysis/stata/`. On this machine the GUI binary cannot run batch mode, so run it through the stata-mcp server. If the server reports `ECONNREFUSED`, open VS Code (extension `deepecon.stata-mcp`) or start it by hand with `node ~/.vscode/extensions/deepecon.stata-mcp-0.5.3/src/start-server.js --port 4000 --stata-path /Applications/StataNow --stata-edition mp`, then reconnect with `/mcp`.
5. No network is needed for the NAEP inputs. The API responses are cached in `analysis/.cache/` (R, 36 JSON files) and `analysis/.cache-stata/` (Stata, 6 JSON files), about 1.3 MB of public JSON, and both caches are tracked in git, so a fresh clone reproduces every table offline. Delete a cache to force a refresh from the live API, then review the refreshed responses in the git diff.
6. For `08-district-enrollment.R`, the raw CCD 2023-24 LEA membership file must be present in `district-enrollment-data/ccd_lea_052_2324_l_1a_073124/` (about 650 MB, too large to commit). The directory file is downloaded with `curl` if missing. `09-kraft-benchmarks.R` reads `kraft-2023-data/kraft2023effectsize.xls`, which is tracked.

## Usage

Run everything from the project root; every path is root-relative. `01-simulations.R` is the root of the pipeline and must run first: scripts 02 to 06 and 09 read `tables/sim-quantiles.csv` (02, 05, and the tests also read `tables/sim-bottom-decile.csv`; 03, 06, 10, and the tests also read `tables/sim-distribution.csv`; 06, 10, and the tests also read `tables/sim-distribution-econdis.csv`), and 02 to 06 stop with an instruction to run 01 if it is missing.

```bash
Rscript analysis/01-simulations.R            # NAEP percentiles and score distributions (national and by ED status), D(p), g*(p), participation requirements, bottom decile
Rscript analysis/02-figures.R                # figures/sim/fig8 (requirements), fig9 (QD curves), fig10 (targeting screen)
Rscript analysis/03-district-cases.R         # tables/sim-district-cases.md, fig11
for c in "Reading G4" "Reading G8" "Math G4" "Math G8"; do
  Rscript analysis/04-district-requirements.R --cell "$c" # fig12 per cell
  Rscript analysis/06-seat-allocation.R --cell "$c"       # fig13 to fig15, the seat CSVs, and the ED / not-ED outcomes per cell
done
Rscript analysis/05-compile-summary.R        # tables/SIM-SUMMARY.md
Rscript analysis/08-district-enrollment.R    # CCD district size distributions (needs the raw CCD membership file)
Rscript analysis/09-kraft-benchmarks.R       # Kraft (2023) benchmarks by grade, subject, study size
```

`04-district-requirements.R` and `06-seat-allocation.R` take `--cell CELL` (defaults `"Math G8"` and `"Reading G4"`) and refuse a bare positional cell name. `01-simulations.R` accepts `--cache DIR` (default `analysis/.cache`), `--out DIR` (default `tables`), `--config FILE` (default `analysis/config/sim-params.yaml`), and `--jurisdiction CODE` (default `NT`, the nation). Only 01 takes `--config`; the other scripts always read the default path, so to try a changed parameter across the pipeline, edit the yaml itself and revert it afterwards.

01, 08, and 09 each write a run manifest (`tables/sim-manifest.txt`, `district-enrollment-2324-manifest.txt`, `kraft-2023-benchmarks-manifest.txt`) with the timestamp, git SHA, R version, and the versions of the packages the script loaded. In 01's manifest the SHA carries a `-dirty` suffix listing the files with uncommitted changes, and the check covers the script, the helpers it sources (`api-helpers.R`, `mixture.R`, `config-helpers.R`), and the config.

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
- who takes part: "Any student", with a participation gradient by prior achievement, or "Economically disadvantaged only", the eligibility screen of `analysis/alloc-rules.R` (seats go at random to ED students, participation at each percentile follows the 2024 ED share there, the participation gradient does not apply, and seats beyond the ED share go unused);
- an effect gradient by prior achievement (this and the participation gradient have five levels each, a linear tilt with p90:p10 ratios of 1:4, 1:2, 1:1, 2:1, and 4:1);
- how the outcome is read: on the distribution (whoever stands at p afterward, the treated and untreated mixture in `analysis/mixture.R`) or on the group (students who started at p, followed through).

The main chart plots the decline D(p)/S (2024 minus 2019, in 2019 SD units, negative where scores fell) from p10 to p90, before the program (dashed) and after it (solid). The charts stop at p10 and p90 because the tails are much less precise: the drop's standard error at p1 or p99 is 2 to 4 times its size at the median. Zero is the 2019 level. The restoration requirement g\*(p) = -D(p)/S is the same curve with its sign flipped. Two small charts show participation and effect by percentile. A further card shows economically disadvantaged and not economically disadvantaged students separately, each against its own 2019 scores at percentiles within the group, with a chart and a table that includes the gap between the groups. Tables give the results at the five percentiles plus the 90-10 gap. The settings are stored in the URL hash, so a configuration can be shared as a link; values are clamped to the controls' ranges and unknown keys are ignored.

A second page, "What would it take?" (`docs/rounds.html`), reached from the explorer's button of that name, asks question 1 as rounds of a program. A round seats a share c of students with an equal chance at every percentile and lifts each by g SD. Counted on the group ("Same students") estimand, one round adds c × g SD at every percentile, so the 10th percentile needs g\*(p10) / (c × g) rounds, rounded up; reaching every student once takes 1 / c rounds; and the 90-10 gap stays at its 2024 value. The arithmetic is `rounds()` in `docs/engine.js`, which has no R counterpart (no committed R output covers more than one round). The two pages share the `cell`, `share`, and `effect` hash keys, so links between them keep the settings.

The tool's files:

- `docs/index.html`: the explorer page, its controls, charts, and tables, with the "What would it take?" button that links to `rounds.html`.
- `docs/rounds.html`: the "What would it take?" page: one round for 100 students at p10, a summary card with the round counts and the 90-10 gap, and the caveats (no fade-out, a second turn as good as the first, new students each round).
- `docs/methods.html`: the methods page, reached from the explorer's "Show me the details" button and from small links beside each control. It has eleven sections: the data, the drop, effect presets, participation presets, who takes part (with subsections on the economic-disadvantage screen, `#screen`, and on the results for each group, `#groups`), who gains the most (including the thin evidence on effects by prior achievement and a Kraft (2023) comparison of studies of low achievers with studies of everyone), two ways to count, rounds of a program (section 8), the checks (including the ED checks), the limits (including those of the ED breakdown), and references (sections 9 to 11). Its tables and charts read `docs/cells.js` and `docs/engine.js`, so it cannot disagree with the explorer or the rounds page. Its source claims were checked against the PDFs on 2026-09-28.
- `docs/style.css`: styles shared by the three pages (moved out of `index.html`).
- `docs/charts.js`: SVG chart helpers (`NAEPCharts`) and shared page helpers (`NAEPShared`: formats, preset names, tilt labels, config lookup, and the provenance line) used by the pages.
- `docs/engine.js`: the calculation engine, kept apart from the page so it can be tested on its own. It ports `make_quantile_fn`, `weighted_quantile`, `quantile_rank` (as `quantileRank`), and the calibrated program quantiles from `analysis/mixture.R`, `water_fill` and `make_ed_screen` (as `edParticipation`) from `analysis/alloc-rules.R`, and the ED / not-ED outcome table of `06-seat-allocation.R` (as `groupScenario`), and adds `rounds()` for the rounds page. `edShareAt` and `edUnknownShare` read the ED share curve and the share with no ED information. A render takes about 2 ms.
- `docs/cells.js`: the per-cell NAEP inputs (including the 2019 and 2024 quantile-function point sets, `qf2019` and `qf2024`, and an `ed` object with the ED population share, the 2024 ED share curve, and each group's own point sets), plus each preset's `cite` field, the Kraft (2020) percentiles, the Table 2(a) validation targets, and the Kraft (2023) all-sizes rows for grades 4 and 8 (low achievers, everyone, all studies). It is generated by `analysis/10-export-tool-data.R` from `tables/sim-quantiles.csv`, `tables/sim-distribution.csv`, `tables/sim-distribution-econdis.csv`, `tables/kraft-2023-benchmarks-by-target.csv`, and the config rather than edited by hand. It records the MD5 of each source instead of a date, so a rerun on unchanged inputs is byte-identical.
- `docs/README.md`: a short guide to the tool, including GitHub Pages setup.
- `analysis/tests/test-tool-engine.mjs`: a Node test of the engine and data (13,788 checks, tolerance 1e-9). It matches the R seat-allocation CSVs for the Proportional rule and the eligibility screen, both estimands, and the ED / not-ED outcomes in `tables/sim-group-outcomes-<cell>.csv`, to about 7e-13 NAEP points, checks the ED data in `cells.js` against `tables/sim-distribution-econdis.csv`, checks the Kraft (2023) rows in `cells.js` against the CSV, and checks the Table 2(a) targets against the differential change computed from the cells. Its section 6 tests `rounds()`: round counts against g\* read straight from `tables/sim-quantiles.csv` for all six cells and every take-up and gain preset pair, one round and k rounds against `scenario()`, the unchanged 90-10 gap, and edge cases (rounding at whole numbers, zero take-up or gain, monotonicity).

To regenerate the data file and test the engine (10 needs the outputs of both 01 and 09):

```bash
Rscript analysis/10-export-tool-data.R     # writes docs/cells.js
node analysis/tests/test-tool-engine.mjs   # checks docs/engine.js
```

To try the tool locally, open `docs/index.html` in a browser or serve the folder (`python3 -m http.server -d docs`). The hosted copy uses the repository's Pages source setting of the `main` branch, `/docs` folder, so a push to `main` that changes `docs/` updates the live page.

### Redesign studies

The snapshot of the explorer redesign canvas is not on this branch. It lives under `design/` on branch `claude/trusting-davinci-vyejhb` (commit `e80ce1c`).

## Testing

```bash
bash analysis/tests/run-all.sh --regen
```

`run-all.sh` runs every `analysis/tests/test-*.R`, then every `analysis/tests/test-*.mjs` when `node` is installed (it prints SKIP for them otherwise), prints PASS or FAIL for each with a summary, and exits non-zero on any failure; a new `test-*.R` or `test-*.mjs` file is picked up with no change to the runner. `--regen` adds `test-regen.sh` after those tests. Without `--regen` the suite is fast and needs no network and no raw data.

| Test | What it checks |
|---|---|
| `test-sim.R` | The Table 2(a) validation, R/Stata agreement, property tests of the allocation rules, and checks on the mixture model, including the quantile function (section 10: complete histograms; the curve passes through every bin point and percentile, is monotone, and has no corner; the histogram alone reproduces the published percentiles within 0.15 points) and economic disadvantage (section 11: the ED share curve, the eligibility screen, and the group outcomes). |
| `test-api-guards.R` | The input guards in `api-helpers.R`, driven offline through a fake downloader with the committed cache as fixtures: the `expect_rows` partial-response gate (truncated, partial, API-error, and empty responses), `usable()`, the population-share guard, the DP:DP score-distribution guards (section 6), and `group_composition` (48 checks). |
| `test-district-enrollment.R` | The committed district-enrollment CSVs (no CCD files needed). |
| `test-kraft-benchmarks.R` | The committed `tables/kraft-2023-benchmarks-by-grade-size.csv`. |
| `test-kraft-target.R` | The Kraft target-population coding and the by-target benchmarks. |
| `test-tool-engine.mjs` | The interactive tool's engine (`docs/engine.js`) and data (`docs/cells.js`): 13,788 checks, including agreement with the R seat-allocation CSVs for the Proportional rule and the eligibility screen (both estimands) and with the ED / not-ED outcome CSVs to about 7e-13 points (tolerance 1e-9), the ED data against `tables/sim-distribution-econdis.csv`, the Kraft (2023) rows against `tables/kraft-2023-benchmarks-by-target.csv`, the Table 2(a) targets against the differential change from the cells, and `rounds()` (section 6). `run-all.sh` runs it when `node` is installed and skips it otherwise. |
| `test-regen.sh` | Reruns 01 to 06 and 09 (04 and 06 for all four featured cells) from the committed API cache, plus 08 when the raw CCD membership file is present (SKIP otherwise), then `cmp`s every `tables/*.csv` byte for byte against a copy taken first, plus the git-ignored `sim-results.rds` when a local copy exists (on 2026-09-29, 22 CSVs and the `.rds`, 23 files, all identical). |

The R tests are plain `Rscript` files, not testthat, and they check the committed outputs. `test-regen.sh` closes the remaining gap by proving the committed code produces those outputs. It refuses to run if `analysis/.cache/` is empty rather than querying the live API. It overwrites `tables/` and `figures/` in place, as a normal run would, and restores nothing; figures are not compared (PNG bytes are not stable across runs), and the Markdown and manifest files carry run dates and SHAs, so inspect them with `git diff tables/` and discard with `git checkout tables/`.

## Folder structure

```
intervention-simulation/
├── README.md
├── CLAUDE.md                 project guidelines for Claude sessions (and a quick orientation for humans)
├── PROGRESS.md               running progress log
├── PROJECTPLAN.md            plan for the ED breakdown in the explorer, memo refresh, and argument cleanup
├── TODO.md                   open items
├── .gitignore
├── tasks/
│   └── lessons.md            session lessons, written as rules
├── analysis/
│   ├── README.md             deeper technical notes on the pipeline
│   ├── 01-simulations.R ... 09-kraft-benchmarks.R (07 retired)
│   ├── 10-export-tool-data.R writes docs/cells.js for the interactive tool
│   ├── config-helpers.R, api-helpers.R
│   ├── alloc-rules.R, mixture.R, kraft-helpers.R
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
│   ├── rounds.html           "What would it take?": rounds of a program
│   ├── methods.html          the methods page
│   ├── style.css             styles shared by the three pages
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
| `analysis/01-simulations.R` | `05-simulations.R` | The pipeline's root. Pulls 2019 and 2024 percentiles and SDs for the six cells from the NAEP Data Service API, and the DP:DP score distribution (percent of students in each 10-point bin; 50 bins, 30 for Math G12's 0-300 scale), one request per cell and year, plus the same distribution by ECONDIS for the economically disadvantaged and not economically disadvantaged groups (one request per cell and year); computes D(p) with standard errors, the differential change, g\*(p), the participation-adjusted requirement, the share of the p10 deficit each benchmarked program would close, and the economic-disadvantage composition of the bottom decile (each group's quantile function inverted at the national cut; "Information not available" takes the remainder). API access goes through `api-helpers.R` and parameters through `config-helpers.R`. Writes `tables/sim-results.md`, `sim-quantiles.csv`, `sim-bottom-decile.csv` (its `measured_mass` column is the tail mass the two measured groups account for), `sim-distribution.csv` (columns `cell`, `year`, `bin`, `lo`, `hi`, `pct`), `sim-distribution-econdis.csv` (columns `cell`, `year`, `group`, `pop_share`, `bin`, `lo`, `hi`, `pct`), `sim-results.rds` (git-ignored), and `sim-manifest.txt` (timestamp, git SHA with dirty check, R and package versions, config path, API endpoint). |
| `analysis/02-figures.R` | `06-figures.R` | The requirements figure (coverage against treated effect, with iso-restoration contours and real programs at their evidenced coverage and effect), quantile-difference curves for all six cells, and the targeting screen. |
| `analysis/03-district-cases.R` | `07-district-cases.R` | Four hypothetical districts that share the national 2024 shape and differ only in where their median sits (offsets of -0.2, -0.1, +0.1, +0.2 national SD), each restoring its own 2019 distribution. Isolates position from size of loss. National percentile ranks come from inverting the national quantile function (`quantile_cdf`), with no assumed tails. |
| `analysis/04-district-requirements.R` | `08-district-requirements.R` | The same districts with the target set to the national 2019 percentile, which turns recovery into catch-up and makes the requirements diverge. Takes `--cell` (default `Math G8`). |
| `analysis/05-compile-summary.R` | `09-compile-summary.R` | Assembles `tables/SIM-SUMMARY.md` from the committed CSVs: validation, observed quantile differences, requirements, and the bottom-decile decomposition. |
| `analysis/06-seat-allocation.R` | `10-seat-allocation.R` | The fixed-seat-budget comparison of the four allocation rules on the post-program 90-10 gap, over budgets from 5 to 100 percent. Writes `tables/sim-seat-allocation-<cell>.csv`, `sim-allocation-shares-<cell>.csv`, `sim-group-outcomes-<cell>.csv` (ED and not-ED p10 to p90 after each rule and budget, plus 2019 and 2024 reference rows), and figures. Takes `--cell` (default `Reading G4`) and validates its inputs before doing any work. |
| `analysis/07-tail-sensitivity.R` | `11-tail-sensitivity.R` | Retired 2026-09-28, with `tables/sim-tail-sensitivity.csv`: the quantile functions are now built from the published score distribution, so no assumed tail remains to vary. The number stays unused so 08 to 10 keep their names. |
| `analysis/08-district-enrollment.R` | `12-district-enrollment.R` | K-5, grade 4, and total enrollment distributions for 2023-24 from the CCD membership and directory files, for three LEA universes, each district-weighted and student-weighted. Writes `tables/district-enrollment-2324-*` and `figures/district-enrollment/`. |
| `analysis/09-kraft-benchmarks.R` | `13-kraft-benchmarks.R` | Effect-size benchmarks by grade, subject, and study size from the Kraft (2023) database, broad tests only, on the same size bins as the district K-5 distribution. Refuses to run unless the file reproduces Kraft's Table 1. Writes `tables/kraft-2023-benchmarks-*` (including the share of effects below each g\*(p)) and `figures/kraft/`. |
| `analysis/10-export-tool-data.R` | (new) | Exports the per-cell inputs (including the quantile-function point sets from `sim-distribution.csv`), preset citations, Kraft (2020) percentiles, Table 2(a) targets, and Kraft (2023) all-sizes rows the interactive tool needs into `docs/cells.js`, so the tool never hand-copies a number. Reads the outputs of 01 and 09. |

### Helpers, configuration, and tests

| Path | What it is |
|---|---|
| `analysis/config-helpers.R` | `load_sim_config()` and the key lookups (`cfg_get`, `cfg_g`, `cfg_c`, `cfg_treated_g`, `cfg_kraft2020`, `cfg_table2a`), and `parse_cell_arg()`, which parses and validates the `--cell` argument of 04 and 06 and refuses a bare positional cell name. Sourced by 01, 02, 04, 05, 06, 10, `test-sim.R`, and `test-api-guards.R`. Stops on a missing package, file, or key; there are no fallback defaults, because a silent fallback is a second copy of the config that nothing keeps in sync. |
| `analysis/api-helpers.R` | NAEP Data Service API access and its input guards, extracted from 01: `fetch_api()` with the `expect_rows` partial-response gate, `usable()`, `get_stats()`, `get_distribution()` and `parse_distribution()` for the DP:DP score distribution (which refuse missing, flagged, or mis-summed bins, or the wrong scale), `ECON_HIST_GROUPS` (the two ECONDIS groups whose score distributions are pulled), and `group_composition()`, which inverts each group's quantile function at the national cut, gives "Information not available" the remainder, and keeps the population-share guard. Takes the cache, jurisdiction, and downloader as arguments so the tests can drive it offline. |
| `analysis/alloc-rules.R` | The four allocation rules and the water-filling solver. Every rule keeps participation within 0 and 1, and every rule but the screen keeps mean participation equal to the seat budget. The screen is built by `ed_share_points()` (the 2024 ED share at each percentile, from the national and ED score distributions) and `make_ed_screen()` (participation min(1, B / ED share) times that share); it spends min(B, ED share). Held apart from `06-` so the tests can load it without writing figures. |
| `analysis/mixture.R` | The outcome model: `quantile_points()` builds each year's points (the cumulative percent at each non-empty bin's upper edge, 0 at the first non-empty bin's lower edge, and the five published percentiles), `make_quantile_fn()` fits a monotone Fritsch-Carlson spline through them with no tails, and the post-program treated/untreated mixture is formed on that curve. `quantile_cdf()` and `quantile_rank()` invert a quantile function (a score to its percentile), and `group_quantile_points()` builds the points for one ECONDIS group from `sim-distribution-econdis.csv`. It stops if a bin point and a percentile are out of order. Kept separate from `alloc-rules.R` on purpose: one decides who gets a seat, the other how the effect reaches the distribution. |
| `analysis/kraft-helpers.R` | Shared Kraft definitions: grade rules, size bins, the benchmark cell filter, the file reader, and the SMD variance approximation. |
| `analysis/config/sim-params.yaml` | Percentiles, cells (each with its reporting-scale maximum, `scale_max`), jurisdiction, years, effect-size benchmarks, participation rates, the treated effect, program points for figures 8 and 12, Kraft (2020) percentiles, and the Table 2(a) validation targets, each with its source. Every benchmark and participation entry also has a `cite` field, the readable citation shown on the tool's methods page. One entry, the opt-in tutoring pairing, is flagged as unconfirmed (see `TODO.md`). The economic-disadvantage population share is no longer a parameter: 05 reads the measured share from `sim-bottom-decile.csv`. |
| `analysis/stata/01_simulations.do` | Independent base-Stata port of the quantile-difference and restoration-requirement arithmetic. JSON is parsed in Mata. Keeps its own parameters on purpose. |
| `analysis/.cache/`, `analysis/.cache-stata/` | Cached public NAEP API responses (36 and 6 JSON files, about 1.3 MB), tracked in git so a fresh clone reproduces without the live API, which NCES can revise or take down. `test-regen.sh` and `test-api-guards.R` depend on them. |
| `analysis/tests/run-all.sh` | Runs every `test-*.R`, every `test-*.mjs` when `node` is installed, and, with `--regen`, `test-regen.sh`; prints a summary and exits non-zero on any failure. |
| `analysis/tests/test-regen.sh` | Regeneration test: reruns the pipeline from the committed cache and byte-compares every `tables/*.csv`. |
| `analysis/tests/test-sim.R` | Core checks: the Table 2(a) validation, R/Stata agreement, property tests of the allocation rules, checks on the mixture model, and the economic-disadvantage checks (ED share curve, screen, group outcomes). |
| `analysis/tests/test-api-guards.R` | Fixture tests for the guards in `api-helpers.R`, including the DP:DP guards and `group_composition`, with no network (48 checks). |
| `analysis/tests/test-district-enrollment.R` | Checks on the committed district-enrollment CSVs. |
| `analysis/tests/test-kraft-benchmarks.R` | Checks on the committed Kraft benchmark CSV. |
| `analysis/tests/test-kraft-target.R` | Checks on the Kraft target-population coding and the by-target benchmarks. |
| `analysis/tests/test-tool-engine.mjs` | Node test of the interactive tool's engine (`docs/engine.js`) and data (`docs/cells.js`): 13,788 checks, including agreement with the R seat-allocation and group-outcome CSVs to about 7e-13 points, the ED data, the Kraft (2023) rows, the Table 2(a) targets, and `rounds()`. |
| `analysis/design-public-data.md` | Design rationale for the public-data approach and the log of review findings. |
| `analysis/appendix-district-variation.md` | District-variation appendix material. |
| `analysis/README.md` | Deeper technical notes, including environment quirks and Stata porting gotchas. |

### Outputs, manuscript, and project files

| Path | What it is |
|---|---|
| `tables/` | `sim-*.csv` (including `sim-distribution.csv` and `sim-distribution-econdis.csv`, the published score distributions nationally and by ED status, and `sim-group-outcomes-<cell>.csv`) and `sim-*.md` (machine-readable and formatted results), `SIM-SUMMARY.md`, `sim-quantiles-stata.csv`, `district-enrollment-2324-*`, `kraft-2023-benchmarks-*`, and the run manifests (`*-manifest*.txt`). The CSVs are the authoritative tracked artifacts; `sim-results.rds` is git-ignored. |
| `figures/sim/`, `figures/district-enrollment/`, `figures/kraft/` | Generated figures (PNG). |
| `manuscript/simulation-memo.md` | The results memo that seeds the paper; its numbers were refreshed from the tables on 2026-09-29. `simulation-memo.rendered.md` is its rendered copy; the rendered `.docx` is git-ignored. |
| `manuscript/render-section.sh` | Wraps `pandoc --citeproc` (the first pandoc 3 or newer on `PATH` that runs, else `~/.local/bin/pandoc`) with `references/references.bib` and `references/apa.csl`; `==text==` becomes Word highlighting, and `.docx` output takes its styles from `reference.docx`. |
| `manuscript/reference.docx` | Word style template (12 point Times New Roman, double spaced, 1 inch margins). |
| `manuscript/ai-use-log.md` | Raw material for a journal AI-use disclosure, including rows imported from the article. |
| `references/references.bib`, `references/apa.csl` | The subset of the article's bibliography this paper cites, and the APA 7 citation style. |
| `kraft-2023-data/` | Copy of the Kraft (2023) effect-size spreadsheet (`kraft2023effectsize.xls`), the paper and its read-me (PDF), `CODEBOOK.md`, `SUMMARY.md`, and the study target-population coding in `studies/` (built by the article's scripts 14 to 18 and copied here as data). The retrieved study PDFs, extracted text, and WWC export under `studies/` are local-only. |
| `district-enrollment-data/` | Copy of the CCD 2023-24 LEA material shared with the article: `SUMMARY.md` and the data-notes and membership-companion spreadsheets are tracked; the raw membership (CSV and SAS) and directory CSVs are local-only. |
| `docs/` | The interactive tool (`index.html`, `rounds.html`, `methods.html`, `style.css`, `charts.js`, `engine.js`, the generated `cells.js`, and `README.md`), hosted on GitHub Pages from `/docs`. See [Interactive tool](#interactive-tool). |
| `CLAUDE.md`, `PROGRESS.md`, `TODO.md`, `PROJECTPLAN.md`, `tasks/lessons.md` | Project guidelines, progress log, open items, the plan for the 2026-09-29 work (ED breakdown in the explorer, memo refresh, argument cleanup), and session lessons. |

## Dependencies

- **R 4.x** (outputs produced with 4.5.1): `jsonlite` (01, 10, `api-helpers.R`, `test-api-guards.R`), `yaml` (`config-helpers.R`), `dplyr`, `tidyr`, `ggplot2`, `scales`, and `ggrepel` (02 to 06; 08 and 09 also use `ggplot2` and `scales`), and `data.table` and `readxl` (08, `kraft-helpers.R` and therefore 09, and the district and Kraft tests). `tools` ships with R.
- **System**: `curl`, `git`, pandoc 3.0 or newer.
- **Optional**: Stata (base only) for the cross-implementation check.
- **Optional**: Node.js, needed only to run `analysis/tests/test-tool-engine.mjs` (`run-all.sh` skips it when `node` is absent). The tool itself runs in any modern browser with no build step.

## Data security

NAEP restricted-use data never enters this folder or its repository: no microdata, no extracts, and no intermediate file containing student records. Nothing in this project needs it. Every input is public (the NAEP Data Service API, published literature, the Kraft database, and the CCD). `.gitignore` blocks common data formats (including `*.csv` outside `tables/`, `*.rds`, `*.dta`, `*.sas7bdat`, and `data/` folders) as a backstop, not as a substitute for care. Do not weaken it: the CSVs in `tables/` are the tracked outputs, and `*.rds` stays ignored. It also keeps the large raw CCD files and the retrieved Kraft study PDFs and text out of version control. The tracked API caches under `analysis/.cache/` and `analysis/.cache-stata/` hold only public, aggregate NAEP Data Service JSON.
