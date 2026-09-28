<!-- codebook v1, 2026-09-18, for Stage 5 of the Kraft target-population coding; sources: the plan in ~/.claude/plans/let-s-create-a-plan-shimmering-quiche.md and the Stage 3 and 4 outputs -->
# Codebook: target population of the Kraft (2023) benchmark studies

## 1. Purpose and unit

Kraft's (2023) effect-size file records what each RCT measured but not whom it served. The paper needs to know how much of each benchmark cell (grade 4 or 8, reading or math, broad tests, sample size 251 or more) comes from studies that targeted low performers, because such studies standardize on a narrower group and so overstate points on a national NAEP scale, while also being the closest analogue to a recovery program aimed at the bottom decile.

The unit of coding is the **study** as Kraft lists it (one `study_id` in `kraft-2023-data/studies/study-list.csv`). Code the sample that produced the effects Kraft recorded. When a report contains several samples or trials, use `es_list`, `n_min`, `n_max`, `grades_all`, and `subjects` in the study list to find the one Kraft used, and say which in `notes`.

Kraft sometimes lists the same trial twice (for example rows 322 and 323, 339 and 341, 600 and 601). Code each row on its own, give the pair identical codes, and name the twin in `notes`.

## 2. The code

Four values for `code`. Pick the first that applies, reading top to bottom.

**`targeted_low`: selection on prior achievement.** The sample was chosen, screened, or referred because of low performance. Triggers: a score cutoff on a prior test or screener; "below grade level", "below proficient", "below the Nth percentile", "failed" or "did not pass" a test; teacher referral or nomination for low achievement or for needing help; response-to-intervention Tier 2 or Tier 3 samples; struggling readers, at-risk students defined by achievement; retained students; mandatory summer school for failing students; credit recovery. Schools or districts chosen because they were low-performing (school improvement lists, priority or focus schools, lowest quartile on state tests) also code here, with `level = school`.

**`targeted_other`: selection on a characteristic other than achievement.** English learners; students with disabilities or an IEP; free or reduced-price lunch eligibility as an individual criterion; schools or districts chosen because they were Title I, high-poverty, high-need, or rural; a racial or ethnic group; gifted or advanced students; behavior, attendance, or dropout risk; homeless, migrant, or foster youth; girls or boys only. A sample defined by a program's own eligibility rule that is not achievement-based (Head Start eligibility, AmeriCorps sites in high-poverty schools) also codes here.

**`universal`: no selection beyond grade, site, or membership.** All students in the participating grades, classrooms, schools, or districts. Whole-school and whole-district programs with no eligibility rule. Lottery samples of applicants to a school or program are `universal` with `opt_in = 1`. A poor, urban, or rural district that participated without being selected on that trait is `universal`; the sample may be 90 percent low-income and still be universal if nothing in the design selected on income.

**`unclear`: the source does not say.** Use it whenever the text does not state an eligibility rule and you would be guessing. An abstract that only reports demographics codes `unclear`, not `universal`. `unclear` is a correct and expected answer, not a failure.

## 3. Tie-breakers

1. A performance criterion plus any other characteristic is `targeted_low` (English learners scoring below a cutoff; Title I schools with students selected on a screener).
2. Selection at two levels: code the student-level rule if there is one, and set `level = both`. A Title I school where all students were served is `targeted_other` with `level = school`; a Title I school where struggling readers were pulled out is `targeted_low` with `level = both`.
3. A baseline screening that did not exclude anyone (everyone was tested, everyone stayed in) does not make a study targeted.
4. A special-education or ELL sample is `targeted_other` even if the intervention is remedial; the selection was on the characteristic, not the score.
5. Reports that give effects for the full sample and for subgroups: code the full sample, set `mixed_samples = 1` if Kraft's effects appear to come from a subgroup, and say so in `notes`.
6. Schools recruited because they had not used the program before, or because they volunteered, are not selected on need; that is `universal` unless another rule applies.
7. Interventions delivered to whole classes but described with phrases such as "struggling" or "at-risk" in the motivation section, not in the sample definition, are coded on the sample definition. Quote the sentence that defines who was in the sample, not the sentence that motivates the program.

## 4. The other fields

| Field | Values | Meaning |
|---|---|---|
| `level` | `student`, `school`, `both`, `none`, `unclear` | Where the selection rule operated. `none` for universal samples. `school` covers districts and classrooms chosen as units. |
| `opt_in` | `0`, `1` | 1 when students or families had to apply, enroll, or volunteer to be in the sample (lottery samples, after-school and summer programs with sign-up, tutoring that required consent to be pulled out). 0 otherwise. |
| `mixed_samples` | `0`, `1` | 1 when Kraft's effects come from a subgroup or from a different sample than the one described. |
| `evidence_quote` | text, under 60 words | Verbatim sentence or clause that states the eligibility rule (or, for `unclear`, the closest description of the sample). No paraphrase. Use straight quotes inside the CSV field only if the source has them. |
| `evidence_location` | text | Page number in the PDF (`p. 7`), or `abstract`, or `WWC sample text`, or `executive summary`. |
| `source_used` | `pdf`, `library`, `abstract`, `wwc-page` | Which text you read. `pdf` covers `text/<key>.txt` from a downloaded or hand-supplied PDF. |
| `confidence` | `high`, `medium`, `low` | `high` needs full text and an explicit eligibility statement. Abstract-only coding is capped at `medium`. `low` when the code rests on an indirect statement or a WWC summary. |
| `resolved_title` | text | Title of the document you coded from, so a reviewer can see you had the right one. |
| `notes` | text | Anything a reviewer needs: twin rows, which trial within a report, doubts, contradictions between sources. |

