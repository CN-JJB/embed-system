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

# 2. Build and Test Fixed Reference Implementation
echo "--- 2. Building Fixed Reference Implementation ---"
make -C "$REF_DIR" clean >/dev/null
make -C "$REF_DIR" all >/dev/null

echo "--- 3. Running 50-Cycle Clean Regression Test on Fixed Reference ---"
for i in $(seq 1 50); do
    "$REF_DIR/fixed_ref" >/dev/null
done
echo "PASS: 50/50 consecutive clean cycles completed with zero hangs or crashes."

# 4. Clean Build Artifacts
make -C "$PART_D_DIR" clean >/dev/null
make -C "$REF_DIR" clean >/dev/null

echo ">>> ALL PART D REGRESSION & INTERACTION CHECKS PASSED <<<"
