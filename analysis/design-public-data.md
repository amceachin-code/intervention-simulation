# Intervention simulations without restricted-use data: revised design

<!-- Written 2026-09-04 as the design for RQ3 of the naep-aera-open article; references to "the manuscript", "the paper", and Table 2 mean that article. Moved here 2026-09-28. -->

<!-- draft v1, 2026-09-04; decision: run the simulations from public NAEP percentiles plus the already-computed reweighted curves, not from student-level microdata -->

## The decision

The simulation analysis is built entirely from **public NAEP percentile data plus results already reported in the manuscript**. No restricted-use microdata, no plausible values, no student records. This removes the licensed-machine dependency and makes the section fully reproducible by any reader, which is worth saying explicitly in the paper.

## Why this works

The requirements analysis operates on **quantiles**, not students. Its inputs are:

| Input | Source | Status |
|---|---|---|
| Q2019(p), Q2024(p) at p = 10, 25, 50, 75, 90 | NAEP Data Service API (public) | retrievable |
| D(p) = Q2024(p) − Q2019(p) | derived | derived |
| Standard errors on each quantile | NAEP Data Service API | to confirm |
| National 2019 SD per grade-subject | API or NAEP technical documentation | to confirm |
| Reweighted QD curves (composition; composition + absences) | **manuscript Figures 5-7 and Table 2, already computed** | in hand |
| Take-up / coverage by achievement level | published literature | in hand |

The one input that genuinely required microdata was covariate-based eligibility assignment (assigning treatment on SLUNCH1/IEP/LEP). That is dropped; see "What changes" below.

## What changes relative to the microdata design

**Dropped: student-level simulation on plausible values.** The earlier design argued that shifting quantiles directly is incoherent for non-monotone transformations, because ranks cross. That argument still holds, and the fix here is different: **do not apply non-monotone shifts at all.** Every scenario is specified as a monotone increasing transformation of the score scale, under which quantiles are equivariant and Q̃(p) = Q(p) + τ(Q(p)) holds exactly. This is a restriction on the scenario space, not an approximation, and it should be stated as such.

Practically this means a targeted scenario is defined as a gain that is a smooth, non-increasing function of the *score*, with slope bounded so that x + τ(x) stays increasing (Lipschitz constant < 1). A step function at a percentile cut is not admissible and is not used.

**Dropped: covariate-based eligibility and the targeting confusion matrix.** Cannot be done without microdata. Replaced by coverage specified as a function of position in the score distribution, taken from the literature rather than from NAEP.

**Kept and strengthened: the requirements framing.** g*(p) = −D(p)/S, and the coverage-adjusted condition c·g ≥ g*(p). Public percentiles give D(p) directly.

**Kept: the reweighted curves as reference lines**, read from the manuscript's existing figures and Table 2. Note these came from the restricted-use analysis, so the *paper* still rests on microdata; only this analysis (then the article.s RQ3 section) is publicly reproducible.

## The central result (grade 4 reading, S ≈ 36.2, ==confirm S==)

Restoration requirement by percentile:

| p | D(p), points | g*(p), SD | vs Kraft (2020) benchmarks |
|---|---|---|---|
| 10 | −10.0 | **0.276** | above the 0.20 "large" threshold |
| 25 | ==TBD== | ==TBD== | |
| 50 | −6.0 | 0.166 | medium |
| 75 | ==TBD== | ==TBD== | |
| 90 | −1.0 | 0.028 | below "small" |

Participation-adjusted requirement to restore the 10th percentile:

| Coverage c | Required treated effect g | Comparison |
|---|---|---|
| 1.00 (universal, full) | 0.276 SD | above "large"; above tutoring at scale (0.155) |
| 0.28 (district HDT participation) | 0.986 SD | exceeds any observed program |
| 0.187 (observed opt-in take-up) | 1.476 SD | exceeds any observed program |
| 0.13 (summer program reach) | 2.123 SD | exceeds any observed program |
| 0.02 (effective tutoring at scale) | 13.80 SD | not a real quantity |

*(Arithmetic shown once: 10/36.2 = 0.276; 0.276/0.187 = 1.476.)*

