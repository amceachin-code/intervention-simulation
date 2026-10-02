# PROGRESS.md: intervention-simulation

Progress log for the standalone intervention-simulation project. The current
task sits at the top. The history imported from `naep-aera-open` follows it.

---

# CURRENT TASK: EXPLORER LIVE FIXES AND DESIGN PASS (2026-10-02, complete, live)

**Status:** Complete and live on GitHub Pages (main at 772a2eb). Built on
branches `explorer-rounds-view` and `explorer-design-pass`, both pushed.

- **Rounds page published** (bd13986). The live view lost its content for
  returning visitors because browsers kept cached `engine.js` and `style.css`
  (Pages sends `max-age=600`).
- **Asset version tags** (ed43cf8). Every page loads `style.css`, `cells.js`,
  `engine.js`, and `charts.js` with `?v=<tag>`. Section 7 of
  `analysis/tests/test-tool-engine.mjs` checks the tags exist and match.
  `docs/README.md` says when to bump the tag. Current tag: `2026-10-02.4`.
- **Draft banner** (c15265d). "DRAFT - WORK IN PROGRESS" across the top of all
  three pages, with light and dark colors, checked by the same test section.
- **Design review.** No `/design` skill exists, so we used the built-in dataviz
  guidance and its palette validator. The review produced 12 findings; Andrew
  chose 1, 2, 7, and 8 (2972796):
  - `frame()` draws at the container width on narrow screens, and pages
    redraw on resize via `onResize()`.
  - The intro box starts collapsed.
  - On desktop the controls stay in view while the results scroll.
  - Every chart has an aria-label.
  - Stat tiles and summary values use proportional digits.
- **Phone order corrected** (772a2eb). The design pass had put the results
  above the controls on phones. Andrew pointed out the numbers need the
  settings first, so the order is now controls, main chart, tiles, rest.
  The rule is recorded in `tasks/lessons.md`.
- **Checked by Andrew:** desktop and a real phone (over the LAN).
- **Open from the review, not chosen:**
  - 3: ED chart as small multiples or a gap line.
  - 4: replace the flat-line profile charts when tilts are neutral.
  - 5: shorter chip labels.
  - 6: tilt buttons labeled by ratio.
  - 9: phone table overflow cue.
  - 10: rounds-page dumbbell on phones.
  - 11: rounds count as a hero number.
  - 12: light-mode green contrast (acceptable as is).

---

# PREVIOUS TASK: "WHAT WOULD IT TAKE?" EXPLORER VIEW (2026-10-01, complete, live)

**Status:** Complete. All plan steps are done and tested. Work is on branch
`explorer-rounds-view`, cut from `main` because the design snapshot (commit
e80ce1c) exists only on `claude/trusting-davinci-vyejhb`. Nothing is
committed yet and nothing is merged to `main`; Andrew reviews first.

## Objective

Port the B1 "Requirement" design (`design/canvas/B1-Requirement.dc.html`,
described in `design/README.md`) into the explorer in `docs/` as a new
"What would it take?" view, in the explorer's existing plain-HTML style.

- Cell values come from `docs/cells.js`, never hard-coded in the view.
- Add tests for the "rounds" arithmetic to
  `analysis/tests/test-tool-engine.mjs`.
- Update `docs/methods.html` and `docs/README.md` to describe the new view.

## Plan

- [x] 1. Read the design notes (`design/README.md`) and the B1 canvas.
- [x] 2. Study the existing `docs/` explorer structure, `docs/engine.js`,
      and `docs/cells.js`.
- [x] 3. Implement the rounds arithmetic as an engine function.
- [x] 4. Add the new view's markup and JavaScript.
- [x] 5. Add tests for the rounds arithmetic to
      `analysis/tests/test-tool-engine.mjs`.
- [x] 6. Update `docs/methods.html` and `docs/README.md`.
- [x] 7. Run the tests and check the view in the browser.
- [x] 8. Code review pass, then final README and PROGRESS update.

## Step details

- **Step 1 (design).** Read `design/README.md` and
  `design/canvas/B1-Requirement.dc.html`.
- **Step 2 (explorer).** Studied `docs/engine.js`, `docs/cells.js`,
  `docs/charts.js`, `docs/style.css`, `docs/index.html`, and
  `docs/methods.html`.
- **Step 3 (engine).** Added `rounds(cell, knotsPct, c, g)` to
  `docs/engine.js`. `ceilRounds` uses a 1e-9 slack: 0.9/(0.3*0.1) computes
  as 30.000000000000004, which a plain ceil would round up to 31.
  - The fade-out threshold is defined on accumulated gains. With a fraction
    f fading between rounds, the level just after a round tends to c*g/f, so
    p10 recovers only if f <= c*g/g*(p10). B1's wording ("of each round's
    gain") was corrected to match.
- **Step 4 (view).** New `docs/rounds.html` in the explorer's plain-HTML
  style. It contains controls with presets from `cells.js`, the one-round
  waffle, dumbbell, and tiles, a summary card, the round-after-round chart,
  the students-reached strip, a preset matrix, and "Read with care".
  - The page shares the hash keys `cell`, `share`, and `effect` with
    `index.html`.
  - The charts are drawn at their container width (420 to 1100), with
    trimmed in-plot labels on phones.
  - New tokens and rules went into `docs/style.css`, in light and dark.
- **Step 5 (tests).** Added section 6 to
  `analysis/tests/test-tool-engine.mjs` (the suite had 12,574 checks before;
  run it for the current count). The section checks:
  - round counts against g* from `tables/sim-quantiles.csv`, for 6 cells x
    16 preset pairs;
  - one round against `scenario()` in group mode, and k rounds against its
    pure shift;
  - that the gap is invariant;
  - reach counts 1/4/6/8, fresh-draw reach, the rounding edge cases, null at
    zero, and monotonicity.
  Mutation checks confirmed the new tests fail when `perRound`,
  `roundsReach`, or the rounding slack is broken.
- **Step 6 (docs).** `docs/methods.html` has a new section 8 "Rounds of a
  program", passed through `/writing-style`, with a per-cell rounds table.
  Sections 9 to 11 were renumbered. The fade-out limit and the checks
  bullets were revised. `docs/README.md` was updated.
- **Step 7 (verification).**
  - `bash analysis/tests/run-all.sh`: 6 passed, 0 failed.
  - Headless Chrome renders in light, dark, and a true 390px iframe, with
    zero console errors on all three pages and on edge-case hashes. The
    Chrome extension was not connected (account mismatch).
  - A stub-DOM harness rendered 490 slider settings with no NaN, null,
    Infinity, or contradictory wording.
  - Math G8 at 18.7% and 0.155 SD reproduces B1's numbers: 10 rounds, 6 to
    reach everyone, a 108.9-point gap, and matrix row 8/10/16/57.
