# Target-population coding of the Kraft (2023) benchmark studies

> **Copy note (2026-09-28).** This folder is a copy of `naep-aera-open/kraft-2023-data/studies/`, made when the intervention simulations were spun out. The scripts that build it (14 to 18) and the batch-coding workflow below live in naep-aera-open, so the project root named below is correct. Redo coding there and copy the outputs here.

This folder holds everything produced while coding whom each RCT behind the paper's effect-size benchmarks served. The benchmark cells are grade 4 or 8, reading or math, broad tests, sample size 251 or more: 254 studies and 698 effect sizes from `kraft-2023-data/kraft2023effectsize.xls`. The pipeline runs in six stages, each ending with a checkpoint report. The plan is summarized in `PROGRESS.md` (entry dated 2026-09-18) and the codebook is `kraft-2023-data/CODEBOOK.md`.

## Files

| File | Stage | What it is | Git |
|---|---|---|---|
| `study-list.csv` | 1 | One row per study: `study_id`, `key`, `batch`, citation, surnames, year, sources, subjects, effect list, sample-size range, grade span, identifier flags. Built by `analysis/14-kraft-study-list.R`. | tracked |
| `study-list-manifest.txt` | 1 | Counts by batch and citation type. | tracked |
| `sources/fryer-2017-references.txt` | 2 | Reference list extracted from Fryer's NBER working paper w22130, used to resolve the Fryer-sourced rows. | tracked |
| `resolution-auto.csv` | 2 | Every candidate reference the resolver considered, with service, identifier, score, and whether it was auto-accepted. Built by `analysis/15-kraft-resolve.py`. | tracked |
| `resolution-manual/<batch>.csv` | 2 | Studies the resolver could not settle, one file per batch, with the candidate list. Batch agents fill `accepted_service`, `accepted_id`, `accepted_title`, `reviewer`, `review_note`, or write `unresolved` in `accepted_id`. | tracked |
| `resolution-manifest.txt` | 2 | Status counts by source. | tracked |
| `resolution.csv` | 6 | Final reference per study, merged from auto and manual decisions, with `resolution_status` in auto, manual, unresolved. | tracked |
| `retrieval-log.csv` | 3 | Per study: status (pdf, manual-pdf, library, abstract-only, unresolved, failed, blocked), URL, service, size, sha256, pages. Built by `analysis/16-kraft-retrieve.py`. A file dropped at `pdf/<key>.pdf` by hand is adopted as `manual-pdf` on the next run and never refetched; an abstract dropped at `abstracts/<key>.txt` (title, URL, `abstract source:` line, blank line, text) is adopted as `abstract-only` with service `hand-supplied`. | tracked |
| `pdf/<key>.pdf`, `text/<key>.txt` | 3 | Retrieved PDFs and their pdftotext output. `pdf/_sources/` holds source documents such as the Fryer chapter. | ignored |
| `abstracts/<key>.txt` | 3 | Abstract and any methods preview for paywalled studies. | tracked |
| `wwc/` | 4 | The WWC data export (`WWC-export-archive.zip` and its files). | ignored |
| `wwc/wwc-manifest.txt`, `wwc/request-payload.json` | 4 | How the export was fetched (the POST that works and why) and the match-run summary. | tracked |
| `wwc-match.csv` | 4 | One row per Kraft study: `wwc_study_id`, `method` (export, search, search-candidates, search-none, or blank), score, candidate count, matched WWC citation. Built by `analysis/17-kraft-wwc-match.py`. | tracked |
| `wwc-match-manual.csv` | 4 | Search candidates for WWC-sourced studies the matcher could not settle. Fill `accepted` (the candidate study id or `none`), `reviewer`, `note`. | tracked |
| `wwc-match-overrides.csv` | 4 | Hand corrections to the matcher: `study_id`, `wwc_study_id` (or `none` to drop a wrong match), `note`. Applied on the next run of the script, together with the `accepted` column of `wwc-match-manual.csv`. | tracked |
| `wwc-codes.csv` | 4 | One row per matched study: WWC citation, rating, grades, demographic percentages, the Setting and Study sample narrative (newer reviews), the sample-characteristics block (older reviews), and the derived `wwc_code`, `wwc_level`, `wwc_rule`, `wwc_confidence`, `wwc_quote`. Never merged into `coding.csv`; it is the independent check. | tracked |
| `wwc/pages/<id>.html`, `wwc/search/<surname>.json` | 4 | Cached WWC study pages and search responses. | ignored |
| `coding/<batch>.csv` | 5 | Hand codes, one file per batch agent, one row per study, appended as each study is finished. | tracked |
| `coding/reliability-<batch>.csv` | 5 | Blind recodes of the 10 percent reliability sample. | tracked |
| `coding/adjudication.csv` | 5 | Andrew's decisions on disagreements. | tracked |
| `coding.csv` | 6 | Merged, validated hand codes. Built by `analysis/18-kraft-merge-coding.py`. | tracked |

