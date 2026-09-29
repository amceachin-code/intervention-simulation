#!/usr/bin/env bash
## Regeneration test: rerun the pipeline from the committed API cache and prove
## every tracked CSV in tables/ comes back byte-identical.
##
## Why: the R tests check properties of the committed outputs, but they cannot
## tell whether the committed outputs are what the committed code produces.
## This closes that gap. It is the check to run after any refactor that is
## meant to change nothing (config wiring, helper extraction, comment fixes).
##
## What it does:
##   1. Copies tables/ to a temp directory (the reference).
##   2. Reruns 01 to 06 and 09 (04 and 06 for all four featured cells), and 08
##      only if the local-only raw CCD membership file is present.
##   3. cmp's every tables/*.csv against the reference and exits non-zero on
##      any difference.
##
## What it does NOT do:
##   - Restore anything. The rerun overwrites tables/ and figures/ in place,
##     exactly as a normal run would. Markdown and manifest files carry run
##     dates and git SHAs, so they will differ from the committed copies; use
##     `git diff tables/` to inspect, `git checkout tables/` to discard.
##   - Compare figures. PNG bytes are not stable across runs (embedded
##     metadata, font rasterisation), so a byte comparison would only produce
##     noise.
##   - Touch the network. 01 reads analysis/.cache/, which is tracked, so a
##     fresh clone reproduces without the live API. If the cache is missing
##     this test fails loudly rather than quietly querying NCES.
##
## Usage (from the project root):  bash analysis/tests/test-regen.sh

set -u

if [ ! -f analysis/01-simulations.R ]; then
  echo "Run from the project root (analysis/01-simulations.R not found)." >&2
  exit 2
fi
## Refuse to run without the committed cache: 01 would otherwise hit the live
## API, and a revised NCES number would show up here as a "regression".
if ! ls analysis/.cache/*.json >/dev/null 2>&1; then
  echo "analysis/.cache/ is empty or missing; this test only runs from the committed cache." >&2
  exit 2
fi

## The reference is the working copy of tables/, not HEAD. Say so when they
## differ, because then a PASS means "reproduces the working copy" only.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  dirty_csv="$(git status --porcelain -- 'tables/*.csv' 2>/dev/null)"
  if [ -n "$dirty_csv" ]; then
    echo "NOTE: tables/*.csv differ from HEAD; the reference is the working copy:"
    echo "$dirty_csv" | sed 's/^/        /'
  fi
fi

REF="$(mktemp -d "${TMPDIR:-/tmp}/sim-regen-ref.XXXXXX")"
LOGDIR="$(mktemp -d "${TMPDIR:-/tmp}/sim-regen-log.XXXXXX")"
cp -p tables/* "$REF"/
echo "reference copy of tables/: $REF"
echo "step logs:                 $LOGDIR"

step_fail=0
run_step() {
  ## $1 is a log-file tag; the rest is the command. Output goes to a log so a
  ## passing run stays readable; the log path is printed on failure.
  local tag="$1"; shift
  if "$@" >"$LOGDIR/$tag.log" 2>&1; then
    echo "  ran   $tag"
  else
    echo "  ERROR $tag (see $LOGDIR/$tag.log)"
    step_fail=1
  fi
}

echo "Rerunning the pipeline from the committed cache..."
run_step 01 Rscript analysis/01-simulations.R
run_step 02 Rscript analysis/02-figures.R
run_step 03 Rscript analysis/03-district-cases.R
for c in "Reading G4" "Reading G8" "Math G4" "Math G8"; do
  tag="$(echo "$c" | tr 'A-Z ' 'a-z-')"
  run_step "04-$tag" Rscript analysis/04-district-requirements.R --cell "$c"
  run_step "06-$tag" Rscript analysis/06-seat-allocation.R --cell "$c"
done
run_step 05 Rscript analysis/05-compile-summary.R
## 07 (tail sensitivity) was retired on 2026-09-28: the quantile functions are
## built from the published score distribution, so there is no assumed tail
## left to vary. The number stays unused so later scripts keep their names.
## 08 needs the raw CCD membership file, which is local-only (650 MB, never
## committed). Skipping is not a failure: its committed CSVs are then simply
## compared against themselves.
if ls district-enrollment-data/ccd_lea_052_2324_l_1a_073124/*.csv >/dev/null 2>&1; then
  run_step 08 Rscript analysis/08-district-enrollment.R
else
  echo "  SKIP  08 (raw CCD membership file not present)"
fi
run_step 09 Rscript analysis/09-kraft-benchmarks.R

echo "Comparing tables/*.csv against the reference..."
n_diff=0; n_same=0
for f in "$REF"/*.csv; do
  b="$(basename "$f")"
  if [ ! -f "tables/$b" ]; then
    echo "  MISSING tables/$b"; n_diff=$((n_diff + 1))
  elif cmp -s "$f" "tables/$b"; then
    echo "  same    tables/$b"; n_same=$((n_same + 1))
  else
    echo "  DIFFERS tables/$b"; n_diff=$((n_diff + 1))
  fi
done
## A CSV that appears only after the rerun is also a change in outputs.
for f in tables/*.csv; do
  b="$(basename "$f")"
  [ -f "$REF/$b" ] || { echo "  NEW     tables/$b"; n_diff=$((n_diff + 1)); }
done

## sim-results.rds is gitignored (restricted-data backstop), so a fresh clone
## has no reference copy. When a local one exists, hold it to the same standard.
if [ -f "$REF/sim-results.rds" ]; then
  if cmp -s "$REF/sim-results.rds" tables/sim-results.rds; then
    echo "  same    tables/sim-results.rds"; n_same=$((n_same + 1))
  else
    echo "  DIFFERS tables/sim-results.rds"; n_diff=$((n_diff + 1))
  fi
fi

echo "regen: $n_same identical, $n_diff differing; step errors: $step_fail"
if [ "$n_diff" -ne 0 ] || [ "$step_fail" -ne 0 ]; then
  echo "FAIL: regeneration did not reproduce the committed CSVs."
  exit 1
fi
echo "PASS: every tables/*.csv reproduced byte-for-byte."
