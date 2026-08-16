#!/usr/bin/env bash
# Run every unit test under `pandoc lua`, which is the same Lua the filter runs in.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

PANDOC="${PANDOC:-pandoc}"

failed=0
for test in unit/*.lua; do
    echo "$test"
    if ! "$PANDOC" lua "$test"; then
        failed=$((failed + 1))
    fi
done

if [ "$failed" -gt 0 ]; then
    echo "$failed unit test file(s) failed" >&2
    exit 1
fi
echo "unit tests passed"