The repository's `.gitignore` blocks every `*.csv` by default; the negation rules under the "Kraft study coding" comment are what track the CSVs here. Do not remove them.

`key` is `<study_id>-<first author, ASCII>-<year>`, for example `1-abdulkadiroglu-2011`, and names every per-study file.

## Running the scripted stages

```bash
export KRAFT_CONTACT_EMAIL=<address>       # sent to Crossref, OpenAlex, Unpaywall polite pools
Rscript analysis/14-kraft-study-list.R
python3 analysis/15-kraft-resolve.py        # ~20 minutes first time; cached afterwards
python3 analysis/16-kraft-retrieve.py
python3 analysis/17-kraft-wwc-match.py      # needs wwc/Interventions_Studies_And_Findings.csv; --no-network for a dry run
python3 analysis/18-kraft-merge-coding.py
```

API responses are cached under `analysis/.cache/kraft/`; delete a service's folder to force a refresh.

## Batch-agent prompt template (Stage 5)

Replace `<batch>` and paste. Each agent works one batch and writes only its own files.

> Project root: /Users/andrewmceachin/projects/naep-aera-open. Read `CLAUDE.md` first, then `kraft-2023-data/CODEBOOK.md` in full, then this README.
>
> Your batch is `<batch>`. Your studies are the rows of `kraft-2023-data/studies/study-list.csv` with `batch == <batch>`.
>
> **Step A, resolution review (done).** Every row of `resolution-manual/<batch>.csv` was settled on 2026-09-18; do not reopen them. `retrieval-log.csv` gives each study's status: `pdf` or `manual-pdf` means `text/<key>.txt` exists, `abstract-only` means `abstracts/<key>.txt` exists, `unresolved` or `failed` means no document. For the `wwc-a` and `wwc-b` batches only: if `wwc-match-manual.csv` has rows for your studies, pick the candidate WWC review that is the study Kraft cited (surnames, year, `n_max`, effects) and fill `accepted` (the candidate study id, or `none`), `reviewer`, and `note`; leave other batches' rows alone.
>
> **Step B, coding.** For each study, open the text in this order: `text/<key>.txt`, then `abstracts/<key>.txt`, then the WWC sample columns of your study's row in `wwc-codes.csv` (`setting`, `study_sample`, `sample_characteristics`; ignore `wwc_code`). Read the abstract first. Then search the text for `participants`, `sample`, `eligib`, `selected`, `recruit`, `screen`, `Title I`, `free or reduced`, `English learner`, `struggling`, `below`, and read the surrounding methods or sample section. For long reports read the executive summary and the sample section only. Decide `code` and `level` per the codebook, copy a verbatim quote of under 60 words that shows the eligibility rule, and record where it is (page number, "abstract", or "WWC sample text"). If the text is a scan with no words, note `failed-ocr` and code from the abstract.
>
> Append one row per study to `kraft-2023-data/studies/coding/<batch>.csv` as you finish it, with the columns `study_id, key, code, level, opt_in, mixed_samples, evidence_quote, evidence_location, source_used, coder, date, confidence, resolved_title, notes`. On start, read that file and skip any `study_id` already present, so a restart resumes where you stopped.
>
> Rules: never modify anything under `articles/`; write only to your batch's files; use Python's csv module to append rows; no em dashes anywhere; abstract-only coding is never `high` confidence; when the source does not state the eligibility rule the code is `unclear`, not a guess; do not search the web. Report back with counts by code, the studies coded `unclear` and why, and anything that looked wrong in the data.