`coder` is your batch id (`bee-a`, `wwc-b`, and so on) and `date` is `2026-09-18`.

## 5. Where to read

Open the sources in this order and stop at the first that has a sample description:

1. `kraft-2023-data/studies/text/<key>.txt` (full text; may be long).
2. `kraft-2023-data/studies/abstracts/<key>.txt` (abstract; some carry a coder note in the header).
3. `kraft-2023-data/studies/wwc-codes.csv`, the row with your `study_id`: the `setting`, `study_sample`, and `sample_characteristics` columns hold the What Works Clearinghouse's description of the sample. Use it as a source when it is the only one, with `source_used = wwc-page` and `evidence_location = WWC sample text`, and always compare it with your own reading when both exist. Ignore `wwc_code`; do not copy it.

For full text: read the abstract, then search the file for `participants`, `sample`, `eligib`, `selected`, `recruit`, `screen`, `Title I`, `free or reduced`, `English learner`, `struggling`, `below`, `at-risk`, `at risk`, `Tier`, `lottery`, and read the surrounding methods or sample section. For long reports (EEF, i3, IES, MDRC, Mathematica) read the executive summary and the sample or design section only. If a text file is nearly empty or is scan garbage, note `failed-ocr` in `notes` and code from the abstract.

Studies with retrieval status `unresolved` (no document anywhere) get a row with `code = unclear`, `source_used` blank, `confidence = low`, and a note saying no source exists. Do not search the web for them; that was done in Stage 2.

## 6. Worked examples

**Ritter (2000), key `744-ritter-2000`, abstract only.** "The study sample is comprised of 385 elementary school students identified by their teachers as in need of tutoring services. From this pool of 'eligible' students, approximately half (51 percent) were randomly selected." Code `targeted_low`, `level = student`, `opt_in = 0`, `confidence = medium` (abstract), `evidence_location = abstract`.

**Fuchs et al. (2013), keys `322-fuchs-2013` and `323-fuchs-2013`, abstract only.** "At-risk students (n = 259) were randomly assigned to intervention and control." Code `targeted_low`, `level = student`, `confidence = medium`; identical rows for both keys, each naming the other in `notes`.

**Festas et al. (2015), key `281-festas-2015`, abstract only.** Six urban middle schools in Portugal, matched in pairs and randomized; 380 eighth graders. No student rule stated. Code `universal`, `level = none`, `confidence = medium`, quote the sentence about the schools and the 380 students. Note the international setting.

**Gallagher et al. (2017) and Gallagher, Woodworth, and Arshan (2015), keys `339-gallagher-2017` and `341-gallagher-2015`.** Forty-four high-need rural districts were recruited for the trial and randomized; all English language arts classes in grades 7 to 10 took part. The selection was on need and rurality at the district level, with no student rule. Code `targeted_other`, `level = school`, `opt_in = 0`, identical rows for both keys.

**Duncan, Moeller, Schoeneberger, and Hitchcock (2018), key `250-duncan-2018`, full text.** Thirty-two Chicago elementary schools were randomized in October 2015 and 26 remained in Year 2; grade 4 and 5 teachers and their students. The report describes the schools (92 percent eligible for free lunch) but states no poverty or performance criterion for choosing them. Code `universal`, `level = none`, `confidence = high`, and quote the sample sentence from the methods section with its page. **Adjudicated 2026-09-25 (Andrew): `targeted_other`, `level = school`.** Math for All is a program targeted to high-need schools, like Teach For America, so its sites count as selected on need even though the report states no criterion. The coders applied this example as written; the adjudication overrides it for 249 and 250.

**Olson et al. (2012) and Kim et al. (2011), keys `485-olson-2012` and `484-kim-2011`, full text.** The Pathway Project sample was 2,726 English learners in the classrooms of 103 teachers. Code `targeted_other`, `level = student`, `confidence = high`. (Key `483-kim-2011` is a different trial, the after-school READ 180 study of low-performing grade 4 to 6 students, which codes `targeted_low`.)

**Wang and Woodworth (2011), key `970-wang-2011`.** "The study sample included all kindergarten and first-grade students at the three schools that participated in the study." The intervention is a Response to Intervention program, but every student was in the sample. Code `universal`, `level = none`. The program name is not an eligibility rule (tie-breaker 7).

## 7. Output format

Append one row per study to `kraft-2023-data/studies/coding/<batch>.csv` with these columns in this order:

```
study_id, key, code, level, opt_in, mixed_samples, evidence_quote, evidence_location, source_used, coder, date, confidence, resolved_title, notes
```

The header row is already in the file. Use a CSV writer, not string concatenation, so quotes and commas in `evidence_quote` survive. On start, read the file and skip any `study_id` already present, so a restart resumes where you stopped. Never write outside your batch's file.
