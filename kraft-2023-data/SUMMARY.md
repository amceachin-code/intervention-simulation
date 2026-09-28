<!-- summary v1, 2026-09-18; sources: the three files in this folder, read in full; spreadsheet profiled with pandas (xlrd); percentiles are type-7 linear-interpolation quantiles -->

> **Copy note (2026-09-28).** This folder is a copy of the one in `naep-aera-open`, which also uses it. File names below are that project's: `05-simulations.R`, `12-district-enrollment.R`, and `13-kraft-benchmarks.R` are `01-`, `08-`, and `09-` here; `rq3-*` files are `sim-*`; `RQ3-memo.md` is `manuscript/simulation-memo.md`.

# Kraft (2023) effect-size benchmark data: summary and use in this project

This folder holds three author-supplied resources from Matthew Kraft's 2023 *Educational Researcher* follow-up to Kraft (2020). Together they give the project a public, reproducible distribution of effect sizes from education RCTs, which RQ3 uses to benchmark the effect an intervention would need to deliver to restore the 2019 score distribution.

| File | What it is |
|---|---|
| `Kraft+2023+The+Effect+Size+Benchmark+that+Matters+Most+ER.pdf` | Author's accepted manuscript of Kraft, M. A. (2023). The effect size benchmark that matters most: Education interventions often fail. *Educational Researcher*, 52(3), 183-187. https://doi.org/10.3102/0013189X231155154. Sixteen pages: 12 of text and endnotes, references, Table 1, one blank page. |
| `read_me_-_kraft_2023_effect_size_data.pdf` | Five-page README and online data appendix for the dataset: inclusion criteria, deduplication, coding rules, and Table A1 describing the six source collections. |
| `kraft2023effectsize.xls` | The dataset: 3,426 effect sizes (rows) by 29 columns, one sheet (`Sheet1`), header in row 1. About 2 MB. The README calls it `kraft2023effectsizes.xlsx`; the file here is the same data as `.xls`. |

The folder is not git-ignored, so all three files can be committed. The data are public and contain no student records.

## 1. The article

**Purpose.** The paper does two things. It replicates the empirical benchmarks of Kraft (2020), which the paper abbreviates IESEI, on an expanded database, and it answers Simpson's (2021) technical comment "Benchmarking a Misnomer." The framing claim is that debates over what counts as small, medium, or large miss the central fact in the data: education interventions often fail to move standardized achievement at all.

**Headline finding.** Across 3,426 effect sizes from 973 RCTs of education interventions with standardized achievement outcomes, 36 percent are below 0.05 SD. Publication bias means the true share is higher. Kraft calls this "the benchmark that matters most."

**Replication of Kraft (2020).** The expanded sample adds over 75 percent more estimates yet leaves the distribution almost unchanged. The overall 30th, 50th, and 70th percentiles are 0.02, 0.10, and 0.21 in both the 2020 and 2023 samples. The one notable change is a longer right tail in math: the math median rises from 0.07 to 0.11 and the math 90th percentile from 0.37 to 0.78, which Kraft attributes to small-sample studies of early numeracy, arithmetic, and fractions that use narrowly focused tests. Averaging effects within study (one value per study, 973 studies) gives 30th, 50th, and 70th percentiles of 0.04, 0.12, and 0.25. Evans and Yuan (2022) report a median of 0.10 across 96 evaluations in low- and middle-income countries, which Kraft reads as external support for the same benchmarks.

**Response to Simpson (2021).** Simpson argued that effect sizes from different studies are incomparable, so benchmarks are inappropriate, and that Kraft's cutpoints (0.05 and 0.20) are too low because he neither took absolute values nor dropped non-significant estimates. Kraft's replies:

- Benchmarks are pragmatic starting points for a narrowly defined literature (causal designs, standardized achievement outcomes), to be adjusted for study features. The alternative, professional judgment alone, is less accessible and more subjective.
- The cutpoints were never meant to be terciles of the empirical distribution. They were chosen to interpret the policy relevance of positive effects, with an implicit lower bound of zero on the "small" category, and to align with reference points such as annual learning gains and teacher effects. Endnote 2 suggests symmetric negative cutpoints (-0.05 and -0.20) if negative effects need categories.
- Absolute values suit power analysis, not policy interpretation. Sign matters because most RCTs compare a treatment to business as usual. Kraft reports that 94 percent of the treatment-control contrasts in Fryer (2017) have that structure. Agodini et al. (2010), Simpson's counterexample of a symmetric multi-arm design, was removed from the sample (endnote 3).
- Dropping non-significant estimates conditions on results known only after the fact and would disproportionately remove small, imprecise effects, exaggerating dispersion. Magnitude and precision should be reported together.