**This is the finding.** It is arithmetic applied to public data plus literature effect sizes, and it is not circular: the numerator is measured, the denominators are observed program parameters. The point is not that any particular program fails, but that the required magnitude at the bottom is outside the range education interventions have ever delivered at scale, and that realistic coverage makes the requirement worse by a factor of 5 to 10.

## Scenario arms (all monotone, all public-data)

| Arm | Specification | Anchor |
|---|---|---|
| A0 Uniform benchmark | τ(x) = c, constant | none needed; stated as arithmetic, Δ unchanged by construction |
| A1 Universal, full participation | τ(x) = g·S for all x | Kraft/Schueler/Falken 0.155 SD at 1,000+ students |
| A2 Bottom-weighted, monotone taper | τ(x) = g·S·max(0, 1 − (x − x₀)/w), slope bounded | shape assumed; **sensitivity parameter, not a finding** |
| A3 Opt-in as universal | expected gain = c(x)·g·S with c rising in x (0.116 → 0.227) | Robinson, Bisht & Loeb (2025) |
| A4 Attendance ceiling | scale D(p) by the share attributable to absences | Yaow et al. (2026): 6-8% at 2019 rates, ≤20% at zero |

A3 remains the most novel arm: the most common real-world design pushes gains toward the top and widens the spread.

## Inference without replicate weights

Published NAEP percentile standard errors already incorporate plausible-value and jackknife variance, so SEs on D(p) follow from the two years' SEs (independent samples): SE[D(p)] = sqrt(SE₂₀₁₉² + SE₂₀₂₄²). g*(p) = −D(p)/S inherits that, treating S as fixed (state this; the SD is estimated too, but its contribution is second-order relative to the quantile SEs).

Program-level uncertainty still dominates and is shown as fans from the meta-analytic prediction intervals, e.g. [−0.468, 0.778] at 1,000+ students. That asymmetry — thin band on the decline, enormous band on the response — is the honest visual.

## What this costs

The paper loses the ability to say how many students change rank, and loses the targeting-accuracy analysis that would have shown how poorly observable eligibility tracks the bottom tail. Both were attractive; neither is load-bearing. Note in the Limitations that the simulations operate on quantiles under a monotonicity restriction and therefore do not model rank mobility.

## What this gains

The analysis becomes independently reproducible from public data, which is unusual for a NAEP microdata paper and is worth one sentence in the Methods and one in the data-availability statement. It also sidesteps the disclosure-review burden entirely for this section.

---

# Review findings (methods + data science, 2026-09-04)

Two reviews were run against the *earlier microdata-based* design. Most findings survive the move to public data; several are dissolved by it. Recorded here so nothing is lost.

## Findings the public-data reframe DISSOLVES

- **Fractional vs stochastic assignment (data-science C1, rated blocking).** The reviewer showed by simulation that fractional/expected assignment is not the ITT: quantiles are non-linear, so Q(E[shift]) != E[Q(shift)]. At coverage 0.5 and an 8-point gain, fractional gave a spread change of +0.000 while stochastic gave +0.59 (SD 0.075 over 200 draws). Worse, fractional assignment **manufactures the uniform identity** for any uniform-coverage arm. This was a real error in the earlier design. It disappears here only because we no longer assign treatment to individual students; coverage now enters as a scalar multiplier on a quantile-level requirement. ==If any student-level arm is ever revived, use stochastic assignment and report the Monte Carlo SD separately.==
- **MDIA re-solving inside replicates (data-science E1).** Cost ranged from 25 minutes to 42 hours depending on interpretation. Note the reviewer's correct observation that **plausible values do not enter the MDIA balancing constraints**, so re-solving per PV would produce 20 identical solutions at 20x the cost. Moot here: we take the reweighted curves as already-computed inputs.
- **Weighted-quantile estimator choice, ties, rank-crossing diagnostics, seed streams, synthetic-data fixture.** All are microdata-pipeline concerns. Public percentiles arrive pre-estimated by NCES.
- **Disclosure gate (data-science R1).** No microdata touches this analysis, so the targeting confusion matrix that created new disclosure exposure is gone along with the covariate-eligibility arm.

