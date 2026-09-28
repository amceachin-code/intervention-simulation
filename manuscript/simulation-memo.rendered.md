<!-- memo v2, 2026-09-10, simulation results for co-authors (written as RQ3 of the naep-aera-open article; moved to intervention-simulation 2026-09-28); sources: tables/sim-quantiles.csv, tables/sim-bottom-decile.csv, figures/sim/ -->

## Executive summary

- This analysis asks what it would take to return the 2024 NAEP score distribution to its 2019 shape. Everything runs on public NAEP percentiles and reproduces the restricted-use differential-change numbers to a tenth of a point, so a reviewer can replicate all of it without a license.
- The requirement is steeply tilted. Restoring the 10th percentile takes 0.26 to 0.29 SD in the featured cells, at or above the 75th percentile of RCT effects in Kraft (2020); restoring the 90th takes 0.03 to 0.13 SD, near or below the median.
- At realistic participation, the best-evidenced at-scale effect (0.155 SD) leaves most of the bottom’s gap open. Participation, not effect size, is the binding constraint: at summer-program reach, the remaining p10 gap in Reading G4 is 0.24 SD of an original 0.26.
- One distinction organizes the allocation analysis: the baseline-distribution question follows students fixed at their pre-program percentiles (the answer at percentile *p* is *Q*<sub>0</sub>(*p*) + *π*(*p*) ⋅ *δ*), while the post-intervention-distribution question re-ranks the shifted population (the answer is *Q*<sub>1</sub>(*p*)). Partial coverage widens the post-intervention distribution even when delivery is untargeted; voluntary opt-in delivery widens it further; only bottom-up allocation closes the 90-10 gap, and it must overshoot the target percentile to do so. The boundary-case numbers survive alternative lower-tail specifications.
- Feasible targeting is blunt. An economic-disadvantage screen captures 82.8 percent of the bottom decile, but roughly five of six treated students sit outside the target, and the screen got noisier between 2019 and 2024.
- Implication for §6.2: a one-size-fits-all program at partial coverage widens the differential rather than leaving it alone, and targeting helps only as far as the screen is sharp.

**Open questions as you read the document**:

- Should we continue this analysis on public data, or is it better to use the restricted-use data? I thought it better to use data anyone could access–e.g., A reviewer can reproduce these analyses without a NAEP license. Thoughts?
- How should we frame the use of NAEP for this? Given name is a random, nationally representative draw of the US, I’ve used it as a case study. It’s not meant to be representative of any gievn district. Nor does the following account for district level variatoin in demographics or achievement. Instead anyone reading this could apply this approach to their own data/district.
- There’s also thinking about the seat allocation piece. My take is that section is more focused on understanding the implications of various programs. It’s less about choosing the allocation budget that minimizes a given gap.

# What would it take to restore 2019?

**All numbers are from public NAEP data and are reproducible without a restricted-use license.**

------------------------------------------------------------------------

## Data and setup

The analysis runs entirely on the **public NAEP Data Service API**, not the restricted-use microdata used for RQ1/RQ2. For each of the six grade-subject cells we pull the published 10th, 25th, 50th, 75th, and 90th percentiles and the national standard deviation, for 2019 and 2024.

We can validate the results from the restricted-use data against the publicly avialable percentiles (*p* = 10, 25, 50, 75, 90). For example, here we replicate the restricted-use **differential change** calculation, *D*(90) − *D*(10), where *D*(*p*) = *Q*<sub>2024</sub>(*p*) − *Q*<sub>2019</sub>(*p*) is the observed quantile difference in NAEP score points, computed from public percentiles (i.e. Table 2 column (a) of the manuscript in all six cells):

<table style="width:100%;">
<colgroup>
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
</colgroup>
<thead>
<tr>
<th></th>
<th>Reading G4</th>
<th>Reading G8</th>
<th>Reading G12</th>
<th>Math G4</th>
<th>Math G8</th>
<th>Math G12</th>
</tr>
</thead>
<tbody>
<tr>
<td>Public</td>
<td>8.66</td>
<td>7.04</td>
<td>1.53</td>
<td>7.88</td>
<td>6.44</td>
<td>4.49</td>
</tr>
<tr>
<td>Table 2(a)</td>
<td>8.7</td>
<td>7.0</td>
<td>1.5</td>
<td>7.9</td>
<td>6.4</td>
<td>4.5</td>
</tr>
</tbody>
</table>

We use two kinds of outside parameters <!-- , both sourced in
`analysis/config/sim-params.yaml`--> to contextualize the magnitude of these differences and the possible range of policy responses:

- We use Kraft (2020) to benchmark effect sizes from the intervention literature. He summarizes a distribution of 1,942 effects from 747 RCTs;
- Kraft, Schueler & Falken (2024) conduct a meta-analysis of tutoring programs. In parrticular they evaluate how observed effects from tutoring RCTs and QEDs relate to participation rates observed in real programs.
- We are also exploring whether we other recent COVID recovery studies help contextualize potential responses.

------------------------------------------------------------------------

## Two ways to look at the contrast: the baseline 2024 distribution or the post-intervention distribution

