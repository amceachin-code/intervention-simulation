# Intervention explorer

A static page (`index.html`) that starts from the restoration requirement g\*(p), the effect in reference-year SD units a program would need at percentile p to return the comparison year's NAEP distribution to the reference year's, and shows how much of it a hypothetical program closes. The pages open on 2019 and 2024, the paper's comparison. Users set:

1. the reference year and a later comparison year, from the NAEP years 2005 to 2024 (grades 4 and 8: 2005, 2007, 2009, 2011, 2013, 2015, 2017, 2019, 2022, 2024; grade 12: 2005, 2009, 2013, 2015, 2019, 2024);
2. the program effect (reference-year SD units, averaged over all percentiles);
3. the share of students treated;
4. who takes part: any student, with participation varying by prior achievement (five levels, from 4:1 favoring p10 over p90 to 4:1 favoring p90), or economically disadvantaged students only, at random among them (the eligibility screen in `analysis/alloc-rules.R`; seats beyond the disadvantaged share go unused);
5. how the effect varies with prior achievement (same scale);
6. whether the outcome is read on the group (students who started at p, followed through) or the distribution (whoever stands at p afterward, the treated/untreated mixture in `analysis/mixture.R`).

A card below the main chart shows economically disadvantaged and other students separately: each group's drop against its own reference-year score, with and without the program, and the gap between the groups at p10, p50, and p90 (the R reference is the group section of `analysis/06-seat-allocation.R`). Its caveat gives both years' disadvantaged and unclassified shares. Where scores rose rather than fell, the tiles say "No drop", and chart shading is clipped to each side of zero.

The settings are kept in the URL hash, so a configuration can be shared as a link. The explorer and the rounds page share the keys `cell`, `ref`, `cmp`, `share`, and `effect`. The methods page has its own year selects, because its hash holds section anchors.

A second page (`rounds.html`), "What would it take?", reached from the explorer's button of that name, asks question 1 as rounds of a program. A round seats a share c of students with an equal chance at every percentile and lifts each by g SD. Counted on the group estimand, one round adds c × g SD at every percentile, so the 10th percentile needs g\*(p10) / (c × g) rounds (rounded up), reaching every student once takes 1 / c rounds, and the 90-10 gap stays at its comparison-year value. It shows one round for 100 students at p10, a summary card (rounds to reach everyone, rounds to bring p10 back, the 90-10 gap), and the caveats (no fade-out, a second turn as good as the first, new students each round). It also gives the one-round "All students" comparison from `scenario`. The page shares the `cell`, `ref`, `cmp`, `share`, and `effect` hash keys with the explorer, so links between the two keep the settings. The arithmetic is `rounds()` in `engine.js`; no R output covers more than one round.

A third page (`methods.html`), reached from the "Show me the details" button and the small links beside each control, explains how each part was built: the data, the drop, the effect and participation presets and their sources, the two gradients, the two ways to count, rounds of a program, choosing the years (section 9, with a table of the years and of the ED shares by year), the checks, and the limits. Its tables and charts read the same `cells.js`, `years.js`, and `engine.js`, so it cannot disagree with the explorer or the rounds page.

## Files

| File | Role |
|---|---|
| `index.html` | The explorer: controls, SVG charts, tables. No libraries, no build step. |
| `rounds.html` | "What would it take?": rounds of a program needed to bring the 10th percentile back to the reference year. |
| `methods.html` | The methods page. |
| `style.css` | Styles shared by all three pages (color tokens, light and dark). |
| `charts.js` | SVG chart helpers and formats shared by the pages (frame, ticks, hover), plus the year-select helpers `yearsOf`, `snapYears`, and `fillYearSelects`. |
| `engine.js` | The computation, a port of `analysis/mixture.R` and `water_fill` in `analysis/alloc-rules.R`, plus `rounds()` for the rounds page. `pair(yearsCell, ref, cmp)` builds any reference and comparison pair from `years.js`, and `cellYears()` lists a cell's years. Field names are year-neutral (`sdRef`, `qRef`, `qfRef`, `qfCmp`, `gStar`, `gap9010.ref` and `.cmp`). |
| `cells.js` | Data, generated: the six cells, the presets, the Kraft (2020) percentiles, the Table 2(a) validation targets, and the Kraft (2023) targeted versus universal rows. Do not edit by hand. Still the source for the presets, the Kraft data, and Table 2(a). |
| `years.js` | Data, generated: every cell-year from 2005 to 2024 (52 records, about 201 KB, `globalThis.TOOL_YEARS`): percentiles, SD, quantile-function points, and the ED breakdown. Do not edit by hand. |

## Updating the data

```
Rscript analysis/10-export-tool-data.R          # from the project root; rewrites docs/cells.js
Rscript analysis/11-export-explorer-years.R     # rewrites docs/years.js and tables/explorer-pairs-check.csv
node analysis/tests/test-tool-engine.mjs        # checks cells.js, years.js, and engine.js against tables/
```

The years and the check pairs are set in `analysis/config/explorer-years.yaml`.

The test compares the engine with the committed R outputs for proportional allocation and the eligibility screen (both estimands, every budget, four cells), and the ED / not-ED results with `tables/sim-group-outcomes-*.csv`; the two agree to under 1e-12 NAEP points. It also checks the methods-page data: the Kraft (2023) rows against `tables/kraft-2023-benchmarks-by-target.csv`, and the Table 2(a) targets against the differential change computed from the cells. For the rounds page it checks `rounds()`: the round counts against g\* read straight from `tables/sim-quantiles.csv` for all six cells and every take-up × gain preset pair, one round against `scenario()`'s group answer and k rounds against its pure shift, the 90-10 gap staying put, reach-everyone counts, fresh-draw reach, rounding at whole numbers, "never" at zero take-up or gain, and monotonicity. For the years it checks that `pair(2019, 2024)` reproduces `cells.js` in every field (section 0), that the engine matches `tables/explorer-pairs-check.csv` (Math G8 2013-2024, Reading G4 2005-2019, Math G12 2005-2015) to 3.5e-13 points (section 8), and that all 52 cell-years and all 210 valid pairs pass the invariants (section 9). Section 7 also checks that no page copy has a literal 2019 or 2024 outside an allowlist. In all, 17,383 checks.

## Asset version tag

Each page loads `style.css`, `cells.js`, `years.js`, `engine.js`, and `charts.js` with a version tag (`engine.js?v=2026-10-03`). GitHub Pages lets browsers cache files for 10 minutes, so without the tag a new page can run against a cached old engine or stylesheet and stop partway through drawing. Whenever you change any of those five files, including a `cells.js` rewrite by `10-export-tool-data.R` or a `years.js` rewrite by `11-export-explorer-years.R`, change the tag in all three pages to a new value: the date, with `.2`, `.3` for later changes on the same day. The engine test (section 7) fails if a page lacks the tag or the pages disagree.

## Viewing and hosting

Open `index.html` (or `rounds.html`, `methods.html`) directly, or serve the folder (`python3 -m http.server -d docs`). For GitHub Pages, set the repository's Pages source to the `main` branch, `/docs` folder.