## Findings that SURVIVE and must be fixed

1. **g*(p) is a units conversion, not a new finding.** The methods reviewer is right: g*(p) = -D(p)/S contains exactly zero information beyond D(p). The contribution is the *comparison* it enables, not the quantity. Delete any claim that this is "a finding, not an identity." Correct framing: *we express the already-reported quantile differences in the effect-size metric the intervention literature uses, so the two can be placed on one axis.*

2. **"Nothing in it is assumed" (Figure 8) is false.** Plotting a mean treated effect g against a percentile-specific requirement g*(p) assumes the treated effect transports across the treated distribution. That is the null-gradient assumption, adopted deliberately. State it on the figure: *"comparison presumes a constant treated effect across the treated distribution; under a positive gradient the bottom contour is easier to clear than shown, under the negative gradient Cortes et al. report, harder."*

3. **phi = 0.6 was a guess and is wrong as characterized.** Verified by simulation (4M standard normal draws): the SD of the lower tail relative to the national SD is **0.467 (lower 20%), 0.491 (25%), 0.514 (30%), 0.602 (50%)**. So 0.6 is the *median-split* value, not the bottom-quintile value. **Drop phi entirely.** Use phi = 1.0 as the sole headline, state plainly that this is optimistic because literature SDs come from restricted, lower-variance samples, and note that any correction moves the conclusion the same way. No unsourced constants.

4. **S must be documented precisely.** "The SD" is ambiguous among (a) total PV variance including posterior uncertainty, (b) latent-theta variance net of measurement error, (c) between-student variance of PV means. These differ by several percent, and every number in the section scales off S. State which one, with the formula and the value per featured cell. Also note the six scales are not vertically linked, so g* must not be compared across grade-subject cells without a caveat.

5. **A3 assumes no selection on gains.** Holding g constant across A1 (universal) and A3 (opt-in) assumes the treated effect does not depend on the assignment mechanism, in a design whose entire premise is severe selection on levels. **Fix by reframing A3 as a pure coverage decomposition:** "even holding the treated effect constant at its evidenced value, differential take-up alone widens the spread by X points," with an explicit note that selection on gains would compound or offset it in an unknown direction.

6. **The 0.187 x 0.21 product mixes sources.** A take-up rate from Robinson, Bisht & Loeb and a *g* from a different bin of a different meta-analysis. It is a constructed illustration, not an ITT from any single study, and must be labelled as such with both sources named in the same sentence.

7. **Kraft's 0.20 "large" threshold is being stretched.** It was proposed for *observed* RCT effects with standardized-test outcomes, not for a *required*-effect benchmark. Cite it carefully, or present the comparison against the empirical percentile distribution of effects (median 0.10, P90 0.47) rather than against the label.

8. **Uncertainty on g*(p) should be shown as a band, not a line.** The CI on g*(.10) will be roughly +/-0.01-0.02 SD while the tutoring prediction interval is [-0.468, 0.778]. That contrast is the point, but the requirement contour should still carry visible uncertainty. Also: SE[D(p)] = sqrt(SE_2019^2 + SE_2024^2) treating the two samples as independent; S contributes second-order variance that can be ignored **if stated**.

9. **Prediction intervals are not policy uncertainty.** The meta-analytic PI is a random-effects prediction for *a new study*, not a distribution over "what would happen if this ran nationally." Displaying it as a fan is defensible but is a choice, and needs one sentence of defence. Keep sampling bands and program fans visually distinct (ribbons vs hatched), with a legend naming them differently.

10. **Pre-specify the percentiles** (10, 25, 50, 75, 90) for all inferential claims, to avoid simultaneous-inference problems on statements like "the requirement exceeds the benchmark somewhere in the lower tail."