We start with *g*(*p*) = −*D*(*p*)/*S*, where *D*(*p*) = *Q*<sub>2024</sub>(*p*) − *Q*<sub>2019</sub>(*p*) is the observed quantile difference in NAEP score points and *S* is the 2019 national SD. *g*(*p*) is the effect size a fully-covered intervention would need to deliver at percentile *p* to bring that percentile back to its 2019 value. Notation for the whole memo: *F*<sub>0</sub> is the baseline 2024 CDF, the distribution before any program runs, with quantile function *Q*<sub>0</sub> = *F*<sub>0</sub><sup>−1</sup> (so *Q*<sub>0</sub> = *Q*<sub>2024</sub>); *F*<sub>1</sub> and *Q*<sub>1</sub> = *F*<sub>1</sub><sup>−1</sup> are the post-intervention CDF and quantile function a program leaves behind, constructed in section 2b; *π*(*p*) is the participation rate at percentile *p* and *δ* is the treated effect in score points. The two contrasts below differ in which CDF the percentile indexes. The first evaluates *Q*<sub>0</sub>(*p*) + *π*(*p*) ⋅ *δ*: membership is fixed before any program runs, and we follow those students. The second evaluates *Q*<sub>1</sub>(*p*): percentiles are read off the post-intervention distribution, after treated students reshuffle. Each has an analog in the treatment-effects literature (heterogeneity by baseline achievement and the unconditional quantile treatment effect, respectively); the analogy is developed in section 2b.

**1. Baseline 2024 distribution: *g*(*p*) on its own.** Here a percentile is a position in the 2024 distribution before any intervention runs, and the students standing there form a fixed group. We ask how large a requirement that group faces. This is the level comparison: restoring p10 requires 0.26 to 0.29 SD across the featured cells, at or above the 75th percentile of interventions covered in Kraft (2020); restoring the top decile requires 0.03 to 0.13 SD, near or below the median. In this contrast, we fix the percentile (e.g. *p* = 10), hold group membership fixed at baseline, and ask what effect sizes would close *g*(*p*) at various treatment participation rates. One definition matters here: the group answer at percentile *p* is *Q*<sub>0</sub>(*p*) + *π*(*p*) ⋅ *δ*, so in this contrast restore means *π*(*p*) ⋅ *δ* = *g*(*p*) ⋅ *S*. That coincides with returning the marginal percentile to its 2019 value only when no treated student crosses the percentile; section 2b quantifies the wedge between the two readings. The analogy to a heterogeneity analysis by baseline achievement is a linkage to the treatment-effects literature rather than the actual approach: we assume no correlation between the treated effect and baseline achievement, so the effect is constant by design and group differences come only from participation rates and from the size of each group’s requirement *g*(*p*), never from differential gains.

**2. Post-intervention distribution: *g*(*p*) − *g*(*p̃*), for *p* ≠ *p̃*.** Here the object is the marginal score distribution itself, compared percentile by percentile without following any student. Before any program runs, the comparison distribution is 2019: *D*(*p*) = *Q*<sub>0</sub>(*p*) − *Q*<sub>2019</sub>(*p*) compares the 2024 and 2019 CDFs at percentile *p*, a descriptive quantile difference across cohorts that shares the form of a quantile treatment effect but carries none of its causal content, and the contrast *g*(*p*) − *g*(*p̃*) asks how the shape of the distribution changed. For example, take the 90/10 gap: *g*(90) − *g*(10) is −0.225 SD (Reading G4) and −0.162 SD (Math G8). Restoring the 10th percentile takes a substantially larger effect after accounting for restoring the 90th. Once a program runs, the CDF of interest becomes *F*<sub>1</sub> and the comparison distribution becomes the no-program 2024 distribution *F*<sub>0</sub>: we fix the share of seats available and look at how *g*(*p*) − *g*(*p̃*) varies by different assignment protocols across the full score distribution. That comparison, *Q*<sub>1</sub>(*p*) − *Q*<sub>0</sub>(*p*), is a model-implied unconditional quantile treatment effect, causal only within the simulation’s assumptions, which section 2b states. Membership at a percentile is not fixed here. Treated students can move past untreated neighbors, so the students occupying a percentile after a program need not be the ones who occupied it before.

<!-- The following figure replicates the figures from restricted use data 

![Figure: quantile-difference curves, all six cells](figures/sim/fig9-qd-curves.png)

**Figure: `figures/sim/fig9-qd-curves.png`.** The observed *D*(*p*) itself, for all six cells: the quantile-difference curves that the whole memo is built on. Upward slope shows the loss concentrated at the bottom; this is the picture behind both contrasts above. -->

------------------------------------------------------------------------

## Three results

### 1. The effect size needed for *g*(*p*) = 0 varies sharply by percentile

<table>
<thead>
<tr>
<th></th>
<th>Reading G4</th>
<th>Math G8</th>
</tr>
</thead>
<tbody>
<tr>
<td>Restore p10</td>
<td><strong>0.259 SD</strong></td>
<td><strong>0.288 SD</strong></td>
</tr>
<tr>
<td>Restore p25</td>
<td>0.216 SD</td>
<td>0.255 SD</td>
</tr>
<tr>
<td>Restore p90</td>
<td>0.034 SD</td>
<td>0.126 SD</td>
</tr>
</tbody>
</table>

**Note: restore in this instance means *g*(*p*) = 0**

The metrics in this analysis are not new. These are largely known from RQ1 and RQ2. But in this section, we can characterize *g*(*p*) against the distribution of observed interventions from Kraft (2020). His distribution of 1,942 effects from 747 education RCTs has a median of 0.10 SD, a 75th percentile of 0.25, and a 90th of 0.47. So restoring the bottom decile in either featured cell sits **above the 75th percentile of the distribution of RCT effect sizes in Kraft (2020)**, while restoring the top decile in reading sits below the median.

<figure>
<img src="../figures/sim/fig8-requirements-p10-reading-g4.png" alt="Figure: required effect vs. participation, Reading G4, p10" />
<figcaption aria-hidden="true">Figure: required effect vs. participation, Reading G4, p10</figcaption>
</figure>

<figure>
<img src="../figures/sim/fig8-requirements-p10-reading-g8.png" alt="Figure: required effect vs. participation, Reading G8, p10" />
<figcaption aria-hidden="true">Figure: required effect vs. participation, Reading G8, p10</figcaption>
</figure>

<figure>
<img src="../figures/sim/fig8-requirements-p10-math-g4.png" alt="Figure: required effect vs. participation, Math G4, p10" />
<figcaption aria-hidden="true">Figure: required effect vs. participation, Math G4, p10</figcaption>
</figure>

<figure>
<img src="../figures/sim/fig8-requirements-p10-math-g8.png" alt="Figure: required effect vs. participation, Math G8, p10" />
<figcaption aria-hidden="true">Figure: required effect vs. participation, Math G8, p10</figcaption>
</figure>

<figure>
<img src="../figures/sim/fig8-requirements-p25-reading-g4.png" alt="Figure: required effect vs. participation, Reading G4, p25" />
<figcaption aria-hidden="true">Figure: required effect vs. participation, Reading G4, p25</figcaption>
</figure>

<figure>
<img src="../figures/sim/fig8-requirements-p25-reading-g8.png" alt="Figure: required effect vs. participation, Reading G8, p25" />
<figcaption aria-hidden="true">Figure: required effect vs. participation, Reading G8, p25</figcaption>
</figure>

<figure>
<img src="../figures/sim/fig8-requirements-p25-math-g4.png" alt="Figure: required effect vs. participation, Math G4, p25" />
<figcaption aria-hidden="true">Figure: required effect vs. participation, Math G4, p25</figcaption>
</figure>

<figure>
<img src="../figures/sim/fig8-requirements-p25-math-g8.png" alt="Figure: required effect vs. participation, Math G8, p25" />
<figcaption aria-hidden="true">Figure: required effect vs. participation, Math G8, p25</figcaption>
</figure>

**Note:** The required effect to offset *g*(*p*) plotted against participation, for all four grade-subject cells at both p10 and p25 relative to p(90). Dotted lines mark Kraft’s p(50)/p(75)/p(90) benchmarks. *These are for reference/ team discussion, we won’t include all of them in the paper. We can put most of them in an appendix.*

### 2. Participation compounds the gap at realistic scale

Kraft, Schueler, and Falken (2024) estimate 0.155 SD as the effect for tutoring programs serving at least 1,000 students, although that estimate is not statistically significant. This is the most recent and detailed evidence for large-scale tutoring programs. Non-RCT evidence from large COVID-era programs points to smaller effects at larger scales (e.g. Callen et al. 2025; Lynch et al. 2022). For our purposes, we can view Kraft, Schueler, and Falken’s (2024) 0.155 SD as an upper bound for what a large-scale program delivers.

Throughout, **participation** means tutored students as a share of **all** students at a given percentile, as opposed to elligbility or the eligibility, and it is not the share to which a program is offered.

**The denominator matters** The literature inconsistently defines the denominator. For example, Carbonari et al. report that effective tutoring served 1 to 2 percent of *eligible* students; Robinson et al. report 18.7 percent take-up among students *offered* a platform; Kraft, Schueler and Falken use survey data to assume districts tutor 28 percent of *their students*. Those three denominators differ by an order of magnitude. A program targeting the bottom quartile of students with a 25 percent take-up rate reaches about 6 percent of all students (.25^2).

Callen et al. reports both denominators for the 8 districts: - across the districts, 12.7 percent of all students attended summer school; - only 25 percent targeted students (defined roughly as “low performers”) attended summer school.

The following tables apply the 0.155 SD effect across the participation scenarios and ask how much of the gap is still open, with participation as a share of all students. A program treating a random share *π* of students delivers *π* × 0.155 SD at each percentile, so the remaining gap is *g*(*p*) − *π* × 0.155. “Closed” means the program delivers at least the required gain.

**Remaining gap after a 0.155 SD program, in 2019 national SD:**

**Reading G4**

<table style="width:100%;">
<colgroup>
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
</colgroup>
<thead>
<tr>
<th>Participation</th>
<th>p10</th>
<th>p25</th>
<th>p50</th>
<th>p75</th>
<th>p90</th>
</tr>
</thead>
<tbody>
<tr>
<td>100 percent (universal)</td>
<td>0.10</td>
<td>0.06</td>
<td>closed</td>
<td>closed</td>
<td>closed</td>
</tr>
<tr>
<td>28 percent (district high-dosage tutoring)</td>
<td>0.22</td>
<td>0.17</td>
<td>0.10</td>
<td>0.04</td>
<td>closed</td>
</tr>
<tr>
<td>18.7 percent (observed opt-in take-up)</td>
<td>0.23</td>
<td>0.19</td>
<td>0.12</td>
<td>0.05</td>
<td>&lt;0.01</td>
</tr>
<tr>
<td>13 percent (summer program reach)</td>
<td>0.24</td>
<td>0.20</td>
<td>0.13</td>
<td>0.06</td>
<td>0.01</td>
</tr>
</tbody>
</table>

**Reading G8**

<table style="width:100%;">
<colgroup>
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
</colgroup>
<thead>
<tr>
<th>Participation</th>
<th>p10</th>
<th>p25</th>
<th>p50</th>
<th>p75</th>
<th>p90</th>
</tr>
</thead>
<tbody>
<tr>
<td>100 percent (universal)</td>
<td>0.08</td>
<td>0.04</td>
<td>closed</td>
<td>closed</td>
<td>closed</td>
</tr>
<tr>
<td>28 percent (district high-dosage tutoring)</td>
<td>0.19</td>
<td>0.15</td>
<td>0.09</td>
<td>0.04</td>
<td>0.01</td>
</tr>
<tr>
<td>18.7 percent (observed opt-in take-up)</td>
<td>0.21</td>
<td>0.16</td>
<td>0.10</td>
<td>0.06</td>
<td>0.02</td>
</tr>
<tr>
<td>13 percent (summer program reach)</td>
<td>0.22</td>
<td>0.17</td>
<td>0.11</td>
<td>0.06</td>
<td>0.03</td>
</tr>
</tbody>
</table>

**Reading G12**

<table style="width:100%;">
<colgroup>
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
</colgroup>
<thead>
<tr>
<th>Participation</th>
<th>p10</th>
<th>p25</th>
<th>p50</th>
<th>p75</th>
<th>p90</th>
</tr>
</thead>
<tbody>
<tr>
<td>100 percent (universal)</td>
<td>closed</td>
<td>closed</td>
<td>closed</td>
<td>closed</td>
<td>closed</td>
</tr>
<tr>
<td>28 percent (district high-dosage tutoring)</td>
<td>0.06</td>
<td>0.02</td>
<td>0.01</td>
<td>0.02</td>
<td>0.02</td>
</tr>
<tr>
<td>18.7 percent (observed opt-in take-up)</td>
<td>0.07</td>
<td>0.04</td>
<td>0.02</td>
<td>0.03</td>
<td>0.03</td>
</tr>
<tr>
<td>13 percent (summer program reach)</td>
<td>0.08</td>
<td>0.05</td>
<td>0.03</td>
<td>0.04</td>
<td>0.04</td>
</tr>
</tbody>
</table>

**Math G4**

<table style="width:100%;">
<colgroup>
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
</colgroup>
<thead>
<tr>
<th>Participation</th>
<th>p10</th>
<th>p25</th>
<th>p50</th>
<th>p75</th>
<th>p90</th>
</tr>
</thead>
<tbody>
<tr>
<td>100 percent (universal)</td>
<td>0.10</td>
<td>0.01</td>
<td>closed</td>
<td>closed</td>
<td>closed</td>
</tr>
<tr>
<td>28 percent (district high-dosage tutoring)</td>
<td>0.21</td>
<td>0.12</td>
<td>0.02</td>
<td>closed</td>
<td>closed</td>
</tr>
<tr>
<td>18.7 percent (observed opt-in take-up)</td>
<td>0.22</td>
<td>0.13</td>
<td>0.04</td>
<td>closed</td>
<td>closed</td>
</tr>
<tr>
<td>13 percent (summer program reach)</td>
<td>0.23</td>
<td>0.14</td>
<td>0.05</td>
<td>closed</td>
<td>closed</td>
</tr>
</tbody>
</table>

**Math G8**

<table style="width:100%;">
<colgroup>
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
</colgroup>
<thead>
<tr>
<th>Participation</th>
<th>p10</th>
<th>p25</th>
<th>p50</th>
<th>p75</th>
<th>p90</th>
</tr>
</thead>
<tbody>
<tr>
<td>100 percent (universal)</td>
<td>0.13</td>
<td>0.10</td>
<td>0.06</td>
<td>0.01</td>
<td>closed</td>
</tr>
<tr>
<td>28 percent (district high-dosage tutoring)</td>
<td>0.24</td>
<td>0.21</td>
<td>0.17</td>
<td>0.12</td>
<td>0.08</td>
</tr>
<tr>
<td>18.7 percent (observed opt-in take-up)</td>
<td>0.26</td>
<td>0.23</td>
<td>0.18</td>
<td>0.13</td>
<td>0.10</td>
</tr>
<tr>
<td>13 percent (summer program reach)</td>
<td>0.27</td>
<td>0.24</td>
<td>0.19</td>
<td>0.14</td>
<td>0.11</td>
</tr>
</tbody>
</table>

**Math G12**

<table style="width:100%;">
<colgroup>
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
<col style="width: 16%" />
</colgroup>
<thead>
<tr>
<th>Participation</th>
<th>p10</th>
<th>p25</th>
<th>p50</th>
<th>p75</th>
<th>p90</th>
</tr>
</thead>
<tbody>
<tr>
<td>100 percent (universal)</td>
<td>closed</td>
<td>closed</td>
<td>closed</td>
<td>closed</td>
<td>closed</td>
</tr>
<tr>
<td>28 percent (district high-dosage tutoring)</td>
<td>0.09</td>
<td>0.10</td>
<td>0.07</td>
<td>0.04</td>
<td>closed</td>
</tr>
<tr>
<td>18.7 percent (observed opt-in take-up)</td>
<td>0.11</td>
<td>0.11</td>
<td>0.09</td>
<td>0.05</td>
<td>closed</td>
</tr>
<tr>
<td>13 percent (summer program reach)</td>
<td>0.12</td>
<td>0.12</td>
<td>0.10</td>
<td>0.06</td>
<td>closed</td>
</tr>
</tbody>
</table>

Read any panel across a row: even at full participation, the best-evidenced at-scale program closes the median and everything above it in reading while leaving 0.10 SD open at the 10th percentile in Reading G4. Math G8 is the hardest cell; universal coverage still leaves a gap at every percentile except the 90th. Read down a column: at Reading G4 p10, the remaining gap grows from 0.10 SD under universal coverage to 0.24 SD at summer-program reach, nearly the entire original requirement of 0.26 SD. Grade 12 is the mirror image; a universal 0.155 SD program more than restores 2019 at every percentile in both subjects.

**Note: I need better citations/descriptions for the various participation rate scenarios**

### 2b. Two distinct policy questions

The participation results show how to help a targeted group. They also help us evaluate how to distribute a fixed seat budget across a population.

**“How do I help a targeted group?”** A district picks a group, say the bottom decile, and asks what a program must deliver to close that group’s gap relative to some threshold. Seats are treated as available. The tables and figures in section 1 answer this.

**“How do I help my whole district?”** Now the seat budget is fixed. Every seat given to a student at the median is a seat denied to a student at the 10th percentile. This becomes an allocation program. How should a district spread a scarce resource, and how does that affect the shape of the distribution.

The two can give conflicting answers. A rule that looks generous to the bottom in the first frame may prove unaffordable in the second. A rule that raises the district mean in the second may widen the very gap the first set out to close.

We test four allocation rules, each spending the same seats and delivering the same 0.155 SD effect, but in different ways. Each rule takes a seat budget *B* (a share of all students) and answers one question: what share of students at percentile *p* holds a seat? **Note:** The two shape-based rules share a final step, the water-fill:

- **Bottom-up (lowest scorers first)**: Give all available seats to students at the lowest percentiles first.

  1.  Sort students from lowest score to highest.
  2.  Give a seat to each student in that order until the seats run out.
  3.  Every student below the cutoff percentile (100 ⋅ *B*) now holds a seat; nobody above it does.

- **Proportional (untargeted)**: Give the program to students uniformly across the distribution, regardless of achievement.

  1.  Offer every percentile the same participation rate, *B*.

- **Opt-in gradient**: Allocate seats as students take them up voluntarily, with take-up rising by achievement. Robinson, Bisht, and Loeb (2025) measured roughly a 2:1 take-up contrast between higher and lower performers offered a tutoring platform; we use a stylized gradient in that spirit rather than an estimate of any one program. Take-up doubles every 40 percentile points across a ramp from p10 to p90 (10 percent at p10, 20 at p50, 40 at p90), held flat outside the ramp, since extrapolating past the anchors it was built on has no support. A constant doubling distance means constant proportional growth per percentile point. That makes the curve an exponential. We rescale every rule’s curve so its population mean equals *B*. The rescaled curve first touches 100 percent participation at *B* = 55.8 percent; past that point we cap and redistribute the freed seats downward, the water-filling described below, so the budget is spent in full.

  1.  Set each percentile’s take-up weight to 10 percent at p10, doubling every 40 percentile points (20 percent at p50, 40 percent at p90), flat outside \[p10, p90\].
  2.  Rescale all weights by one constant so their population mean equals *B*.
  3.  Water-fill (below).

- **Eligibility screen (ECONDIS)**: Target economic disadvantage as a proxy for the bottom decile. Seats follow the measured share of economically disadvantaged students at each percentile, rescaled to the budget. Where that share would carry a percentile past 100 percent participation we cap it and hand the freed seats back to the percentiles still under the cap, repeating until the budget is exhausted. The rule therefore spends its full allocation at every budget, and at full coverage it too collapses into the proportional rule.

  1.  Set each percentile’s weight to the measured share of economically disadvantaged students at that percentile.
  2.  Rescale all weights by one constant so their population mean equals *B*.
  3.  Water-fill (below).

- *Water-fill (shared subroutine)*

  1.  If no percentile’s rate exceeds 100 percent, stop.
  2.  Cap every percentile above 100 percent at exactly 100.
  3.  Count the seats the caps freed, and hand them to the uncapped percentiles in proportion to their weights.
  4.  Go to step 1.

The subroutine matters because naive clipping loses the freed seats. Applied to the eligibility screen at full budget, naive clipping spends only 84 percent of its allocation, and the rules stop being comparable at equal cost.

**As a figure.** The curves below show what share of each percentile holds a seat under each rule, at four example budgets. Bottom-up is a step; proportional is flat; the opt-in gradient rises with achievement; the screen falls. The opt-in curve is flat above p90 at every budget, the built-in edge of the ramp; the plateau that spreads down from the top in the 75 percent panel is the water-fill at work.

<figure>
<img src="../figures/sim/fig15-allocation-curves-reading-g4.png" alt="Figure: participation rate by percentile under each rule" />
<figcaption aria-hidden="true">Figure: participation rate by percentile under each rule</figcaption>
</figure>

**As tables.** The same curves read at the five target percentiles. Each row’s population mean equals its budget. The rules differ in who gets access to the intervention.

*Participation share (percent) at 13 percent of seats:*

<table>
<thead>
<tr>
<th>Rule</th>
<th>p10</th>
<th>p25</th>
<th>p50</th>
<th>p75</th>
<th>p90</th>
</tr>
</thead>
<tbody>
<tr>
<td>Bottom-up (lowest first)</td>
<td>100</td>
<td>0</td>
<td>0</td>
<td>0</td>
<td>0</td>
</tr>
<tr>
<td>Proportional (untargeted)</td>
<td>13</td>
<td>13</td>
<td>13</td>
<td>13</td>
<td>13</td>
</tr>
<tr>
<td>Opt-in gradient</td>
<td>5.8</td>
<td>7.6</td>
<td>11.7</td>
<td>18.0</td>
<td>23.3</td>
</tr>
<tr>
<td>Eligibility screen (ECONDIS)</td>
<td>19.8</td>
<td>17.6</td>
<td>12.2</td>
<td>8.8</td>
<td>6.8</td>
</tr>
</tbody>
</table>

*Participation share (percent) at 25 percent of seats:*

<table>
<thead>
<tr>
<th>Rule</th>
<th>p10</th>
<th>p25</th>
<th>p50</th>
<th>p75</th>
<th>p90</th>
</tr>
</thead>
<tbody>
<tr>
<td>Bottom-up (lowest first)</td>
<td>100</td>
<td>100</td>
<td>0</td>
<td>0</td>
<td>0</td>
</tr>
<tr>
<td>Proportional (untargeted)</td>
<td>25</td>
<td>25</td>
<td>25</td>
<td>25</td>
<td>25</td>
</tr>
<tr>
<td>Opt-in gradient</td>
<td>11.2</td>
<td>14.5</td>
<td>22.4</td>
<td>34.6</td>
<td>44.8</td>
</tr>
<tr>
<td>Eligibility screen (ECONDIS)</td>
<td>38.1</td>
<td>33.8</td>
<td>23.5</td>
<td>17.0</td>
<td>13.2</td>
</tr>
</tbody>
</table>

*Participation share (percent) at 50 percent of seats:*

<table>
<thead>
<tr>
<th>Rule</th>
<th>p10</th>
<th>p25</th>
<th>p50</th>
<th>p75</th>
<th>p90</th>
</tr>
</thead>
<tbody>
<tr>
<td>Bottom-up (lowest first)</td>
<td>100</td>
<td>100</td>
<td>100</td>
<td>0</td>
<td>0</td>
</tr>
<tr>
<td>Proportional (untargeted)</td>
<td>50</td>
<td>50</td>
<td>50</td>
<td>50</td>
<td>50</td>
</tr>
<tr>
<td>Opt-in gradient</td>
<td>22.4</td>
<td>29.1</td>
<td>44.8</td>
<td>69.1</td>
<td>89.5</td>
</tr>
<tr>
<td>Eligibility screen (ECONDIS)</td>
<td>76.2</td>
<td>67.6</td>
<td>46.9</td>
<td>34.0</td>
<td>26.3</td>
</tr>
</tbody>
</table>

*Participation share (percent) at 75 percent of seats:*

<table>
<thead>
<tr>
<th>Rule</th>
<th>p10</th>
<th>p25</th>
<th>p50</th>
<th>p75</th>
<th>p90</th>
</tr>
</thead>
<tbody>
<tr>
<td>Bottom-up (lowest first)</td>
<td>100</td>
<td>100</td>
<td>100</td>
<td>100</td>
<td>0</td>
</tr>
<tr>
<td>Proportional (untargeted)</td>
<td>75</td>
<td>75</td>
<td>75</td>
<td>75</td>
<td>75</td>
</tr>
<tr>
<td>Opt-in gradient</td>
<td>39.3</td>
<td>50.9</td>
<td>78.5</td>
<td>100</td>
<td>100</td>
</tr>
<tr>
<td>Eligibility screen (ECONDIS)</td>
<td>100</td>
<td>100</td>
<td>74.6</td>
<td>54.1</td>
<td>41.8</td>
</tr>
</tbody>
</table>

**The same two ways to think about this question: the baseline distribution or the post-intervention distribution**

One question is about **the baseline distribution**: fix students at their pre-program percentiles and follow them. Take the students who were sitting at the 10th percentile, run the program, and ask how they did against the students who were sitting at the 90th. Membership in each group is fixed at the start, so it makes no difference whether anyone overtook anyone else.

The other question is about **the post-intervention distribution**. Run the program, let students reshuffle, and ask how the score at the 10th percentile compares to the score at the 90th. Membership in each group is not fixed: treated students can move past untreated neighbors, so the students occupying a percentile afterward need not be the ones who occupied it before. The post-intervention 90/10 gap can also be set against its 2019 counterpart, but the object of interest is the width of the post-intervention distribution itself.

To answer the second question, we need to estimate a post-intervention distribution from the public data takes one further step. The natural shortcut is to move each percentile by its participation rate times the treated effect, so that a rule reaching 13 percent of students at percentile *p* lifts that percentile by 0.13 ⋅ *δ*. That is correct only if every student at *p* receives a partial dose sized to the participation rate. Real coverage does not work that way. A program reaching 13 percent of students delivers the whole effect to 13 percent of them and nothing to the other 87 percent, so the post-intervention population is a mixture of a treated component and an untreated one. Mixing a distribution with a shifted copy of itself does not merely move it, it spreads it, because treated students move past untreated neighbors who stay exactly where they were.

We therefore compute the mixture rather than the shortcut. We rebuild a quantile function for the 2024 distribution from the five published percentiles, interpolating monotonically between them and fitting normal tails outside p10 and p90. Recall *F*<sub>0</sub> and *Q*<sub>0</sub> = *F*<sub>0</sub><sup>−1</sup> from the notation at the top of the memo (here the no-program distribution is the baseline 2024 distribution), and write *u* for a rank in the no-program distribution, a position stated as a share between 0 and 1, so that *Q*<sub>0</sub>(*u*) is the score of the student standing at position *u*. At each rank *u* we leave weight 1 − *π*(*u*) at *Q*<sub>0</sub>(*u*) and move weight *π*(*u*) to *Q*<sub>0</sub>(*u*) + *δ*; the combined population defines the post-intervention CDF *F*<sub>1</sub> and its quantile function *Q*<sub>1</sub> = *F*<sub>1</sub><sup>−1</sup>, and we read the post-intervention percentiles off *Q*<sub>1</sub>. Where *π* is 0 or 1, as under bottom-up allocation, it reduces to exact rank-preserving assignment, so all four rules run through one calculation. The reconstruction reproduces the published percentiles exactly at a zero budget by construction, and the results move by less than 0.01 points when the rank grid is refined fivefold.

We assume who takes part is independent of how much they would gain. The rules already carry selection across percentiles, which is the entire content of the opt-in gradient; this is the further claim that there is no selection on gains within a percentile.

In the language of the treatment-effects literature, these are two familiar estimands, the same pair introduced in the “Two ways to look at the contrast” section above. The baseline-distribution question takes the form of a heterogeneity analysis by baseline achievement: fix subgroups by pre-program rank and compare mean changes across subgroups. Because every treated student gains the same *δ* by design, all of the heterogeneity lives in participation, and the subgroup effect is the coverage-weighted mean effect *π*(*p*) ⋅ *δ*, the average gain per student in the subgroup. (We avoid the intent-to-treat label: ITT is defined against an offer or assignment stage, and the allocation rules assign seats directly, with no offer for the effect to be diluted across.) The post-intervention-distribution question is an unconditional quantile treatment effect implied by the model, *Q*<sub>1</sub>(*p*) − *Q*<sub>0</sub>(*p*): it compares the marginal post-intervention distribution with the marginal no-program distribution percentile by percentile, and it is causal only within the simulation’s assumptions (constant *δ*, no selection on gains within a percentile). The estimands agree at a percentile when the program moves no student across it, and separate when treated students cross it. ==NOTE: add citations from (Heckman, Smith, and Clements 1997; Bitler, Gelbach, and Hoynes 2006; Firpo 2007).==

**Note: for the following figures, should we show more than just the 90-10 gap? Some of the what follows is mechanical because the 90%tile isn’t allocated to treatment in most conditions.**

We present the baseline-distribution question first, then the post-intervention-distribution question, for Reading G4, followed by the same pair of tables for Math G8, the second featured cell.

**Remaining 90-10 gap for the students who started at p10 and p90 (baseline-distribution question), Reading G4 (no program: 8.7 points):**

<table style="width:100%;">
<colgroup>
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
</colgroup>
<thead>
<tr>
<th>Allocation rule</th>
<th>10% of seats</th>
<th>13%</th>
<th>25%</th>
<th>50%</th>
<th>75%</th>
<th>100%</th>
</tr>
</thead>
<tbody>
<tr>
<td>Bottom-up (lowest scorers first)</td>
<td><strong>2.7</strong></td>
<td><strong>2.7</strong></td>
<td><strong>2.7</strong></td>
<td><strong>2.7</strong></td>
<td><strong>2.7</strong></td>
<td>8.7</td>
</tr>
<tr>
<td>Proportional (untargeted)</td>
<td>8.7</td>
<td>8.7</td>
<td>8.7</td>
<td>8.7</td>
<td>8.7</td>
<td>8.7</td>
</tr>
<tr>
<td>Opt-in gradient</td>
<td>9.5</td>
<td>9.7</td>
<td>10.7</td>
<td>12.7</td>
<td>12.3</td>
<td>8.7</td>
</tr>
<tr>
<td>Eligibility screen (ECONDIS)</td>
<td>8.1</td>
<td>7.9</td>
<td>7.2</td>
<td>5.7</td>
<td>5.2</td>
<td>8.7</td>
</tr>
</tbody>
</table>

Each cell is the gap, in score points, between the average student who started at p90 and the average student who started at p10, after the program runs at that budget. Membership in the two groups is fixed at baseline (e.g. examining heterogeneity by baseline achievement), so a treated student who overtakes an untreated neighbor still counts in the group where they began. Each group’s mean rises by its participation rate times the treated effect, which means the gap moves only when the two groups participate at different rates. That is why the proportional row is flat at 8.7: equal rates at p10 and p90 cancel exactly, at every budget. The post-intervention-distribution question below drops the fixed membership and reads the gap off the post-intervention percentiles instead (e.g. QTE framework), and there even equal rates widen the gap, because a percentile that mixes treated and untreated students spreads out.

In formulas, the two questions differ only in which CDF the percentile indexes. The baseline-distribution answer at percentile *p* reads the rank off *F*<sub>0</sub> and shifts the score attached to it: *Q*<sub>0</sub>(*p*) + *π*(*p*) ⋅ *δ*, so that gap is the no-program gap plus *δ* ⋅ (*π*(90) − *π*(10)). The post-intervention answer reads the rank off *F*<sub>1</sub>: it is *Q*<sub>1</sub>(*p*), the score with a share *p* of the mixture below it, where at each rank *u* (the same 0-to-1 scale *p* lives on, used here as the running variable that sweeps the whole distribution) weight 1 − *π*(*u*) stays at *Q*<sub>0</sub>(*u*) and weight *π*(*u*) moves to *Q*<sub>0</sub>(*u*) + *δ*. The pair to keep in mind is *Q*<sub>0</sub>(*p*) + *π*(*p*) ⋅ *δ* against *Q*<sub>1</sub>(*p*): shift the score attached to a fixed rank, or re-rank the shifted population.

The sharpest disagreement between the two tables is bottom-up allocation at 10 percent of seats, 2.7 against 6.0. It is the boundary case. The budget covers exactly the bottom decile, so the students who started at p10 are treated and their group gains the full effect: with *δ* = 8.7 − 2.7 = 6.0 points (0.155 SD on the Reading G4 scale), the baseline-distribution gap closes to 2.7. The post-intervention p10 rises by less than *δ*. The treated students leapfrog the untreated students who sat between the old p10 and the old p10 plus 6 points; those students do not move, and they refill the bottom of the distribution from behind. Recall that *F*<sub>0</sub>(*v*) is the share of students scoring at or below *v* before the program. The new p10 is the score *v* at which the treated share below, *F*<sub>0</sub>(*v* − *δ*), and the untreated share below, *F*<sub>0</sub>(*v*) − 0.10, sum to 0.10, so *v* solves *F*<sub>0</sub>(*v*) + *F*<sub>0</sub>(*v* − *δ*) = 0.20. That score sits 2.7 points above the old p10, not 6.0, and the gap stays at 6.0. At 13 percent the budget treats a buffer above the 10th percentile, the score standing at the new p10 belongs to a treated student, and the two questions agree at 2.7. The general rule: the two answers split whenever coverage stops at or near the percentile being measured.

The boundary-case number leans on the fitted lower tail, the one modeling choice in the reconstruction, so we recomputed the bottom-up column under three alternative lower-tail specifications: a normal fitted to the local p10-p25 slope, a logistic tail, and a straight-line extension of the p10-p25 segment (`analysis/07-tail-sensitivity.R`; `tables/sim-tail-sensitivity.csv`). At 10 percent of seats the entry moves between 5.7 and 6.2 in Reading G4 and between 3.3 and 4.2 in Math G8; at 13 percent of seats it is 2.7 in every specification in Reading G4 and 0.8 to 0.9 in Math G8. The split between the two questions at the boundary is a feature of coverage stopping at the measured percentile, not an artifact of the tail model.

**Remaining 90-10 gap in the post-intervention distribution (post-intervention-distribution question), Reading G4 (no program: 8.7 points):**

<table style="width:100%;">
<colgroup>
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
</colgroup>
<thead>
<tr>
<th>Allocation rule</th>
<th>10% of seats</th>
<th>13%</th>
<th>25%</th>
<th>50%</th>
<th>75%</th>
<th>100%</th>
</tr>
</thead>
<tbody>
<tr>
<td>Bottom-up (lowest scorers first)</td>
<td>6.0</td>
<td><strong>2.7</strong></td>
<td><strong>2.7</strong></td>
<td><strong>2.7</strong></td>
<td><strong>2.7</strong></td>
<td>8.7</td>
</tr>
<tr>
<td>Proportional (untargeted)</td>
<td>9.1</td>
<td>9.3</td>
<td>9.6</td>
<td>9.8</td>
<td>9.4</td>
<td>8.7</td>
</tr>
<tr>
<td>Opt-in gradient</td>
<td>10.1</td>
<td>10.4</td>
<td>11.7</td>
<td>13.2</td>
<td>12.6</td>
<td>8.7</td>
</tr>
<tr>
<td>Eligibility screen (ECONDIS)</td>
<td>8.5</td>
<td>8.4</td>
<td>8.0</td>
<td>6.7</td>
<td>6.1</td>
<td>8.7</td>
</tr>
</tbody>
</table>

<!-- Distribution-question tables for Reading G8 and Math G4, commented out
for now while the memo features Reading G4 and Math G8.

**Remaining 90-10 gap after the program, Reading G8 (no program: 7.0
points):**

| Allocation rule | 10% of seats | 13% | 25% | 50% | 75% | 100% |
|---|---|---|---|---|---|---|
| Bottom-up (lowest scorers first) | 4.4 | **1.2** | **1.2** | **1.2** | **1.2** | 7.0 |
| Proportional (untargeted) | 7.5 | 7.6 | 7.9 | 8.1 | 7.8 | 7.0 |
| Opt-in gradient | 8.4 | 8.7 | 9.9 | 11.5 | 10.9 | 7.0 |
| Eligibility screen (ECONDIS) | 6.8 | 6.7 | 6.2 | 4.9 | 4.4 | 7.0 |

**Remaining 90-10 gap after the program, Math G4 (no program: 7.9
points):**

| Allocation rule | 10% of seats | 13% | 25% | 50% | 75% | 100% |
|---|---|---|---|---|---|---|
| Bottom-up (lowest scorers first) | 5.7 | **3.0** | **3.0** | **3.0** | **3.0** | 7.9 |
| Proportional (untargeted) | 8.2 | 8.4 | 8.6 | 8.8 | 8.5 | 7.9 |
| Opt-in gradient | 9.0 | 9.3 | 10.3 | 11.6 | 11.1 | 7.9 |
| Eligibility screen (ECONDIS) | 7.7 | 7.6 | 7.2 | 6.1 | 5.7 | 7.9 |

-->

**Remaining 90-10 gap for the students who started at p10 and p90 (baseline-distribution question), Math G8 (no program: 6.4 points):**

<table style="width:100%;">
<colgroup>
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
</colgroup>
<thead>
<tr>
<th>Allocation rule</th>
<th>10% of seats</th>
<th>13%</th>
<th>25%</th>
<th>50%</th>
<th>75%</th>
<th>100%</th>
</tr>
</thead>
<tbody>
<tr>
<td>Bottom-up (lowest scorers first)</td>
<td><strong>0.3</strong></td>
<td><strong>0.3</strong></td>
<td><strong>0.3</strong></td>
<td><strong>0.3</strong></td>
<td><strong>0.3</strong></td>
<td>6.4</td>
</tr>
<tr>
<td>Proportional (untargeted)</td>
<td>6.4</td>
<td>6.4</td>
<td>6.4</td>
<td>6.4</td>
<td>6.4</td>
<td>6.4</td>
</tr>
<tr>
<td>Opt-in gradient</td>
<td>7.3</td>
<td>7.5</td>
<td>8.5</td>
<td>10.6</td>
<td>10.2</td>
<td>6.4</td>
</tr>
<tr>
<td>Eligibility screen (ECONDIS)</td>
<td>5.8</td>
<td>5.6</td>
<td>4.8</td>
<td>3.1</td>
<td>2.7</td>
<td>6.4</td>
</tr>
</tbody>
</table>

**Remaining 90-10 gap in the post-intervention distribution (post-intervention-distribution question), Math G8 (no program: 6.4 points):**

<table style="width:100%;">
<colgroup>
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
<col style="width: 14%" />
</colgroup>
<thead>
<tr>
<th>Allocation rule</th>
<th>10% of seats</th>
<th>13%</th>
<th>25%</th>
<th>50%</th>
<th>75%</th>
<th>100%</th>
</tr>
</thead>
<tbody>
<tr>
<td>Bottom-up (lowest scorers first)</td>
<td>4.0</td>
<td><strong>0.8</strong></td>
<td><strong>0.3</strong></td>
<td><strong>0.3</strong></td>
<td><strong>0.3</strong></td>
<td>6.4</td>
</tr>
<tr>
<td>Proportional (untargeted)</td>
<td>6.9</td>
<td>7.0</td>
<td>7.3</td>
<td>7.7</td>
<td>7.3</td>
<td>6.4</td>
</tr>
<tr>
<td>Opt-in gradient</td>
<td>7.7</td>
<td>8.1</td>
<td>9.3</td>
<td>11.2</td>
<td>10.7</td>
<td>6.4</td>
</tr>
<tr>
<td>Eligibility screen (ECONDIS)</td>
<td>6.2</td>
<td>6.1</td>
<td>5.7</td>
<td>4.1</td>
<td>3.3</td>
<td>6.4</td>
</tr>
</tbody>
</table>

Every row holds the allocation rule and the effect size fixed at 0.155 SD; only the budget changes across the row, so reading across shows what that rule does to the gap as the budget grows from 10 to 100 percent of seats. Reading down a column holds the budget fixed and compares what the four rules do with identical resources. Every rule returns to the no-program gap at full coverage (8.7 in Reading G4, 6.4 in Math G8), which is the one point where the answer is known in advance: if every student holds a seat, allocation cannot change the shape of anything.

**Partial coverage widens the distribution even when it treats everyone equally** Proportional allocation offers every percentile the same rate and targets nobody. Read as a baseline-distribution question, it does nothing to the gap at all: the average student at p10 and the average student at p90 each gain the same *π* ⋅ *δ*. Read as a post-intervention-distribution question, proportional allocation pushes the 90-10 gap from 8.7 to 9.8 points at half coverage. At any partial rate some students move a full 0.155 SD while their neighbors move nothing, and a percentile split that way is wider than the one it started as.

<!-- The 13%/50% side-by-side below is now redundant with the two full
tables above; commented out rather than deleted in case the compact form
is useful later.

**Remaining 90-10 gap under the two questions, Reading G4 (no program: 8.7
points):**

| Rule | Group question, 13% / 50% | Distribution, 13% / 50% |
|---|---|---|
| Bottom-up (lowest scorers first) | 2.7 / 2.7 | 2.7 / 2.7 |
| Proportional (untargeted) | 8.7 / 8.7 | 9.3 / 9.8 |
| Opt-in gradient | 9.7 / 12.7 | 10.4 / 13.2 |
| Eligibility screen (ECONDIS) | 7.9 / 5.7 | 8.4 / 6.7 |

-->

The practical consequence is that the proportional row, not the no-program line, is the bar a targeted rule has to clear. Bottom-up clears it by a wide margin, the eligibility screen clears it modestly at every budget, and the opt-in gradient never does.

**The opt-in gradient adds harm on top of that, and it is the one rule that looks bad under both questions.** At half coverage the distributional gap runs to 13.2 points against 8.7 with no program. Of that 4.5-point widening, 1.1 points is the splitting any partial program produces (the proportional row’s 9.8) and 3.4 points is the take-up gradient itself, so about a quarter of the widening is the price of partial coverage rather than of opt-in behavior.

The gradient survives that subtraction, and the baseline-distribution question is what shows it cleanly. There the proportional rule sits at 8.7 and opt-in sits at 12.7, and the whole 4.0-point difference is attributable to who took up the offer, with no splitting mixed in. So the two readings agree on the substantive point and disagree only on its size: voluntary delivery is worse than untargeted delivery, and untargeted delivery is already worse than doing nothing to the distribution. The gradient’s 4:1 take-up ratio across the p10-to-p90 span is a stylized steepening of the 2:1 contrast Robinson, Bisht, and Loeb (2025) measured.

**Bottom-up allocation is the only rule that closes the gap, and it needs enough seats to clear the target.** At 13 percent of seats and above it cuts the 90-10 gap from 8.7 to 2.7 points, and in Math G8 from 6.4 to 0.8 at 13 percent and to 0.3 from 25 percent on. At exactly 10 percent of seats the distributional answer is only 6.0, and the reason is worth stating because it is a genuine feature of the policy rather than an artifact. A program that treats exactly the bottom decile lifts those students past the untreated students immediately above them, and the new bottom decile refills with students the program never touched. The budget has to overshoot the percentile it is trying to move. The transition is smooth, from 8.3 points at an 8 percent budget to 6.0 at 10 percent to 2.7 at 13.

The practical difficulty is that bottom-up allocation requires identifying the bottom decile. The eligibility-screen row is the honest version of trying: it moves the gap from 8.7 to 8.4 at a realistic budget, which is better than the proportional row’s 9.3 at the same budget but a long way from the 2.7 that knowing the target exactly would buy.

### 3. Targeting works better than expected, but is blunt

Using published within-subgroup percentiles, economic disadvantage captures **82.8 percent of the bottom decile** in Reading G4 while covering 51.0 percent of students.

But it is blunt in a specific way. Because the eligible group is half the population and the bottom decile is a tenth of it, only about **16 percent of the students a fully-implemented program would treat are actually in the bottom decile**. Roughly five in six of the treated sit outside the target. Shifting the target to the bottom quartile improves that to about one in three, which is the strongest argument for reporting p25 alongside p10.

And the screen is degrading where it matters most. Between 2019 and 2024 the economically disadvantaged share of the bottom decile fell from 82.8 to 78.0 percent in Reading G4, with parallel drops in Reading G8 and both grade 4 and 8 mathematics. Grade 12, where the differential decline is small, did not move. Meanwhile the “information not available” category grew from about 6 to about 9 percent in every cell. **The instrument a targeted policy would use became noisier over exactly the period we are studying.**

------------------------------------------------------------------------

## What §6.2 can and cannot say

The current draft asserts that a one-size-fits-all intervention “will not address the differential decline” and that targeted interventions “are necessary.” A one-size-fits-all intervention delivered at partial coverage does not merely fail to close the differential, it widens it (**note: how strongly should we state this?**. What cannot stand is the implication that targeting fixes this: targeting helps only if the screen is sharp, and the honest screen we can build recovers a small part of the distance.

## Items for us to consider.

1.  **Scale.** Restoring the bottom decile requires roughly 0.26 to 0.29 SD, above what even large-scale (1,000+ student) tutoring programs deliver in the best-evidenced RCTs; restoring the top decile requires 0.03 to 0.13 SD. Stated as a contrast, *g*(90) − *g*(10) is −0.225 SD (Reading G4) and −0.162 SD (Math G8): the recovery task is demanding at the bottom and nearly trivial at the top.
2.  **Recruitment matters.** Flesh out evidence about the differential take-up rate for interventions, playing voluntary and mandatory interventions off each other (e.g. what are the trade offs of each design?).
3.  **Constant treatment effect assumption.** Do we need to consider scenarios where treatment effects interact with prior achievement (E.g. neg and pos correlation between treatment effect and prior achievement)? - The allocation results assume that within a percentile, who takes part is independent of how much they would gain. The rules carry selection across percentiles, which is the whole content of the opt-in gradient, but they carry none within one. Selection on gains would move the results in a direction no source in the tutoring literature pins down.
4.  **The key question is untested.** Almost nobody has asked whether interventions help low-performing students more. The 265-RCT tutoring meta-analysis runs no within-study test by baseline achievement, and its authors say plainly that any percentile-varying profile is the modeller’s assumption. The summer meta-analysis could not test it. The two largest post-COVID summer evaluations found no heterogeneity by prior performance. Our distributional results show why that silence matters, so this point belongs in §6.3 as well.
5.  **The interventions with demonstrated bottom-weighted effects are system-level** (Mississippi’s early-literacy policy), not supplemental services, and they operate over years.
6.  **Targeting is not automatically beneficial.** Programs that pull students from core instruction, or substitute prior-grade remediation for scaffolded grade-level content, have produced null or negative effects for the students they intended to help. The distinction is well-designed versus poorly designed, not universal versus targeted.