- **Step 8 (review and wrap-up).** Code review pass with all 23 suggestions
  applied. The harness then found two more wording fixes: small programs
  printing "0.0 rather than 0.0", and near-100% take-up printing "0 in 100
  unserved". README and PROGRESS updated.

## Key decisions

- The view reads every cell value from `docs/cells.js`; no numbers are typed
  into the markup or view script.
- The rounds arithmetic lives in the engine (step 3) so the Node test suite
  can check it without a browser.
- B1's unbacked "about a round longer" line was replaced by a live one-round
  "All students" comparison from `scenario()`.
- The headline, the lede, and the one-round note are now conditional on the
  settings.
- The rounds page keeps the effect slider step at 0.001 so the presets land
  exactly; the explorer's 0.005 step was left alone.
- No merge to `main` before Andrew's review.

## Open items for Andrew

- No R reference exists for more than one round.
- `tables/SIM-SUMMARY.md` section 7.2 and the memo still use the
  per-participant g*/c framing.
- B1 is ported. B2 and C are not.

## Files

- Created: `docs/rounds.html`.
- Modified: `docs/engine.js`, `docs/index.html`, `docs/methods.html`,
  `docs/style.css`, `docs/charts.js`, `docs/README.md`,
  `analysis/tests/test-tool-engine.mjs`, `README.md`, `PROJECTPLAN.md`,
  `PROGRESS.md`.
- Deleted: none.

## Follow-up (2026-10-01): three sections removed at Andrew's request

- **Request.** Andrew asked to remove three sections from
  `docs/rounds.html`: the "Round after round" chart, the "Students reached"
  strip, and the "Rounds to bring the 10th percentile back to 2019" preset
  matrix.
- **Removed from `docs/rounds.html`.** Their markup; `drawRounds`,
  `drawReach`, `drawMatrix`, `roundsFrame`, `chartWidth`, `bucket`, the
  chart-length K logic, the cap and reach notes, and the resize listener.
- **Removed from `docs/style.css`.** Their CSS (matrix, cap-note,
  rounds-h3, rounds-bottom, chart label halos, direct-label light and warn)
  and their colour tokens (`--series-p10`, `--series-p90`, `--warn`, `--m1`
  to `--m5`) from all three theme blocks.
- **Layout.** "Read with care" is now a full-width card (`.care-card`).
- **Kept.** The controls, the one-round card, the summary card, "Read with
  care", and engine `rounds()` with its tests. `rounds90`, `toRestore`, and
  `freshDrawReached` are still exercised by the tests, and
  `freshDrawReached` also feeds a caveat.
- **Methods table, then removed.** The per-cell rounds table in
  `docs/methods.html` section 8 was kept at first and flagged to Andrew. He
  asked for unnecessary methods content to go, so the table and its
  `roundsTable` script were removed. The section 8 prose stays: every
  paragraph explains something still on the page (round counts and reach in
  the summary card, the fade threshold and the "All students" comparison in
  "Read with care"). Methods page renders with zero console errors.
- **Docs.** `README.md` and `docs/README.md` descriptions updated;
  `PROJECTPLAN.md` got a one-line amendment.
- **Verified.**
  - `node analysis/tests/test-tool-engine.mjs`: 13,788 checks, 0 failed.
  - A stub-DOM sweep of 490 settings found no bad wording.
  - Headless Chrome shows zero console errors, and the desktop and 390px
    layouts are clean.
- **Files.** All touched files (`docs/rounds.html`, `docs/style.css`,
  `README.md`, `docs/README.md`, `PROJECTPLAN.md`) were already in the list
  above.

---

# PREVIOUS TASK: ED BREAKDOWN, TWO TODO FIXES, STATA-MCP (2026-09-29, closed)

**Status:** Complete. All plan steps (3, G, A to F, wrap-up, verification,
code review) are done and tested. Nothing is in progress. Next: commit and
push (Andrew asked for it).

Full plan: `/Users/andrewmceachin/.claude/plans/replicated-napping-canyon.md`.

## Objective

Andrew (2026-09-29): the paper venue is undecided. The focus is getting the
explorer tool spun up, then deciding whether it ships as an artifact with the
NAEP AERA Open paper or goes into a new paper. Three asks:

1. Integrate the economic-disadvantage (ED) breakdown, both as a targeting
   rule (seats go only to ED students) and as an outcome group (ED and
   not-ED distributions before and after a program).
2. Fix two items from the "Analysis" list in `TODO.md`: refresh the stale
   distributional numbers in `manuscript/simulation-memo.md`, and give `04-`
   and `06-` the same `--flag` arguments as `01-` and `02-`.
3. Get the stata-mcp server running (it failed this session with
   ECONNREFUSED).

## Plan

- [x] 0. Investigate current ED use, confirm the two TODO items, write and
      get approval for the plan.
- [x] 3. Stata-mcp server restarted and verified (see Step details).
- [x] G. Argument conventions: `04-district-requirements.R` and
      `06-seat-allocation.R` take `--cell "Math G8"`; unknown cells fail with
      the valid list; `test-regen.sh`, `README.md`, `analysis/README.md`,
      `CLAUDE.md` updated.
- [x] A. Data by ED status: `get_distribution(variable=, groups=)`,
      `parse_distribution(group=)`; ECONDIS DP:DP pulled for 6 cells x 2
      years; `tables/sim-distribution-econdis.csv`; `group_composition()`
      uses group quantile functions; `group_cdf` and `dist-helpers.R`
      retired; `nat_pct` in `03-district-cases.R` uses the national 2019
      quantile function.
- [x] B. ED share curve s(p): `ed_share_points()` in `analysis/alloc-rules.R`.
- [x] C. Exact eligibility screen: `make_ed_screen()`, r = min(1, B/pop_ED),
      pi(p) = r x s(p).
- [x] D. ED/not-ED outcomes: `06-seat-allocation.R` writes
      `tables/sim-group-outcomes-<cell>.csv`.
- [x] E. Explorer: `10-export-tool-data.R` exports ED data;
      `docs/engine.js` gets `inputs.rule` and `groupScenario()`;
      `docs/index.html` gets a "Who is eligible" choice and an ED/not-ED
      card; `docs/methods.html` gets screen and group subsections plus
      Checks and Limits updates; `docs/README.md` notes the new input.
- [x] F. Memo refresh (last, after the ED change moves the screen numbers):
      update every post-program number in `manuscript/simulation-memo.md`
      from the regenerated tables, remove tail-sensitivity text, rewrite the
      method and screen text, run `/writing-style`, re-render; mark the stale
      "40/60" and "6.0 vs 2.7" lines in `PROGRESS.md` history as superseded.
