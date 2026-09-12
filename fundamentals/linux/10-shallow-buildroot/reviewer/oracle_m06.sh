#!/usr/bin/env bash
# P3-M06 Assessment Reference Oracle (REVIEWER-ONLY)
#
# Grades a learner's repaired Buildroot configuration fragment against the
# COMPLETE canonical contract, including the verified 2026.05.2 symbol table.
# When an output tree and a runtime capture are supplied, the oracle also
# requires the overlay to be present in the packaged image and the capture to be
# bound to that image.
#
# Never reference or copy this file into learner-facing material.
#
# Usage:
#   oracle_m06.sh [CANDIDATE.conf] [ASSESSMENT] [OUTPUT_DIR] [LOG] [PROVENANCE]
#     ASSESSMENT: gate | challenge   (default: gate)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M06_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M06_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

COMPLETE_PROFILE="reviewer/reference/buildroot-2026.05.2-complete.json"
SYMBOLS="fixtures/buildroot-symbols.json"
OVERLAY="fixtures/br2-external/board/qemu-virt-a7/rootfs-overlay"

ASSESSMENT="gate"
CANDIDATE=""
OUTPUT_DIR=""
LOG=""
PROVENANCE=""
for arg in "$@"; do
    case "$arg" in
        gate|challenge) ASSESSMENT="$arg" ;;
        *) if [ -z "$CANDIDATE" ]; then CANDIDATE="$arg";
           elif [ -z "$OUTPUT_DIR" ]; then OUTPUT_DIR="$arg";
           elif [ -z "$LOG" ]; then LOG="$arg";
           else PROVENANCE="$arg"; fi ;;
    esac
done

[ -n "$CANDIDATE" ] || CANDIDATE="${ASSESSMENT}/build/candidate.conf"
SEED_FILE="reviewer/reference/${ASSESSMENT}_seed.json"

FAILURES=0
fail() { echo "[FAIL] ASSESSMENT MISMATCH: $1" >&2; FAILURES=$((FAILURES + 1)); }

echo "=================================================================="
echo "=== P3-M06 Assessment Reference Oracle                         ==="
echo "=== Assessment: $ASSESSMENT"
echo "=== Candidate : $CANDIDATE"
[ -n "$OUTPUT_DIR" ] && echo "=== Output    : $OUTPUT_DIR"
echo "=================================================================="

[ -f "$CANDIDATE" ] || { fail "candidate fragment missing: $CANDIDATE"; echo "=== ASSESSMENT REFERENCE REJECT ===" >&2; exit 1; }
[ -f "$COMPLETE_PROFILE" ] || { echo "FATAL: complete profile missing" >&2; exit 2; }
[ -f "$SEED_FILE" ] || { echo "FATAL: seed mapping missing: $SEED_FILE" >&2; exit 2; }

# 1. Complete semantic contract, including symbol existence.
set +e
SEMANTIC_OUTPUT=$("$PY" scripts/verify_br_config.py "$CANDIDATE" \
    --profile "$COMPLETE_PROFILE" --symbol-table "$SYMBOLS" 2>&1)
SEMANTIC_RC=$?
set -e
if [ "$SEMANTIC_RC" -eq 2 ]; then
    echo "ERROR: candidate could not be evaluated" >&2
    echo "$SEMANTIC_OUTPUT" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi
if [ "$SEMANTIC_RC" -ne 0 ]; then
    fail "candidate violates the complete canonical Buildroot contract"
    echo "$SEMANTIC_OUTPUT" | grep -E '^\[FAIL\]|^    - ' | head -n 12 >&2 || true
fi

# 2. The seeded defect family specifically must be repaired.
while IFS= read -r ident; do
    [ -n "$ident" ] || continue
    if echo "$SEMANTIC_OUTPUT" | grep -qE "^\[FAIL\] ${ident}\b"; then
        fail "seeded invariant still violated: $ident"
    else
        echo "[PASS] seeded invariant satisfied: $ident"
    fi
done < <("$PY" - "$SEED_FILE" <<'PYEOF'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    for ident in json.load(handle).get("oracle_invariants", []):
        print(ident)
PYEOF
)

# 3. Output tree audit, when an output directory is supplied.
if [ -n "$OUTPUT_DIR" ]; then
    if [ ! -d "$OUTPUT_DIR" ]; then
        fail "output directory missing: $OUTPUT_DIR"
    else
        set +e
        AUDIT_OUTPUT=$("$PY" scripts/audit_output_tree.py \
            --output "$OUTPUT_DIR" --overlay "$OVERLAY" --require-kernel 2>&1)
        AUDIT_RC=$?
        set -e
        if [ "$AUDIT_RC" -eq 2 ]; then
            echo "ERROR: output tree could not be evaluated" >&2
            echo "$AUDIT_OUTPUT" >&2
            echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
            exit 2
        elif [ "$AUDIT_RC" -ne 0 ]; then
            fail "output tree fails the provenance / overlay propagation audit"
            echo "$AUDIT_OUTPUT" | grep -E '^\[FAIL\]|^    - ' | head -n 8 >&2 || true
        else
            echo "[PASS] output tree audit clean (overlay present in target and image)"
        fi
    fi
fi

# 4. Runtime binding, when a capture is supplied.
if [ -n "$LOG" ] || [ -n "$PROVENANCE" ]; then
    if [ -z "$OUTPUT_DIR" ] || [ -z "$LOG" ] || [ -z "$PROVENANCE" ]; then
        fail "runtime binding requires OUTPUT_DIR, LOG and PROVENANCE together"
    elif [ ! -f "$LOG" ] || [ ! -f "$PROVENANCE" ]; then
        fail "runtime binding input missing"
    else
        IMAGE="$OUTPUT_DIR/images/rootfs.cpio.gz"
        [ -f "$IMAGE" ] || IMAGE="$OUTPUT_DIR/images/rootfs.cpio"
        set +e
        BIND_OUTPUT=$("$PY" scripts/verify_appliance_runtime.py \
            "$IMAGE" "$PROVENANCE" "$LOG" --overlay "$OVERLAY" 2>&1)
        BIND_RC=$?
        set -e
        if [ "$BIND_RC" -eq 0 ]; then
            echo "[PASS] runtime evidence is bound to the audited image"
        elif [ "$BIND_RC" -eq 2 ]; then
            echo "ERROR: runtime evidence could not be evaluated" >&2
            echo "$BIND_OUTPUT" >&2
            echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
            exit 2
        else
            fail "runtime evidence is not bound to the audited image"
            echo "$BIND_OUTPUT" | grep -E '^\[FAIL\]' | head -n 6 >&2 || true
        fi
    fi
fi

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "=== ASSESSMENT REFERENCE PASS (M06 $ASSESSMENT candidate) ==="
    exit 0
fi
echo "=== ASSESSMENT REFERENCE REJECT: $FAILURES mismatch(es) ===" >&2
exit 1
