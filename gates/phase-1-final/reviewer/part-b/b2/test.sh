#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B2_DIR="$SCRIPT_DIR/../../../part-b/variants/b2"

echo "=== Testing Variant B2 (Family B-FD) ==="

# 1. Verify Buggy Fixture Reproduces
echo "--- 1. Verifying Buggy Reproduction ---"
make -C "$B2_DIR" clean >/dev/null
make -C "$B2_DIR" repro >/dev/null

set +e
"$B2_DIR/repro" >/dev/null 2>&1
BUG_STATUS=$?
set -e

if [ "$BUG_STATUS" -eq 0 ]; then
    echo "FAIL: Buggy harness unexpectedly passed with exit code 0!"
    exit 1
fi
echo "PASS: Buggy harness detected descriptor leak as expected (exit code $BUG_STATUS)."

# 2. Verify Fixed Solution Passes Cleanly
echo "--- 2. Verifying Fixed Solution Across 100 Cycles ---"
gcc -I"$B2_DIR" -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror \
    "$SCRIPT_DIR/solution.c" "$B2_DIR/harness.c" -o "$SCRIPT_DIR/fixed_test"

for i in $(seq 1 100); do
    "$SCRIPT_DIR/fixed_test" >/dev/null
done

rm -f "$SCRIPT_DIR/fixed_test"
echo ">>> SUCCESS: Variant B2 verified (bug reproduces, solution passes 100/100) <<<"