**Publication bias and estimation error.** Two reasons the benchmarks may be too high rather than too low. First, effects from the smallest studies are more than ten times larger on average than effects from the largest (0.40 for n at or below 100 versus 0.04 for n above 2,000), and the 194 effects from U.S. Department of Education studies that required reporting regardless of result have a median of 0.03 against 0.10 overall. Second, estimation error inflates the spread of observed estimates relative to the spread of true effects (endnote 4 gives the variance decomposition); Kraft suggests Bayesian shrinkage as a future correction.

**Path forward.** Keep the 0.05 and 0.20 benchmarks as a baseline, update them by checking how their rank in the distribution shifts as new estimates arrive rather than by re-cutting terciles, and keep the frequency of failure, together with cost and scalability, at the center of any interpretation.

**Table 1 of the paper (effect sizes in SD units).** Reproduced here because it is the reference table for RQ3 benchmarking.

| Statistic | All ES | One per study | Math | Reading | n<=100 | 101-250 | 251-500 | 501-2,000 | >2,000 | Broad | Narrow | DoE |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Mean | 0.18 | 0.20 | 0.24 | 0.16 | 0.40 | 0.25 | 0.18 | 0.10 | 0.04 | 0.17 | 0.27 | 0.04 |
| SD | 0.33 | 0.29 | 0.44 | 0.27 | 0.44 | 0.45 | 0.28 | 0.16 | 0.13 | 0.32 | 0.38 | 0.16 |
| Mean (weighted) | 0.05 | 0.06 | 0.06 | 0.06 | 0.40 | 0.24 | 0.18 | 0.09 | 0.03 | 0.05 | 0.15 | 0.02 |
| P10 | -0.07 | -0.04 | -0.08 | -0.07 | -0.08 | -0.13 | -0.06 | -0.06 | -0.06 | -0.08 | -0.04 | -0.12 |
| P30 | 0.02 | 0.04 | 0.03 | 0.03 | 0.14 | 0.04 | 0.06 | 0.02 | -0.01 | 0.02 | 0.06 | -0.04 |
| P50 | 0.10 | 0.12 | 0.11 | 0.10 | 0.36 | 0.17 | 0.14 | 0.07 | 0.03 | 0.10 | 0.16 | 0.03 |
| P70 | 0.21 | 0.25 | 0.29 | 0.20 | 0.57 | 0.35 | 0.22 | 0.13 | 0.07 | 0.20 | 0.32 | 0.08 |
| P90 | 0.57 | 0.55 | 0.78 | 0.49 | 0.91 | 0.76 | 0.43 | 0.27 | 0.15 | 0.55 | 0.74 | 0.19 |
| k (effect sizes) | 3,426 | 973 | 1,011 | 2,178 | 504 | 759 | 593 | 896 | 480 | 3,057 | 369 | 194 |
| n (studies) | 973 | 973 | 396 | 659 | 194 | 194 | 203 | 286 | 208 | 954 | 91 | 56 |

The table also reports P1, P20, P40, P60, P80, and P99; see page 15 of the PDF. Weights are sample sizes. Ninety-three percent of outcomes are math or ELA tests.

## 2. The README and data appendix

**Inclusion criteria.** (1) Education interventions, (2) evaluated by randomized controlled trials, (3) with a standardized test outcome. Simpson's advance copy of his comment surfaced several data-entry errors, which prompted a full rebuild of the analytic file against these criteria.

**Sources.** Six collections, five American and one British. Table A1 in the README gives each collection's mean, weighted mean, 30th, 50th, and 70th percentiles, and counts.

| Source (code in the data) | Effect sizes | Studies | Mean | Median |
|---|---|---|---|---|
| IES What Works Clearinghouse (`wwc`) | 1,477 | 270 | 0.26 | 0.14 |
| Best Evidence Encyclopedia (`bee`) | 954 | 318 | 0.12 | 0.10 |
| Education Endowment Foundation (`eef`) | 487 | 236 | 0.15 | 0.08 |
| Fryer (2017), Handbook of Field Experiments (`fryer`) | 314 | 182 | 0.16 | 0.09 |
| Investing in Innovation evaluations (`i3`) | 100 | 27 | 0.06 | 0.03 |
| IES-commissioned RCTs 2002-2013 (`ies90`) | 94 | 29 | 0.02 | 0.03 |

