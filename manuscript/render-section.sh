#!/usr/bin/env bash
# Render a Markdown section draft to paste-ready APA (author-date) text.
#
# USAGE (run from the project root, e.g. ~/projects/intervention-simulation):
#   manuscript/render-section.sh manuscript/simulation-memo.md        # writes simulation-memo.rendered.md
#   manuscript/render-section.sh manuscript/simulation-memo.md docx   # also writes simulation-memo.docx
#
# The first argument (the .md file) is REQUIRED. Running the script with no
# argument fails with "source .md required".
#
# Writes <name>.rendered.md next to the source; add "docx" to also write <name>.docx
# (the .docx carries ==highlights== as real Word highlighting).
# Bibliographies: references/references.bib (the subset this project cites)
# Highlighting: wrap text in ==double equals== in the source. The .docx gets native Word (yellow)
# highlighting; the .rendered.md keeps the == markers so they stay visible and searchable.
# Needs pandoc >= 3.0 (built-in --citeproc and the `mark` extension). On the Mac, Homebrew pandoc qualifies.
# In the Claude workspace the system pandoc is 2.9; a current one is installed at
# ~/.local/bin/pandoc when needed (re-download from github.com/jgm/pandoc/releases if missing).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?usage: manuscript/render-section.sh manuscript/<section>.md [docx]}"
OUT="${SRC%.md}.rendered.md"
BIBS=(--bibliography="$ROOT/references/references.bib")
# Use the first pandoc that runs and is version 3 or newer: an Intel build
# left in /usr/local/bin fails with "Bad CPU type" on Apple silicon, so try
# every copy on the PATH (then ~/.local/bin) rather than trusting the first
# one found. Read line by line so a path with a space survives.
PANDOC=""
while IFS= read -r cand; do
  [ -x "$cand" ] || continue
  major="$( { "$cand" --version 2>/dev/null || true; } | head -1 | sed -E 's/^pandoc ([0-9]+).*/\1/')"
  if [[ "$major" =~ ^[0-9]+$ ]] && [ "$major" -ge 3 ]; then PANDOC="$cand"; break; fi
done < <(type -ap pandoc; echo "$HOME/.local/bin/pandoc")
[ -n "$PANDOC" ] || { echo "render-section.sh: no working pandoc 3 or newer found" >&2; exit 1; }
"$PANDOC" --citeproc "${BIBS[@]}" --csl="$ROOT/references/apa.csl" \
  -f markdown+mark -t markdown_strict --wrap=none "$SRC" -o "$OUT"
# newer pandoc emits <span class="nocase"> around brace-protected names; strip it for paste-ready text,
# and turn the mark spans back into ==markers==
TMP="$(mktemp)"
perl -pe 's#<span class="nocase">([^<]*)</span>#$1#g; s#<span class="mark">(.*?)</span>#==$1==#g' "$OUT" > "$TMP"
cat "$TMP" > "$OUT" && rm -f "$TMP"
# Image src attributes come out of pandoc root-relative (e.g. figures/sim/foo.png),
# matching how they're written in the source. Rewrite them relative to OUT's own
# directory so a Markdown preview opened from anywhere (e.g. manuscript/) still
# resolves the images, without touching the source file's paths.
OUTDIR="$(cd "$(dirname "$OUT")" && pwd)"
PREFIX="$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$ROOT" "$OUTDIR")"
[ "$PREFIX" = "." ] || perl -i -pe "s#(<img src=\")(?!https?://|/)#\$1$PREFIX/#g" "$OUT"
echo "wrote $OUT"
if [ "${2:-}" = "docx" ]; then
  # manuscript/reference.docx sets the Word output's styles (12pt Times New Roman, double spaced, 1-inch margins);
  # edit that file's styles in Word to change the output formatting.
  REFDOC=()
  [ -f "$ROOT/manuscript/reference.docx" ] && REFDOC=(--reference-doc="$ROOT/manuscript/reference.docx")
  DOCX="$(cd "$(dirname "${SRC%.md}.docx")" && pwd)/$(basename "${SRC%.md}.docx")"
  "$PANDOC" --citeproc "${BIBS[@]}" --csl="$ROOT/references/apa.csl" -f markdown+mark "${REFDOC[@]}" "$SRC" -o "$DOCX"
  # For tables with 6+ columns, pandoc estimates each column's relative width
  # from its content and, when the total would overflow the page, falls back
  # to a FIXED full-width layout with all columns forced EQUAL -- a long text
  # label next to short numeric columns then wraps across several lines while
  # the numeric columns sit mostly empty. Recompute each column's width from
  # its own longest cell instead of splitting the page evenly.
  DXDIR="$(mktemp -d)"
  unzip -oq "$DOCX" -d "$DXDIR"
  python3 - "$DXDIR/word/document.xml" <<'PYEOF'
