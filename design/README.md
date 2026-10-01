<!-- draft v1, 2026-10-01; sources: docs/cells.js, docs/engine.js, tables/sim-seat-allocation-math-g8.csv -->
# Explorer redesign (design canvas)

Design studies for the next version of the explorer in `docs/`. The live canvas is the claude.ai artifact <https://claude.ai/artifact/DyQayqxs3r5sKGfuwEZpDc> (private to the owner). This folder is a snapshot of its files so the work survives outside that session. It sits outside `docs/` on purpose: GitHub Pages serves `docs/`, and these files only render inside the canvas editor (they load its `support.js`), so they would appear there as broken pages.

## Artboards (`canvas/`)

| File | What it is |
|---|---|
| `Main.dc.html` | Today's explorer, redrawn for Math, grade 8, as the baseline. |
| `A-Tuned.dc.html`, `A-Phone-*.dc.html` | Direction A: the same explorer with a clearer hierarchy, plus two phone screens. Static. |
| `B1-Requirement.dc.html` | Direction B, question 1, reframed as rounds of a program. Working: subject-and-grade buttons for all six cells, a take-up slider (0 to 100%) and a gain slider (0.00 to 0.50 SD), with the research presets as quick picks. |
| `B2-Seats.dc.html` | Direction B, question 2: the four seat-allocation rules side by side at a 28% budget (Math, grade 8). Static. |
| `C-Compare.dc.html` | Direction C: up to four programs compared on one chart and table. Static. |
| `canvas.json` | The canvas index (artboard positions and titles). |

## Where the numbers come from

Static artboards were drawn from `docs/engine.js` and `docs/cells.js` (scenario outputs) and, for B2, `tables/sim-seat-allocation-math-g8.csv` at a 0.28 budget. `scripts/gen-comps.js` and `scripts/gen-b1-static.js` regenerate those chart fragments (run from `docs/`, with an output path argument).

B1 computes everything in its own script block from six hard-coded cell inputs copied from `docs/cells.js` (2019 SD, the 2024 minus 2019 drop at p10 and p90, and the 2019 90-10 gap). The round arithmetic follows the "Same students" (group) estimand with an equal chance of a seat at every percentile:

- one round adds c × g SD at every percentile, so rounds to restore percentile p = g\*(p) / (c × g);
- rounds to reach every student once = 1 / c, if each round serves students who have not had a turn;
- the 90-10 gap does not change, whatever the number of rounds.

These assume gains add up, nothing fades, and a second turn helps as much as the first. Counted across all students instead (the distributional estimand), Math, grade 8 needs one more round at 18.7% take-up and 0.155 SD, and the gap widens slightly while a round is under way. No committed R output covers more than one round, so a production version needs an R reference and a test (the convention in `analysis/tests/test-tool-engine.mjs`).

Checked on 2026-10-01: for all six cells, B1's one-round gain at p10 and its 2024 90-10 gap match `NAEPEngine.scenario` in group mode, and its widening per cell (8.7, 7.0, 1.5, 7.9, 6.4, 4.5) matches the Table 2(a) targets.

## Open items

- `tables/SIM-SUMMARY.md` §7.2, the memo, and `docs/methods.html` ("One program, one year, no fade-out") still use the per-participant (g\*/c) framing that B1 replaces.
- B1's headline and lede are fixed text and read oddly at extreme slider settings; the summary card is computed.
- Chart labels were placed for Math, grade 8; other cells and extreme settings may need label nudging once viewed.
