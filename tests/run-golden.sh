#!/usr/bin/env bash
# The idea's own acceptance criterion, as a test: a deck written with `title-slides: true`
# must render to the same thing as the deck with the titles typed out by hand.
#
# For each fixtures/<case>.qmd there is a fixtures/<case>.expected.qmd — the same deck,
# no filter, every continuation title written out. Both are rendered to revealjs and
# compared after normalising identifiers and the extension's marker classes.
set -euo pipefail

tests="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QUARTO="${QUARTO:-quarto}"
PANDOC="${PANDOC:-pandoc}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Render from a directory holding the extension exactly as `quarto add` would install it,
# so the tests exercise the installed layout rather than a path only they know about.
cp -r "$tests/../_extensions" "$work/"
cp "$tests/fixtures/"*.qmd "$work/"
cd "$work"

failed=0
for expected in "$tests"/fixtures/*.expected.qmd; do
    case="$(basename "$expected" .expected.qmd)"
    echo "golden: $case"

    "$QUARTO" render "$case.qmd" --to revealjs --output "$case.html" --quiet
    "$QUARTO" render "$case.expected.qmd" --to revealjs --output "$case.expected.html" --quiet

    "$PANDOC" lua "$tests/normalise-deck.lua" "$work/$case.html" > "$work/$case.actual.txt"
    "$PANDOC" lua "$tests/normalise-deck.lua" "$work/$case.expected.html" > "$work/$case.wanted.txt"

    if diff -u "$work/$case.wanted.txt" "$work/$case.actual.txt" > "$work/$case.diff"; then
        echo "  ok   matches the hand-written deck"
    else
        failed=$((failed + 1))
        echo "  FAIL differs from the hand-written deck:"
        sed 's/^/       /' "$work/$case.diff"
    fi
done

if [ "$failed" -gt 0 ]; then
    echo "$failed golden test(s) failed" >&2
    exit 1
fi
echo "golden tests passed"
