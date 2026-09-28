# PROGRESS.md: intervention-simulation

Progress log for the standalone intervention-simulation project. The current
task sits at the top. The history imported from `naep-aera-open` follows it.

---

# CURRENT TASK: MOVE THE SIMULATIONS OUT OF NAEP-AERA-OPEN (2026-09-28)

**Status:** in progress. Step 2 (copy files) is under way.

## Objective

Move the RQ3 simulation analysis out of
`/Users/andrewmceachin/projects/naep-aera-open` into this standalone project,
with full project scope and no tie to the article. The article's current RQ3
is a narrative section and no longer uses the simulations. The simulation
code, outputs, memo, and scope now belong here.

Source commit in `naep-aera-open`: `f644941`.

## Plan

- [x] 0. Launch the README and PROGRESS background agents.
- [x] 1. Scaffold folders.
- [ ] 2. Copy files: simulation scripts 05 to 11, helpers, the Stata port, the
      params yaml, tests, design docs, the memo, and the NAEP API cache; plus
      `kraft-2023-data/` and `district-enrollment-data/` whole, and scripts
      12 and 13, `kraft-helpers.R`, and their tests. **(in progress)**
- [ ] 3. Rename `rq3-*` to `sim-*`, renumber scripts 05 to 13 as 01 to 09, and
      repoint every path.
- [ ] 4. Project docs: `CLAUDE.md`, `README.md`, `TODO.md`,
      `analysis/README.md`, `tasks/lessons.md`, `manuscript/ai-use-log.md`,
      `.gitignore`.
- [ ] 5. References: a subset `.bib`, `apa.csl`, and the render script.
- [ ] 6. Regenerate all outputs; verify they are byte-identical to the
      originals; run the tests; render the memo.
- [ ] 7. `git init` and an initial commit.
- [ ] 8. Clean up `naep-aera-open`: `git rm` the simulation-only files (left
      uncommitted), trim `test-rq3.R`, and update its docs.
- [ ] 9. `/datascience-reviewer` passes on both projects.
- [ ] 10. Final README and PROGRESS agents; offer a code review.

## Key decisions

- **The g\*(p) code is shared.** Script 05 (now 01), `dist-helpers.R`, and
  `rq3-params.yaml` (now `sim-params.yaml`), plus their outputs, are copied to
  both projects. Article scripts 13, 19, and 20 read
  `tables/rq3-quantiles.csv`, so the article keeps its own copy.
- **Kraft (2023) and CCD data are copied to both projects.** They are shared
  copies, so a fix in one must be mirrored in the other.
- **Simulation-only files are removed from the article** (step 8).
- **Naming:** `sim-*` replaces `rq3-*`, since the work is no longer tied to a
  research question in the article.

## Files (planned)

**Copied from `naep-aera-open`, renamed and renumbered:**

- `analysis/01-simulations.R` to `analysis/07-tail-sensitivity.R` (old 05 to 11)
- `analysis/08-district-enrollment.R`, `analysis/09-kraft-benchmarks.R` (old
  12, 13)
- `analysis/alloc-rules.R`, `analysis/mixture.R`, `analysis/dist-helpers.R`,
  `analysis/kraft-helpers.R`
- `analysis/stata/` (Stata port)
- `analysis/config/sim-params.yaml`
- `analysis/tests/test-sim.R` and the Kraft and district tests
- `analysis/design-public-data.md`, `analysis/appendix-district-variation.md`
- `manuscript/simulation-memo.md` (was `manuscript/RQ3-memo.md`)
- The NAEP API cache
- `kraft-2023-data/`, `district-enrollment-data/` (whole)
- `tables/sim-*`, `figures/sim/` (regenerated in step 6)

**Created:** `CLAUDE.md`, `README.md`, `TODO.md`, `analysis/README.md`,
`tasks/lessons.md`, `manuscript/ai-use-log.md`, `.gitignore`, a references
subset `.bib`, `apa.csl`, `manuscript/render-section.sh`, `PROGRESS.md`.

**Removed from `naep-aera-open` (step 8):** the simulation-only scripts,
helpers, tests, memo, and outputs. `test-rq3.R` there is trimmed rather than
deleted.

---

# IMPORTED HISTORY (from naep-aera-open PROGRESS.md)

Condensed from `naep-aera-open/PROGRESS.md` (phases 1 to 3, 2026-09-11, and
the 2026-09-18 redirect). **File names in that log use the old names.** They
map to this project as follows:

| Old (naep-aera-open) | New (this project) |
|---|---|
| `analysis/05-*.R` to `analysis/13-*.R` | `analysis/01-*.R` to `analysis/09-*.R` (05->01, 06->02, 07->03, 08->04, 09->05, 10->06, 11->07, 12->08, 13->09) |
| `10-seat-allocation.R`, `06-figures.R`, `09-compile-summary.R` | `06-seat-allocation.R`, `02-figures.R`, `05-compile-summary.R` |
| `rq3-params.yaml` | `sim-params.yaml` |
| `tables/rq3-*` | `tables/sim-*` |
| `figures/rq3/` | `figures/sim/` |
| `manuscript/RQ3-memo.md` | `manuscript/simulation-memo.md` |
| `analysis/tests/test-rq3.R` | `analysis/tests/test-sim.R` |
| `analysis/RQ3-public-data-design.md` | `analysis/design-public-data.md` |

## Phase 1: seat-allocation bugs (2026-09-11, closed)

