#!/bin/bash
set -euo pipefail

# P3-M01 Assessment Reference Oracle (REVIEWER-ONLY)
# ---------------------------------------------------
# Grades the materialized Challenge and Gate fixtures against the internal
# expected classification mapping using semantic ELF headers/segments from
# production GNU Binutils (readelf). This file is the single source of truth
# for the answer mapping and must never be referenced by or copied into
# learner-facing material.
#
# Hardening contract (Round 3):
#   TARGET_STATIC  = ARM machine + ET_EXEC + no PT_INTERP + no PT_DYNAMIC /
#                    dynamic section. An ET_DYN/shared-object artifact can
#                    never classify as static.
#   TARGET_DYNAMIC = ARM machine + ET_EXEC + PT_INTERP present; for the Gate
#                    family assessing the glibc loader, the requested
#                    interpreter must match the intended loader contract.
#   HOST_OR_NON_ARM = bound to the actual ELF machine identity, not filename.

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

echo "=================================================================="
echo "=== P3-M01 Assessment Reference Oracle                         ==="
echo "=================================================================="

FAILURES=0

fail() {
    echo "[FAIL] CLASSIFICATION MISMATCH: $1" >&2
    FAILURES=$((FAILURES + 1))
}

# Semantic ELF classification (no raw byte / string search over the file).
classify() {
    local f="$1"
    [ -f "$f" ] || { echo "MISSING"; return 1; }
    if ! readelf -h "$f" >/dev/null 2>&1; then
        echo "NOT_ELF"
        return 0
    fi

    local machine etype
    machine=$(readelf -h "$f" 2>/dev/null | awk -F: '/Machine:/ {print $2}' | xargs)
    etype=$(readelf -h "$f" 2>/dev/null | awk -F: '/Type:/ {print $2}' | xargs)

    # Non-ARM identity is bound to the actual ELF machine field.
    if [[ "$machine" != *"ARM"* ]]; then
        echo "HOST_OR_NON_ARM"
        return 0
    fi

    # Only the executable form (ET_EXEC) is valid for the assessed
    # TARGET_STATIC / TARGET_DYNAMIC classes. ET_DYN (shared object / PIE)
    # is a distinct class and can never masquerade as either.
    case "$etype" in
        *"EXEC"*) ;;
        *"DYN"*)   echo "ARM_ET_DYN"; return 0 ;;
        *)         echo "ARM_UNKNOWN_ETYPE"; return 0 ;;
    esac

    local has_interp=0 has_dynamic=0
    if readelf -l "$f" 2>/dev/null | grep -q "Requesting program interpreter"; then
        has_interp=1
    fi
    if readelf -l "$f" 2>/dev/null | grep -qE "PT_DYNAMIC|\bDYNAMIC\b"; then
        has_dynamic=1
    fi
    if readelf -d "$f" 2>/dev/null | grep -q "Dynamic section at offset"; then
        has_dynamic=1
    fi

    if [ "$has_interp" -eq 1 ]; then
        echo "TARGET_DYNAMIC"
        return 0
    fi
    if [ "$has_dynamic" -eq 1 ]; then
        echo "ARM_EXEC_DYNAMIC_NO_INTERP"
        return 0
    fi
    echo "TARGET_STATIC"
    return 0
}

# Requested program interpreter path (PT_INTERP segment contents).
interpreter_of() {
    local f="$1"
    readelf -l "$f" 2>/dev/null | grep "Requesting program interpreter" | head -1 | awk -F: '{print $2}' | tr -d '[]' | xargs
}

# 3. Internal expected mapping (reviewer-only; fresh variant)
#    path | expected class | interpreter contract (TARGET_DYNAMIC only)
EXPECTED="
challenge/fixtures/unknown_1|HOST_OR_NON_ARM|
challenge/fixtures/unknown_2|TARGET_DYNAMIC|/lib/ld-linux-armhf.so.3
challenge/fixtures/unknown_3|TARGET_STATIC|
gate/fixtures/candidate_alpha|TARGET_DYNAMIC|/lib/ld-linux-armhf.so.3
gate/fixtures/candidate_beta|TARGET_STATIC|
gate/fixtures/candidate_gamma|HOST_OR_NON_ARM|
"

while IFS='|' read -r path expected contract; do
    [ -n "$path" ] || continue
    observed=$(classify "$path")
    printf "%-38s | expected %-28s | observed %-28s\n" "$path" "$expected" "$observed"
    if [ "$observed" != "$expected" ]; then
        fail "$path: expected=$expected observed=$observed"
        continue
    fi
    # Gate/challenge glibc-loader contract binding: an arbitrary interpreter
    # path must not satisfy a TARGET_DYNAMIC expectation.
    if [ "$expected" = "TARGET_DYNAMIC" ] && [ -n "$contract" ]; then
        local_interp=$(interpreter_of "$path")
        if [ "$local_interp" != "$contract" ]; then
            fail "$path: interpreter contract mismatch (expected '$contract', observed '$local_interp')"
        fi
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