Most of the growth from the 2020 sample comes from the WWC. The study counts in Table A1 sum to 1,062, more than the 973 studies reported, because a study can appear in more than one source.

**Deduplication.** The six sources overlap and use inconsistent citation and reporting norms. An effect-size ID built from up to six author surnames, year, subject, grade, effect size rounded to two decimals, and outcome type removed cross-source duplicates, followed by a hand review. A study ID built from authors and year defines studies, which understates the count when one team published more than once in a year. Kraft states that some duplicates may remain and asks that errors be reported to him.

**Coding rules that matter for reuse.**

- Grade indicators are not mutually exclusive. A study pooling grades enters every grade it covers, so grade subsets overlap and cannot be summed.
- Following Hill et al. (2007), tests are coded broad (composite subject measures) or narrow (subtests or specific-skill tests). When a study reports both, only the broad measure is kept, though the README concedes both may survive for some studies.
- Twenty-nine effect sizes have no citation. They come from the Boulay et al. (2018) summary of 67 i3 evaluations and were reported to IES but never published.
- No standard errors. The compiled sources mostly did not report them. Kraft points to the WWC database for anyone who needs precision-weighted analysis.

## 3. The spreadsheet

**Layout.** One sheet, 3,426 data rows, 29 columns.

| Column | Content |
|---|---|
| `Unique Study ID` | Integer 1 to 1,074 with gaps; missing for the 29 uncited i3 rows |
| `Source where we found effect size` | `wwc`, `bee`, `eef`, `fryer`, `i3`, `ies90` |
| `Citation - author/date` | Short citation string; missing for the 29 i3 rows |
| `First author` to `Sixth author` | Lower-case surnames; `.` where not applicable |
| `Publication year` | 1964 to 2021; median 2012, interquartile range 2008 to 2016 |
| `Effect size` | Numeric, SD units, no missing values |
| `Academic subject` | Reading 2,178; Math 1,011; Science 187; Multiple 47; Social Studies 3 |
| `Specific outcome test` | Free text; 78 missing. Most frequent: PPVT, NGRT, GRADE, Woodcock-Johnson subtests, ITBS, NAEP selected items |
| `Sample size` | Numeric, 1 to 185,612, median 317; 49 missing |
| `Narrow test / subtest` | 0 broad (3,057), 1 narrow (369); 342 of the 369 narrow tests are reading |
| `gradeprek` to `grade12` | Fourteen 0/1 indicators, non-exclusive |

**Grade coverage.** Effect sizes flagged for grade 4: 897; grade 8: 642; grade 12: 104. Grades 9 to 12 are thin (308, 212, 129, 104), so grade-12 benchmarks from these data rest on about a hundred estimates.

**Verification against the paper.** Reading the file and computing the overall statistics reproduces Table 1's first column to two decimals: mean 0.18, SD 0.33, weighted mean 0.05, P10 -0.07, P30 0.02, P50 0.10, P70 0.21, P90 0.57, P99 1.37, k = 3,426. The share below 0.05 is 35.8 percent, matching the paper's 36 percent. Subject and broad/narrow columns match exactly. ==The sample-size bins do not.== Cutting the file at 100, 250, 500, and 2,000 gives 617, 780, 596, 904, and 480 effects against the paper's 504, 759, 593, 896, and 480. The paper's bins sum to 3,232 while the file has 3,377 rows with a sample size, so Table 1's sample-size columns appear to rest on a slightly different version of the file or on an additional exclusion the README does not describe. The largest bin matches, the bin means (0.35, 0.25, 0.18, 0.10, 0.04) follow the paper's pattern, and the discrepancy does not touch the overall, subject, or scope columns.

**One discrepancy to flag.** ==The file has 1,041 distinct study IDs (plus 29 rows with none), but the paper reports 973 studies.== Averaging within the file's IDs gives 30th, 50th, and 70th percentiles of 0.05, 0.12, and 0.25 against the paper's 0.04, 0.12, and 0.25, so the effect on study-level statistics is small. The gap may reflect the author-year study ID described in the README being coarser than the numeric ID in the file. Worth an email to Kraft before any study-level count is cited.

## 4. What the data add for RQ3

