<!-- Moved verbatim from CLAUDE.md on 2026-10-03 to keep CLAUDE.md short. CLAUDE.md points here. -->
# Project notes: NAEP intervention simulations

The full project background, data, terminology, writing, citation, running, and layout notes. CLAUDE.md keeps the hard rules and a summary.

Project guidelines for Claude sessions in this folder. Read this file first, then `TODO.md` for open items and `PROGRESS.md` for history.

## 1. What this project is

A standalone research project, planned as its own paper, that asks two questions about recovery from the 2019-to-2024 NAEP score decline:

1. **What would it take** to return the 2024 score distribution to its 2019 shape? The restoration requirement g\*(p) = -D(p)/S is the effect, in 2019 SD units, that a program would need to deliver at percentile p, where D(p) is the 2024 minus 2019 quantile difference and S is the cell's 2019 national SD. Partial participation raises the requirement to g\*/participation.
2. **Who should get the seats?** With a fixed seat budget, four allocation rules (bottom-up, proportional, opt-in gradient, economic-disadvantage screen) spend the same seats at the same treated effect and are compared on the post-program distribution, especially the 90-10 gap. Outcomes come from an exact mixture of treated and untreated students on a quantile function rebuilt from five published percentiles.

Supporting pieces: hypothetical district cases, district-level requirements, a lower-tail sensitivity check, Kraft (2023) RCT effect-size benchmarks by grade, subject, and study size, and the CCD 2023-24 district size distribution.

Owner: Andrew McEachin (ETS Research Institute). Framing, target journal, and co-authors are not yet decided (see `TODO.md`).

**Origin.** This work began as RQ3 of the AERA Open article in `../naep-aera-open/` and was spun out on 2026-09-28 (source commit f644941). The article's RQ3 is now a narrative section that does not use the simulations. This project is independent of the article: do not edit `../naep-aera-open/` from here, and do not assume the article cites anything here.

## 2. Data

Public data only.

- **NAEP Data Service API**: 2019 and 2024 national percentiles (10, 25, 50, 75, 90) and SDs for reading and math at grades 4, 8, and 12 (six cells), plus the economic-disadvantage breakdown. Responses are cached in `analysis/.cache/` (R) and `analysis/.cache-stata/` (Stata). The caches are public JSON and are tracked in git, so a fresh clone reproduces every table without the live API; delete a cache to force a refresh, and review the refreshed responses in the diff.
- **Literature parameters** in `analysis/config/sim-params.yaml`, each with its source. Every R script reads them through `analysis/config-helpers.R`; do not hardcode a parameter in a script. The Stata port keeps its own copies on purpose (independent implementation).
- **`kraft-2023-data/`**: the Kraft (2023) effect-size database and the target-population coding of its studies.
- **`district-enrollment-data/`**: CCD 2023-24 LEA membership and directory files.

The two data folders are **copies shared with `../naep-aera-open/`**, which also uses them. If you correct something in either folder, note it in `TODO.md` so the fix can be mirrored in the article's copy. The study-coding pipeline that built `kraft-2023-data/studies/` (article scripts 14 to 18) stays in the article; its outputs are copied here as data.

**Validation that licenses public data.** The differential change (p90 difference minus p10 difference) computed here reproduces Table 2 column (a) of the article's restricted-use analysis in all six cells: 8.7, 7.0, 1.5, 7.9, 6.4, 4.5. `analysis/tests/test-sim.R` asserts it. The R pipeline and the independent Stata port agree to 1e-14 on the quantile differences and g\*.

## 3. Terminology

- **Quantile-difference (QD) curve**: 2024 quantile minus 2019 quantile, by percentile. Upward slope means larger losses at the bottom.
- **Differential change**: the p90 difference minus the p10 difference. Positive means the spread widened.
- **Reference year** is 2019. Differences are always 2024 minus 2019, so declines are negative.
- Requirements and program effects are in **2019 SD units** (cell-specific S, settled 2026-09-10). Score changes are in **NAEP score points**. Say which scale you are on.
- Percentiles of interest: 10th, 25th, 50th, 75th, 90th.
- Do not say "learning loss" for the cross-cohort decline. NAEP compares different cohorts. "Score decline" or "cohort decline" is accurate.

## 4. Writing rules

- Run any prose longer than a paragraph through `/writing-style` before handing it to Andrew. No em dashes, no colon-reveal constructions.
- Scholarly and plain register. "We" for the authors' actions; past tense for what was done, present tense for what the results show.
- Score points to one decimal in tables and whole points in prose unless a decimal carries the argument.
- Never assert a number that is not in a committed output, a source you have opened, or arithmetic you show once.
- Flag text for attention with `==double equals==`; `manuscript/render-section.sh` turns it into Word highlighting.
- Every drafted document gets a one-line provenance header comment (`<!-- draft v1, YYYY-MM-DD; sources: ... -->`).

## 5. Citations

- `references/references.bib` holds the entries this project cites, copied from the article's library on 2026-09-28. Add new entries here directly. `references/apa.csl` is the APA 7 style.
- Cite with pandoc syntax (`[@kraft-2020]`) and render with `manuscript/render-section.sh <file.md> [docx]` (pandoc 3 or newer).
- Do not fabricate or extrapolate citations. Before quoting a number from a source, open the source. The article's library (`../naep-aera-open/articles/`) is read-only from here.
- Keep `manuscript/ai-use-log.md` current for any journal AI-use disclosure.

## 6. Running the code

Run everything from the project root; paths are root-relative. Order, and what each step needs, is in `analysis/README.md`. In short: `01-simulations.R` is the root and writes `tables/sim-quantiles.csv` and `tables/sim-bottom-decile.csv`, which everything else reads. `04-` and `06-` take `--cell` (for example `--cell "Math G8"`), matching the `--flag` style of `01-` and `02-`. Tests are standalone `Rscript` files in `analysis/tests/` that check committed outputs with no network; `bash analysis/tests/run-all.sh` runs them all, and `--regen` adds a full rerun from the committed cache that byte-compares every `tables/*.csv`.

This machine intercepts TLS, so the scripts shell out to `curl` rather than R's internal downloader. Run the Stata port through the stata-mcp server (the GUI binary cannot run batch mode here).

## 7. Folder layout

```
intervention-simulation/
├── CLAUDE.md, README.md, PROGRESS.md, TODO.md
├── analysis/                  R code (01-09, helpers), config/, stata/, tests/, design notes
├── tables/                    sim-*, SIM-SUMMARY.md, district-enrollment-2324-*, kraft-2023-benchmarks-*
├── figures/                   sim/, kraft/, district-enrollment/
├── manuscript/                simulation-memo.md, render-section.sh, reference.docx, ai-use-log.md
├── references/                references.bib, apa.csl
├── kraft-2023-data/           shared copy with the article
├── district-enrollment-data/  shared copy with the article (raw CCD files local-only)
└── tasks/                     lessons.md
```

## 8. Hard rules

1. **NAEP restricted-use data never enters this folder or the git repository.** No microdata, no extracts, no intermediate files that contain student records. `.gitignore` blocks common data formats as a backstop, not as a substitute for care. Do not weaken it: the CSVs in `tables/` are the tracked outputs, and `*.rds` stays ignored.
2. Do not fabricate numbers or citations.
3. Before writing into a folder Andrew fills by hand, list it first and never overwrite (`tasks/lessons.md`).
4. Commit only when asked.