11. **State the assumptions that make this a counterfactual at all**, rather than hiding behind "illustrative, not causal": (i) additivity on the NAEP scale, (ii) homogeneity of the treated effect, (iii) no spillovers to untreated students (Morton & Hashim's pull-out evidence is precisely a displacement result), (iv) no effect on the scale itself. Also state when the framework breaks.

12. **Keep one grade 12 cell after all.** The methods reviewer makes a good point: G12 math retains a differential change of 3.2 after composition, and noting that the G12 reading requirement is flat across percentiles actively *supports* the honest qualification of the headline claim that TODO section C flags as currently overclaimed. One sentence, near-zero word cost.

## The one structural recommendation both reviewers converge on

Drop the simulation from the main text; lead with the requirements table and a coverage description. The methods reviewer: "once you have g*(p) and c(p), the simulated Delta is a deterministic function of quantities you have already reported." The public-data reframe delivers exactly this, because it makes the simulation *unable* to be anything more.

**Coverage: what c(p) actually requires, and where to get it** (revised 2026-09-04 after Andrew's question).

The right question is not whether the eligibility flags exist at the individual level (they do: IEP, LEP, and ECONDIS/SLUNCH1 are listed in section 3.2 as student-level covariates and section 4.2 reports exact MDIA balance on each). The right question is what c(p) needs, and the answer is **the joint distribution of eligibility and achievement** - the correlation between being classifiable as eligible and sitting low in the score distribution.

**That relationship is already public.** From the NAEP Data Service API, grade 4 reading 2019, national:

| FRPL group | share of students | mean score |
|---|---|---|
| Eligible | 50.95% | 207.01 |
| Not eligible | 42.74% | 234.85 |
| Information not available | 6.30% | 231.84 |

Share-weighted these reproduce the published overall mean to 0.02 points (220.45 reconstructed vs 220.47 reported), so the two series are mutually consistent. The FRPL gap is 27.8 points, about 0.77 SD. `IEP` returns the same structure (184.07 identified vs 226.26 not identified, a 42.2-point gap), as does `LEP`.

**What this establishes** (==rewritten 2026-09-04 after retrieving subgroup percentiles; my two earlier formulations were both wrong==).

==Superseded 2026-09-29: the decomposition now uses each ECONDIS group's published score distribution (DP:DP), with no assumed tail; see `group_composition` in `api-helpers.R`. The paragraph below records the original five-percentile method.==

Subgroup percentiles ARE publicly available (see the API section below), so c(p) can be **measured rather than assumed**. Using published percentiles within each ECONDIS category, with each group's left tail below its own P10 fitted as a normal through P10 and P25, with the reconstructed mass below the overall P10 coming to 0.103 (2019) and 0.102 (2024) against a definitional 0.10 (an internal consistency check, not a validation of the tail shape; see the sensitivity note below):

**Grade 4 reading, national, composition of the bottom decile**

| Group | share of population | P(below overall P10) | share of the bottom decile |
|---|---|---|---|
| **2019** | | | |
| Economically disadvantaged | 51.0% | 16.8% | **82.8%** |
| Not economically disadvantaged | 42.7% | 3.5% | 14.7% |
| Information not available | 6.3% | 4.1% | 2.5% |
| **2024** | | | |
| Economically disadvantaged | 49.9% | 16.0% | **78.0%** |
| Not economically disadvantaged | 41.3% | 4.2% | 16.9% |
| Information not available | 8.8% | 6.0% | 5.1% |

**Correcting the record on my own two earlier claims:**

1. My first version said eligibility is a "weak sort" that "misses much of the bottom tail." **False.** ECONDIS is 51 percent of the population but 83 percent of the bottom decile - a lift of about 1.6x. For a single binary administrative flag that is a fairly strong sort, and the independent methods review reached the same 0.83 figure from a normality argument.
2. My second version retreated to a "precision, not recall" claim, on the grounds that only ~17 percent of ECONDIS students are in the bottom decile. That number is right (16.8 percent in 2019, 16.0 percent in 2024) but the framing was still wrong, because as the reviewer notes it is **arithmetically forced**: when a group is half the population and the target is a tenth, at most about a fifth of the group can be in the target. It measures group size, not targeting quality.

Also drop the "eligible mean sits only 0.37 SD below overall" line entirely. That statistic is likewise forced by the group being 51 percent of the population - the overall mean is half made of it. The honest separation statistic is the between-group gap, 27.8 points or about 0.72 SD on the corrected SD.

**The defensible claims, all measured:**

- **Targeting on economic disadvantage works well as a screen.** It captures 83 percent of the bottom decile while covering half the population.
- **The cost, not the precision, is the binding constraint.** Reaching every eligible student means reaching half of all students, so a fixed budget buys half the per-student intensity of a program aimed at the bottom decile. That is the real force of the coverage arithmetic (c times g must clear g*), and it does not depend on any claim about targeting accuracy.
- **The screen weakened in grades 4 and 8, but not at grade 12** (==measured across all six cells 2026-09-04; my earlier "degraded everywhere" was too strong==). Share of the bottom decile that is economically disadvantaged: Reading G4 82.8 to 78.0, Reading G8 78.1 to 75.4, Math G4 82.7 to 78.4, Math G8 77.6 to 76.3 - but Reading G12 61.6 to 63.2 and Math G12 68.1 to 69.6, i.e. slightly *stronger*. Meanwhile the "information not available" category grew in every cell, from about 6-7 percent to about 9 percent. So in the grades where the differential decline is large, the instrument a targeted policy would use got noisier over exactly the period being studied; at grade 12, where the differential decline is small or absent, it did not. That pattern is consistent and it is new.
- **Targeting lift is smaller at grade 12 in absolute terms too**: economically disadvantaged students are about 40 percent of the grade 12 population and 62-70 percent of its bottom decile, against roughly 50 percent and 78-83 percent at grade 4. Another reason grade 12 behaves differently and should be handled separately.

**The caution to state either way.** These are administrative classification variables, not clean measures of the constructs a policy targets. Section 4.2 already documents that the FRPL "information not available" category rose from about 6 percent in 2019 to about 9 percent in 2024, a 50 percent relative increase in missingness across exactly the two comparison years, and it is the single covariate flagged as out of balance before reweighting. Community Eligibility Provision compounds this: in a CEP school every student is coded eligible regardless of family income. IEP and LEP record whether a system has identified and classified a student, and identification rates vary by state, district, and year. There is also a framing tension worth one sentence: these same variables are a *nuisance* in RQ1, adjusted away as compositional drift, and would be a *targeting instrument* in the simulations.

**Open items on the public route** (agent working):
- 2024 subgroup calls return status 200 with an empty result for `SLUNCH3`, while `TOTAL` works for 2024. The subgroup variable code appears to have changed for the 2024 administration. Needs resolving before the 2019-to-2024 comparison can be built.
- Whether percentiles can be crossed with subgroup, i.e. the 10th/25th/50th/75th/90th percentile *within* each eligibility category. If yes, c(p) is fully public and exact. If only subgroup means and shares are available, c(p) must be approximated (e.g. under a normal-within-group assumption, stated as such) or imported from the literature.
- Whether standard errors are retrievable; the returned rows had a null SE field.

**Decision rule.** If subgroup percentiles are public, build c(p) entirely from public data and the section has no restricted-use dependency at all. If not, either approximate with a stated distributional assumption, or run the single cross-tabulation on the licensed machine and return one rounded, disclosure-reviewed table. Note the disclosure exposure in that last case: it is a cross-tab of achievement by subgroup, and grade 12 (n about 19,000 to 24,000 split further by eligibility) is where a small cell would appear.


---

# The public API: resolved (2026-09-04)

Endpoint `https://www.nationsreportcard.gov/DataService/GetAdhocData.aspx`. Stattype codes are `XX:YY` form, which is why bare guesses failed. Colons URL-encode as `%3A`.

| Code | Meaning |
|---|---|
| `PC:P1` `PC:P2` `PC:P5` `PC:P7` `PC:P9` | 10th, 25th, 50th, 75th, 90th percentile |
| `SD:SD` | standard deviation |
| `MN:MN` / `RP:RP` | mean / population share |
| `DP:DP` | distribution percentages, 10-point intervals |

`&ShowDetails=true` populates `stdError`. `&QCData=true` adds unweighted `cellN`. `type=independentvariables&cohort=1|2|3` lists valid variables per year.

**Subscales:** reading RRPCM at all grades; math MRPCM at grades 4 and 8; **grade 12 math is MWPCM** on a 0-300 scale, not MRPCM (which 400s).

**Subgroup variables that work in BOTH years:** `ECONDIS` (economic disadvantage), `IEP`, `LEP` / `ELL3`, and `B018101` (the absence item, confirming B018101 over B018014). `SLUNCH3`/`SLUNCH6` were retired after 2019, which is why 2024 calls returned empty. `ECONDIS` 2019 returns values identical to SLUNCH3, so it is a drop-in with no break in series.

**Percentiles cross with subgroups in both years, with SEs.** This is what makes c(p) measurable.

## Validation against the restricted-use analysis

Public percentiles reproduce **all six** of Table 2 column (a) exactly: R4 8.7, R8 7.0, R12 1.5, M4 7.9, M8 6.4, M12 4.5. I verified G4 reading directly:

| stat | 2019 | 2024 | diff | SE19 | SE24 |
|---|---|---|---|---|---|
| P10 | 168.3 | 158.3 | **-10.0** | 0.36 | 0.65 |
| P25 | 197.0 | 188.7 | -8.3 | 0.27 | 0.57 |
| P50 | 224.6 | 219.0 | -5.6 | 0.23 | 0.42 |
| P75 | 247.7 | 244.5 | -3.2 | 0.27 | 0.36 |
| P90 | 266.1 | 264.8 | **-1.3** | 0.36 | 0.38 |
| SD | 38.5 | 41.2 | **+2.7** | 0.19 | 0.22 |

Differential change = 8.7, matching Table 2. **This is the reconciliation check the methods reviewer asked for, and it passes.** Report it in one line in the manuscript; it validates mixing public aggregates with the restricted-use reweighted curves in one figure.

## Corrected S, and its effect

**S = 38.5, not 36.2.** The 36.2 came from your discussion figure's footer, which is a 2005-based SD. Every requirement figure shifts about 6 percent:

| quantity | S=36.2 (old) | **S=38.5 (correct)** |
|---|---|---|
| restore p10 | 0.276 SD | **0.260 SD** |
| restore p90 | 0.036 SD | 0.034 SD |
| tutoring at scale (0.155 SD) closes | 56% of p10 deficit | **60%** |
| opt-in ITT closes | 14% | **15%** |

The headline survives: 0.260 SD is still above Kraft's 0.20 "large" threshold and above what tutoring delivers at national scale. Note also the SD itself widened from 38.5 to 41.2, which is independent quotable evidence of distributional spreading.

## Caveats

Grade 12 and multi-stattype calls take 30-180s uncached; run cells in parallel with generous timeouts. No auth or rate limiting observed. `statusCode:400` means a bad stattype or subscale; `status:200` with an empty result means the variable does not exist for that year. Value 999 is a suppression sentinel; filter on `isStatDisplayable`/`errorFlag`. The 2024 variable list returns malformed JSON with unescaped quotes, so parse it with regex rather than `json.loads`.


---

## Sensitivity of c(p) to the left-tail assumption (added 2026-09-04 after data-science review)

The reviewer correctly objected that the reconstructed-mass column does not validate the tail extrapolation: it moves about 0.002 while the estimand moves about 4 points, and its excess over 0.100 is a predictable artefact of linear interpolation between percentile knots sitting above the true CDF. It is an internal consistency check, nothing more, and the tables now say so.

The real sensitivity, computed for grade 4 reading 2019 by varying only the left-tail model:

| Left-tail model | ED share of the bottom decile | Reconstructed mass |
|---|---|---|
| Normal fitted through P10 and P25 | 82.8% | 0.1032 |
| Logistic | 80.6% | 0.1060 |
| Exponential decay | 79.2% | 0.1080 |

So the honest statement is **79 to 83 percent**, and the normal fit happens to give the mass closest to the definitional target. The substantive conclusion (economic disadvantage captures roughly four-fifths of the bottom decile while covering half the population) is robust across all three.

**Caution carried forward:** the 2019-to-2024 change in this share is 3 to 5 points in grades 4 and 8, which is the same order as the tail-model uncertainty. The direction is consistent across cells and both subjects, which is what makes it worth reporting, but it should be stated as a pattern rather than a precise decline, and the sensitivity range should appear alongside it.
