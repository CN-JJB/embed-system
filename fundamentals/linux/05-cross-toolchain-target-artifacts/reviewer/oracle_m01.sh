#!/bin/bash
set -euo pipefail

# P3-M01 Assessment Reference Oracle (REVIEWER-ONLY)
# ---------------------------------------------------
# Grades the materialized Challenge and Gate fixtures against the internal
# expected classification mapping using production GNU Binutils (readelf).
# This file is the single source of truth for the answer mapping and must
# never be referenced by or copied into learner-facing material.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M01_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M01_ROOT"

CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"

if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "ERROR: Cross compiler '${CROSS_COMPILE}gcc' not found in PATH." >&2
    exit 1
fi

HOST_CC="${HOST_CC:-gcc}"
command -v "$HOST_CC" >/dev/null 2>&1 || { echo "ERROR: Host compiler '$HOST_CC' not found in PATH." >&2; exit 1; }

# NOTE: fixtures are materialized by the caller (reviewer-check orchestrator or
# the oracle mutation harness) so that mutated fixtures are graded as-is.

# 2. Classification oracle (production readelf)
classify() {
    local f="$1"
    [ -f "$f" ] || { echo "MISSING"; return 1; }
    if ! readelf -h "$f" >/dev/null 2>&1; then
        echo "NOT_ELF"
        return 0
    fi
    if ! readelf -h "$f" 2>/dev/null | grep -q "ARM"; then
        echo "HOST_OR_NON_ARM"
        return 0
    fi
    if readelf -l "$f" 2>/dev/null | grep -q "Requesting program interpreter"; then
        echo "TARGET_DYNAMIC"
    else
        echo "TARGET_STATIC"
    fi
    return 0
}

# 3. Internal expected mapping (reviewer-only; fresh variant)
#    challenge/unknown_1 -> HOST_OR_NON_ARM
#    challenge/unknown_2 -> TARGET_DYNAMIC
#    challenge/unknown_3 -> TARGET_STATIC
#    gate/candidate_alpha -> TARGET_DYNAMIC
#    gate/candidate_beta  -> TARGET_STATIC
#    gate/candidate_gamma -> HOST_OR_NON_ARM
EXPECTED="
challenge/fixtures/unknown_1|HOST_OR_NON_ARM
challenge/fixtures/unknown_2|TARGET_DYNAMIC
challenge/fixtures/unknown_3|TARGET_STATIC
gate/fixtures/candidate_alpha|TARGET_DYNAMIC
gate/fixtures/candidate_beta|TARGET_STATIC
gate/fixtures/candidate_gamma|HOST_OR_NON_ARM
"

echo "=================================================================="
echo "=== P3-M01 Assessment Reference Oracle                         ==="
echo "=================================================================="

FAILURES=0
while IFS='|' read -r path expected; do
    [ -n "$path" ] || continue
    observed=$(classify "$path")
    printf "%-38s | expected %-16s | observed %-16s\n" "$path" "$expected" "$observed"
    if [ "$observed" != "$expected" ]; then
        echo "[FAIL] CLASSIFICATION MISMATCH for $path: expected=$expected observed=$observed"
        FAILURES=$((FAILURES + 1))
    fi
done <<< "$EXPECTED"

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "=== ASSESSMENT REFERENCE PASS (M01 Challenge + Gate) ==="
    exit 0
else
    echo "=== ASSESSMENT REFERENCE REJECT: $FAILURES classification mismatch(es) ===" >&2
    exit 1
fi