- [x] Wrap-up: regenerate `SIM-SUMMARY.md`; close TODO items (including the
      `04-`/`06-` argument item) and log the tilted-screen idea. (Done
      already: `05-compile-summary.R` section 6/6b/7 prose and the `02-`
      fig10 caption are now computed from the table.)
- [x] Verify: `bash analysis/tests/run-all.sh --regen`, Node engine test vs
      R tables, unchanged numbers (D, g*, Table 2(a)) stay byte-identical,
      Stata guard run via stata-mcp, explorer check in Chrome, memo number
      grep and re-render.

## Step details

- **Step 0 (planning).** Done 2026-09-29. Found that ED is used only inside
  the R eligibility-screen rule (`make_ed_curve`, `analysis/alloc-rules.R`),
  fed by `group_cdf` (`analysis/dist-helpers.R`), which still uses a normal
  tail. The screen caps participation at 100 percent rather than at the ED
  share. `docs/` has no ED code.
- **Step 3 (stata-mcp).** Done 2026-09-29. The server is the VS Code
  extension `deepecon.stata-mcp` 0.5.3 (HTTP at
  `localhost:4000/mcp-streamable`). It stopped at 07:09 when VS Code closed.
  Restarted standalone with
  `node ~/.vscode/extensions/deepecon.stata-mcp-0.5.3/src/start-server.js --port 4000 --stata-path /Applications/StataNow --stata-edition mp`,
  then reconnected via `/mcp`; `display c(stata_version)` returned 19.5 MP.
  **Note for future sessions:** if stata-mcp shows ECONNREFUSED, open VS
  Code or run that command, then reconnect with `/mcp`.
- **Step G (arguments).** Done 2026-09-29. `04-` and `06-` take `--cell`.
  A bare positional cell name is refused with a message. `04-` now
  validates the cell. Updated `analysis/tests/test-regen.sh`, `README.md`,
  `analysis/README.md`, `CLAUDE.md`.
- **Step A (data by ED status).** Done 2026-09-29.
  `get_distribution(variable=, groups=)` and `parse_distribution(group=)` in
  `analysis/api-helpers.R`. `01-simulations.R` pulls ECONDIS DP:DP for 6
  cells x 2 years (12 new cache files in `analysis/.cache/`, to be
  committed) and writes `tables/sim-distribution-econdis.csv` (cell, year,
  group, pop_share, bin, lo, hi, pct; ED and not-ED only).
  `group_composition` now takes `gdist` and uses each group's quantile
  function (`quantile_points` with the group percentiles as knots), inverted
  at the cut via the new `quantile_cdf()` in `analysis/mixture.R`.
  "Information not available" gets the remainder of the national cut_pct
  and is checked to lie in [0, its share]. Column `reconstructed_mass`
  renamed `measured_mass`. `analysis/dist-helpers.R` (`group_cdf`) deleted.
  `03-district-cases.R`'s `nat_pct` now inverts the national 2019 quantile
  function (no tails): district case numbers moved by up to about 1 point
  (for example District D p25 32.0 to 30.9; coverage 84% to 80%).
  **Effect:** the ED share of the bottom decile fell 1.4 to 3.6 points in
  grades 4 and 8 compared with the old normal-tail method (Reading G4 2019:
  82.8 to 79.4); p25 shares rose about 1 point.
- **Steps B and C (ED share curve and screen).** Done 2026-09-29.
  `ed_share_points()` and `make_ed_screen()` in `analysis/alloc-rules.R`
  replace `make_ed_curve`. s(p) = pop_ED x pct_ED / pct_TOTAL per bin, placed
  at midpoint national ranks, linearly interpolated, clamped to [0, 1]; it
  averages within 0.0005 of pop_ED in every cell. The screen uses the 2024
  ED share (the program seats 2024 students; the old rule used 2019).
  pi(p) = min(1, B/pop_ED) x s(p); the screen spends min(B, pop_ED).
  Reading G4 screen gap at 100% budget is now 6.3 (was 8.7 via
  water-filling). Non-screen rows of the seat tables are byte-identical.
- **Step D (ED/not-ED outcomes).** Done 2026-09-29. `06-seat-allocation.R`
  writes `tables/sim-group-outcomes-<cell>.csv` (rule, budget, group ED /
  Not ED, p10 to p90 in NAEP points, plus "2019" and "2024, no program"
  reference rows). Group quantile functions are histogram-only. Reading G4
  ED gap (not-ED minus ED) at p10: 34.2 (2019), 31.6 (2024), 25.6 under
  bottom-up at 13%, 30.1 under the screen at 13%.
- **Tests (G to D).** `test-api-guards.R`: 48 pass (6 new: group parsing,
  flagged unrequested group ignored, over-fill stop). `test-sim.R` new
  section 11 (ED share curve, screen spend, r x s(p), two-route
  bottom-decile agreement within 0.002, group outcome invariants). All pass.
  `02-figures.R` fig10 caption and `05-compile-summary.R` section 6/6b/7
  prose are now computed from the table.
