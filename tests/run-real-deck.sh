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
"$QUARTO" render T4-funciones.qmd --to revealjs --output deck.html --quiet

"$PANDOC" lua "$tests/deck-outline.lua" "$work/deck.html" > "$work/outline.txt"

if diff -u "$deck/expected.outline" "$work/outline.txt"; then
    echo "  ok   the deck renders to the slides it should, titles and accents intact"
else
    echo "  FAIL the rendered deck does not match fixtures/real-deck/expected.outline" >&2
    exit 1
fi

# The extension must have added and removed nothing at all on this document.
for marker in title-slides-continuation title-slides-index; do
    if grep -q "$marker" "$work/deck.html"; then
        echo "  FAIL the extension injected $marker into a deck with nothing to do" >&2
        exit 1
    fi
done
echo "  ok   no continuation and no index slide was injected"

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

# The same deck with the filter switched off must produce the same slides. This is the
# strongest available statement of "the extension changed nothing".
sed 's/^title-slides: true$/title-slides: false/; s/^show-index: true$/show-index: false/' \
    T4-funciones.qmd > off.qmd
"$QUARTO" render off.qmd --to revealjs --output off.html --quiet
"$PANDOC" lua "$tests/deck-outline.lua" "$work/off.html" > "$work/off-outline.txt"

if diff -u "$work/off-outline.txt" "$work/outline.txt"; then
    echo "  ok   filter on and filter off give the same slide outline"
else
    echo "  FAIL switching the filter off changes the deck" >&2
    exit 1
fi

echo "real-deck test passed"
