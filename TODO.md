# TODO

Open items for the intervention-simulation project. Items marked "carried over" come from `../naep-aera-open/TODO.md` (2026-09-04 to 2026-09-11), where this work was RQ3; file names there use the old numbering (05-simulations.R is now 01-simulations.R, and so on through 13 to 09).

## Framing

- [ ] **Decide the paper's framing, target journal, and co-authors.** The memo (`manuscript/simulation-memo.md`) was written for the article's co-authors as RQ3 results. It needs a stand-alone introduction and research questions before it can seed a draft.
- [ ] **Decide how to handle the Table 2(a) validation targets.** They come from the article's restricted-use analysis. If the article is not yet published when this paper circulates, the validation needs a citation plan (cite the article as forthcoming, or report the public-data numbers alone).

## Analysis

- [ ] **Attendance ceiling scenario** (carried over, 2026-09-04). `yaow-etal-2026` supplies the causal counterfactual: returning chronic absence to 2019 levels erases only 6 to 8 percent of the remaining decline, and eliminating it entirely no more than about 20 percent. Frame the attendance arm as a ceiling ("if absences returned to 2019 levels"), not as an intervention. Their finding that the marginal effect of absences is roughly linear with no threshold at 18 days supports caution about the NAEP past-month absence item.
- [ ] **Scenario arms** (carried over). The methods review suggested cutting to three arms (A0/A1/A3); the A2 taper formula needs an upper clip if that arm survives.
- [ ] **Hardcoded parameters duplicate the config** (carried over follow-up). `05-compile-summary.R` and several other scripts hardcode benchmarks, participation rates, and an unsourced `edpop <- 0.510` instead of reading `analysis/config/sim-params.yaml`. Real drift risk if a parameter is revised.
- [ ] **Confirm the opt-in tutoring pairing** (carried over follow-up). `04-district-requirements.R` has its own `benchmarks` tribble with an "Opt-in tutoring (ITT)" row pairing `g = 0.214` with `c = 0.187`, a combination not in the config. Confirm with co-authors whether it is intentional.
- [ ] **Normalize argument conventions.** `04-` and `06-` take a positional cell name; `01-` and `02-` take `--flags`.

## Shared data

- [ ] Any correction to `kraft-2023-data/` or `district-enrollment-data/` must be logged here and mirrored in `../naep-aera-open/`.
