#!/usr/bin/env bash
# Render the example deck the way a user would and check the slides that come out: how
# many, at what level, which ones the extension titled, and what those titles say.
#
# The unit tests work on the AST and the golden tests compare two renders against each
# other; this one asserts what the rendered deck actually contains.
set -euo pipefail

tests="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QUARTO="${QUARTO:-quarto}"
PANDOC="${PANDOC:-pandoc}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cp -r "$tests/../_extensions" "$work/"
cp "$tests/../example/deck.qmd" "$work/"
cd "$work"

echo "smoke: rendering example/deck.qmd to revealjs"
"$QUARTO" render deck.qmd --to revealjs --output deck.html --quiet

"$PANDOC" lua "$tests/deck-outline.lua" "$work/deck.html" > "$work/outline.txt"

if diff -u "$tests/expected/deck.outline" "$work/outline.txt"; then
    echo "  ok   the deck has the slides and titles it should"
else
    echo "  FAIL the rendered deck does not match tests/expected/deck.outline" >&2
    exit 1
fi

# The point of the whole exercise: the untitled slides came out titled.
continuations="$(grep -c '^2 continuation ' "$work/outline.txt" || true)"
if [ "$continuations" -lt 1 ]; then
    echo "  FAIL no continuation slide was produced" >&2
    exit 1
fi
echo "  ok   $continuations continuation slides carry a title"

# One index slide per section, and no more.
sections="$(grep -c '^1 slide ' "$work/outline.txt" || true)"
indexes="$(grep -c '^2 index ' "$work/outline.txt" || true)"
if [ "$indexes" -ne "$sections" ]; then
    echo "  FAIL $sections sections but $indexes index slides" >&2
    exit 1
fi
if [ "$indexes" -lt 1 ]; then
    echo "  FAIL no index slide was produced" >&2
    exit 1
fi
echo "  ok   $indexes index slides, one per section"

# Exactly one entry emboldened on each, and it is the section that comes next: every
# index line names its current entry, and the line after it is that section's slide.
if grep '^2 index ' "$work/outline.txt" | grep -qv '(1 bold)$'; then
    echo "  FAIL an index slide does not have exactly one bold entry" >&2
    grep '^2 index ' "$work/outline.txt" | grep -v '(1 bold)$' >&2
    exit 1
fi
expected=""
while IFS= read -r line; do
    if [ -n "$expected" ]; then
        if [ "$line" != "1 slide $expected" ]; then
            echo "  FAIL an index emboldened \"$expected\" but \"$line\" follows it" >&2
            exit 1
        fi
        expected=""
    fi
    case "$line" in
        "2 index "*)
            expected="${line#* -> }"
            expected="${expected% (*}"
            ;;
    esac
done < "$work/outline.txt"
if [ -n "$expected" ]; then
    echo "  FAIL an index slide is the last slide, with no section after it" >&2
    exit 1
fi
echo "  ok   each index emboldens exactly the section it precedes"

echo "smoke tests passed"
