#!/bin/bash
set -euo pipefail

# P3-M04 Assessment Reference Oracle (REVIEWER-ONLY)
#
# Grades the learner's candidate launch MANIFEST plus the runtime evidence
# bound to it. The scored contract has exactly one source of truth: the
# data-only candidate manifest, interpreted only by
# scripts/parse_candidate_manifest.py. Reviewer runtime reproduces the
# candidate's own machine/CPU/RAM/SMP/nographic/bootargs argv -- it never
# substitutes canonical machine values for the candidate's declarations.
#
# Usage: oracle_m04.sh <candidate-manifest> [provenance] [console-log]
#   - manifest must satisfy the canonical launch contract;
#   - when provenance + console log are supplied, the executed argv recorded
#     in provenance must equal the manifest declarations, and the guest log
#     must contain the ordering-bound evidence for that executed argv.
#
# This file is the single source of truth for the scored expectations and
# must never be referenced by or copied into learner-facing material.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

CANDIDATE="${1:-$M04_ROOT/gate/build/candidate_boot_manifest.conf}"
PROVENANCE="${2:-}"
CONSOLE_LOG="${3:-}"

FAILURES=0
fail() { echo "[FAIL] ASSESSMENT MISMATCH: $1" >&2; FAILURES=$((FAILURES + 1)); }

echo "=================================================================="
echo "=== P3-M04 Assessment Reference Oracle                         ==="
echo "=== Candidate:  $CANDIDATE"
[ -n "$PROVENANCE" ] && echo "=== Provenance: $PROVENANCE"
[ -n "$CONSOLE_LOG" ] && echo "=== Console:    $CONSOLE_LOG"
echo "=================================================================="

[ -f "$CANDIDATE" ] || { fail "candidate manifest missing: $CANDIDATE"; echo "=== ASSESSMENT REFERENCE REJECT ===" >&2; exit 1; }

# 1. Canonical launch contract on the candidate's own manifest (schema,
#    duplicates, conflicts, canonical values, normalized argv).
if ! bash "$M04_ROOT/scripts/verify_boot_contract.sh" "$CANDIDATE" >/dev/null 2>&1; then
    fail "candidate manifest violates the canonical launch contract"
    bash "$M04_ROOT/scripts/verify_boot_contract.sh" "$CANDIDATE" 2>&1 | tail -n 6 >&2 || true
fi

# 2. Executed-argv + guest-evidence binding (when supplied).
if [ -n "$PROVENANCE" ] || [ -n "$CONSOLE_LOG" ]; then
    if [ -z "$PROVENANCE" ] || [ -z "$CONSOLE_LOG" ]; then
        fail "runtime binding requires both the executed-argv provenance and the console log"
    elif [ ! -f "$PROVENANCE" ]; then
        fail "executed-argv provenance missing: $PROVENANCE"
    elif [ ! -f "$CONSOLE_LOG" ]; then
        fail "console log missing: $CONSOLE_LOG"
    else
        if ! bash "$M04_ROOT/scripts/verify_candidate_runtime.sh" \
                "$PROVENANCE" "$CONSOLE_LOG" "$CANDIDATE" >/dev/null 2>&1; then
            fail "candidate runtime evidence is not bound to the manifest's executed argv"
            bash "$M04_ROOT/scripts/verify_candidate_runtime.sh" \
                "$PROVENANCE" "$CONSOLE_LOG" "$CANDIDATE" 2>&1 \
                | grep -E '^(REJECT|\[FAIL)' | tail -n 6 >&2 || true
        fi
    fi
fi

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "=== ASSESSMENT REFERENCE PASS (M04 candidate) ==="
    exit 0
fi
echo "=== ASSESSMENT REFERENCE REJECT: $FAILURES mismatch(es) ===" >&2
exit 1
