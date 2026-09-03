#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B1_DIR="$SCRIPT_DIR/../../../part-b/variants/b1"

echo "=== Testing Variant B1 (Family B-MEM) ==="

# 1. Verify Buggy Fixture Reproduces
echo "--- 1. Verifying Buggy Reproduction ---"
make -C "$B1_DIR" clean >/dev/null
make -C "$B1_DIR" repro >/dev/null

set +e
"$B1_DIR/repro" >/dev/null 2>&1
BUG_STATUS=$?
set -e

if [ "$BUG_STATUS" -eq 0 ]; then
    echo "FAIL: Buggy harness unexpectedly passed with exit code 0!"
    exit 1
fi
echo "PASS: Buggy harness failed as expected (exit code $BUG_STATUS)."

# 2. Verify Fixed Solution Passes 100 Clean Iterations
echo "--- 2. Verifying Fixed Solution Across 100 Cycles ---"
gcc -I"$B1_DIR" -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror \
    -fsanitize=address,undefined -fno-omit-frame-pointer \
    "$SCRIPT_DIR/solution.c" "$B1_DIR/harness.c" -o "$SCRIPT_DIR/fixed_test"

export ASAN_OPTIONS=detect_leaks=1:halt_on_error=1
for i in $(seq 1 100); do
    "$SCRIPT_DIR/fixed_test" >/dev/null
done

rm -f "$SCRIPT_DIR/fixed_test"
echo ">>> SUCCESS: Variant B1 verified (bug reproduces, solution passes 100/100) <<<"
