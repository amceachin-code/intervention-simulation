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