- **`alloc_optin()` returned participation above 100 percent.** The rescaled
  take-up line had no cap and crossed 1 above a budget of 75.6 percent. A
  reflected-triangle fix was applied, then replaced by water-filling.
- **`alloc_screen()` clipped with `pmin(1, ...)` and under-spent** (84.4
  percent of budget at B = 1). It now water-fills, so every rule spends the
  same seats.
- **Standing correctness test:** at a full budget every rule returns the
  no-program baseline (8.7 Reading G4, 6.4 Math G8). Any rule change must pass
  it.
- **Take-up anchoring corrected.** The Robinson, Bisht, and Loeb (2025) group
  means (11.64 percent D/F, 22.69 percent passing) belong at rank centroids 50
  points apart, not at p0 and p100. That doubles the slope. The shape became
  flat below p25, linear to p75, flat above, which broke the triangle's
  geometry and forced water-filling.
- **Feasibility ceiling added to the memo.** Under random assignment at rate
  pi, the post-program p-th percentile can rise no higher than the
  pre-program (p/(1 - pi))-th. Restoring Reading G4 p10 at 13 to 28 percent
  participation is impossible at any effect size.
- **Refactor:** rules moved to `alloc-rules.R` so tests can load them;
  production numbers byte-identical. `FILL_GRID` changed to bin midpoints;
  `ed_curve` now errors rather than silently degrading; input validation
  added; `gap_remaining` column added.

## Phase 2: rank-preserving mixture rebuild (2026-09-11, closed)

- **Problem:** `residual()` used `Q_after(p) = Q_before(p) + pi(p) * delta`,
  a partial-dose shortcut. Real programs give the full effect to some students
  and nothing to others, so the outcome is a two-component mixture, which
  spreads the distribution.
- **Built `analysis/mixture.R`:** `RANK_GRID`, `make_quantile_fn()`
  (monotone interpolation with normal tails), `weighted_quantile()` (midpoint
  convention, drops atoms under 1e-12), `program_quantiles()` (the exact
  large-population mixture), and `calibrated_program_quantiles()` (anchors a
  zero budget to the published percentiles, removing a 0.008-point grid
  artifact).
- **Three findings:**
  1. Partial coverage widens the 90-10 gap whoever gets the seats. The
     proportional curve, not the no-program line, is the bar a targeted rule
     must clear.
  2. Opt-in widening splits roughly 40/60 between the mixture and the take-up
     gradient.
  3. Bottom-up needs its budget to overshoot the target percentile: 6.0 at a
     10 percent budget versus 2.7 at 13 percent.
- **New stated assumptions:** no selection on gains within a percentile;
  large population (no Monte Carlo term).
- Tests grew to 75 to 76 assertions, including grid independence and a guard
  against regression to the linear model. Memo method, results, captions, and
  caveats rewritten and re-rendered.

## Phase 3: observed opt-in rule removed (2026-09-11, closed)

- At Andrew's request the "Opt-in gradient (observed)" rule was removed from
  the memo, `alloc-rules.R` (`alloc_optin`, `optin_line`, `optin_mean`,
  `OPTIN_*`), the seat-allocation script, and the tests. The geometric
  variant is now the only opt-in rule, named plain "Opt-in gradient".
  Identifiers `alloc_optin_geom` and `geomtakeup_line` were kept (renaming
  the latter risks masking `ggplot2::geom_line`).
- Kept deliberately: the scalar "18.7 percent (observed opt-in take-up)"
  participation scenario in memo section 2.
- Regenerated seat-allocation and allocation-share tables and figures 13 to 15
  for all four cells; memo re-rendered. Suite at 76 checks, all passing.
  A post-task review fixed six documentation issues.

## Open items carried from the review passes

- No uncertainty is propagated; `g_star_se` is unused and G = 0.155 is not
  significant.
- The eligibility screen caps at 100 percent, not at the ED share.
- `ed_curve` treats cumulative subgroup shares as pointwise and invents its
  p50 and p90 anchors.
- g(p) uses the unadjusted decline, though RQ1 shows about a quarter is
  compositional.
- The compile-summary script (old 09, now 05) hand-types numbers.
- The design doc (old lines 28 and 96) still claims the mixture problem
  "disappears" and that step functions are inadmissible; both need rewriting.
- A few UK spellings remain in comments.

## Kraft benchmarks and the redirect (2026-09-18, closed)

- Added the Kraft benchmarks script (old 13, now `09-kraft-benchmarks.R`):
  replicates Kraft (2023) Table 1 by grade, subject, and study size (251 to
  500, 501 to 2,000, more than 2,000), refusing to run unless the overall
  percentiles reproduce. Outputs
  `tables/kraft-2023-benchmarks-by-grade-size.csv`, a manifest, and
  `figures/kraft/fig-k1-benchmarks-by-size.png`, with the g\*(p10)
  requirement drawn from the quantiles table. 11 tests pass.
- Grade 4 medians fall with study size (reading 0.12 / 0.08 / 0.02; math
  0.13 / 0.06 / 0.01). Grade 8 math, 251 to 500, is thin (six studies).
- **Decision (Andrew, 2026-09-18):** the simulations (seat allocation,
  mixture, district cases, the memo) move to a separate second paper. The
  article's RQ3 became a narrative built on the Kraft benchmarks, the CCD K-5
  district distribution, and cited studies. That decision is what this
  project now carries out.
