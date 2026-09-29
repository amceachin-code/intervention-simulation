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
- [ ] **Source the ED population share.** `ed_population_share: 0.510` (yaml; used in section 6b of `05-compile-summary.R`) was hardcoded as `edpop` without a citation. It matches the Reading G4 2019 ECONDIS population share in `tables/sim-bottom-decile.csv` (0.5095) rounded. Confirm, or compute it from that CSV (which would move the 6b numbers slightly).
- [ ] **Use score distributions for the ED breakdown and the district cases** (follow-up to the 2026-09-28 histogram change). The national quantile functions now come from NAEP's DP:DP score distribution (`quantile_points` in `analysis/mixture.R`). Two pieces still rebuild distributions from five percentiles with assumed tails: `group_cdf` (`analysis/dist-helpers.R`, the ED breakdown behind `sim-bottom-decile.csv` and the eligibility-screen rule) and `nat_pct` in `03-district-cases.R`. The API returns DP:DP by ECONDIS (checked for Reading G4: all three groups, 50 bins summing to 100, 2019 and 2024; the "information not available" group has some rows flagged 257). Request one year per call: a two-year ECONDIS request returned an empty body.
- [ ] **The memo's distributional numbers are stale.** `manuscript/simulation-memo.md` has a dated note saying so; if the memo seeds a draft, take every post-intervention-distribution number from `tables/sim-seat-allocation-*.csv`. The partial-coverage widening in particular is much smaller than the memo says (Reading G4, half coverage: 0.25 points, not 1.17).
- [ ] **Normalize argument conventions.** `04-` and `06-` take a positional cell name; `01-` and `02-` take `--flags`.

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
