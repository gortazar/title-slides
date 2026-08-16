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

echo "smoke tests passed"
