#!/bin/bash
set -euo pipefail

# P3-M04 Assessment Reference Oracle (REVIEWER-ONLY)
# Grades a learner's candidate launch configuration plus the boot evidence
# bound to it. This file is the single source of truth for the scored
# expectations and must never be referenced by or copied into
# learner-facing material.
#
# Usage: oracle_m04.sh <candidate-config> [candidate-log]
#   1. Candidate config must satisfy the canonical boot contract
#      (exactly-one console=ttyAMA0,115200, earlycon, rdinit=/init,
#      canonical machine/CPU/RAM/SMP/nographic).
#   2. If a candidate log is supplied, its logged 'Kernel command line:'
#      must contain the candidate's own BOOTARGS tokens (no stock reference
#      log can satisfy another config), and the log must pass runtime
#      evidence verification (real kernel, handoff, init, real BusyBox
#      userspace response). Forged/concatenated milestone text REJECTs.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

CANDIDATE="${1:-$M04_ROOT/gate/build/candidate_boot_config.sh}"
CANDIDATE_LOG="${2:-}"

FAILURES=0
fail() { echo "[FAIL] ASSESSMENT MISMATCH: $1" >&2; FAILURES=$((FAILURES + 1)); }

echo "=================================================================="
echo "=== P3-M04 Assessment Reference Oracle                         ==="
echo "=== Candidate: $CANDIDATE"
[ -n "$CANDIDATE_LOG" ] && echo "=== Log: $CANDIDATE_LOG"
echo "=================================================================="

[ -f "$CANDIDATE" ] || { fail "candidate configuration missing: $CANDIDATE"; echo "=== ASSESSMENT REFERENCE REJECT ===" >&2; exit 1; }

# 1. Canonical boot contract on the candidate's own file.
if ! bash "$M04_ROOT/scripts/verify_boot_contract.sh" "$CANDIDATE" >/dev/null 2>&1; then
    fail "candidate violates the canonical boot contract"
    bash "$M04_ROOT/scripts/verify_boot_contract.sh" "$CANDIDATE" 2>&1 | tail -n 3 >&2 || true
fi

# Extract the candidate's BOOTARGS for log binding.
STRIPPED=$(grep -v '^[[:space:]]*#' "$CANDIDATE" || true)
CAND_BOOTARGS=""
if echo "$STRIPPED" | grep -Eq 'BOOTARGS='; then
    CAND_BOOTARGS=$(echo "$STRIPPED" | grep -E 'BOOTARGS=' | tail -n 1 | sed -E 's/^[[:space:]]*BOOTARGS=["'"'"']?([^"'"'"']+)["'"'"']?.*$/\1/')
fi
if [ -z "$CAND_BOOTARGS" ]; then
    CAND_BOOTARGS=$(echo "$STRIPPED" | grep -E '(-append)' | head -n 1 | sed -E 's/.*-append[[:space:]]+["'"'"']?([^"'"'"']+)["'"'"']?.*/\1/')
fi
[ -n "$CAND_BOOTARGS" ] || fail "could not extract candidate BOOTARGS for log binding"

# 2. Candidate log binding (when supplied).
if [ -n "$CANDIDATE_LOG" ]; then
    [ -f "$CANDIDATE_LOG" ] || fail "candidate log missing: $CANDIDATE_LOG"
    if [ -f "$CANDIDATE_LOG" ] && [ -n "$CAND_BOOTARGS" ]; then
        if ! bash "$M04_ROOT/scripts/verify_runtime_boot.sh" "$CANDIDATE_LOG" "$CAND_BOOTARGS" >/dev/null 2>&1; then
            fail "candidate log is not runtime evidence for the candidate BOOTARGS (forged/reference log?)"
            bash "$M04_ROOT/scripts/verify_runtime_boot.sh" "$CANDIDATE_LOG" "$CAND_BOOTARGS" 2>&1 | tail -n 3 >&2 || true
        fi
    fi
fi

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "=== ASSESSMENT REFERENCE PASS (M04 candidate) ==="
    exit 0
else
    echo "=== ASSESSMENT REFERENCE REJECT: $FAILURES mismatch(es) ===" >&2
    exit 1
fi