**Where the project stands.** `analysis/config/rq3-params.yaml` benchmarks the restoration requirement g*(p) against Kraft (2020) percentiles (P10 -0.08, P25 0.00, P50 0.10, P75 0.25, P90 0.47; 1,942 effects, 747 RCTs), and `manuscript/RQ3-memo.md` reports that restoring the 10th percentile (0.26 to 0.29 SD in the featured cells) sits above the 75th percentile of that distribution. Those numbers came from a published table. With the 2023 file in hand the pipeline can compute any cut of the distribution itself, from a public source with a DOI, and the citation moves to the larger, cleaner sample.

**Candidate benchmark sets, computed from the file** (SD units; percentiles of the raw effect-size distribution, one row per effect size).

| Subset | k | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|
| All effect sizes | 3,426 | -0.07 | 0.01 | 0.10 | 0.27 | 0.57 |
| Broad tests only | 3,057 | -0.08 | 0.01 | 0.10 | 0.25 | 0.55 |
| Reading | 2,178 | -0.07 | 0.01 | 0.10 | 0.25 | 0.49 |
| Math | 1,011 | -0.08 | 0.01 | 0.11 | 0.36 | 0.78 |
| Sample size >= 1,000 | 892 | -0.05 | -0.01 | 0.04 | 0.11 | 0.20 |
| Reading, n >= 1,000 | 491 | -0.04 | 0.00 | 0.04 | 0.10 | 0.19 |
| Math, n >= 1,000 | 283 | -0.07 | -0.01 | 0.05 | 0.11 | 0.20 |
| Sample size > 2,000 | 480 | -0.06 | -0.01 | 0.03 | 0.09 | 0.15 |
| DoE-required reporting (`i3` + `ies90`) | 194 | -0.11 | -0.05 | 0.03 | 0.11 | 0.19 |

Three consequences for the memo's framing.

1. **The overall benchmark barely moves, but the 75th percentile crosses one featured cell.** Against all 3,426 effects, P75 is 0.27, so Reading G4's requirement of 0.259 falls just below it while Math G8's 0.288 stays above. Against reading effects only (P75 0.25), Reading G4 stays above. The memo's "above the 75th percentile" sentence should be re-stated with the subject-specific benchmark or with a cut that does not hinge on a 0.01 difference.
2. **Subject-specific benchmarks cut against math.** The math distribution's long right tail (P75 0.36, P90 0.78) is, per Kraft, an artifact of small studies with narrow early-math tests. Benchmarking Math G8 against it would make the requirement look ordinary. Restricting to broad tests does little for math (only 27 math effects are coded narrow), so the fix is to condition on scale, not on test scope.
3. **Conditioning on scale is the defensible move and strengthens the argument.** Among studies with at least 1,000 students, the bin Kraft, Schueler, and Falken (2024) use for at-scale tutoring, the 90th percentile is 0.20 in both subjects and 52 percent of effects are below 0.05. A 0.26 to 0.29 SD requirement then exceeds the 90th percentile of what evaluated programs deliver at scale, and the 0.155 SD at-scale tutoring estimate already in the config sits near the 85th percentile of that same subset. This aligns the benchmark distribution with the participation and scale logic the memo already uses.

