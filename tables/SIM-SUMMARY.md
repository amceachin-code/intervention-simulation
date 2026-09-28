# Simulation results: benchmarking the recovery requirement

Rebuilt from an empty cache on 2026-09-28. Public NAEP data only; no restricted-use inputs.
The quantile differences and restoration requirements were computed independently in R
and Stata and agree to 1e-14 across all 30 cell-percentile pairs. The participation
adjustment and the bottom-decile decomposition below have a single implementation, in R.

## 1. Validation: public data reproduces the restricted-use analysis

The differential change (p90 difference minus p10 difference) computed from public
percentiles, against Table 2 column (a) of the manuscript, which was computed from
restricted-use microdata. This is what licenses using public data for the simulations.

| Cell | Public | Table 2(a) | Delta | SE of diff. change |
|---|---|---|---|---|
| Reading G4 | 8.66 | 8.7 | -0.04 | 0.91 |
| Reading G8 | 7.04 | 7.0 | +0.04 | 1.06 |
| Reading G12 | 1.53 | 1.5 | +0.03 | 1.82 |
| Math G4 | 7.88 | 7.9 | -0.02 | 0.73 |
| Math G8 | 6.44 | 6.4 | +0.04 | 1.03 |
| Math G12 | 4.49 | 4.5 | -0.01 | 1.30 |

All six agree to the reported precision. Note Reading G12's 1.53 sits inside its own
SE of 1.82, which supports treating grade 12 separately.

## 2. Observed quantile differences, 2024 minus 2019 (NAEP score points)

| Cell | p10 | p25 | p50 | p75 | p90 | 2019 SD | 2024 SD |
|---|---|---|---|---|---|---|---|
| Reading G4 | -10.0 | -8.3 | -5.6 | -3.2 | -1.3 | 38.5 | 41.2 |
| Reading G8 | -8.9 | -7.2 | -4.9 | -3.2 | -1.9 | 37.8 | 40.2 |
| Reading G12 | -4.2 | -2.8 | -2.2 | -2.6 | -2.7 | 42.3 | 42.9 |
| Math G4 | -8.0 | -5.2 | -2.1 | -0.5 | -0.1 | 31.8 | 34.5 |
| Math G8 | -11.4 | -10.1 | -8.4 | -6.5 | -5.0 | 39.7 | 42.0 |
| Math G12 | -4.8 | -4.9 | -4.2 | -2.9 | -0.3 | 35.6 | 37.0 |

Every quantile fell in every cell. The SD widened in all six, which is independent
evidence of distributional spreading.

## 3. Restoration requirement g*(p), in 2019 national SD units

The effect a fully-covered intervention must deliver at each percentile to restore
its 2019 value. Benchmark: Kraft (2020), 1,942 effects from 747 RCTs, median 0.10,
P75 0.25, P90 0.47.

| Cell | p10 | p25 | p50 | p75 | p90 | p10 sits |
|---|---|---|---|---|---|---|
| Reading G4 | **0.259** | 0.216 | 0.146 | 0.082 | 0.034 | **above P75** |
| Reading G8 | **0.236** | 0.191 | 0.130 | 0.085 | 0.050 | above the median |
| Reading G12 | **0.100** | 0.067 | 0.053 | 0.062 | 0.063 | below the median |
| Math G4 | **0.251** | 0.163 | 0.066 | 0.017 | 0.003 | **above P75** |
| Math G8 | **0.288** | 0.255 | 0.213 | 0.163 | 0.126 | **above P75** |
| Math G12 | **0.135** | 0.139 | 0.118 | 0.081 | 0.009 | above the median |

## 4. Participation-adjusted requirement: what the treated effect must be

Required g = g*(p10) / participation, where participation is the share of a
percentile's students who actually take part. Real programs reach 13-28 percent.

| Cell | Universal (100%) | District HDT (28%) | Opt-in (18.7%) | Summer (13%) |
|---|---|---|---|---|
| Reading G4 | 0.26 | 0.92 | 1.38 | 1.99 |
| Reading G8 | 0.24 | 0.84 | 1.26 | 1.82 |
| Reading G12 | 0.10 | 0.36 | 0.53 | 0.77 |
| Math G4 | 0.25 | 0.90 | 1.34 | 1.93 |
| Math G8 | 0.29 | 1.03 | 1.54 | 2.21 |
| Math G12 | 0.14 | 0.48 | 0.72 | 1.04 |

Nothing in the education literature delivers 1.3 to 2.2 SD. The best-evidenced
at-scale tutoring effect is 0.155 SD, and it is not statistically distinguishable
from zero.

## 4b. The same requirement measured at p25 instead of p10

p25 is arguably the more policy-relevant target: an eligibility screen can plausibly
reach the bottom quartile, whereas no observable screen isolates the bottom decile.
The requirement falls but does not become easy.

| Cell | g*(p10) | g*(p25) | g*(p90) | p25 at c=28% | p25 at c=18.7% |
|---|---|---|---|---|---|
| Reading G4 | 0.259 | **0.216** | 0.034 | 0.77 | 1.15 |
| Reading G8 | 0.236 | **0.191** | 0.050 | 0.68 | 1.02 |
| Reading G12 | 0.100 | **0.067** | 0.063 | 0.24 | 0.36 |
| Math G4 | 0.251 | **0.163** | 0.003 | 0.58 | 0.87 |
| Math G8 | 0.288 | **0.255** | 0.126 | 0.91 | 1.36 |
| Math G12 | 0.135 | **0.139** | 0.009 | 0.50 | 0.74 |