import re, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    content = f.read()

# 6.5in content width (12240 page width minus 1440+1440 twip margins), this
# reference.docx's page setup -- reread from document.xml if that ever changes.
TOTAL_TWIPS = 9360
TWIPS_PER_CHAR = 170
MIN_COL = 850
PAD = 300

def col_char_widths(tbl_xml, ncols):
    widths = [0] * ncols
    for row in re.findall(r"<w:tr>.*?</w:tr>", tbl_xml, re.S):
        cells = re.findall(r"<w:tc>.*?</w:tc>", row, re.S)
        for i, cell in enumerate(cells[:ncols]):
            length = len("".join(re.findall(r"<w:t[^>]*>([^<]*)</w:t>", cell)))
            widths[i] = max(widths[i], length)
    return widths

def largest_remainder_round(values, total):
    floors = [int(v) for v in values]
    remainder = total - sum(floors)
    order = sorted(range(len(values)), key=lambda i: values[i] - floors[i], reverse=True)
    for i in order[:max(0, remainder)]:
        floors[i] += 1
    return floors

def allocate(natural, total_budget, min_col, ncols):
    # Every column gets a floor off the top; remaining budget splits
    # proportionally to how far each column's natural width exceeds that
    # floor, so a long label column doesn't starve short numeric siblings.
    base_floor = min(min_col, total_budget / ncols)
    remaining = total_budget - base_floor * ncols
    excess = [max(0.0, n - base_floor) for n in natural]
    total_excess = sum(excess)
    if total_excess <= 0:
        return [total_budget / ncols] * ncols
    return [base_floor + remaining * (e / total_excess) for e in excess]

def fix_table(m):
    tbl = m.group(0)
    ncols = len(re.findall(r'<w:gridCol w:w="\d+" />', tbl))
    if ncols == 0:
        return tbl
    char_widths = col_char_widths(tbl, ncols)
    natural = [max(MIN_COL, w * TWIPS_PER_CHAR + PAD) for w in char_widths]
    widths = largest_remainder_round(
        allocate(natural, TOTAL_TWIPS, MIN_COL, ncols), TOTAL_TWIPS
    )
    new_grid = "<w:tblGrid>" + "".join(f'<w:gridCol w:w="{w}" />' for w in widths) + "</w:tblGrid>"
    tbl = re.sub(r"<w:tblGrid>.*?</w:tblGrid>", new_grid, tbl, count=1, flags=re.S)
    tbl = re.sub(
        r'<w:tblW w:type="[^"]*" w:w="[^"]*" />(<w:tblLayout w:type="fixed" />)?',
        f'<w:tblW w:type="dxa" w:w="{TOTAL_TWIPS}" /><w:tblLayout w:type="fixed" />',
        tbl, count=1,
    )
    return tbl

content = re.sub(r"<w:tbl>.*?</w:tbl>", fix_table, content, flags=re.S)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PYEOF
  # Pandoc already embeds any ![alt](path) image reference into word/media/ with
  # a proper relationship (rIdN.png); nothing further is needed here. Figures
  # must be written in real Markdown image syntax in the source, not as a
  # bold-text "**Figure: `path`**" callout, or pandoc has nothing to embed.
  (cd "$DXDIR" && zip -q -X -r "$DOCX.tmp" .)
  mv "$DOCX.tmp" "$DOCX"
  rm -rf "$DXDIR"
  echo "wrote $DOCX"
fi
