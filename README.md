# intervention-simulation

Working folder for a paper on what it would take to undo the 2019-to-2024 NAEP score decline across the whole achievement distribution, not just at the mean. The paper asks two linked questions. First, what treated effect, at each percentile, would return the 2024 NAEP score distribution to its 2019 shape? Second, given a fixed budget of program seats, how do universal, targeted, and opt-in programs change the distribution, and in particular the 90-10 gap?

The analysis is built entirely on public data: percentiles and standard deviations from the NAEP Data Service API for six grade-subject cells (reading and mathematics at grades 4, 8, and 12), effect sizes from the intervention literature, the Kraft (2023) database of RCT effect sizes, and the NCES Common Core of Data (CCD) district enrollment files for 2023-24. No restricted-use license is needed to run any of it.

> **Status (2026-09-28).** This README was written from the migration plan while files were still being copied in from the parent project. File names and paths below describe the planned layout. A refresh will follow once every file is in place.

## Provenance

This project was spun out of [`naep-aera-open`](../naep-aera-open) (a journal article for *AERA Open* on the 2019-to-2024 NAEP decline) at commit `f644941` on 2026-09-28. In that repository the work here was called "RQ3", the third research question. On 2026-09-18 the article's RQ3 was redirected to a narrative analysis on public inputs, and the simulation pipeline was kept intact as the seed of a separate second paper. This folder is that second paper.

What changed in the move:

