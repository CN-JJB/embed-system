#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PART_D_DIR="$SCRIPT_DIR/../../part-d"
REF_DIR="$SCRIPT_DIR/reference"

echo "=== Testing Part D (Process/FD + Concurrency Interacting Faults) ==="

# 1. Verify Broken Fixture Stalls & Times Out Safely
echo "--- 1. Verifying Broken Fixture Stall & Watchdog Timeout ---"
make -C "$PART_D_DIR" clean >/dev/null
make -C "$PART_D_DIR" repro >/dev/null

set +e
"$PART_D_DIR/repro" >/dev/null 2>&1
BROKEN_STATUS=$?
set -e

if [ "$BROKEN_STATUS" -ne 2 ]; then
    echo "FAIL: Expected broken fixture to hit watchdog timeout (exit 2), got $BROKEN_STATUS."
    exit 1
fi
echo "PASS: Broken fixture stalled and was terminated by safety watchdog (exit code $BROKEN_STATUS)."

# 2. Verify Single-Fix 1 (Process/FD Fixed Only -> Residual Concurrency Failure)
echo "--- 2. Verifying Single-Fix 1 (Process/FD Fixed Only) ---"
gcc -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread \
    -I"$PART_D_DIR/src" \
    "$SCRIPT_DIR/partial_fd_fixed.c" "$PART_D_DIR/src/pipeline.c" "$PART_D_DIR/src/queue.c" \
    -o "$SCRIPT_DIR/run_partial_fd"

set +e
"$SCRIPT_DIR/run_partial_fd" >/dev/null 2>&1
PARTIAL_FD_STATUS=$?
set -e
rm -f "$SCRIPT_DIR/run_partial_fd"

if [ "$PARTIAL_FD_STATUS" -ne 1 ]; then
    echo "FAIL: Expected partial FD fix to fail with residual concurrency drain error (exit 1), got $PARTIAL_FD_STATUS."
    exit 1
fi
echo "PASS: Partial FD fix cleanly produced residual concurrency drain failure (exit code 1)."

# 3. Verify Single-Fix 2 (Concurrency Fixed Only -> Residual Process/FD Stall)
echo "--- 3. Verifying Single-Fix 2 (Concurrency Fixed Only) ---"
gcc -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread \
    -I"$REF_DIR" \
    "$SCRIPT_DIR/partial_conc_fixed.c" "$REF_DIR/pipeline.c" "$REF_DIR/queue.c" \
    -o "$SCRIPT_DIR/run_partial_conc"

set +e
"$SCRIPT_DIR/run_partial_conc" >/dev/null 2>&1
PARTIAL_CONC_STATUS=$?
set -e
rm -f "$SCRIPT_DIR/run_partial_conc"

if [ "$PARTIAL_CONC_STATUS" -ne 2 ]; then
    echo "FAIL: Expected partial concurrency fix to hit watchdog timeout (exit 2), got $PARTIAL_CONC_STATUS."
    exit 1
fi
echo "PASS: Partial concurrency fix cleanly stalled on stream boundary (exit code 2)."

# 4. Demonstrate the Two Diagnostic Evidence Channels
echo "--- 4. Demonstrating Dual Diagnostic Evidence Channels ---"
gcc -std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror -pthread \
    -I"$PART_D_DIR/src" \
    "$SCRIPT_DIR/test_channels.c" "$PART_D_DIR/src/pipeline.c" "$PART_D_DIR/src/queue.c" \
    -o "$SCRIPT_DIR/run_channels"
"$SCRIPT_DIR/run_channels" >/dev/null
rm -f "$SCRIPT_DIR/run_channels"
echo "PASS: Both OS/FD descriptor table audit and thread lifecycle drain channels demonstrated."

# 5. Build and Test Fixed Reference Implementation Across 50 Consecutive Cycles
echo "--- 5. Verifying Fixed Reference Implementation (50 Cycles) ---"
make -C "$REF_DIR" clean >/dev/null
make -C "$REF_DIR" all >/dev/null

for i in $(seq 1 50); do
    "$REF_DIR/fixed_ref" >/dev/null
done
echo "PASS: 50/50 consecutive clean cycles completed with zero hangs, leaks, or crashes."

# 6. Clean Build Artifacts
make -C "$PART_D_DIR" clean >/dev/null
make -C "$REF_DIR" clean >/dev/null

echo ">>> ALL PART D REGRESSION & INTERACTION CHECKS PASSED <<<"
