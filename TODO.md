# TODO

Open items for the intervention-simulation project. Items marked "carried over" come from `../naep-aera-open/TODO.md` (2026-09-04 to 2026-09-11), where this work was RQ3; file names there use the old numbering (05-simulations.R is now 01-simulations.R, and so on through 13 to 09).

## Framing

- [ ] **Decide the paper's framing, target journal, and co-authors.** The memo (`manuscript/simulation-memo.md`) was written for the article's co-authors as RQ3 results. It needs a stand-alone introduction and research questions before it can seed a draft.
- [ ] **Decide how to handle the Table 2(a) validation targets.** They come from the article's restricted-use analysis. If the article is not yet published when this paper circulates, the validation needs a citation plan (cite the article as forthcoming, or report the public-data numbers alone).

## Analysis

- [ ] **Attendance ceiling scenario** (carried over, 2026-09-04). `yaow-etal-2026` supplies the causal counterfactual: returning chronic absence to 2019 levels erases only 6 to 8 percent of the remaining decline, and eliminating it entirely no more than about 20 percent. Frame the attendance arm as a ceiling ("if absences returned to 2019 levels"), not as an intervention. Their finding that the marginal effect of absences is roughly linear with no threshold at 18 days supports caution about the NAEP past-month absence item.
- [ ] **Scenario arms** (carried over). The methods review suggested cutting to three arms (A0/A1/A3); the A2 taper formula needs an upper clip if that arm survives.
- [x] **Hardcoded parameters duplicate the config** (carried over follow-up; done 2026-09-28). Every R script and `tests/test-sim.R` now reads effect sizes, participation rates, Kraft (2020) percentiles, the treated effect, and Table 2(a) targets from `analysis/config/sim-params.yaml` via `analysis/config-helpers.R`, with no fallback defaults. Outputs were byte-identical before and after. The Stata port keeps its own copies deliberately. Two values moved into the yaml unchanged but still need a source: see the next two items.
- [ ] **Confirm the opt-in tutoring pairing** (carried over follow-up). The "Opt-in tutoring (ITT)" point in `district_requirements_points` (yaml; used by `04-district-requirements.R`) pairs `g = 0.214` (tut_mid) with `c = 0.187` (optin), a combination no single source reports. Confirm with co-authors whether it is intentional.
- [ ] **Source the ED population share.** `ed_population_share: 0.510` (yaml; used in section 6b of `05-compile-summary.R`) was hardcoded as `edpop` without a citation. It matches the Reading G4 2019 ECONDIS population share in `tables/sim-bottom-decile.csv` (0.5095) rounded. Confirm, or compute it from that CSV (which would move the 6b numbers slightly).
- [ ] **Normalize argument conventions.** `04-` and `06-` take a positional cell name; `01-` and `02-` take `--flags`.

## Shared data

- [ ] Any correction to `kraft-2023-data/` or `district-enrollment-data/` must be logged here and mirrored in `../naep-aera-open/`.