- Every `rq3-*` name became `sim-*` (tables, figures, the parameters file, the test suite).
- The scripts were renumbered from `05-` through `13-` to `01-` through `09-`. The mapping is in the table under [Analysis scripts](#analysis-scripts).
- The article-only scripts stayed behind: the Kraft study-coding pipeline (`14-` to `18-`), the narrative exhibits (`19-`), and the narrative robustness check (`20-`).
- `kraft-2023-data/` and `district-enrollment-data/` are copies of the folders shared with the article. The raw CCD files and the Kraft PDFs stay local and are git-ignored.

## The method in brief

1. **Quantile differences.** For each cell, pull the 2019 and 2024 scores at the 10th, 25th, 50th, 75th, and 90th percentiles and compute D(p), the 2024 score minus the 2019 score at percentile p, with standard errors. The differential change D(90) minus D(10) summarizes how the spread moved.
2. **Restoration requirement.** g\*(p) = -D(p)/S, where S is the 2019 national standard deviation. It is the treated effect, in 2019 SD units, that would return percentile p to its 2019 score if every student at that percentile were treated.
3. **Participation adjustment.** Programs do not reach everyone. The participation-adjusted requirement scales g\*(p) by the share of students at p who actually take part, which shows how quickly the needed effect climbs past anything the literature has observed.
4. **Seat allocation.** A fixed seat budget is spent under four rules that deliver the same treated effect and differ only in who gets a seat: bottom-up (fill from the lowest scorer upward), proportional (the same rate everywhere), opt-in gradient (take-up rising with achievement, a stylized geometric ramp), and an economic-disadvantage screen. Rules that would ask for more than 100 percent participation at some percentile are water-filled: capped at full participation, with the freed seats redistributed to percentiles still under the cap, so the budget is conserved.
5. **Outcome model.** A program reaching 13 percent of students gives the full effect to 13 percent and nothing to the rest. The post-program population is therefore a mixture of treated and untreated students, read off a quantile function rebuilt from the five published percentiles (monotone interpolation between the knots, normal tails outside them). This is why proportional allocation widens the 90-10 gap rather than leaving it unchanged.
6. **District cases.** Hypothetical districts that share the national shape of the 2024 distribution but sit at different medians, first restoring their own 2019 distribution and then catching up to the national one.
7. **Robustness and context.** A lower-tail sensitivity check on the bottom-up case, Kraft (2023) benchmarks by grade, subject, and study size set against g\*(p), CCD district size distributions to give the study-size bins a real-world frame, and an independent Stata port of the core quantile computations.

The validation that licenses the public-data approach: the differential change computed from public percentiles reproduces Table 2 column (a) of the restricted-use analysis in the parent article in all six cells (8.7, 7.0, 1.5, 7.9, 6.4, 4.5). The test suite asserts this, so a NAEP revision or a wrong subscale or jurisdiction code breaks the tests instead of quietly changing the results.

## Setup

1. Install R (4.x) and the packages:

   ```r
   install.packages(c("jsonlite", "yaml", "dplyr", "ggplot2", "tidyr",
                      "scales", "ggrepel", "data.table", "readxl"))
   ```

2. Make sure `curl` and `git` are on `PATH`. Fetching shells out to `curl`, because R's internal download methods fail certificate verification on a machine that intercepts TLS. `git` supplies the commit SHA written into each manifest.
3. Install pandoc 3.0 or newer for `manuscript/render-section.sh`. If the system pandoc is older, put a current release at `~/.local/bin/pandoc`; the script falls back to it.
4. Optional: Stata (base Stata only, no user-written packages) to run the cross-implementation check in `analysis/stata/`.
5. For `08-district-enrollment.R`, the raw CCD 2023-24 LEA membership file must be present in `district-enrollment-data/` (it is too large to commit). The directory file is downloaded with `curl` if missing. For `09-kraft-benchmarks.R`, the Kraft spreadsheet must be present in `kraft-2023-data/`.

## Usage

Run everything from the project root. `01-simulations.R` must run first, because every later simulation script reads the CSVs it writes.

```bash
Rscript analysis/01-simulations.R                     # NAEP percentiles, D(p), g*(p), coverage requirements
Rscript analysis/02-figures.R                         # requirements, quantile-difference, and targeting-screen figures
Rscript analysis/03-district-cases.R                  # hypothetical districts restoring their own 2019 distribution
Rscript analysis/04-district-requirements.R "Math G8" # the same districts catching up to the national 2019 target
Rscript analysis/05-compile-summary.R                 # tables/SIM-SUMMARY.md
Rscript analysis/06-seat-allocation.R "Reading G4"    # four allocation rules on a fixed seat budget
Rscript analysis/07-tail-sensitivity.R                # lower-tail robustness of the bottom-up case
Rscript analysis/08-district-enrollment.R             # CCD district size distributions (needs the raw CCD files)
Rscript analysis/09-kraft-benchmarks.R                # Kraft (2023) benchmarks by grade, subject, study size

Rscript analysis/tests/test-sim.R                     # core simulation checks, no network needed
Rscript analysis/tests/test-district-enrollment.R     # no CCD files needed
Rscript analysis/tests/test-kraft-benchmarks.R
Rscript analysis/tests/test-kraft-target.R
```

`06-seat-allocation.R` and `04-district-requirements.R` take a cell name as their first argument (`"Reading G4"`, `"Reading G8"`, `"Math G4"`, `"Math G8"`, and so on). `01-simulations.R` accepts `--cache DIR`, `--out DIR`, and `--jurisdiction` (default `NT`, the nation). API responses are cached under `analysis/.cache/`, so re-runs are offline and reproducible; delete that directory to force a refresh. The tests are standalone Rscript files that read the committed CSVs, so they need no network and no raw data.

The Stata port, from the Stata command line or the stata-mcp server:

```stata
do analysis/stata/01_simulations.do
```

It writes `tables/sim-quantiles-stata.csv` and a manifest. The R and Stata pipelines should agree to machine precision on all 30 cell-percentile pairs; if either is edited, re-run both and diff the CSVs.

To render the memo to APA author-date form:

```bash
manuscript/render-section.sh manuscript/simulation-memo.md        # writes simulation-memo.rendered.md
manuscript/render-section.sh manuscript/simulation-memo.md docx   # also writes simulation-memo.docx
```

## Folder structure

```
intervention-simulation/
├── README.md
├── CLAUDE.md                 project guidelines for Claude sessions (and a quick orientation for humans)
├── PROGRESS.md               running progress log
├── TODO.md                   open items
├── ai-use-log.md             raw material for the AI-use disclosure
├── .gitignore
├── tasks/
│   └── lessons.md            session lessons, written as rules
├── analysis/
│   ├── README.md             deeper technical notes on the pipeline
│   ├── 01-simulations.R ... 09-kraft-benchmarks.R
│   ├── alloc-rules.R, mixture.R, dist-helpers.R, kraft-helpers.R
│   ├── config/sim-params.yaml
│   ├── stata/01_simulations.do
│   ├── tests/                test-sim.R and three more
│   ├── design-public-data.md
│   └── appendix-district-variation.md
├── tables/                   sim-*.csv/md, SIM-SUMMARY.md, district-enrollment-2324-*, kraft-2023-benchmarks-*
├── figures/
│   ├── sim/
│   ├── district-enrollment/
│   └── kraft/
├── manuscript/
│   ├── simulation-memo.md
│   ├── render-section.sh
│   └── reference.docx
├── references/
│   ├── references.bib        the subset of the parent project's bibliography this paper cites
│   └── apa.csl
├── kraft-2023-data/          Kraft (2023) effect-size database (PDFs local-only)
└── district-enrollment-data/ CCD 2023-24 LEA files (raw files local-only)
```

## File listing

### Analysis scripts

| Script | Was (in `naep-aera-open`) | What it does |
|---|---|---|
| `analysis/01-simulations.R` | `05-simulations.R` | The pipeline's root. Pulls 2019 and 2024 percentiles and SDs for the six cells from the NAEP Data Service API; computes D(p) with standard errors, the differential change, g\*(p), the participation-adjusted requirement, the share of the p10 deficit each benchmarked program would close, and the economic-disadvantage composition of the bottom decile. Writes `tables/sim-results.md`, `sim-quantiles.csv`, `sim-bottom-decile.csv`, and `sim-manifest.txt` (timestamp, git SHA, R version, API endpoint). |
| `analysis/02-figures.R` | `06-figures.R` | The requirements figure (coverage against treated effect, with iso-restoration contours and real programs at their evidenced coverage and effect), quantile-difference curves for all six cells, and the targeting screen. |
| `analysis/03-district-cases.R` | `07-district-cases.R` | Four hypothetical districts that share the national 2024 shape and differ only in where their median sits (offsets of -0.2, -0.1, +0.1, +0.2 national SD), each restoring its own 2019 distribution. Isolates position from size of loss. |
| `analysis/04-district-requirements.R` | `08-district-requirements.R` | The same districts with the target set to the national 2019 percentile, which turns recovery into catch-up and makes the requirements diverge. Takes a cell name (default `Math G8`). |
| `analysis/05-compile-summary.R` | `09-compile-summary.R` | Assembles `tables/SIM-SUMMARY.md` from the committed CSVs: validation, observed quantile differences, requirements, and the bottom-decile decomposition. |
| `analysis/06-seat-allocation.R` | `10-seat-allocation.R` | The fixed-seat-budget comparison of the four allocation rules on the post-program 90-10 gap, over budgets from 5 to 100 percent. Writes `tables/sim-seat-allocation-<cell>.csv`, `sim-allocation-shares-<cell>.csv`, and figures. Takes a cell name (default `Reading G4`) and validates its inputs before doing any work. |
| `analysis/07-tail-sensitivity.R` | `11-tail-sensitivity.R` | Recomputes the bottom-up case at 10 percent of seats under four lower-tail specifications (normal from the p10-to-p90 span, normal from the local p10-to-p25 slope, logistic, linear) and reports how far the answer moves. Writes `tables/sim-tail-sensitivity.csv`. |
| `analysis/08-district-enrollment.R` | `12-district-enrollment.R` | K-5, grade 4, and total enrollment distributions for 2023-24 from the CCD membership and directory files, for three LEA universes, each district-weighted and student-weighted. Writes `tables/district-enrollment-2324-*` and `figures/district-enrollment/`. |
| `analysis/09-kraft-benchmarks.R` | `13-kraft-benchmarks.R` | Effect-size benchmarks by grade, subject, and study size from the Kraft (2023) database, broad tests only, on the same size bins as the district K-5 distribution. Refuses to run unless the file reproduces Kraft's Table 1. Writes `tables/kraft-2023-benchmarks-*` (including the share of effects below each g\*(p)) and `figures/kraft/`. |

### Helpers, configuration, and tests

| Path | What it is |
|---|---|
| `analysis/alloc-rules.R` | The four allocation rules and the water-filling solver. Every rule keeps mean participation equal to the seat budget and participation within 0 and 1. Held apart from `06-` so the tests can load it without writing figures. |
| `analysis/mixture.R` | The outcome model: rebuilds a quantile function from five percentiles and forms the post-program treated/untreated mixture. Kept separate from `alloc-rules.R` on purpose: one decides who gets a seat, the other how the effect reaches the distribution. |
| `analysis/dist-helpers.R` | `group_cdf()` and related helpers behind the bottom-decile decomposition. |
| `analysis/kraft-helpers.R` | Shared Kraft definitions: grade rules, size bins, the benchmark cell filter, the file reader, and the SMD variance approximation. |
| `analysis/config/sim-params.yaml` | Cells, effect sizes, coverage rates, and validation targets, each with its source. |
| `analysis/stata/01_simulations.do` | Independent base-Stata port of the quantile-difference and restoration-requirement arithmetic. JSON is parsed in Mata. |
| `analysis/tests/test-sim.R` | Core checks: the Table 2 validation, R/Stata agreement, property tests of the allocation rules, and checks on the mixture model. |
| `analysis/tests/test-district-enrollment.R` | Checks on the committed district-enrollment CSVs. |
| `analysis/tests/test-kraft-benchmarks.R` | Checks on the committed Kraft benchmark CSV. |
| `analysis/tests/test-kraft-target.R` | Checks on the Kraft target-population coding and the by-target benchmarks. |
| `analysis/design-public-data.md` | Design rationale for the public-data approach and the log of review findings. |
| `analysis/appendix-district-variation.md` | District-variation appendix material. |
| `analysis/README.md` | Deeper technical notes, including environment quirks and Stata porting gotchas. |

### Outputs, manuscript, and project files

| Path | What it is |
|---|---|
| `tables/` | `sim-*.csv` and `sim-*.md` (machine-readable and formatted results), `SIM-SUMMARY.md`, `district-enrollment-2324-*`, and `kraft-2023-benchmarks-*`. The CSVs are the authoritative tracked artifacts; `.rds` files are git-ignored. |
| `figures/sim/`, `figures/district-enrollment/`, `figures/kraft/` | Generated figures. |
| `manuscript/simulation-memo.md` | The results memo that seeds the paper. |
| `manuscript/render-section.sh` | Wraps `pandoc --citeproc` with `references/references.bib` and `references/apa.csl`; `==text==` becomes Word highlighting, and `.docx` output takes its styles from `reference.docx`. |
| `manuscript/reference.docx` | Word style template (12 point Times New Roman, double spaced, 1 inch margins). |
| `references/references.bib`, `references/apa.csl` | The subset of the parent bibliography this paper cites, and the APA citation style. |
| `kraft-2023-data/` | Copy of the Kraft (2023) effect-size spreadsheet, codebook, and target-population coding shared with the article. PDFs are local-only. |
| `district-enrollment-data/` | Copy of the CCD 2023-24 LEA membership and directory material shared with the article. Raw CSV and SAS files are local-only. |
| `CLAUDE.md`, `PROGRESS.md`, `TODO.md`, `ai-use-log.md`, `tasks/lessons.md` | Project guidelines, progress log, open items, AI-use log, and session lessons. |

## Dependencies

- **R 4.x**: `jsonlite`, `yaml`, `dplyr`, `ggplot2`, `tidyr`, `scales`, `ggrepel`, `data.table`, `readxl`.
- **System**: `curl`, `git`, pandoc 3.0 or newer.
- **Optional**: Stata (base only) for the cross-implementation check.

## Data security

NAEP restricted-use data never enters this folder or its repository: no microdata, no extracts, and no intermediate file containing student records. Nothing in this project needs it. Every input is public (the NAEP Data Service API, published literature, the Kraft database, and the CCD). `.gitignore` blocks common data formats and `*.rds` as a backstop, not as a substitute for care, and it keeps the large raw CCD files and the Kraft PDFs out of version control.
