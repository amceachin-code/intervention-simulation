# Intervention explorer

A static page (`index.html`) that starts from the restoration requirement g\*(p), the effect in 2019 SD units a program would need at percentile p to return the 2024 NAEP distribution to 2019, and shows how much of it a hypothetical program closes. Users set:

1. the program effect (2019 SD units, averaged over all percentiles);
2. the share of students treated;
3. who takes part: any student, with participation varying by prior achievement (five levels, from 4:1 favoring p10 over p90 to 4:1 favoring p90), or economically disadvantaged students only, at random among them (the eligibility screen in `analysis/alloc-rules.R`; seats beyond the disadvantaged share go unused);
4. how the effect varies with prior achievement (same scale);
5. whether the outcome is read on the group (students who started at p, followed through) or the distribution (whoever stands at p afterward, the treated/untreated mixture in `analysis/mixture.R`).

A card below the main chart shows economically disadvantaged and other students separately: each group's drop against its own 2019 score, with and without the program, and the gap between the groups at p10, p50, and p90 (the R reference is the group section of `analysis/06-seat-allocation.R`).

The settings are kept in the URL hash, so a configuration can be shared as a link.

A second page (`rounds.html`), "What would it take?", reached from the explorer's button of that name, asks question 1 as rounds of a program. A round seats a share c of students with an equal chance at every percentile and lifts each by g SD. Counted on the group estimand, one round adds c × g SD at every percentile, so the 10th percentile needs g\*(p10) / (c × g) rounds (rounded up), reaching every student once takes 1 / c rounds, and the 90-10 gap stays at its 2024 value. It shows one round for 100 students at p10, a summary card (rounds to reach everyone, rounds to bring p10 back, the 90-10 gap), and the caveats (no fade-out, a second turn as good as the first, new students each round). It also gives the one-round "All students" comparison from `scenario`. The page shares the `cell`, `share`, and `effect` hash keys with the explorer, so links between the two keep the settings. The arithmetic is `rounds()` in `engine.js`; no R output covers more than one round.

A third page (`methods.html`), reached from the "Show me the details" button and the small links beside each control, explains how each part was built: the data, the drop, the effect and participation presets and their sources, the two gradients, the two ways to count, rounds of a program, the checks, and the limits. Its tables and charts read the same `cells.js` and `engine.js`, so it cannot disagree with the explorer or the rounds page.

## Files

| File | Role |
|---|---|
| `index.html` | The explorer: controls, SVG charts, tables. No libraries, no build step. |
| `rounds.html` | "What would it take?": rounds of a program needed to bring the 10th percentile back to 2019. |
| `methods.html` | The methods page. |
| `style.css` | Styles shared by all three pages (color tokens, light and dark). |
| `charts.js` | SVG chart helpers and formats shared by the pages (frame, ticks, hover). |
| `engine.js` | The computation, a port of `analysis/mixture.R` and `water_fill` in `analysis/alloc-rules.R`, plus `rounds()` for the rounds page. |
| `cells.js` | Data, generated: the six cells, the presets, the Kraft (2020) percentiles, the Table 2(a) validation targets, and the Kraft (2023) targeted versus universal rows. Do not edit by hand. |

## Updating the data

```
Rscript analysis/10-export-tool-data.R      # from the project root; rewrites docs/cells.js
node analysis/tests/test-tool-engine.mjs    # checks cells.js and engine.js against tables/
```

The test compares the engine with the committed R outputs for proportional allocation and the eligibility screen (both estimands, every budget, four cells), and the ED / not-ED results with `tables/sim-group-outcomes-*.csv`; the two agree to under 1e-12 NAEP points. It also checks the methods-page data: the Kraft (2023) rows against `tables/kraft-2023-benchmarks-by-target.csv`, and the Table 2(a) targets against the differential change computed from the cells. For the rounds page it checks `rounds()`: the round counts against g\* read straight from `tables/sim-quantiles.csv` for all six cells and every take-up × gain preset pair, one round against `scenario()`'s group answer and k rounds against its pure shift, the 90-10 gap staying put, reach-everyone counts, fresh-draw reach, rounding at whole numbers, "never" at zero take-up or gain, and monotonicity.

## Viewing and hosting

Open `index.html` (or `rounds.html`, `methods.html`) directly, or serve the folder (`python3 -m http.server -d docs`). For GitHub Pages, set the repository's Pages source to the `main` branch, `/docs` folder.