- **Step E (explorer).** Done 2026-09-29.
  - `analysis/10-export-tool-data.R` exports per cell `ed` = {pop,
    share{pct, share} (2024, from `ed_share_points`), groups [ED, Not ED]
    with pop2024, qf2019, qf2024 (histogram-only quantile points)}. The
    sources list adds `tables/sim-distribution-econdis.csv`.
  - `docs/engine.js` adds `edParticipation`, `inverseQuantile` (bisection
    to 1e-10), `participationFor` (`inputs.rule` "tilt" or "ed"), and
    `groupScenario` (per-group mixture at the national rank, cached per
    cell).
  - `analysis/tests/test-tool-engine.mjs` now checks the Proportional AND
    Eligibility rows against R, group outcomes against
    `sim-group-outcomes-*.csv` (7,760 values, max diff about 7e-13), ED
    data against the econdis CSV, and screen invariants. 12,574 checks
    pass.
  - `docs/index.html`: step 3 gains "Any student" / "Economically
    disadvantaged only" (the tilt control is greyed out under the screen;
    help text gives the ED share, the share at p10 and p90, and unused
    seats). New card "Economically disadvantaged students and everyone
    else": chart against each group's own 2019 in SD units, direct labels
    at the left end, gap table at p10/p50/p90 in NAEP points, and a note on
    the NSLP definition and the "information not available" share. The
    rule is stored in the URL hash.
  - `docs/style.css`: `--series-ed` (violet #4a3aa7, dark #9085e9) and
    `--series-ned` (aqua #1baf7a, dark #199e70), validated with the dataviz
    palette validator (aqua is under 3:1 on light, so the table carries the
    numbers); `.seg.off`; `.direct-label`.
  - `docs/methods.html`: section 1 mentions ED distributions; section 5
    gains h3 "Seats only for economically disadvantaged students"
    (`#screen`) and "Results for disadvantaged students and everyone else"
    (`#groups`), with numbers filled from `cells.js`; section 8 adds a
    group-results check; section 9 adds "A school-lunch measure of
    disadvantage" and "A random screen".
  - `docs/README.md` updated.
  - Verified with headless Chrome screenshots (the Chrome extension was not
    connected): the page renders with no JS errors. Fixed a label
    collision found in the screenshots.
- **Step F (memo).** Done 2026-09-29. Memo numbers refreshed from
  `tables/sim-seat-allocation-*.csv`,
  `tables/sim-allocation-shares-reading-g4.csv`, and
  `tables/sim-bottom-decile.csv`. The tail-sensitivity paragraph was removed,
  the method text rewritten, and the screen described as random assignment
  among ED students. The dated note at the top was replaced. The memo passed
  through `/writing-style` and was re-rendered (`.rendered.md` and `.docx`).
  `manuscript/render-section.sh` fixed: the Intel pandoc in `/usr/local/bin`
  fails on Apple silicon ("Bad CPU type"), so the script now uses the first
  pandoc 3+ on the PATH that runs.
- **Verification.** Done 2026-09-29. `bash analysis/tests/run-all.sh --regen`:
  7/7 pass, 23 tables byte-identical, no step errors. The Stata port, rerun
  via stata-mcp, reproduces `tables/sim-quantiles-stata.csv` byte for byte
  and agrees with R to 1e-14 (the manifest timestamp change was reverted).
  Explorer checked with headless Chrome (the extension was not connected).
- **Code review.** Done 2026-09-29; Andrew chose "apply all". 35 findings,
  one false (`CLAUDE.md` was already updated). Applied:
  - Stale screen text in the `06-` fig13/fig15 captions; history notes in
    `alloc-rules.R` and `test-sim.R`; the engine `meanPart` comment and page
    provenance line; seat and technical-notes text in `docs/index.html`.
  - `analysis/README.md` arguments and table list.
  - `parse_cell_arg` in `config-helpers.R` (used by `04-` and `06-`); `SLUG`
    in `06-`.
  - `group_quantile_points` and `quantile_rank` in `mixture.R`. The `06-`
    national rank is now a vectorized `approx` on a 0.001 grid instead of
    20k `uniroot` calls; the JS `quantileRank` mirrors it and
    `inverseQuantile` was removed.
  - `ECON_HIST_GROUPS` moved to `api-helpers.R`; `read_fixture` helper in
    `test-api-guards.R`.
  - `01-` fetches ECONDIS stats once per cell, with no `<<-`.
  - `05-` lift/tail arithmetic in one wide table.
  - `ed_population_share` removed from `sim-params.yaml`; `05-` reads the
    measured 0.5095 from `sim-bottom-decile.csv` (TODO item closed).
  - Engine shared caches (`onGrid`, `withoutProgram`), `edShareAt`,
    `edUnknownShare`.
  - Test tolerances tightened to back the methods-page claims (two-route ED
    share < 0.002; JS vs R TOL 1e-9); the `ed_full` test reads pop from the
    data.
  - `api-helpers.R` header documents its `mixture.R` dependency.
  - `render-section.sh` probes the pandoc version and handles spaces in
    paths.
- **Not done from the approved plan.** The exact recombination test (ED +
  not-ED + information-not-available group back to national), because the
  information group's histogram has flagged bins. Group outcomes are checked
  by other invariants instead.
- **Next.** Commit and push (Andrew asked for it).

## Key decisions

- Journal and framing are deferred. The explorer tool is the priority.
- Andrew chose the two "Analysis" TODO items: fix the memo's stale
  distributional numbers, and normalize the `04-`/`06-` arguments.
- ED enters as BOTH a targeting rule and an outcome group.
- The eligibility screen is redefined as random assignment among ED
  students: r = min(1, B/pop_ED), pi(p) = r x s(p). Seats beyond the ED share
  default to unused (alternative: give them to not-ED students at random).
- The ED share curve s(p) comes from ECONDIS DP:DP histograms over the
  national TOTAL histogram. Group 3 ("Information not available") is not
  pulled; its mass is the total minus groups 1 and 2.
- The screen uses the 2024 ED share, because the program seats 2024
  students (the old rule used 2019).
- Group quantile functions for the ED/not-ED outcomes are histogram-only
  (no tails).
- The memo refresh happens last, after the ED change moves the screen
  numbers.

## Files

- **Created:** `tables/sim-distribution-econdis.csv`,
  `tables/sim-group-outcomes-<cell>.csv` (one per `06-` cell), 12 ECONDIS
  cache files in `analysis/.cache/`.
- **Modified (step E):** `analysis/10-export-tool-data.R`,
  `analysis/tests/test-tool-engine.mjs`, `docs/cells.js`, `docs/engine.js`,
  `docs/index.html`, `docs/style.css`, `docs/methods.html`,
  `docs/README.md`.
- **Modified (step F, wrap-up, review):** `analysis/config-helpers.R`,
  `analysis/config/sim-params.yaml`, `analysis/README.md`, `TODO.md`,
  `manuscript/render-section.sh`, `manuscript/simulation-memo.md`,
  `manuscript/simulation-memo.rendered.md`, `docs/README.md`,
  `tables/SIM-SUMMARY.md`, `tables/sim-results.md`,
  `tables/sim-district-cases.md`, `figures/sim/*`.
- **Modified:** `PROGRESS.md`, `README.md`, `CLAUDE.md`,
  `analysis/README.md`, `analysis/api-helpers.R`, `analysis/mixture.R`,
  `analysis/alloc-rules.R`, `analysis/01-simulations.R`,
  `analysis/02-figures.R`, `analysis/03-district-cases.R`,
  `analysis/04-district-requirements.R`, `analysis/05-compile-summary.R`,
  `analysis/06-seat-allocation.R`, `analysis/tests/test-api-guards.R`,
  `analysis/tests/test-sim.R`, `analysis/tests/test-regen.sh`, regenerated
  `tables/` outputs (seat allocation, allocation shares, bottom decile,
  district cases, SIM summary, results, manifest) and `figures/sim/`
  (fig10, fig11, fig13 to fig15).
- **Deleted:** `analysis/dist-helpers.R`.

---

# PREVIOUS TASK: QUANTILE FUNCTIONS FROM THE NAEP SCORE HISTOGRAM (2026-09-28, closed)

**Status:** Steps 0 to 9 complete; verified and reviewed. Being committed and
pushed (Andrew approved updating the GitHub page once the review passed).

## Objective

Remove the kink near the 90th percentile in the explorer's "All students"
curve, and in the R distributional results, by building each national
quantile function from NAEP's DP:DP score histogram (percent of students in
10-point bins) instead of five percentiles plus normal tails. Background: the
old make_quantile_fn joined a normal tail to the spline at p90 with a slope
1.4 to 1.8 times the spline's; the mixture inherits that corner once boosted
students pass the 2024 p90 score (open item (a) of the interactive-tool
task).

## Plan

- [x] 0. Housekeeping: methods page committed and pushed (58525ca); plan,
      progress, and README agents launched.
- [x] 1. Pull and store the histograms (api-helpers.R get_distribution, 01
      writes tables/sim-distribution.csv, scale_max in the yaml, cache
      committed).
- [x] 2. quantile_points() and a tail-free make_quantile_fn in mixture.R.
- [x] 3. 06-seat-allocation.R builds Q2024 from the new points.
- [x] 4. Retire 07-tail-sensitivity.R and its table.
- [x] 5. Explorer: 10 exports qf2019/qf2024 point sets; engine.js uses them.
- [x] 6. Tests (test-sim.R, test-api-guards.R, test-tool-engine.mjs),
      including a no-corner check.
- [x] 7. Regenerate, and compare old versus new seat-allocation results.
- [x] 8. Prose: methods page, index notes, READMEs, memo note, TODO.
- [x] 9. Browser check, code review, final README/PROGRESS, commit on
      approval.

## Step details

- **Step 1.** `get_distribution()` and `parse_distribution()` in
  `api-helpers.R` (one request per year; `expect_rows` = bins + 6 summary
  rows; refuses missing, duplicated, flagged, negative, or mis-summed bins and
  the wrong scale). `scale_max` added to each cell in the yaml. 01 writes
  `tables/sim-distribution.csv` (cell, year, bin, lo, hi, pct). 12 new cached
  responses in `analysis/.cache/`. All 12 cell-years pulled with no dropped
  rows.
- **Step 2.** `quantile_points()` and a tail-free `make_quantile_fn()` in
  `mixture.R`. Every curve passes exactly through all bin points and the five
  percentiles, is monotone, and has left/right slope ratios within 1.033
  anywhere from p1 to p99 (old function: 1.4 to 1.8 at p90). Uncalibrated
  grid error at the knots is 0.008 to 0.012 points (comments say about 0.01).
- **Step 3.** 06 builds Q2024 from `quantile_points`. Old versus new (tables
  saved to the scratchpad before regenerating): only the distributional
  columns moved; `gap_remaining_tracked` unchanged to the last digit. Largest
  changes in `gap_remaining`: Reading G4 0.94 points (Proportional, B=0.39:
  9.83 to 8.89); Reading G8 0.87; Math G4 0.54; Math G8 0.80. Reading G4 at
  B=0.50: Proportional 9.83 to 8.91, Opt-in 13.17 to 12.77, Eligibility 6.68
  to 5.95; bottom-up at B=0.10 5.96 to 5.79; bottom-up at B>=0.13 unchanged
  (2.69). Proportional widening at half coverage fell from 1.17 to 0.25
  points; a closed-form check (0.125 x (delta/SD)^2 x gap) gives about 0.3, so
  most of the old widening was the tail artifact. The finding that partial
  coverage widens the gap survives but is much smaller.
- **Step 4.** `07-tail-sensitivity.R` and `sim-tail-sensitivity.csv` removed;
  `test-regen.sh` and `analysis/README.md` updated.
- **Step 5.** 10 exports `qf2019`/`qf2024` from `quantile_points`;
  `engine.js` uses them; `qnorm`/`pnorm` removed as dead code. JS matches R to
  3.1e-13 points.
- **Step 6.** `test-sim.R` section 9 threshold for the proportional widening
  re-based to between 0.1 and 0.6 points with the closed-form reason; new
  section 10; `test-api-guards.R` section 6; `test-tool-engine.mjs` section 4
  rewritten (3118 checks).
- **Step 7.** 02 and 05 outputs unchanged; fig13 and fig14 (four cells each)
  regenerated. `run-all.sh --regen`: 7 of 7 pass.
- **Step 8.** `methods.html` sections 1, 2, 8, 9 and the `index.html` notes
  rewritten and run through /writing-style; the memo got a dated ==note== (not
  rewritten); the bib title for the NAEP Data Service entry now mentions score
  distributions; `TODO.md` got the ED/nat_pct follow-up and the stale-memo
  warning.
- **Step 9.** Code review found no bugs affecting results; all its
  suggestions were applied (`quantile_points` with no percentiles; the
  histogram-only test now calls `quantile_points` directly; a vacuous bin-edge
  assertion replaced by a comment; the unused `cum_pct` column dropped;
  `dist_n_bins` helper; stale comments). Andrew chose to keep stopping with an
  error, rather than dropping the bin point, if a bin point and a percentile
  are ever out of order; the closest pairs today are 0.05 percentile points
  apart (Math G4 2024 p50; Reading G8 2019 p25).
- **Axis.** At Andrew's request the charts were widened to p1 to p99, then
  returned to p10 to p90 after he found the tails odd. Checked: the tails
  really bend (e.g., Reading G4 drop -0.26 SD at p10 to -0.17 at p1; +0.04 at
  p99), but their standard errors, backed out of the histogram's bin SEs
  (validated against NAEP's published d_se at p10/p50/p90), are 0.04 to 0.07
  SD at p1 and 0.02 to 0.06 at p99, two to four times the median's. Some
  bends are within noise (Math G12 bottom); Reading G4's top bend is about 3
  SE and could be real or an artifact of NAEP's extreme-score estimation. The
  methods page explains the 10 to 90 range under "Thin tails". The no-corner
  test still covers p1 to p99.
- **Closes** open item (a) of the interactive-tool task (the p90 tail kink).

## Key decisions (Andrew, 2026-09-28)

- Anchor the curve to the five published percentiles; the histogram sets the
  shape elsewhere. D(p), g*, Table 2(a), the group estimand, and the Stata
  port are unchanged by design.
- Retire 07-tail-sensitivity.R (no assumed tail remains).
- Scope: national quantile function only. group_cdf (ED breakdown) and 03's
  nat_pct are a follow-up. The API does return DP:DP by ECONDIS (checked for
  Reading G4: three groups, 50 bins, each summing to 100, both years; the
  "information not available" group has some rows flagged 257 / not
  displayable), so the follow-up can use public data.
- Request one year per call: a two-year ECONDIS DP:DP request returned an
  empty body.

## Pre-plan checks (read-only, 2026-09-28)

- DP:DP exists for all 12 cell-years: 50 bins (30 for Math G12, 0 to 300),
  each summing to 100, no mass piled at floor or ceiling.
- A monotone spline through the cumulative bin points reproduces all 60
  published percentiles within 0.11 points (most within 0.05).
  Linear-within-bin was off by up to 0.5.
- Adding the five published percentiles to the histogram points keeps every
  set strictly increasing.

## Files

- **Created:** `tables/sim-distribution.csv`, 12 `analysis/.cache/*.json`,
  `PROJECTPLAN.md`.
- **Modified:** `analysis/api-helpers.R`, `analysis/01-simulations.R`,
  `analysis/mixture.R`, `analysis/06-seat-allocation.R`,
  `analysis/10-export-tool-data.R`, `analysis/config/sim-params.yaml`,
  `analysis/tests/test-sim.R`, `analysis/tests/test-api-guards.R`,
  `analysis/tests/test-tool-engine.mjs`, `analysis/tests/test-regen.sh`,
  `analysis/README.md`, `docs/engine.js`, `docs/charts.js`, `docs/cells.js`,
  `docs/index.html`, `docs/methods.html`, `references/references.bib`,
  `manuscript/simulation-memo.md`, `TODO.md`, `README.md`, `PROGRESS.md`,
  `tables/sim-seat-allocation-*.csv`, `figures/sim/fig13-*`,
  `figures/sim/fig14-*`, run manifests.
- **Deleted:** `analysis/07-tail-sensitivity.R`,
  `tables/sim-tail-sensitivity.csv`.

---

# PREVIOUS TASK: EXPLORER METHODS PAGE (2026-09-28, closed)

**Status:** All steps complete. Committed as 58525ca and pushed to main (live
on GitHub Pages).

## Objective

Add a "Show me the details" button to the explorer (`docs/index.html`) that
links to a new `docs/methods.html`. The methods page explains how each part
of the tool was built:

1. The data.
2. The drop (the 2019-to-2024 decline curve).
3. The effect presets.
4. The participation presets.
5. Who takes part.
6. Who gains most, including the thin evidence on effects by prior
   achievement and the Kraft (2023) comparison of targeted and universal
   programs.
7. The two ways to count (group and distributional views).
8. The checks.
9. The limits.
10. References.

## Plan

- [x] 1. Verify sources from the PDFs.
- [x] 2. Move the shared CSS and chart helpers into `docs/style.css` and
      `docs/charts.js`.
- [x] 3. Add `kraft_target` to `analysis/10-export-tool-data.R` and the Node
      test (`analysis/tests/test-tool-engine.mjs`).
- [x] 4. Write `docs/methods.html` and run it through `/writing-style`.
- [x] 5. Add the button and per-control links to `docs/index.html`.
- [x] 6. Verify, run a code review, and commit and push on Andrew's approval.

## Step details

- **Step 1.** The source-check agent read each PDF (report in the session
  scratchpad; the findings that matter are logged in `TODO.md` under "Source
  check (2026-09-28)").
  - Verified: KSF 2024 Table 5 panel D (0.155 n.s., 58 effect sizes; 0.214,
    75), math and reading pooled; only nine full-sample studies at 1,000+.
    Lynch 2022 0.10 is math only (0.096 all math, 0.101 standardized). 0.027
    summer is per attendee (at least one day), math only, Callen 2025 Table 6;
    Morton 2025 0.024 in 2023. Robinson 2025 18.69 percent take-up; 22.69 vs
    11.64 percent by course grades. Callen 12.7 percent attended; one in four
    targeted students.
  - Problems found: Kraft 2020 Table 1 has deciles only, so config p25/p75
    are interpolated; the narrow-sample argument is in Kraft 2020, not Kraft
    2023; the config's KSF 28 percent quote is not verbatim; the Carbonari
    2025 expert-teacher reach (26 percent of eligible grades or 32 percent of
    the analytic sample, not "20 to 32 percent") and its 0.22 figure; the Yaow
    range is 3 to 8 percent (6 to 8 in North Carolina only; TODO corrected);
    the `callen-etal-2025` bib entry was a broken placeholder.
- **Step 2.** `style.css` and `charts.js` created; `index.html` links them.
  `charts.js` exports `NAEPCharts` (frame, hover, ticks, path, ord, CURVE_P;
  frame marks the five published percentiles by default) and `NAEPShared`
  (formats, CHIP_NAMES, tilt labels, configValue, provenanceText), per the
  code review.
- **Step 3.** The export adds `kraft_target` (grades 4 and 8, all sizes;
  universal, targeted_low, pooled; fields grade, subject, target, studies,
  p50, thin), `kraft2020`, `table2a`, and each preset's `cite`. It errors
  unless there is exactly one row per grade, subject, and target.
  Deterministic on rerun. Test section 5 added; mutation-tested (a tampered
  p50 and a tampered Table 2(a) value each fail). 2117 checks pass.
- **Step 4.** `methods.html` has ten sections. All tables, charts, and config
  numbers come from `cells.js` and `engine.js`; prose numbers from the
  sources sit next to their citations. It uses only Kraft 2020 p10, p50, and
  p90, and cites Kraft 2020 for the narrow-sample point. APA reference list.
  Passed through `/writing-style`.
- **Step 5.** "Show me the details" button beside the lede; small links by
  each control (Data, Sources, How this works) to the matching section; a
  pointer in the "How the tool works" note.
- **Step 6.** Headless Chrome at 1000 to 1300px and 500px (the tables scroll
  inside their own boxes). `bash analysis/tests/run-all.sh --regen`: 7 of 7
  pass, all tables byte-identical. The three run manifests the regen touched
  (timestamp and SHA only) were restored with `git checkout`. A code review
  found no bugs, and Andrew approved all of its suggestions, which were
  applied: shared helpers, shared tilt labels, a single-pass Kraft lookup, the
  neutral hover index found by id, merged CSS rules, updated comments, cite
  moved into the config, unused `k` and `weighted_mean` dropped from the
  export, and the explorer's provenance limited to the files it uses. The
  dark-theme `data-theme` block was kept for a future toggle.

## Key decisions

- The methods page is a separate static page in `docs/`, served by the same
  GitHub Pages site as the explorer.
- Shared styling and chart code move into their own files so both pages use
  one copy.
- `kraft_target` exports the Kraft (2023) all-sizes rows for grades 4 and 8
  (universal, targeted_low, pooled) from
  `tables/kraft-2023-benchmarks-by-target.csv`, so the methods page shows the
  targeted versus universal comparison without hand-typed numbers.
- Preset citations live in the config's `cite` field, next to the numbers.
- The broken `callen-etal-2025` bib entry was replaced by the real AERJ entry
  under that key (the config uses it); `fritsch-carlson-1980` was added.
- Config values flagged by the source check were not changed; they are logged
  in `TODO.md` for Andrew.

## Open items for Andrew

- (a) Done: committed and pushed in 58525ca. The run manifests still record
  784d489; they are refreshed by the histogram task, which regenerates them.
- (b) The `TODO.md` "Source check (2026-09-28)" items: Kraft 2020 p25/p75,
  the KSF quote, the Carbonari reach and effect, the Callen bib mirror in the
  article, confirming `fritsch-carlson-1980`, and the `carbonari-etal-2025`
  year.

## Files

- **Created:** `docs/methods.html`, `docs/style.css`, `docs/charts.js`.
- **Modified:** `docs/index.html`, `docs/cells.js` (regenerated),
  `docs/engine.js` (comment only), `docs/README.md`,
  `analysis/10-export-tool-data.R`, `analysis/tests/test-tool-engine.mjs`,
  `analysis/config/sim-params.yaml` (cite fields and a comment),
  `analysis/README.md`, `references/references.bib`, `TODO.md`, `README.md`,
  `PROGRESS.md`.
- **Deleted:** none.

---

# PREVIOUS TASK: INTERACTIVE HTML MOCKUP TOOL (2026-09-28, closed)

**Status:** all plan steps complete and committed. The explorer was first
committed in 5057e5f, then rewritten in plain language with an introduction
(commit 784d489). It is live at
https://amceachin-code.github.io/intervention-simulation/. The repository is
private at github.com/amceachin-code/intervention-simulation, with GitHub
Pages serving `main:/docs`.

## Objective

Build a simple, static, interactive HTML mockup tool in `docs/` (for GitHub
Pages) that starts from the restoration requirement g\*(p) and lets the user
choose:

1. Effect size.
2. Share treated.
3. Participation-by-prior-achievement gradient (five levels, strong negative
   to strong positive).
4. Effect-by-prior-achievement gradient (same five-level scale).
5. Outcome view: **group** (follow the students who start at p:
   Q(p) + pi(p) delta(p)) or **distributional** (the exact treated/untreated
   mixture, as in `analysis/mixture.R`).

## Plan

- [x] 1. `analysis/10-export-tool-data.R` writes `docs/cells.js` from
      `tables/sim-quantiles.csv` and `analysis/config/sim-params.yaml`.
- [x] 2. `docs/engine.js`: qnorm; monotone Hermite quantile function with
      normal tails (a port of `make_quantile_fn`); water-fill; linear tilt
      w(u) = 1 + k(u - 50)/40 with k in {-0.6, -1/3, 0, 1/3, 0.6}; group and
      mixture quantiles with the calibration offset; summary.
- [x] 3. `docs/index.html`: controls; SVG charts (decline curve, gain,
      remaining requirement; participation and effect profiles); summary
      table; 90-10 gap.
- [x] 4. `docs/README.md`.
- [x] 5. `analysis/tests/test-tool-engine.mjs`, verified against the
      Proportional rule in `tables/sim-seat-allocation-*.csv`; hooked into
      `analysis/tests/run-all.sh`.
- [x] 6. Add step 10 to `analysis/README.md`.
- [x] 7. Browser check, code review, final README and PROGRESS updates.

## Step details

- **Step 1.** `10-export-tool-data.R` drops the unused `sd2024` and
  `diff_change` fields. It records source MD5s instead of a date, so the
  output is deterministic (verified byte-identical on rerun).
- **Step 2.** `engine.js` was verified against R. The spline matches to
  1e-10. qnorm uses Acklam plus a Halley step with West's double-precision
  CDF. The seat-allocation CSVs agree to 1.7e-13 points. After review, the
  engine evaluates the curve and knots in one pass and caches the no-program
  baseline per cell, which cut render time from 30 ms to about 2 ms.
- **Step 3.** At Andrew's request, the main chart shows D(p)/S (negative,
  the decline) rather than g\*(p). The program lifts the curve toward zero,
  and above zero means above the 2019 level. The table and tiles use the same
  sign. The URL hash stores settings, clamped, with unknown keys ignored.
  Parameters have no hand-typed fallbacks. The 90-10 verdict covers every
  case.
- **Step 5.** `test-tool-engine.mjs` has 2061 checks, including qnorm
  against R and the knots. `run-all.sh` runs `*.mjs` tests when node exists
  and uses nullglob. All 6 tests pass.
- **Step 7.** Headless Chrome screenshots at desktop width and a 500px
  viewport (the headless minimum) show no overflow. The Chrome extension was
  not connected, so a true 390px check was not done. A code review was run
  and all findings were applied.

## Key decisions

- Input 5 is the group versus distributional choice.
- Gradients are a linear tilt with the mean held fixed, so the gradient
  reshapes who is treated (or how much they gain) without changing the
  overall share treated or the average effect.
- The effect input is the population-average treated effect, in 2019 SD
  units.
- The main chart plots D(p)/S (the decline, negative) rather than g\*(p), per
  Andrew.
- Hosting is GitHub Pages from a new repository that Andrew will create.

## Open items for Andrew

- (a) Done 2026-09-28 (quantile functions now come from the score distribution; see the histogram task). Was: `make_quantile_fn`'s normal tail meets the spline at p90 (and p10)
  with a slope about twice the spline's end slope, so the implied density
  halves at the knot. The mixture carries that kink into the curve near p85
  to p90, and the committed R p90 results include it. Worth a methods look
  alongside `07-tail-sensitivity`.
- (b) Done: the repository is github.com/amceachin-code/intervention-simulation
  (private), with Pages serving `main:/docs`.
- (c) Done: committed in 5057e5f and 784d489.

## Files

- **Created:** `analysis/10-export-tool-data.R`,
  `analysis/tests/test-tool-engine.mjs`, `docs/index.html`,
  `docs/engine.js`, `docs/cells.js`, `docs/README.md`.
- **Modified:** `analysis/tests/run-all.sh`, `analysis/README.md`,
  `README.md`, `PROGRESS.md`.
- **Deleted:** none.

---

# EARLIER TASK: MOVE THE SIMULATIONS OUT OF NAEP-AERA-OPEN (2026-09-28, closed)

**Status:** all plan steps complete. The review-fix changes from step 9 are
applied but uncommitted; committing them is Andrew's call.

## Objective

Spin the simulation analysis (formerly RQ3 of
`/Users/andrewmceachin/projects/naep-aera-open`) out into this standalone
project, with full project scope and no tie to the article. The article's
current RQ3 is a narrative section and no longer uses the simulations. The
simulation code, outputs, memo, and scope now belong here.

Source commit in `naep-aera-open`: `f644941`.

## Plan

- [x] 0. Launch the README and PROGRESS background agents.
- [x] 1. Scaffold folders.
- [x] 2. Copy files: simulation scripts, helpers, the Stata port, the params
      yaml, tests, design docs, the memo (working-tree version, including
      uncommitted edits), and the NAEP API caches; plus `kraft-2023-data/`
      (279M) and `district-enrollment-data/` (1.3G) whole, and scripts 12 and
      13, `kraft-helpers.R`, and their tests.
- [x] 3. Rename `rq3-*` to `sim-*`, renumber scripts 05 to 13 as 01 to 09, and
      repoint every path. RQ3 wording reworded throughout.
- [x] 4. Project docs: `CLAUDE.md`, `README.md`, `TODO.md`,
      `analysis/README.md`, `tasks/lessons.md`, `manuscript/ai-use-log.md`,
      `.gitignore`.
- [x] 5. References: `references/references.bib` (a 14-key subset),
      `references/apa.csl`, and `manuscript/render-section.sh` repointed.
- [x] 6. Regenerate all outputs and verify them (details below).
- [x] 7. `git init` and commits (details below).
- [x] 8. Clean up `naep-aera-open`: simulation-only files `git rm`'d (left
      uncommitted there), `test-rq3.R` trimmed, docs updated.
- [x] 9. `/datascience-reviewer` passes on both projects; review fixes
      applied here (uncommitted; details below).
- [x] 10. Final README and PROGRESS agents; code-review offer.

## Step details

### Step 6: regeneration and verification

- Every CSV and the `.rds` in `tables/` came out byte-identical to the
  article's originals.
- The Stata port reproduced Table 2(a), and its CSV was byte-identical.
- The memo rendered with every image resolving.
- All tests passed.
- Markdown output diffs were the renames plus two wording changes that were
  already in the article's scripts but had never been regenerated there.

### Step 7: commits

- `0f70131`: the spin-out.
- `30d0343`: records the initial commit SHA in the run manifests.
- `d8033df`: Table 2(a) references now name "the companion AERA Open
  article"; fig9 caption regenerated; `SIM-SUMMARY.md` no longer claims an
  empty-cache rebuild; render-script examples and data SUMMARY copy notes
  fixed.
- `84d1602`: refreshes the manifest SHA.

### Step 9: reviewer passes and fixes

The reviewer found that the move broke nothing. Its verdict was "not yet
satisfied" on issues that predate the move. Andrew approved all suggestions.
Applied here, uncommitted:

- The NAEP API caches (`analysis/.cache/`, `analysis/.cache-stata/`) are now
  tracked in git.
- New `analysis/config-helpers.R`. Every R script reads
  `analysis/config/sim-params.yaml` through it, with no fallback values.
  New yaml keys: `treated_effect`, `district_requirements_points`,
  `requirements_figure_points`, `ed_population_share`. `optin_takeup` was
  deleted because the `GEOM_*` constants differ from it. The `years` key is
  now wired into 01.
- New `analysis/api-helpers.R`, extracted from `01-simulations.R`.
- New tests: `analysis/tests/test-api-guards.R` (33 checks, mutation-tested),
  `analysis/tests/test-regen.sh`, and `analysis/tests/run-all.sh`.
- Manifests now record package versions; the dirty-tree check is widened.
- `file.exists` guards added in 03, 04, 05, and 07; 07 now sources
  `alloc-rules.R`; stale comments fixed.

Verified after the fixes: all CSV, `.rds`, and `.md` outputs byte-identical;
`bash analysis/tests/run-all.sh --regen` passes 6 of 6; a parameter change was
shown to propagate through the outputs and then reverted.

**Not done, by choice:** `06-seat-allocation.R` still hardcodes
`B0 <- 0.13`, and the prose "0.155 SD" in `03-district-cases.R` is still
hardcoded. Only 01 takes `--config`.

## Next steps

1. Commit the review-fix changes (Andrew's decision).
2. Rerun 01, 08, and 09 so the manifests record a clean SHA, and commit.
3. Open `TODO.md` items: framing; the Table 2(a) citation plan; the
   attendance ceiling; scenario arms; opt-in pairing; the source for the ED
   share; argument conventions.

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
- **The memo stays a historical co-author memo**, with a provenance header,
  rather than being rewritten as a paper draft.

## Files

**Copied from `naep-aera-open`, renamed and renumbered:**

- `analysis/01-simulations.R` to `analysis/07-tail-sensitivity.R` (old 05 to
  11)
- `analysis/08-district-enrollment.R`, `analysis/09-kraft-benchmarks.R` (old
  12, 13)
- `analysis/alloc-rules.R`, `analysis/mixture.R`, `analysis/dist-helpers.R`,
  `analysis/kraft-helpers.R`
- `analysis/stata/01_simulations.do` (Stata port)
- `analysis/config/sim-params.yaml`
- `analysis/tests/test-sim.R`, `test-kraft-benchmarks.R`,
  `test-kraft-target.R`, `test-district-enrollment.R`
- `analysis/design-public-data.md`, `analysis/appendix-district-variation.md`
- `manuscript/simulation-memo.md` (was `manuscript/RQ3-memo.md`), with its
  rendered `.rendered.md` and `.docx`, and `manuscript/reference.docx`
- `analysis/.cache/`, `analysis/.cache-stata/` (NAEP API caches, now tracked)
- `kraft-2023-data/`, `district-enrollment-data/` (whole)

**Regenerated outputs:** `tables/sim-*`, `tables/SIM-SUMMARY.md`,
`tables/kraft-2023-benchmarks-*`, `tables/district-enrollment-2324-*`,
`figures/sim/`, `figures/kraft/`, `figures/district-enrollment/`.

**Created in the spin-out:** `CLAUDE.md`, `README.md`, `TODO.md`,
`PROGRESS.md`, `analysis/README.md`, `tasks/lessons.md`,
`manuscript/ai-use-log.md`, `manuscript/render-section.sh`, `.gitignore`,
`references/references.bib`, `references/apa.csl`.

**Created in the step 9 fixes (uncommitted):** `analysis/config-helpers.R`,
`analysis/api-helpers.R`, `analysis/tests/test-api-guards.R`,
`analysis/tests/test-regen.sh`, `analysis/tests/run-all.sh`.

**Modified in the step 9 fixes (uncommitted):** `.gitignore`, `CLAUDE.md`,
`TODO.md`, `analysis/README.md`, scripts 01 to 09, `analysis/alloc-rules.R`,
`analysis/config/sim-params.yaml`, `analysis/stata/01_simulations.do`,
`analysis/tests/test-sim.R`, and the three manifests
(`tables/sim-manifest.txt`, `tables/kraft-2023-benchmarks-manifest.txt`,
`tables/district-enrollment-2324-manifest.txt`).

**Deleted from `naep-aera-open` (step 8, `git rm`'d, uncommitted there):**
scripts 06 to 11, `analysis/alloc-rules.R`, `analysis/mixture.R`,
`analysis/stata/`, the RQ3 design notes, `manuscript/RQ3-memo.md`,
`figures/rq3/`, and the simulation-only tables. `test-rq3.R` there was trimmed
rather than deleted.

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
     gradient (superseded 2026-09-29: about 6/94 after the score-distribution
     rebuild).
  3. Bottom-up needs its budget to overshoot the target percentile: 6.0 at a
     10 percent budget versus 2.7 at 13 percent (superseded 2026-09-29: 5.8
     versus 2.7 after the score-distribution rebuild).
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