Two things worth noting. Restoring p25 in Reading G4 needs 0.216 SD, still above the
75th percentile of observed education effects, and still 1.15 SD once opt-in take-up
is applied. And Math G12 is the one cell where p25 requires slightly MORE than p10
(0.139 vs 0.135), because its decline is flat across the lower half rather than
concentrated in the bottom tail.

## 5. Share of the p10 deficit closed

| Cell | Program | Universal | District HDT | Opt-in | Summer |
|---|---|---|---|---|---|
| Reading G4 | Tutoring, >=1000 students (0.155) | 60% | 17% | 11% | 8% |
| Reading G4 | Tutoring, 400-999 (0.214) | 83% | 23% | 15% | 11% |
| Reading G4 | Summer, meta-analytic (0.100) | 39% | 11% | 7% | 5% |
| Reading G4 | Summer, realized (0.027) | 10% | 3% | 2% | 1% |
| Math G8 | Tutoring, >=1000 students (0.155) | 54% | 15% | 10% | 7% |
| Math G8 | Tutoring, 400-999 (0.214) | 74% | 21% | 14% | 10% |
| Math G8 | Summer, meta-analytic (0.100) | 35% | 10% | 6% | 5% |
| Math G8 | Summer, realized (0.027) | 9% | 3% | 2% | 1% |

(Featured cells only; the other four are in tables/sim-results.md.)

## 6. Who is in the bottom decile: the targeting screen

Share of students below the 10th percentile who are economically disadvantaged,
against that group's share of the whole population. The gap is the targeting lift.

| Cell | Pop. share 2019 | Bottom decile 2019 | Pop. share 2024 | Bottom decile 2024 | Change |
|---|---|---|---|---|---|
| Reading G4 | 51.0% | **82.8%** | 49.9% | **78.0%** | -4.8 pp |
| Reading G8 | 46.8% | **78.1%** | 47.1% | **75.4%** | -2.7 pp |
| Reading G12 | 39.6% | **61.6%** | 41.4% | **63.2%** | +1.6 pp |
| Math G4 | 50.5% | **82.7%** | 49.6% | **78.4%** | -4.3 pp |
| Math G8 | 46.7% | **77.6%** | 47.0% | **76.3%** | -1.3 pp |
| Math G12 | 40.6% | **68.1%** | 41.7% | **69.6%** | +1.5 pp |

Sensitivity: the bottom-decile share depends on the left-tail model. For Reading G4
2019 it is 82.8% (normal), 80.6% (logistic), 79.2% (exponential), so read these as
roughly 79-83% rather than as point estimates. The 2019-to-2024 changes of 3-5 points
are the same order as that uncertainty; the direction is consistent across grades 4
and 8 in both subjects, which is why it is worth reporting as a pattern.

## 6b. Why p25 is the better target: the population math of take-up

This is the strongest argument for measuring the requirement at p25 rather
than p10, and it is about efficiency of effort, not just a smaller deficit.

A program screened on economic disadvantage covers about half the population.
Of the students it reaches, only some are in the target group, and of the
target group, only some get reached. Both directions matter, and they trade
off differently depending on where the target is drawn.

| Target | ED share of the target | Target as % of population | Share of treated students who are IN the target | Effort landing outside the target |
|---|---|---|---|---|
| bottom 10% | 82.8% | 10% | **16.2%** | 83.8% |
| bottom 25% | 73.4% | 25% | **36.0%** | 64.0% |

(Grade 4 reading, 2019.) At p10, about five of every six treated students sit
outside the target group, because the target is only a tenth of the population
while the screen covers half of it. At p25 that falls to roughly two of three.
The same screen is far less wasteful against the broader target.

There is a reachability constraint pointing the same way. With perfect
targeting, a program with participation c can reach at most
min(1, c/q) of the bottom q. At the observed 18.7 percent opt-in participation rate that
is 100 percent of the bottom decile but only 75 percent of the bottom quartile.
So take-up binds on intensity at p10 and on both intensity and reach at p25 --
but the p10 target is the one where almost all the effort is wasted on
students outside it.

Taken together: p10 is where the deficit is largest, and p25 is where a real
screen can act efficiently. Reporting both, and being explicit that no
observable screen isolates the bottom decile, is more defensible than either
alone.

## 7. What this supports

1. **The recovery task is asymmetric.** Restoring p10 needs 0.26 SD (G4 reading) to
   0.29 SD (G8 math), at or above the 75th percentile of all observed education
   effects. Restoring p90 needs 0.03 to 0.13 SD. It is not one task.
2. **Participation is the binding constraint, not effect size.** At realistic take-up the
   requirement rises to 1.3-2.2 SD, beyond anything ever delivered at scale.
3. **Targeting on economic disadvantage is a decent screen but a blunt instrument.**
   It captures roughly four-fifths of the bottom decile at grades 4 and 8, while
   covering about half the population, so a fixed budget buys half the per-student
   intensity of a program aimed at the bottom decile.
4. **The screen weakened where the decline is worst.** Grades 4 and 8 lost 1-5 points
   of targeting lift between 2019 and 2024; grade 12, where the differential decline
   is small, did not.

## Caveats carried

- Comparing a mean treated effect to a percentile-specific requirement assumes the
  effect transports across the treated distribution (null-gradient assumption). No
  source in the intervention, finance, or teacher-effects literatures provides a
  genuine quantile treatment effect on a test-score distribution.
- Literature effect sizes are standardized on restricted, lower-variance samples,
  so mapping them onto a national NAEP SD is optimistic. No deflation is applied,
  which makes the conclusion conservative.
- The six NAEP scales are not vertically linked; do not compare g* across cells.
- SE[D(p)] treats the two administrations as independent, per NCES convention. The
  shared score scale induces a small positive covariance, so these SEs are slightly
  conservative.
