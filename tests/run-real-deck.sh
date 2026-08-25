#!/usr/bin/env bash
# Render a real lecture deck that once failed, the way a user renders one.
#
# The failure it guards against was a *resolution* failure: Quarto never found the
# extension, fell back to treating `filters: [title-slides]` as a path to an executable,
# and died before the filter ran. So this test is deliberately built the way a user's
# project is — the extension installed under `_extensions/<owner>/title-slides/`, the
# document beside it, the filter named rather than pathed. A test that pointed the filter
# at a file would pass while the user still could not render.
#
# What it asserts about the deck is that nothing changed: it has no top-level `---` and no
# `#`, so both features are inert on it, and a clean no-op render is the whole point.
set -euo pipefail

tests="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
deck="$tests/fixtures/real-deck"

QUARTO="${QUARTO:-quarto}"
PANDOC="${PANDOC:-pandoc}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# `quarto add gortazar/title-slides` produces exactly this layout.
mkdir -p "$work/_extensions/gortazar"
cp -r "$tests/../_extensions/title-slides" "$work/_extensions/gortazar/"
cp "$deck/T4-funciones.qmd" "$deck/codigus.png" "$work/"
cd "$work"

echo "real-deck: rendering T4-funciones.qmd through an installed extension"
# Deliberately not --quiet: that suppresses Quarto's warnings altogether, and the warning
# is half of what this test is checking.
"$QUARTO" render T4-funciones.qmd --to revealjs --output deck.html > render.log 2>&1

# This is the deck the index rule was changed for. It has fourteen `##` headings and no
# `#` at all: under the old rule it had "no sections" and got a warning instead of an
# index; under the current one its `##` headings are exactly what an index lists.
if grep -q 'show-index is set, but' render.log; then
    echo "  FAIL show-index still says it has nothing to index" >&2
    grep 'show-index' render.log >&2
    exit 1
fi
echo "  ok   show-index no longer claims this deck has nothing to index"

"$PANDOC" lua "$tests/deck-outline.lua" "$work/deck.html" > "$work/outline.txt"

if diff -u "$deck/expected.outline" "$work/outline.txt"; then
    echo "  ok   the deck renders to the slides it should, titles and accents intact"
else
    echo "  FAIL the rendered deck does not match fixtures/real-deck/expected.outline" >&2
    exit 1
fi

# The deck has no top-level `---`, so there is still nothing for the carry to do.
if grep -q 'title-slides-continuation' "$work/deck.html"; then
    echo "  FAIL a continuation was injected into a deck with no rule to carry across" >&2
    exit 1
fi
echo "  ok   no continuation slide was injected"

# One index slide before each of the fourteen slides, and each names one entry in bold.
indexes="$(grep -c '^2 index ' "$work/outline.txt" || true)"
slides="$(grep -c '^2 slide ' "$work/outline.txt" || true)"
if [ "$indexes" -ne "$slides" ] || [ "$indexes" -ne 14 ]; then
    echo "  FAIL expected 14 slides each preceded by an index, got $slides and $indexes" >&2
    exit 1
fi
if grep '^2 index ' "$work/outline.txt" | grep -qv '(1 bold)$'; then
    echo "  FAIL an index slide does not have exactly one bold entry" >&2
    exit 1
fi
echo "  ok   $indexes index slides, one before each of the $slides slides"

# The answered decision: a run of identical adjacent titles is listed once. This deck
# repeats `Definición` twice and `Parámetros por defecto` three times, one of them with a
# trailing space, so fourteen slides collapse to nine entries.
entries="$("$PANDOC" lua "$tests/index-entries.lua" "$work/deck.html")"
if [ "$entries" -ne 9 ]; then
    echo "  FAIL expected the fourteen repeated titles to collapse to 9 entries, got $entries" >&2
    exit 1
fi
echo "  ok   the repeated titles collapse to $entries entries"

# This deck repeats headings — `Definición` twice, `Parámetros por defecto` three times,
# `Retorno de Valores` against `Retorno de valores` — so it arrives full of would-be
# duplicate anchors. Whatever the extension does, every slide must still end up with an
# identifier of its own.
slide_ids="$(grep -o '<section id="[^"]*" class="[^"]*slide[^"]*"' "$work/deck.html" \
    | sed 's/.*id="\([^"]*\)".*/\1/' || true)"
total="$(printf '%s\n' "$slide_ids" | grep -c . || true)"
unique="$(printf '%s\n' "$slide_ids" | sort -u | grep -c . || true)"
if [ "$total" -ne "$unique" ]; then
    echo "  FAIL $total slides but only $unique distinct identifiers" >&2
    printf '%s\n' "$slide_ids" | sort | uniq -d >&2
    exit 1
fi
echo "  ok   $total slides, $unique distinct identifiers despite the repeated headings"

# With the filter switched off the deck must come back to its original fourteen slides:
# the index slides are the only thing the extension adds here, and nothing else moved.
sed 's/^title-slides: true$/title-slides: false/; s/^show-index: true$/show-index: false/' \
    T4-funciones.qmd > off.qmd
"$QUARTO" render off.qmd --to revealjs --output off.html --quiet
"$PANDOC" lua "$tests/deck-outline.lua" "$work/off.html" > "$work/off-outline.txt"

off_slides="$(grep -c '^2 slide ' "$work/off-outline.txt" || true)"
if [ "$off_slides" -ne 14 ] || grep -q '^2 index ' "$work/off-outline.txt"; then
    echo "  FAIL with the filter off the deck should be its plain 14 slides" >&2
    cat "$work/off-outline.txt" >&2
    exit 1
fi
# Every slide the author wrote survives the filter, in the same order.
grep '^2 slide ' "$work/outline.txt" > "$work/on-slides.txt"
if diff -u "$work/off-outline.txt" "$work/on-slides.txt"; then
    echo "  ok   the author's 14 slides are untouched; only index slides were added"
else
    echo "  FAIL the filter changed the author's own slides" >&2
    exit 1
fi

echo "real-deck test passed"
