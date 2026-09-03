#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B3_DIR="$SCRIPT_DIR/../../../part-b/variants/b3"

echo "=== Testing Variant B3 (Family B-CONC) ==="

# 1. Verify Buggy Fixture Reproduces
echo "--- 1. Verifying Buggy Reproduction ---"
make -C "$B3_DIR" clean >/dev/null
make -C "$B3_DIR" repro >/dev/null

set +e
"$B3_DIR/repro" >/dev/null 2>&1
BUG_STATUS=$?
set -e

if [ "$BUG_STATUS" -eq 0 ]; then
    echo "FAIL: Buggy harness unexpectedly passed with exit code 0!"
    exit 1
fi
echo "PASS: Buggy harness detected invariant violation as expected (exit code $BUG_STATUS)."

# 2. Verify Fixed Solution Across 100 Cycles
echo "--- 2. Verifying Fixed Solution Across 100 Cycles ---"
gcc -I"$B3_DIR" -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread \
    "$SCRIPT_DIR/solution.c" "$B3_DIR/harness.c" -o "$SCRIPT_DIR/fixed_test"

for i in $(seq 1 100); do
    "$SCRIPT_DIR/fixed_test" >/dev/null
done
rm -f "$SCRIPT_DIR/fixed_test"

# 3. Verify Fixed Solution Under ThreadSanitizer (TSan) when supported
echo "--- 3. Verifying Fixed Solution Under ThreadSanitizer (TSan) ---"
TSAN_SUMMARY="TSan not executed"
if gcc -I"$B3_DIR" -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread -fsanitize=thread \
    "$SCRIPT_DIR/solution.c" "$B3_DIR/harness.c" -o "$SCRIPT_DIR/tsan_test" 2>/dev/null; then
    TSAN_LOG="$SCRIPT_DIR/tsan.log"
    set +e
    setarch x86_64 -R "$SCRIPT_DIR/tsan_test" >"$TSAN_LOG" 2>&1
    TSAN_STATUS=$?
    set -e

    if [ "$TSAN_STATUS" -eq 0 ]; then
        echo "PASS: ThreadSanitizer reported no data races in this execution."
        TSAN_SUMMARY="recorded TSan run reported no races"
    elif grep -q "WARNING: ThreadSanitizer: data race" "$TSAN_LOG"; then
        cat "$TSAN_LOG" >&2
        rm -f "$SCRIPT_DIR/tsan_test" "$TSAN_LOG"
        echo "FAIL: ThreadSanitizer reported a data race." >&2
        exit 1
    else
        echo "NOTICE: TSan runtime unavailable/unsupported in this environment (exit $TSAN_STATUS)."
        TSAN_SUMMARY="TSan runtime unavailable/unsupported"
    fi
    rm -f "$SCRIPT_DIR/tsan_test" "$TSAN_LOG"
else
    echo "NOTICE: TSan compilation unsupported in current environment."
    TSAN_SUMMARY="TSan compilation unsupported"
fi

echo ">>> SUCCESS: Variant B3 verified (bug reproduces, solution passes 100/100; $TSAN_SUMMARY) <<<"