**Grade-specific cuts (added the same day, in answer to Andrew's question).** The file supports a grade 4 distribution split by subject, restricted to broad tests and large samples. Counts and percentiles below are for effect sizes whose grade indicator includes the grade, on broad tests only.

| Cell | Sample-size floor | k | Studies | Share below 0.05 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|---|---|
| Grade 4 reading | n >= 500 | 169 | 90 | 0.51 | 0.00 | 0.05 | 0.11 | 0.16 |
| Grade 4 reading | n >= 1,000 | 114 | 75 | 0.62 | -0.01 | 0.03 | 0.09 | 0.14 |
| Grade 4 reading | n > 2,000 | 65 | 49 | 0.71 | -0.01 | 0.02 | 0.05 | 0.11 |
| Grade 4 math | n >= 500 | 157 | 89 | 0.50 | -0.01 | 0.05 | 0.11 | 0.18 |
| Grade 4 math | n >= 1,000 | 119 | 76 | 0.51 | -0.01 | 0.03 | 0.10 | 0.15 |
| Grade 4 math | n > 2,000 | 72 | 49 | 0.58 | -0.02 | 0.01 | 0.09 | 0.14 |
| Grade 8 reading | n >= 1,000 | 108 | 59 | 0.58 | -0.01 | 0.03 | 0.07 | 0.19 |
| Grade 8 math | n >= 1,000 | 94 | 52 | 0.51 | -0.01 | 0.05 | 0.13 | 0.21 |
| Grade 12 reading | n >= 1,000 | 19 | 14 | 0.37 | 0.02 | 0.11 | 0.15 | 0.25 |
| Grade 12 math | n >= 1,000 | 29 | 15 | 0.55 | -0.02 | 0.03 | 0.07 | 0.15 |

Three things to know before using these.

- **"Grade 4" means the study's sample included grade 4, not that it was a grade 4 study.** Only 37 reading and 114 math effects come from studies coded to grade 4 alone, and at n >= 1,000 those fall to 10 and 7. The grade 4 cells above are therefore mostly multi-grade elementary studies whose pooled effect is entered under every grade they cover. That is how Kraft builds his own grade tables, and it is the only workable definition here.
- **Grade 4 and grade 8 are usable; grade 12 is not.** At n >= 1,000 the grade 4 and 8 cells hold 94 to 119 effects from 52 to 76 studies, enough for stable quartiles and a defensible 90th percentile. Grade 12 holds 19 and 29 effects from 14 and 15 studies, too few for anything beyond a median with a caveat.
- **The at-scale grade 4 distribution is compressed and centered near zero.** With n >= 1,000 and broad tests, the median is 0.03 in both subjects, the 90th percentile is 0.14 to 0.15, and more than half of effects fall below 0.05. The restoration requirements of 0.26 SD (Reading G4) and 0.25 SD (Math G4) sit far above the 90th percentile of this distribution. Widening the floor to n >= 500 raises the 90th percentile only to 0.16 to 0.18.

Because no standard errors are in the file, these are unweighted empirical quantiles. Eleven grade 4 rows lack a sample size and drop out of every size-restricted cell.

**Widening grade 4 to grades 3 to 5.** Adding neighboring grades to the inclusion rule adds modest numbers at scale and leaves the percentiles nearly unchanged. Broad tests only, n >= 1,000; rows with a missing sample size excluded.

| Cell | Grade rule | k | Studies | Share below 0.05 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|---|---|
| Reading | Grade 4 | 114 | 75 | 0.62 | -0.01 | 0.03 | 0.09 | 0.14 |
| Reading | Grade 3 or 4 | 152 | 90 | 0.62 | -0.01 | 0.03 | 0.09 | 0.15 |
| Reading | Grade 4 or 5 | 159 | 94 | 0.67 | -0.02 | 0.01 | 0.07 | 0.13 |
| Reading | Grade 3, 4, or 5 | 197 | 109 | 0.66 | -0.02 | 0.01 | 0.07 | 0.14 |
| Math | Grade 4 | 119 | 76 | 0.51 | -0.01 | 0.03 | 0.10 | 0.15 |
| Math | Grade 3 or 4 | 127 | 82 | 0.53 | -0.01 | 0.03 | 0.10 | 0.15 |
| Math | Grade 4 or 5 | 128 | 83 | 0.52 | -0.01 | 0.03 | 0.10 | 0.18 |
| Math | Grade 3, 4, or 5 | 136 | 89 | 0.54 | -0.02 | 0.03 | 0.10 | 0.16 |

Reading gains the most (34 studies when both grades are added) because many grade 3 and grade 5 reading studies do not extend to grade 4. Math gains 13 studies, since the large math studies already span grades 3 to 5 and are counted under grade 4. Without the sample-size floor the gains are larger (reading 160 to 269 studies, math 152 to 212), but those cells reintroduce the small-study math tail. The grade 4 cell alone is adequate for both subjects; the wider rule is a robustness check for reading rather than a necessity.

**Kraft's Table 1 sample-size columns, replicated by grade and subject (added 2026-09-18).** Broad tests only; the three size bins are Kraft's, and they are also the bins used for the district K-5 enrollment distribution in `tables/district-enrollment-2324-bins.csv`. Reading a district's K-5 enrollment against these columns treats the district as if it were a study sample of that size. Weighted mean uses the study sample size as weight, as in Kraft's table.

| Grade | Subject | Study size | k | Studies | Mean | Weighted mean | Share below 0.05 | P10 | P25 | P50 | P75 | P90 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 4 | Reading | 251 to 500 | 64 | 37 | 0.14 | 0.13 | 0.34 | -0.03 | 0.03 | 0.12 | 0.21 | 0.32 |
| 4 | Reading | 501 to 2,000 | 104 | 48 | 0.08 | 0.07 | 0.38 | -0.01 | 0.02 | 0.08 | 0.13 | 0.18 |
| 4 | Reading | More than 2,000 | 65 | 49 | 0.02 | 0.02 | 0.71 | -0.05 | -0.01 | 0.02 | 0.05 | 0.11 |
| 4 | Math | 251 to 500 | 43 | 27 | 0.41 | 0.34 | 0.30 | 0.00 | 0.03 | 0.13 | 0.38 | 1.09 |
| 4 | Math | 501 to 2,000 | 85 | 45 | 0.06 | 0.06 | 0.42 | -0.06 | -0.01 | 0.06 | 0.13 | 0.22 |
| 4 | Math | More than 2,000 | 72 | 49 | 0.04 | 0.03 | 0.58 | -0.06 | -0.02 | 0.01 | 0.09 | 0.14 |
| 8 | Reading | 251 to 500 | 50 | 17 | 0.15 | 0.14 | 0.22 | -0.01 | 0.08 | 0.15 | 0.21 | 0.35 |
| 8 | Reading | 501 to 2,000 | 109 | 37 | 0.08 | 0.08 | 0.34 | -0.01 | 0.03 | 0.07 | 0.13 | 0.20 |
| 8 | Reading | More than 2,000 | 64 | 44 | 0.04 | 0.02 | 0.66 | -0.05 | 0.00 | 0.03 | 0.07 | 0.13 |
| 8 | Math | 251 to 500 | 14 | 6 | 0.43 | 0.41 | 0.29 | 0.04 | 0.10 | 0.39 | 0.69 | 0.93 |
| 8 | Math | 501 to 2,000 | 66 | 31 | 0.14 | 0.15 | 0.29 | -0.05 | 0.03 | 0.12 | 0.20 | 0.32 |
| 8 | Math | More than 2,000 | 63 | 39 | 0.03 | 0.02 | 0.59 | -0.08 | -0.02 | 0.03 | 0.08 | 0.14 |

This table is now produced by `analysis/13-kraft-benchmarks.R`, which writes `tables/kraft-2023-benchmarks-by-grade-size.csv` (with a grades 3 to 5 rule and an all-sizes row added) and five figures in `figures/kraft/` (`fig-k1` to `fig-k5`), one per reference line at the effect needed to restore the 2024 10th, 25th, 50th, 75th, and 90th percentiles to their 2019 values. For reference, the same three bins across all grades and subjects on broad tests give medians of 0.14, 0.07, and 0.03 and 90th percentiles of 0.43, 0.27, and 0.15 (k = 517, 829, 457). The grade 8 math 251-to-500 cell rests on 6 studies and should not be quoted. Widening grade 4 to grades 3 to 5 adds 40 to 60 effects per cell and leaves every median within 0.02 of the grade 4 value.

**Suggested implementation.** Read the `.xls` directly in R with `readxl::read_xls()` from `kraft-2023-data/`, compute the percentile sets above inside `05-simulations.R` (or a small `analysis/kraft-benchmarks.R` that writes `tables/rq3-kraft-benchmarks.csv`), and replace the hard-coded `kraft2020_effect_percentiles` block in the YAML with a pointer to that output. Add a test that the overall percentiles reproduce Table 1. Keep the 2020 numbers in the YAML only as a validation reference. Any figure that draws Kraft's P50, P75, and P90 reference lines (Figure 8 and the memo's participation figures) would then be regenerated with the chosen subset, and the caption would say which subset.

**Caveats to carry into the text.** No standard errors, so no precision weighting. Possible residual duplicates. Effects are standardized on each study's own sample, often a targeted low-performing group, so they overstate points gained on a national NAEP SD (the same caution the source map already records for Kraft, Schueler, and Falken). Grade-12 coverage is thin. Publication bias makes every percentile an upper bound on what a typical program achieves.

## 5. Citation entries

Added to `references/additions.bib` as `kraft-2023` (the article) and `kraft-2023-data` (the dataset). ==The dataset has no DOI of its own in the README; confirm whether Kraft posted it with a persistent identifier (for example on his website or the ER supplement) before the reference list is finalized.== AERA Open requires datasets to be cited with a persistent identifier where one exists.
