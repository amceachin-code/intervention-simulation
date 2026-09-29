# TODO

Open items for the intervention-simulation project. Items marked "carried over" come from `../naep-aera-open/TODO.md` (2026-09-04 to 2026-09-11), where this work was RQ3; file names there use the old numbering (05-simulations.R is now 01-simulations.R, and so on through 13 to 09).

## Framing

- [ ] **Decide the paper's framing, target journal, and co-authors.** The memo (`manuscript/simulation-memo.md`) was written for the article's co-authors as RQ3 results. It needs a stand-alone introduction and research questions before it can seed a draft.
- [ ] **Decide how to handle the Table 2(a) validation targets.** They come from the article's restricted-use analysis. If the article is not yet published when this paper circulates, the validation needs a citation plan (cite the article as forthcoming, or report the public-data numbers alone).

## Analysis

- [ ] **Attendance ceiling scenario** (carried over, 2026-09-04). `yaow-etal-2026` supplies the causal counterfactual: returning chronic absence to 2019 levels erases only 3 to 8 percent of the remaining decline (6 to 8 percent in North Carolina, 7 and 3 percent in the urban district; corrected 2026-09-28 against printed p. 20), and eliminating it entirely no more than about 20 percent. Frame the attendance arm as a ceiling ("if absences returned to 2019 levels"), not as an intervention. Their finding that the marginal effect of absences is roughly linear with no threshold at 18 days supports caution about the NAEP past-month absence item.
- [ ] **Scenario arms** (carried over). The methods review suggested cutting to three arms (A0/A1/A3); the A2 taper formula needs an upper clip if that arm survives.
- [x] **Hardcoded parameters duplicate the config** (carried over follow-up; done 2026-09-28). Every R script and `tests/test-sim.R` now reads effect sizes, participation rates, Kraft (2020) percentiles, the treated effect, and Table 2(a) targets from `analysis/config/sim-params.yaml` via `analysis/config-helpers.R`, with no fallback defaults. Outputs were byte-identical before and after. The Stata port keeps its own copies deliberately. Two values moved into the yaml unchanged but still need a source: see the next two items.
- [ ] **Confirm the opt-in tutoring pairing** (carried over follow-up). The "Opt-in tutoring (ITT)" point in `district_requirements_points` (yaml; used by `04-district-requirements.R`) pairs `g = 0.214` (tut_mid) with `c = 0.187` (optin), a combination no single source reports. Confirm with co-authors whether it is intentional.
- [x] **Source the ED population share** (done 2026-09-29). `05-compile-summary.R` section 6b now reads the measured Reading G4 2019 ECONDIS population share (0.5095) from `tables/sim-bottom-decile.csv`; the unsourced `ed_population_share: 0.510` is gone from the yaml. Switching from 0.510 to 0.5095 moves the 6b percentages by about 0.01 point; the larger 2026-09-29 change in 6b comes from the new ED shares.
- [x] **Use score distributions for the ED breakdown and the district cases** (done 2026-09-29). `01-simulations.R` pulls DP:DP by ECONDIS (ED and not ED; one year per request) into `tables/sim-distribution-econdis.csv`. `group_composition` inverts each group's quantile function at the cut; "Information not available" (flagged bins) takes the remainder. `dist-helpers.R` (`group_cdf`) is deleted, and `nat_pct` in `03-district-cases.R` inverts the national quantile function. ED shares of the bottom decile fell 1.4 to 3.6 points in grades 4 and 8 against the old normal-tail method; district-case numbers moved up to about 1 point.
- [x] **Eligibility screen redefined** (done 2026-09-29). Random assignment among ED students: `make_ed_screen` gives participation min(1, B / ED share) times the 2024 ED share at each percentile (`ed_share_points`), and seats beyond the ED share go unused. This closes the review caveat that the screen capped at 100 percent rather than at the ED share. `06-seat-allocation.R` also writes ED / not-ED outcomes (`tables/sim-group-outcomes-<cell>.csv`), and the explorer offers both.
- [ ] **Tilted eligibility screen** (idea, 2026-09-29). A screen that seats ED students but favors the lowest scorers among them. Out of scope for the random screen; would need a rule and a matching R reference.
- [ ] **Seats beyond the ED share** (decision, 2026-09-29). They go unused by default. The alternative, giving them to not-ED students at random, is a one-line change in `make_ed_screen` and `edParticipation`; confirm the default with co-authors.
- [x] **The memo's distributional numbers were stale** (done 2026-09-29). Every post-intervention and screen number in `manuscript/simulation-memo.md` now comes from the committed tables; the tail-sensitivity paragraph is gone, the method text describes the score-distribution quantile functions, and the dated note at the top says what changed. `render-section.sh` now picks the first pandoc on the PATH that runs.
- [x] **Normalize argument conventions** (done 2026-09-29). `04-` and `06-` take `--cell`, like the `--flags` of `01-` and `02-`, and refuse a bare positional cell name.

## Source check (2026-09-28)

Checked against the PDFs for the explorer's methods page (`docs/methods.html`). The page works around each item below; the config itself is unchanged.

- [ ] **Kraft (2020) p25 and p75 are not published.** Table 1 reports deciles only. `kraft2020_effect_percentiles` p25 = 0.00 and p75 = 0.25 look interpolated (P20 -0.01, P30 0.02, P70 0.21, P80 0.30). p10, p50, p90, 1,942 effects, and 747 RCTs are correct. Relabel them as interpolated, or replace them with reported deciles; check which scripts read p25/p75 (`cfg_kraft2020` defaults to p50, p75, p90). The methods page uses only p10, p50, p90.
- [ ] **The 28 percent quote in `requirements_figure_points` is not verbatim.** The paper (printed p. 14) says "Assuming districts target an average of 28% of students for tutoring"; the School Pulse Panel sentence says "among districts offering high-dosage tutoring, approximately 28% of district students participate." Fix the yaml comment.
- [ ] **Carbonari et al. (2025) expert-teacher reach.** The yaml says "32% of eligible, math" and the comment "20-32 percent of eligible students". Math is 26 percent of eligible grades (Table 4) or 32 percent of the analytic sample (Table 7); 20 percent is reading. The paper also says the program "did not target students by performance," which makes the `share_targeted` axis questionable for this point.
- [ ] **Carbonari et al. (2025) tutoring effect.** "About 0.22" fits two of the three effective programs (0.218 math, 0.225 reading); the third is 0.329 (reading small group). The math program had fewer than 30 treated students.
- [ ] **Callen bib entry fixed here; mirror it in the article.** `references.bib` had a broken `callen-etal-2025` placeholder (a notes-file title, no author or year) beside the real `callen-etal-2025-aerj`. The real entry now carries the `callen-etal-2025` key the config uses. Check whether the article's library has the same broken entry.
- [ ] **Confirm `fritsch-carlson-1980`.** Added to `references.bib` for the methods page (SIAM J. Numer. Anal. 17(2), 238-246). Entered from the standard citation, not from a PDF in the library.
- [ ] **`carbonari-etal-2025` year.** The PDF is online-first marked 2026; update the year when it is in an issue.

## Shared data

- [ ] Any correction to `kraft-2023-data/` or `district-enrollment-data/` must be logged here and mirrored in `../naep-aera-open/`.
