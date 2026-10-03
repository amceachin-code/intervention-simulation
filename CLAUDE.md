# CLAUDE.md: NAEP intervention simulations

Simulations of recovery from the 2019-to-2024 NAEP score decline: what it would take to restore the 2019 distribution, and who should get program seats. Owner: Andrew McEachin. Read `TODO.md` and `PROGRESS.md` first; background, data, and run details are in `PROJECT-NOTES.md` (read it before analysis, writing, or citation work).

## Hard rules
1. NAEP restricted-use data never enters this folder or git. Do not weaken `.gitignore`.
2. Never fabricate numbers or citations. Every number comes from a committed output, an opened source, or shown arithmetic.
3. Before writing into a folder Andrew fills by hand, list it first and never overwrite.
4. Commit only when asked. Do not edit `../naep-aera-open/`.
5. Parameters live in `analysis/config/sim-params.yaml` (read through `config-helpers.R`); never hardcode one. The paper pipeline (01-10) stays fixed at 2019 to 2024.

## Terms
"Score decline" or "cohort decline", never "learning loss". Differences are later year minus reference year. Requirements and effects are in reference-year SD units; score changes in NAEP points; say which.

## Writing
Run prose longer than a paragraph through `/writing-style`. Scholarly, plain register; "we" for the authors. Flag text with `==double equals==`. Every drafted document starts with `<!-- draft vN, YYYY-MM-DD; sources: ... -->`. Cite with pandoc keys from `references/references.bib`.

## Running
From the project root. Order and flags: `analysis/README.md`. Tests: `bash analysis/tests/run-all.sh` (`--regen` to rebuild from cache). This machine intercepts TLS, so scripts shell out to `curl`.
