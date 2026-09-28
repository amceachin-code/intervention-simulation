#!/usr/bin/env bash
## Run every test in analysis/tests/ and summarize.
##
##   bash analysis/tests/run-all.sh           every tests/test-*.R (fast, no network)
##   bash analysis/tests/run-all.sh --regen   the same, then test-regen.sh, which
##                                            reruns the pipeline from the committed
##                                            cache and cmp's tables/*.csv
##
## The R tests are standalone Rscript files that exit non-zero on failure; this
## runner only collects exit codes, so a new test-*.R file is picked up with no
## change here. Exits non-zero if any test fails. Run from the project root.
##
## Order: the R tests run first because they read the committed outputs as
## they are; test-regen.sh then rewrites tables/ in place (see its header).

set -u

if [ ! -d analysis/tests ]; then
  echo "Run from the project root (analysis/tests not found)." >&2
  exit 2
fi

REGEN=0
for a in "$@"; do
  case "$a" in
    --regen) REGEN=1 ;;
    *) echo "unknown argument: $a (only --regen is accepted)" >&2; exit 2 ;;
  esac
done

LOGDIR="$(mktemp -d "${TMPDIR:-/tmp}/sim-tests.XXXXXX")"
passed=(); failed=()

run_one() {
  ## $1 is the display name; the rest is the command. Full output goes to a
  ## log; on failure the FAIL lines are echoed so the cause is visible here.
  local name="$1"; shift
  local log="$LOGDIR/$(basename "$name").log"
  if "$@" >"$log" 2>&1; then
    echo "  PASS  $name"; passed+=("$name")
  else
    echo "  FAIL  $name (log: $log)"; failed+=("$name")
    grep -E "FAIL|ERROR|Error" "$log" | sed 's/^/          /' | head -20
  fi
}

echo "R tests:"
for t in analysis/tests/test-*.R; do
  run_one "$t" Rscript "$t"
done
if [ "$REGEN" -eq 1 ]; then
  echo "Regeneration test:"
  run_one analysis/tests/test-regen.sh bash analysis/tests/test-regen.sh
fi

echo
echo "Summary: ${#passed[@]} passed, ${#failed[@]} failed (logs in $LOGDIR)"
if [ "${#failed[@]}" -ne 0 ]; then
  for f in "${failed[@]}"; do echo "  failed: $f"; done
  exit 1
fi
[ "$REGEN" -eq 1 ] || echo "(test-regen.sh not run; pass --regen to include it)"
exit 0
