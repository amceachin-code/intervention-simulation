<!-- draft v1, 2026-10-01; sources: approved plan, design/canvas/B1-Requirement.dc.html (commit e80ce1c) -->

# Project Plan

**Title:** Port B1 "What would it take?" into the explorer as a rounds view

**Status:** Approved 2026-10-01 (plan `enumerated-wobbling-key.md`). Work is on branch `explorer-rounds-view`, cut from `main`. Not merged until Andrew reviews.

## Objective

`design/canvas/B1-Requirement.dc.html` (on the design-snapshot branch, commit e80ce1c) reframes question 1 as **rounds of a program**:

- One round adds c x g SD at every percentile (group estimand, equal chance of a seat).
- The 10th percentile therefore needs g\*(p10) / (c x g) rounds to return to 2019.
- Reaching everyone once takes 1 / c rounds.
- The 90-10 gap never changes.

The canvas only renders inside the canvas editor and hard-codes six cells' numbers. The goal is a working page in `docs/`, in the explorer's plain-HTML style, with:

- every number taken from `docs/cells.js`;
- the arithmetic in `docs/engine.js`, under test;
- the methods page and the docs README updated to match.

## Scope

**In scope**

- A pure `rounds()` function in `docs/engine.js`, exported on `NAEPEngine`.
- A new page, `docs/rounds.html`, with controls, a one-round card, a summary card, a round-after-round chart, a students-reached strip, a preset matrix, a "Read with care" list, and a footer. (Amended 2026-10-01: at Andrew's request the round-after-round chart, the students-reached strip, and the preset matrix were removed after the first build.)
- Links from `docs/index.html` and `docs/methods.html` to the new page.
- Additive styles in `docs/style.css` (no changes to existing rules).
- A new section 6 in `analysis/tests/test-tool-engine.mjs`.
- A new methods section, "8. Rounds of a program", with renumbering and a revised limit.
- `docs/README.md` updates.
- Housekeeping: this `PROJECTPLAN.md`, correcting the branch name in the new `PROGRESS.md` entry, final README and PROGRESS agents, and an offer of the code-review pass.

**Out of scope**

- `docs/cells.js` (generated; not edited by hand or regenerated here).
- `design/` (stays on the snapshot branch).
- `tables/SIM-SUMMARY.md` and `manuscript/simulation-memo.md`, which still use the per-participant g\*/c framing.
- Any R reference for multi-round results.
- Merging to `main`.

## Architecture & Design Decisions

1. **One shared engine function.** `rounds()` is pure and lives in `docs/engine.js` on `NAEPEngine`, so Node can test it and both pages share it. Signature and returns:

   ```
   rounds(cell, c, g) -> {
     S, gStar10, gStar90,          // from cell.g_star at p10 / p90 (already -D/S, tested)
     drop10, drop90, gap2019, gap2024, widen,   // points, from cell.q2019 and cell.d
     perRound, perRoundPts,        // c*g SD, c*g*S points, same at every percentile
     toRestore10, toRestore90,     // exact ratios gStar/perRound (Infinity if perRound = 0)
     rounds10, rounds90, roundsReach,   // whole rounds, ceil with 1e-9 slack, null if never
     turnsPerStudent,              // gStar10 / g
     shareUndonePerRound,          // perRound / gStar10 (also the fade-out threshold)
     freshDrawReached(k)           // 1 - (1-c)^k
   }
   ```

2. **Assumptions stated in the code.** The header comment states the assumptions: gains add, no fade, a second turn equals the first, and each round serves new students. It also says this is the group estimand with neutral tilts.
3. **Rounding.** `ceilRounds` keeps the design's EPS slack, so an exact integer ratio is not bumped up a round. "Never" (c = 0 or g = 0) is `null`.
4. **Same page skeleton as `index.html`.** `style.css`, then `cells.js`, `engine.js`, `charts.js`, then one inline script. Reuse `NAEPCharts.el / niceTicks / path` and `NAEPShared.f1 / f3 / fmtPct / cellName / configValue / chipName / provenanceText`.
5. **No literals for presets or defaults.** Take-up chips come from `D.participation` and gain chips from `D.benchmarks` (sorted). Defaults are Math G8, the `optin` take-up, and the `D.treated_effect` gain (the B1 defaults), looked up by id.
6. **State in the URL hash.** `cell`, `c`, `g`, clamped the same way as `readHash` in `index.html`.
7. **A local chart frame.** A small `roundsFrame()` in the page, because `NAEPCharts.frame` is fixed to the p10 to p90 axis.
8. **Conditional headline.** B1's open item: fixed text reads oddly at extremes, so the headline and "Read with care" items are computed where B1 computes them.
9. **Additive styling only.** New tokens and classes (matrix shades, waffle/dumbbell/rounds-chart series colors, a summary-card variant) are defined in the light, `prefers-color-scheme: dark`, and `[data-theme]` blocks, as the existing tokens are.
10. **Methods anchors stay stable.** Sections after the new one are renumbered, but their ids do not change, so existing links keep working.

## Implementation Steps

1. **Engine: `rounds()` in `docs/engine.js`**
   - Add `rounds(cell, c, g)` with the returns in Design Decision 1 and the assumptions header comment.
   - Add `ceilRounds` with the design's EPS (1e-9).
   - Export on `NAEPEngine`.

2. **New page: `docs/rounds.html`**
   - **Controls card:** a cell `<select>`, a take-up slider (0 to 100%) and a gain slider (0 to 0.50 SD), each with `.chips` presets from `D.participation` and `D.benchmarks`. State in the URL hash, clamped like `index.html`'s `readHash`.
   - **One round card:** a 10x10 waffle; a three-row dumbbell at p10 (no program, took part, average of all); three `.tile`s (each participant, average of all, share of drop undone).
   - **Summary card:** rounds to reach everyone once, rounds to restore p10, the 90-10 gap after any number of rounds, a computed lede sentence, and a gap note.
   - **Round after round chart:** SVG with x = rounds 0..K and y = points vs 2019; p10 and p90 lines, no-program reference lines, the reach-everyone marker, the restore markers, and the "points apart in every round" bracket. Built with a local `roundsFrame()`.
   - **Students reached strip:** reached once, reached twice, and the fresh-random-draw curve.
   - **Preset matrix:** an HTML `<table>` of rounds to restore p10 for every take-up x gain preset, shaded by bucket, with the current setting outlined.
   - **Read with care list:** computed where B1 computes it. The headline becomes conditional.
   - **Footer:** the provenance line and a link back into the explorer carrying the cell (`index.html#cell=...`).

3. **Links**
   - `docs/index.html`: a second button in the lede row, "What would it take?", linking to `rounds.html` and keeping the cell.
   - `docs/methods.html`: a link in the intro and in the new section.

4. **Styles: `docs/style.css`**
   - Additions only: matrix shade classes, series-color tokens for the waffle, dumbbell, and rounds chart (light, dark media query, and `[data-theme]` blocks), and a summary-card variant.

5. **Tests: new section 6 in `analysis/tests/test-tool-engine.mjs`**
   - See Testing Strategy for the full list.

6. **Methods: `docs/methods.html`**
   - New section "8. Rounds of a program" after "Two ways to count". Renumber checks, limits, and references (ids unchanged). Update the contents list.
   - A small table of rounds to restore p10 per cell at the default program, built from `rounds()`.
   - Revise the "One program, one year, no fade-out" limit: the rounds page assumes no fade, and that is the best case. Say why.
   - Add a bullet to "The checks" for the new tests.
   - Run drafted prose through `/writing-style`. Bump the provenance header comment.

7. **Docs README: `docs/README.md`**
   - Describe `rounds.html`, `rounds()` in the engine, the new test section, and the files table.

8. **Housekeeping (per CLAUDE.md)**
   - Create this `PROJECTPLAN.md` after approval.
   - Correct the branch name in the new `PROGRESS.md` entry (it says `claude/trusting-davinci-vyejhb`; the branch is `explorer-rounds-view`).
   - Launch the final README and PROGRESS agents at the end.
   - Offer the code-review pass.

## Dependencies & Prerequisites

- **No new libraries.** The page uses the explorer's existing `style.css`, `cells.js`, `engine.js`, and `charts.js`.
- **Node**, for `analysis/tests/test-tool-engine.mjs`.
- **R**, for `bash analysis/tests/run-all.sh` (the R tests plus the engine test).
- **python3** (`http.server`) and Chrome, for the manual page check.
- **Branch `explorer-rounds-view`**, cut from `main`. The design snapshot (commit e80ce1c) is not on `main` and is read only as a reference.

## Testing Strategy

**Automated: section 6 of `analysis/tests/test-tool-engine.mjs`**

1. `rounds10` equals ceil(g_star_p10 / (c g)), with g_star read **from `tables/sim-quantiles.csv`** (independent of `cells.js`), for all six cells x the 16 preset pairs.
2. Cross-check through the tested engine path, in group mode:
   - `E.scenario` at share 1 and effect k x c x g (a pure shift, equal to k rounds) leaves p10 short of 2019 at k = rounds10 - 1, and at or above it at k = rounds10.
   - One round's p10 gain equals the p10 gain from `scenario(share c, effect g, group)`.
3. The 90-10 gap after any k rounds equals `scenario(...).gap9010.y2024`. `widen` equals the Table 2(a) target to one decimal.
4. `roundsReach` is 1, 4, 6, and 8 for the four take-up presets. `freshDrawReached` matches 1 - (1 - c)^k.
5. Edges: c = 0 or g = 0 gives `null` ("never"); an exact integer ratio is not rounded up; c = 1 reaches everyone in one round; results are monotone (more c or g never needs more rounds).

**Verification runs**

1. `node analysis/tests/test-tool-engine.mjs`: the new section passes and the old sections are unchanged.
2. `bash analysis/tests/run-all.sh`: R tests plus the engine test.
3. Serve with `python3 -m http.server -d docs` and check `rounds.html` in Chrome:
   - all six cells;
   - the preset chips;
   - slider extremes (0%, 100%, 0 SD, 0.5 SD);
   - the hash round trip;
   - light and dark themes;
   - phone width;
   - Math G8 at 18.7% / 0.155 SD reproduces B1's numbers;
   - a clean console;
   - `index.html` and `methods.html` still render.
4. `git diff main --stat` to confirm scope. No merge to `main`.

## Risks & Open Questions

These are flagged to Andrew and not fixed here.

- **No multi-round R reference.** No R reference covers more than one round. The JS tests check the arithmetic against the CSV and against the engine's one-round path only.
- **An unsupported B1 line.** B1's "counted across all students, about a round longer" line has no committed output behind it. The page keeps it as a qualitative caveat with no number, unless Andrew wants it cut.
- **Framing mismatch.** `tables/SIM-SUMMARY.md` section 7.2 and the memo still use the per-participant g\*/c framing, so they will not match the new page's rounds framing until they are revised.
- **Best-case assumptions.** The rounds arithmetic assumes no fade, additive gains, and an equal effect on a second turn. The page and the methods limit say so. Fade, or a smaller effect on a second turn, would mean more rounds.

## Estimated File Changes

**Created**

- `docs/rounds.html`
- `PROJECTPLAN.md` (this file)

**Modified**

- `docs/engine.js`
- `docs/index.html`
- `docs/methods.html`
- `docs/style.css`
- `docs/README.md`
- `analysis/tests/test-tool-engine.mjs`
- `PROGRESS.md` (branch-name correction, plus the agent updates)
- `README.md` (through the final README agent)

**Not touched**

- `docs/cells.js` (generated)
- `design/` (stays on the snapshot branch)
- `tables/SIM-SUMMARY.md`, `manuscript/simulation-memo.md`

## Previous plans

<!-- plan v2, 2026-09-29; source: approved plan replicated-napping-canyon.md -->

# Project Plan: ED breakdown in the explorer, memo refresh, argument cleanup

**Title:** ED breakdown in the explorer, memo refresh, argument cleanup

**Status:** Approved 2026-09-29. Stata MCP prerequisite done (server on localhost:4000; a test command returned Stata 19.5 MP).

## Objective

Andrew wants the explorer (`docs/`) working first, so he can decide later whether it ships with the AERA Open paper or goes into a new paper. He asked for:

1. **The economic-disadvantage (ED) breakdown, both ways.**
   - As a targeting rule: seats go only to ED students.
   - As an outcome group: ED and not-ED students' distributions before and after a program.
2. **Two cleanups.** Refresh the out-of-date distributional numbers in `manuscript/simulation-memo.md`, and give `04-` and `06-` the same `--flag` arguments as `01-` and `02-`.
3. **Stata MCP.** Done.

**What the code does today.**

- The ED breakdown is not a comparison group. It is used only inside the R eligibility-screen rule. `make_ed_curve` (`analysis/alloc-rules.R:156`) draws a made-up four-point ED-share line from two numbers: the ED share of students below p10 and below p25.
- Those two numbers come from `group_cdf` (`analysis/dist-helpers.R:10`), which uses five percentiles plus a normal tail. That is the last tail assumption left in the pipeline after commit 2ae29bd.
- The screen caps participation at 100 percent rather than at the ED share, which is a known flaw.
- `docs/` has no ED code at all.

## Scope

**In scope**

- `--cell` flag arguments for `04-district-requirements.R` and `06-seat-allocation.R`, with callers and docs updated.
- Pulling, validating, caching, and storing ECONDIS `DP:DP` score histograms (groups 1 and 2) for all six cells in 2019 and 2024.
- Replacing `group_cdf` in `group_composition()` and the tails in 03's `nat_pct` with histogram-based quantile functions.
- An ED share curve s(p) built from the histograms, replacing the four-point `make_ed_curve`.
- An exact definition of the eligibility screen (random among ED students, capped at the ED population).
- ED and not-ED outcome distributions in R (`06`) and in the explorer.
- Explorer inputs, a new card, methods-page text, and export changes.
- Refreshing the numbers and method text in `manuscript/simulation-memo.md`.
- Generated (not hand-typed) ED prose in `05-compile-summary.R`, regenerated outputs, tests, and `TODO.md` updates.

**Out of scope**

- A tilted ED screen (lower-scoring ED students get priority). Logged in `TODO.md` as a follow-up.
- Journal framing, target journal, and co-authors.
- A Stata port of the ECONDIS work. The Stata run is only a guard on D and g\*.

## Architecture & Design Decisions

1. **Groups 1 and 2 only.** Pull "Economically disadvantaged" and "Not economically disadvantaged". Group 3 ("Information not available") has flagged bins and is not needed, since its mass is the national total minus groups 1 and 2.
2. **One request per cell and year.** Two-year ECONDIS `DP:DP` requests return an empty body, so there are 12 requests in all.
3. **Backward-compatible API helpers.** `get_distribution()` gains a `variable` argument defaulting to `"TOTAL"`, so existing cache keys do not change. `parse_distribution()` gains a `group` argument that filters on `varValueLabel`; the existing checks (complete, unflagged, sums to 100) then run per group. The row-count check allows for group 3's flagged rows.
4. **ED share curve with no tails and no invented knots.** For each 10-point bin b, s_b = pop_ED x pct_ED,b / pct_TOTAL,b, with the national TOTAL histogram as the denominator. Each bin sits at its midpoint national rank (from the cumulative national histogram); s(p) is linearly interpolated and clamped to [0, 1].
5. **The screen is random assignment among ED students.** The ED treatment rate is r = min(1, B / pop_ED), and participation at percentile p is pi(p) = r x s(p). This is exact, and it fixes the cap: the rule never treats more students than there are ED students.
6. **Seats beyond the ED share go unused by default.** The explorer says so (for example, "ED students are 51 percent of students; the remaining seats have no eligible takers"). Handing the extra seats to not-ED students at random is a one-line alternative if Andrew prefers it.
7. **The who-takes-part tilt is off when the screen is on.**
8. **Group outcomes reuse the national machinery.** A student at group rank u has national rank F_nat(Q_g(u)). Participation is pi(F_nat(Q_g(u))) under the national rules (bottom-up, proportional, opt-in), and r for ED or 0 for not-ED under the screen. The effect is the national rule's effect at that national rank. The post-program group distribution is the same exact two-part mixture of treated and untreated students, via `weighted_quantile()` on the group's rank grid. Group percentiles from the cached ECONDIS PC pull are passed as knots to `quantile_points()`.
9. **Scales.** Scores are in NAEP points; requirements stay in 2019 national SD units (the cell's S).
10. **R builds, JS receives.** `10-export-tool-data.R` exports every ED value from committed tables; nothing is typed by hand in `docs/`.
11. **Memo last.** The memo refresh follows steps A to E so its numbers are final.

## Implementation Steps

1. **G. Argument conventions**
   - `analysis/04-district-requirements.R` and `analysis/06-seat-allocation.R` take `--cell "Math G8"`, using the `getarg` idiom from `analysis/01-simulations.R:28-37`.
   - Unknown cells fail right away with the list of valid cells (06 already does; add it to 04).
   - Update callers and docs: `analysis/tests/test-regen.sh:77-81`, `README.md` (lines 58-61, 67, 199, 201), `analysis/README.md:13-16`, `CLAUDE.md:58`, and the usage lines in both scripts.
   - Tick the item off in `TODO.md`.

2. **A. Data: score distributions by ED status**
   - `analysis/api-helpers.R`: add the `variable` argument to `get_distribution()` and the `group` argument to `parse_distribution()`; relax the row-count check for group 3's flagged rows.
   - `analysis/01-simulations.R`: pull ECONDIS `DP:DP` for 6 cells x 2 years (12 requests). Write `tables/sim-distribution-econdis.csv` with columns `cell, year, group, pop_share, bin, lo, hi, pct`; `pop_share` comes from the already cached ECONDIS `RP:RP` pull.
   - Commit the new `analysis/.cache/*.json` files so `--regen` never needs the network.
   - `group_composition()`: get `p_below_cut` from the group histogram via `quantile_points()` and `make_quantile_fn()` in `analysis/mixture.R`, inverted at the cut, instead of from `group_cdf`. `tables/sim-bottom-decile.csv` keeps its shape; its values move slightly.
   - Retire `group_cdf` (`analysis/dist-helpers.R`) and its unit tests if nothing else calls it.
   - `analysis/03-district-cases.R`: replace the tails in `nat_pct` with the inverse of the national 2019 quantile function built from `tables/sim-distribution.csv`. This closes the second half of the TODO item.

3. **B. ED share at each percentile**
   - New `ed_share_points(dist_total, dist_econ, cell, year)` in `analysis/alloc-rules.R`, returning `{pct, share}` per Design Decision 4.
   - `make_ed_curve` becomes a thin wrapper around it.

4. **C. The eligibility screen**
   - Implement r = min(1, B / pop_ED) and pi(p) = r x s(p) in `analysis/alloc-rules.R` / `analysis/06-seat-allocation.R`.
   - Leave unused seats unused by default; turn off the tilt when the screen is on.
   - Log the tilted screen in `TODO.md`.

5. **D. ED and not-ED outcomes**
   - Group quantile functions via `quantile_points(dist_group_year, knots_pct, knots_val)` with the cached ECONDIS PC percentiles as knots.
   - `analysis/06-seat-allocation.R` writes `tables/sim-seat-allocation-by-group-<cell>.csv` with columns `rule, budget, group, post_p10, post_p50, post_p90, gap_ed_p50`. The group gap is ED minus not-ED at each percentile, at 2019, 2024, and after the program.

6. **E. Explorer**
   - `analysis/10-export-tool-data.R`: per cell, export `ed: {pop, share:{pct,share}, qf:{ed2019, ed2024, ned2019, ned2024}}` from committed tables; regenerate `docs/cells.js`.
   - `docs/engine.js`: add `inputs.rule: "tilt" | "ed"`, choosing `piFn` at line 230 (`waterFill` unchanged for the tilt rules). Add `groupScenario(cell, inputs)` returning ED and not-ED curves and gaps, reusing `makeQuantileFn`, `weightedQuantile`, and `approx`.
   - `docs/index.html` and `docs/charts.js`: a "Who is eligible" choice in step 3 (all students with the tilt, or ED students only), wired into state, the URL hash, `readHash` validation, and `sync()`. A new card, "Economically disadvantaged and other students", with one chart of each group's drop and post-program curve and a small table of the ED/not-ED gap at p10, p50, and p90 for 2019, 2024, and after the program. Labels go in `NAEPShared`.
   - `docs/methods.html`: new section 5b on the screen and the ED share curve; a group-outcomes paragraph; updates to section 8 (Checks) and section 9 (Limits): NAEP's ED flag is school-lunch eligibility, which varies by state and over time, and the "information not available" group grew from about 6 percent to about 9 percent.
   - `docs/README.md`: note the new input.

7. **F. Memo refresh** (`manuscript/simulation-memo.md`)
   - Take every post-program distribution number from the regenerated `tables/sim-seat-allocation-*.csv`: lines 286, 294-297, 337-340; the commented-out tables at 307-320 and 355-358; lines 344, 362, 364, 368, 372-374.
   - Delete the tail-sensitivity paragraph (288) and the claim at line 10 about surviving other tail choices.
   - Rewrite the method text (263) to describe the spline through the score bins.
   - Change "about a quarter" (364) to the current split (the audit put it at about 6/94 before the ED change).
   - Soften "widens" (12, 401) to match sizes of 0.03 to 0.25 points.
   - Rewrite the eligibility-screen rows and ED numbers at lines 378-394 to the new definition.
   - Replace the dated note at line 3 with a new one.
   - Run new prose through `/writing-style`; re-render with `manuscript/render-section.sh manuscript/simulation-memo.md docx` (also refreshes the stale `.rendered.md`).
   - In `PROGRESS.md` history, mark the "40/60" and "6.0 vs 2.7" lines as superseded rather than rewriting them.

8. **Summary, figures, TODO, and wrap-up**
   - `analysis/05-compile-summary.R` sections 6/6b: generate the hand-typed prose ("five of every six", 82.8/80.6/79.2) from the table.
   - Rerun `analysis/02-figures.R` (fig10 reads `sim-bottom-decile.csv`); regenerate `tables/SIM-SUMMARY.md`.
   - `TODO.md`: close the score-distribution item, the screen-cap caveat, and the argument item; log the tilted-screen idea.
   - Update `PROGRESS.md` and `README.md` through the required background agents. Commit only on Andrew's approval.

## Dependencies & Prerequisites

- **R packages already used** by the pipeline; no new packages.
- **node**, for `analysis/tests/test-tool-engine.mjs`.
- **NAEP Data Service API network access** for 12 new ECONDIS `DP:DP` requests (6 cells x 2 years, one year per call). After they are cached and committed, no network is needed. `curl` is used because this machine intercepts TLS.
- **stata-mcp** server at localhost:4000, for the Stata guard run.
- **pandoc 3 or newer**, for re-rendering the memo.
- **python3** (`http.server`) and Chrome, for the explorer check.

## Testing Strategy

1. `bash analysis/tests/run-all.sh --regen`: every R test and the Node engine test pass, and the byte comparison passes from the committed cache with no network. Expected byte differences: `sim-bottom-decile.csv`, the screen rows of `sim-seat-allocation-*`, and the new tables. Each changed file and the reason are listed before the reference is regenerated.
2. New R tests:
   - s(p) stays within [0, 1];
   - ED + not-ED stays at or below the national total in every bin;
   - the screen spends min(B, pop_ED) seats exactly;
   - pi(p) = r x s(p);
   - the group mixture (plus group 3 as national minus groups 1 and 2, weighted by population) recombines to the national result within 1e-6 points;
   - a zero budget reproduces each group's 2024 distribution;
   - the old four-point curve and the new s(p) roughly agree at p10 and p25.
3. `test-tool-engine.mjs`: the JavaScript screen and group results match the new R tables to 1e-6 in the four G4 and G8 cells.
4. Unchanged numbers stay unchanged: D(p), g\*, Table 2(a) (8.7, 7.0, 1.5, 7.9, 6.4, 4.5), and the proportional, bottom-up, and opt-in rows of the seat tables are byte-identical.
5. Stata port: run `analysis/stata/01_simulations.do` through stata-mcp and confirm the 1e-14 agreement on D and g\*. It does not touch ECONDIS, so this is only a guard.
6. Explorer: serve with `python3 -m http.server -d docs` and check in Chrome: the ED screen at 13 percent and at 75 percent (to see the unused-seats note), the ED card, the URL hash round trip, and no console errors.
7. Memo: grep that every changed number matches its table row, check for em dashes, and re-render.

## Risks & Open Questions

- **Seats beyond the ED share default to unused.** At budgets above pop_ED the screen spends fewer seats than the other rules, so comparisons at equal budget are not equal spending. Andrew may prefer giving the extra seats to not-ED students at random (a one-line change); the explorer note makes the default visible.
- **The "information not available" group.** It is not pulled directly; its mass is taken as national minus groups 1 and 2. It grew from about 6 percent to about 9 percent between 2019 and 2024, which affects the ED/not-ED comparison and is noted in the methods Limits section. NAEP's ED flag is school-lunch eligibility, which varies by state and over time.
- **ECONDIS `DP:DP` flagged bins.** Group 3 has flagged bins, so the parser must filter by group before the unflagged check and the row-count check must allow for group 3's rows. If groups 1 or 2 turn out to have flagged or missing bins in any cell, the pull must stop rather than silently drop them.
- **Byte-regen reference changes.** `sim-bottom-decile.csv`, the screen rows of `sim-seat-allocation-*`, and the new tables will change the `--regen` reference. Each change must be listed and explained before the reference is regenerated, and all other rows must stay byte-identical.

## Estimated File Changes

**Created**

- `tables/sim-distribution-econdis.csv`
- `tables/sim-seat-allocation-by-group-<cell>.csv` (one per cell run)
- New `analysis/.cache/*.json` responses (12 ECONDIS `DP:DP` pulls)

**Modified**

- `analysis/api-helpers.R`
- `analysis/01-simulations.R`
- `analysis/alloc-rules.R`
- `analysis/dist-helpers.R` (retire `group_cdf` if unused)
- `analysis/03-district-cases.R`
- `analysis/04-district-requirements.R`
- `analysis/05-compile-summary.R`
- `analysis/06-seat-allocation.R`
- `analysis/10-export-tool-data.R`
- Tests: `analysis/tests/test-sim.R`, `analysis/tests/test-api-guards.R`, `analysis/tests/test-tool-engine.mjs`, `analysis/tests/test-regen.sh`
- Explorer: `docs/engine.js`, `docs/cells.js` (regenerated), `docs/index.html`, `docs/charts.js`, `docs/methods.html`, `docs/README.md`
- `manuscript/simulation-memo.md` and its rendered outputs
- `README.md`, `analysis/README.md`, `CLAUDE.md` (usage line), `TODO.md`, `PROGRESS.md`
- Regenerated outputs: `tables/sim-bottom-decile.csv`, `tables/sim-seat-allocation-*.csv`, `tables/SIM-SUMMARY.md`, fig10 in `figures/sim/`

**Deleted**

- Possibly `group_cdf` and its unit tests, if nothing else calls it.



<!-- plan v1, 2026-09-28; source: approved plan curious-twirling-barto.md -->

# Project Plan: national quantile functions from NAEP's score histogram

**Status:** Approved 2026-09-28; step 0 done (methods page committed as 58525ca and pushed).

## Objective

Remove the corner in the explorer's "All students" curve near the 90th percentile, and the same artifact in the committed R seat-allocation results (PROGRESS.md open item (a)).

The cause is `make_quantile_fn()` (`analysis/mixture.R:60`, ported in `docs/engine.js:119`). It rebuilds each distribution from the five published percentiles and adds normal tails fitted to p10 and p90. Where the tail meets the spline at p90, the slope jumps by a factor of 1.4 to 1.8. Once enough boosted students pass the 2024 p90 score, the mixture reads from that tail and inherits the corner.

The NAEP Data Service API also publishes `DP:DP`: the percent of students in each 10-point score bin (50 bins; 30 for Math G12 on its 0 to 300 scale), plus the mean. A read-only check on 2026-09-28 found:

- All 12 cell-by-year histograms exist and sum to 100.
- No subject or grade has mass piled at the scale floor or ceiling.
- A monotone spline through the cumulative bin points reproduces all 60 published percentiles to within 0.11 points.
- Adding the five published percentiles to those points keeps every set strictly increasing.

The goal is a national quantile function built from the histogram, with no assumed tails and no corner. D(p), g\*, the Table 2(a) check, the group estimand, and the Stata port stay exactly as they are. Only the distributional ("All students") results move.

## Scope

**In scope**

- Pulling, validating, caching, and storing the `DP:DP` histograms for all six cells in 2019 and 2024.
- A new national quantile function in R (`analysis/mixture.R`) and in the explorer (`docs/engine.js`), built from one shared set of quantile points per cell and year.
- Seat allocation (`06`) and the explorer export (`10`) switched to the new function.
- Retiring the tail-sensitivity script (`07`) and its table.
- Tests, regenerated outputs, an old-versus-new comparison of the seat-allocation results, and prose updates on the docs pages and READMEs.

**Out of scope (deferred to a logged follow-up)**

- `group_cdf` (the economic-disadvantage breakdown).
- 03's `nat_pct` (district cases).

Note on the follow-up: the API does return `DP:DP` histograms by `ECONDIS` (all three groups, 50 bins summing to 100 in 2019 and 2024 for Reading G4), so the follow-up is feasible with public data. Requests must go one year per call: a two-year `ECONDIS` `DP:DP` request returned an empty body.

**Unchanged by design**

- Table 2(a) validation.
- `sim-quantiles.csv` values.
- g\* and D(p).
- The group estimand (`gap_remaining_tracked`).
- `sim-bottom-decile.csv` (ED breakdown).
- The Stata port, which uses the knots only.
- 03's district cases.

## Architecture & Design Decisions

1. **Anchor to the five published percentiles.** The curve passes exactly through the published p10, p25, p50, p75, and p90; the histogram sets the shape everywhere else (Andrew, 2026-09-28). This keeps every knot-based identity in the tests true and means the calibration offset again absorbs only the roughly 0.008-point grid artifact.
2. **Bounded support from the bin edges; no tails.** Each point set is `(cumulative percent, score)` at every non-empty bin's upper edge, plus `(0, lower edge of the first non-empty bin)`, plus the five published `(p, Q(p))` knots. A histogram point within 1e-9 percent of a knot is dropped. The spline is the existing monotone Fritsch-Carlson method (`splinefun(method = "monoH.FC")` in R, `monoHFC` in JS) on [0, 100]. Because the support is bounded by the bin edges, no normal tails are needed, and the tail branch is deleted as dead code.
3. **R builds the point sets; JS receives them.** `quantile_points()` in `mixture.R` is the single place that merges histogram points and knots. `10-export-tool-data.R` exports the ready-made points to the explorer, so the merge logic is not duplicated in JavaScript.
4. **Store the raw histogram, derive points downstream.** `tables/sim-distribution.csv` holds the histogram itself (public data); points are computed where they are used.
5. **Retire 07.** The tail-sensitivity check existed to bound the effect of the assumed tails. With no tails, it has no purpose. Its record of the size of the change is replaced by an old-versus-new comparison of the seat-allocation results. Script numbering is kept (no renumbering of 08, 09, 10).
6. **Leave the memo historical.** `manuscript/simulation-memo.md` is not rewritten. A dated, highlighted note at the top says its distributional numbers used the five-point curve and are superseded by `tables/`.

## Implementation Steps

0. **Housekeeping.** (Done.) The methods-page work was committed first as 58525ca and pushed, so this change is its own diff. Launch the README, PROGRESS, and PROJECTPLAN background agents.

1. **Pull and store the histograms** (`analysis/api-helpers.R`, `analysis/01-simulations.R`, `analysis/config/sim-params.yaml`)
   - `sim-params.yaml`: add `scale_max` per cell (500; Math G12 300).
   - `api-helpers.R`: add `DIST_STAT <- "DP:DP"` and `get_distribution(cell, years, ...)`.
     - It reuses `fetch_api`, `usable`, and the cache.
     - `expect_rows = (scale_max/10 + 6) * length(years)`: the bins plus the six DJ/DNT summary rows.
     - It validates contiguous bins `DP:D1..DP:Dn`, zero error flags, and a sum within 0.01 of 100 per year, and stops otherwise.
     - First confirm how `usable()` treats empty bins (`isStatDisplayable`); zero bins must survive or be restored as 0.
   - `01-simulations.R`: a separate call per cell (not added to the TOTAL request, since `01:101` maps every non-SD code to a percentile). Write the new tracked table `tables/sim-distribution.csv` with columns `cell, year, bin, lo, hi, pct, cum_pct`.
   - Commit the new `analysis/.cache/*.json` responses (tracked cache, per CLAUDE.md).

2. **Quantile points and function** (`analysis/mixture.R`)
   - Add `quantile_points(dist_rows, knots_pct, knots_val)`, which builds the merged, strictly increasing `(pct, score)` set and errors on a tie or a non-monotone set.
   - Change `make_quantile_fn(pct, vals)` to a plain monotone spline that requires `pct[1] == 0` and `pct[n] == 100`. Delete the normal-tail branch.
   - Leave `RANK_GRID`, `weighted_quantile`, `program_quantiles`, and `calibrated_program_quantiles` unchanged.
   - Update the comments at `mixture.R:23-28` and `50-59` (the old 1.17 / 2.69 / 5.96 figures).

3. **Seat allocation** (`analysis/06-seat-allocation.R:112`)
   - Build `Q2024_fn` from `quantile_points(sim-distribution rows for the cell and 2024, PS, q2019 + d)`.
   - Everything else, including `residual_tracked`, is unchanged.

4. **Retire 07** (the tail-sensitivity script)
   - Delete `analysis/07-tail-sensitivity.R` and `tables/sim-tail-sensitivity.csv`.
   - Remove 07 from `analysis/tests/test-regen.sh`, `README.md`, `analysis/README.md`, and any reader in `05-compile-summary.R` (check).
   - Keep the numbering as is.

5. **Explorer** (`analysis/10-export-tool-data.R`, `docs/engine.js`)
   - `10-export-tool-data.R`: read `tables/sim-distribution.csv` and export per cell `qf2019` and `qf2024` = `{pct: [...], score: [...]}` from `quantile_points`, sourced from `mixture.R`. Add the CSV to `sources`.
   - `engine.js`:
     - `makeQuantileFn` gets the same change as R: a spline over the supplied points, with the tail branch removed.
     - `scenario` builds `Q19` and `Q24` from `cell.qf2019` and `cell.qf2024`.
     - The baseline cache key becomes `cell.label + "|2024"`.
     - Update the comments at lines 115-116 and 259-264.

6. **Tests**
   - `analysis/tests/test-sim.R` section 9: keep the knot, calibration, and full-coverage identities. Re-check the pinned inequalities (lines 349, 356) and grid independence (line 369) against the new values; adjust thresholds only with a stated reason.
   - `test-sim.R` new checks:
     - Each histogram sums to 100.
     - The quantile function passes through every histogram point and every published knot.
     - It is monotone on `RANK_GRID`.
     - No corner: left and right slopes at p10, p25, p50, p75, and p90 agree within a small ratio (for example < 1.05), which the old function fails at p90.
     - The histogram-only spline reproduces the published percentiles within 0.15 points (data-consistency check).
   - `analysis/tests/test-api-guards.R`: a cached `DP:DP` fixture parses to contiguous bins that sum to 100, and a truncated histogram is rejected.
   - `analysis/tests/test-tool-engine.mjs`:
     - Section 1 also checks `qf*` in `cells.js` against `sim-distribution.csv`.
     - Section 2 is unchanged; it compares against the regenerated R CSVs.
     - Sections 3 and 4 still hold, because the function passes through the knots.
     - Add a JS "no corner" check.

7. **Regenerate and compare**
   - Run 01, 06 (four cells), and 05, then `10-export-tool-data.R`.
   - Before overwriting, save the current `sim-seat-allocation-*.csv` to the scratchpad and produce an old-versus-new comparison: `gap_remaining` and `res_p90` by rule and budget, and the maximum change per cell. This replaces 07's record of the size of the change and goes in PROGRESS.md and the final summary.
   - Rerun 02 if any figure reads the seat-allocation CSVs (figures 13 and 14). Then `bash analysis/tests/run-all.sh --regen` must pass on the new outputs.

8. **Prose**
   - `docs/methods.html` section 2 (the new construction; cite the NAEP Data Service distribution data), section 8 (add the histogram-reproduces-percentiles check), section 9 (rewrite "Five points"), and the tooltip wording.
   - `docs/index.html` "How the tool works" and technical notes.
   - The outcome-model lines in `README.md` and `analysis/README.md`.
   - `manuscript/simulation-memo.md`: add a dated `==highlighted==` note at the top saying its distributional numbers used the five-point curve and are superseded by `tables/`. Do not rewrite it.
   - `TODO.md`: close PROGRESS item (a); add the follow-up for `group_cdf` and `nat_pct`; note that the memo numbers are stale if it seeds a draft.
   - Run the new prose through `/writing-style`.

9. **Wrap-up.** Browser check of both pages, code-review offer, and final README and PROGRESS agents. Commit only on Andrew's approval.

## Dependencies & Prerequisites

- **NAEP Data Service API**, `DP:DP` statistic (score-bin histograms), for all six cells in 2019 and 2024.
- **R packages already used** by the pipeline; no new packages.
- **node**, for `analysis/tests/test-tool-engine.mjs`.
- **curl**: this machine intercepts TLS, so the scripts shell out to `curl` rather than R's internal downloader.

## Testing Strategy

- New and updated unit checks in `test-sim.R`, `test-api-guards.R`, and `test-tool-engine.mjs` (see step 6): histogram sums, pass-through at every point and knot, monotonicity, a no-corner slope-ratio check in both R and JS, the histogram-only reproduction of the published percentiles, and rejection of a truncated histogram.
- `bash analysis/tests/run-all.sh --regen`: all tests pass, and the only CSV changes are the distributional columns of `sim-seat-allocation-*.csv`, the new `sim-distribution.csv`, and the removal of `sim-tail-sensitivity.csv` (confirmed with `git diff --stat tables/`).
- Rerun of the kink case (Reading G4, 50 percent share, 0.3 SD): the slope of the "with the program" line from p80 to p90 rises smoothly, with no jump like the current 0.24 to 0.55 to 1.26.
- Headless Chrome screenshots of the explorer chart near p90 and of the methods page, at desktop width and 500px.
- The old-versus-new comparison table reviewed with Andrew before any commit.

## Risks & Open Questions

- **Empty bins and `usable()`.** If `usable()` drops rows where `isStatDisplayable` is false, zero-percent bins could vanish and break the contiguity check. This must be confirmed first; zero bins must survive or be restored as 0.
- **Two-year requests possibly failing.** A two-year `ECONDIS` `DP:DP` request returned an empty body. The national (TOTAL) two-year request may behave the same way; if so, `get_distribution` must fall back to one year per call.
- **Pinned test thresholds.** The inequalities at `test-sim.R` lines 349 and 356 and the grid-independence check at line 369 were pinned against the old function. They may need new values; any change needs a stated reason, not a silent loosening.
- **Size of the change to published seat-allocation results.** The distributional results (`gap_remaining`, `res_p90`) will move. How far is unknown until step 7; the old-versus-new comparison makes it visible before anything is committed.
- **Memo numbers going stale.** `manuscript/simulation-memo.md` will carry superseded distributional numbers. The dated note and the TODO entry guard against their reuse in a draft.

## Estimated File Changes

**Created**

- `tables/sim-distribution.csv`
- New `analysis/.cache/*.json` responses (`DP:DP` histograms)

**Modified**

- `analysis/api-helpers.R`
- `analysis/01-simulations.R`
- `analysis/mixture.R`
- `analysis/06-seat-allocation.R`
- `analysis/10-export-tool-data.R`
- `docs/engine.js` (and the regenerated `docs/cells.js`)
- `analysis/config/sim-params.yaml`
- Tests: `analysis/tests/test-sim.R`, `analysis/tests/test-api-guards.R`, `analysis/tests/test-tool-engine.mjs`, `analysis/tests/test-regen.sh`
- Docs pages: `docs/methods.html`, `docs/index.html`
- READMEs: `README.md`, `analysis/README.md`
- `TODO.md`
- `manuscript/simulation-memo.md` (dated note only)
- Regenerated outputs: `tables/sim-seat-allocation-*.csv`, and figures if 02 reads them
- Possibly `analysis/05-compile-summary.R` (if it reads the 07 table)

**Deleted**

- `analysis/07-tail-sensitivity.R`
- `tables/sim-tail-sensitivity.csv`
