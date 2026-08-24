#!/usr/bin/env bash
# Install the published extension into an empty directory and render through it.
#
# This is the check that would have caught the reported failure. A user's document names
# the filter — `filters: [title-slides]` — and Quarto has to resolve that name against an
# installed `_extensions/` tree. If `quarto add` ever landed the extension under a
# different directory name, every document naming the filter would fail with
# "Could not run … as a JSON filter", which is precisely what was reported. So assert the
# shape of what installing actually produces, rather than trusting it.
#
# Needs the network, so it cannot run inside the nix build sandbox: CI runs it as its own
# step. Without a network it skips loudly — it never passes quietly.
set -euo pipefail

tests="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QUARTO="${QUARTO:-quarto}"
EXTENSION="${EXTENSION:-gortazar/title-slides}"

if ! curl -fsS --max-time 20 -o /dev/null https://github.com 2>/dev/null; then
    echo "install: SKIPPED — no network, and installing from the release needs one" >&2
    echo "install: run it where github.com is reachable to check the published artefact" >&2
    exit 0
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

echo "install: quarto add $EXTENSION into an empty directory"
"$QUARTO" add "$EXTENSION" --no-prompt

# The name a document uses is the *last* path component, whatever owner directory Quarto
# puts it under. That is the thing `filters: [title-slides]` resolves against.
installed="$(find _extensions -maxdepth 2 -type d -name title-slides)"
if [ -z "$installed" ]; then
    echo "  FAIL nothing installed at a path ending in title-slides:" >&2
    find _extensions -maxdepth 2 >&2 || echo "  (no _extensions/ at all)" >&2
    exit 1
fi
echo "  ok   installed at $installed"

for required in _extension.yml title-slides.lua setext.lua; do
    if [ ! -f "$installed/$required" ]; then
        echo "  FAIL the installed extension has no $required" >&2
        exit 1
    fi
done
echo "  ok   the filter and the module it loads both landed"

# Quarto's own view of it: this is what a user should be asked to run when the filter
# cannot be found.
# quarto writes the listing to stderr, so it has to be folded into stdout to be read.
if ! "$QUARTO" list extensions 2>&1 | grep -q title-slides; then
    echo "  FAIL quarto list extensions does not report it" >&2
    "$QUARTO" list extensions >&2
    exit 1
fi
echo "  ok   quarto list extensions reports it"

# And the point of it all: a document naming the filter renders, and the filter ran.
cat > deck.qmd <<'EOF'
---
title: "Installed"
format: revealjs
filters:
  - title-slides
title-slides: true
---

## Introduction

first

---

a continuation
EOF

"$QUARTO" render deck.qmd --to revealjs --output deck.html --quiet
if ! grep -q 'title-slides-continuation' deck.html; then
    echo "  FAIL the deck rendered but the filter did not run" >&2
    exit 1
fi
echo "  ok   a document naming the filter renders, and the title was carried"

echo "install test passed"
