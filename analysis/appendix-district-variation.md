# Appendix note: district-level variation and the national targeting estimates

<!-- draft v1, 2026-09-04; appendix/supplement candidate, NOT a change to the main analysis -->

**Status: optional nuance.** This does not change the targeting story in the main
text. It qualifies how the national estimates should be read, and it is written
so it can be dropped into the supplement or cut entirely without disturbing
anything else.

## The issue

Every simulation estimate is national. The restoration requirement g*(p), the coverage
arithmetic, and the composition of the bottom decile and quartile are all
computed by pooling students across the country. But achievement is not
distributed uniformly across districts, and a national percentile mixes two
different kinds of low-scoring student:

1. students near the bottom of their own district's distribution, and
2. students in districts whose whole distribution sits low.

A recovery program is administered by districts and states, not by the nation,
so which of these dominates matters for how the requirement should be read.

## What the library says about the size of between-unit variation

- **Shear, Taylor & Fahle (2026):** between-school ICCs average **0.194 in math
  and 0.168 in reading** across all 50 states, and rose 10 to 18 percent in the
  elementary grades between 2009 and 2019. Between-school economic segregation is
  the single strongest predictor (R-squared 0.468).
- **Atteberry & McEachin (2020):** roughly **75 to 80 percent of the variance in
  achievement *growth*** is between schools, against a modest school share of the
  variance in *levels*. The distinction matters here: the simulations operate on levels.
- **Callen et al. (2024):** the pandemic-era divergence itself split differently
  by subject. In mathematics, schools accounted for about **three quarters** of
  the extra loss at the bottom; in reading, most of the extra loss occurred
  **within** schools. So the between/within mix is not a fixed property of the
  system, and it differs across the two subjects this paper reports.
- **Fahle et al. (2023):** within districts, students of different racial and
  economic groups lost similar amounts, while districts differed sharply from one
  another.

Note these are between-*school* figures. Between-*district* variation is smaller,
since districts pool across schools. ==If this appendix is used, cite a
between-district ICC directly rather than inferring one from the school-level
numbers.==

## What that implies for the national estimates

A simple decomposition makes the point. Simulating a national population as a
between-district component plus a within-district component, and asking where the
national bottom tail actually sits:

| Between-district ICC | Share of the national p10 from bottom-quartile districts | Districts containing at least one national-p10 student |
|---|---|---|
| 0.05 | 39% | 3,000 of 3,000 |
| 0.12 | 48% | 2,998 of 3,000 |
| 0.20 | 54% | 2,984 of 3,000 |

(Illustrative simulation, 3,000 districts of 400 students. Not an empirical
estimate; it shows the shape of the arithmetic, not a measured quantity.)

Two things follow, and they pull in opposite directions.

**The national picture holds up.** Even at implausibly high between-district
variation, roughly half the national bottom decile comes from districts that are
*not* in the lowest quartile, and the bottom decile is spread across essentially
every district in the country. There is no configuration in which the national
bottom tail is concentrated in a small number of identifiable places. The
targeting arithmetic in the main text, that no observable screen isolates the
bottom decile, is if anything reinforced.

**But the requirement is heterogeneous.** A single national g*(p) averages over
districts facing very different tasks. A district whose own distribution sits a
third of a standard deviation below the national mean needs a substantially
larger gain to bring its students to the *national* 2019 tenth percentile than
the national average figure implies, and a high-achieving district needs less.
The national number is the right quantity for a national policy claim and the
wrong one for a district planning exercise.

## How this could be used

Three options, in increasing order of cost:

1. **A caveat sentence in the Limitations.** "All estimates are national. Because
   achievement varies substantially across districts, the requirement facing any
   individual district may be materially larger or smaller than the national
   figure, and the composition of its own bottom decile will differ from the
   national composition." This is nearly free and probably sufficient.
2. **A short appendix** reproducing the argument above with a properly sourced
   between-district ICC, making explicit that the national bottom tail is
   dispersed rather than concentrated.
3. **A state-level extension.** The NAEP Data Service API exposes state
   jurisdictions, so the entire simulation pipeline could be re-run per state at no
   additional data cost, replacing the simulation above with measured variation
   across 51 jurisdictions. **I spot-checked three states and the spread is
   large:**

   | State | D(p10) | D(p90) | Differential change |
   |---|---|---|---|
   | Massachusetts | -14.3 | **+1.0** | **15.3** |
   | Mississippi | -4.0 | **+1.3** | 5.2 |
   | California | -5.8 | -1.9 | 3.8 |
   | *National* | *-10.0* | *-1.3* | *8.7* |

   (Grade 4 reading, 2019 to 2024.) Massachusetts's differential change is three
   times California's and nearly twice the national figure. In both Massachusetts
   and Mississippi the 90th percentile actually **rose** while the 10th fell
   sharply, which is the divergence pattern in its purest form. The national 8.7
   is an average over states facing very different situations, and a state-level
   requirement g*(p10) would range at least from about 0.10 SD to about 0.37 SD
   on these three alone. Computed against the national 2019 SD of 38.5: MA 0.371,
   CA 0.151, MS 0.104, against the national 0.260. ==If this is pursued, use each
   state's own SD rather than the national one, and say which; the choice changes
   whether the comparison is "relative to national spread" or "relative to that
   state's own spread," and those answer different questions.==

   This is a genuine extension rather than a caveat, and it would take about a
   day. It is also the version most likely to interest a policy audience, since
   recovery decisions are made at the state level.

## Recommendation

Option 1 for this paper, with option 2 if a reviewer presses on external
validity. Option 3 is a good idea but belongs in a follow-up: it changes the
paper's scope from a national distributional analysis to a comparative one, and
the word budget is already tight at 8,000 to 10,000.

Worth noting that the paper's own precursor, Castellano et al. (2025), reports
the 2019-to-2024 percentile changes **by state** and finds the same upward-sloping
shape in most states, including high-scoring ones. That is existing evidence that
the distributional pattern is not an artifact of national pooling, and citing it
may do the work of option 2 in a single sentence.
