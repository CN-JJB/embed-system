#!/usr/bin/env bash
# P3-M05 Assessment Reference Oracle (REVIEWER-ONLY)
#
# Grades a learner's repaired device tree blob against the COMPLETE canonical
# QEMU virt contract, plus (when supplied) the runtime evidence bound to it.
#
# The oracle is the only component that knows which invariant the seeded
# artifact violated; the learner-facing profile is a deliberately smaller
# subset.  Never reference or copy this file into learner-facing material.
#
# Usage:
#   oracle_m05.sh [CANDIDATE.dtb] [ASSESSMENT] [PROVENANCE] [CONSOLE_LOG]
#     ASSESSMENT: gate | challenge   (default: gate)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M05_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M05_ROOT"

PY="${PYTHON:-python3}"
command -v "$PY" >/dev/null 2>&1 || PY=python

ASSESSMENT="gate"
CANDIDATE=""
PROVENANCE=""
CONSOLE_LOG=""
for arg in "$@"; do
    case "$arg" in
        gate|challenge) ASSESSMENT="$arg" ;;
        *) if [ -z "$CANDIDATE" ]; then CANDIDATE="$arg";
           elif [ -z "$PROVENANCE" ]; then PROVENANCE="$arg";
           else CONSOLE_LOG="$arg"; fi ;;
    esac
done

COMPLETE_PROFILE="reviewer/reference/qemu-virt-a7-complete.json"
SEED_FILE="reviewer/reference/${ASSESSMENT}_seed.json"

if [ -z "$CANDIDATE" ]; then
    CANDIDATE="${ASSESSMENT}/build/candidate.dtb"
fi

FAILURES=0
fail() { echo "[FAIL] ASSESSMENT MISMATCH: $1" >&2; FAILURES=$((FAILURES + 1)); }

echo "=================================================================="
echo "=== P3-M05 Assessment Reference Oracle                         ==="
echo "=== Assessment: $ASSESSMENT"
echo "=== Candidate : $CANDIDATE"
[ -n "$PROVENANCE" ] && echo "=== Provenance: $PROVENANCE"
[ -n "$CONSOLE_LOG" ] && echo "=== Console   : $CONSOLE_LOG"
echo "=================================================================="

[ -f "$CANDIDATE" ] || { fail "candidate artifact missing: $CANDIDATE"; echo "=== ASSESSMENT REFERENCE REJECT ===" >&2; exit 1; }
[ -f "$COMPLETE_PROFILE" ] || { echo "FATAL: complete profile missing" >&2; exit 2; }
[ -f "$SEED_FILE" ] || { echo "FATAL: seed mapping missing: $SEED_FILE" >&2; exit 2; }

# 1. Format: an unparseable artifact is an ERROR, not a semantic rejection.
set +e
"$PY" scripts/dt_structural_check.py "$CANDIDATE" --quiet >/dev/null 2>&1
STRUCT_RC=$?
set -e
if [ "$STRUCT_RC" -eq 2 ]; then
    echo "ERROR: candidate is not a parseable device tree blob" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi

# 2. Full semantic contract.
set +e
SEMANTIC_OUTPUT=$("$PY" scripts/validate_dt_semantics.py "$CANDIDATE" \
    --profile "$COMPLETE_PROFILE" 2>&1)
SEMANTIC_RC=$?
set -e
if [ "$SEMANTIC_RC" -eq 2 ]; then
    echo "ERROR: candidate could not be evaluated" >&2
    echo "$SEMANTIC_OUTPUT" >&2
    echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
    exit 2
fi
if [ "$SEMANTIC_RC" -ne 0 ]; then
    fail "candidate violates the complete canonical device tree contract"
    echo "$SEMANTIC_OUTPUT" | grep -E '^\[FAIL\]|^    - ' | head -n 12 >&2 || true
fi

# 3. The seeded defect family specifically must be repaired.
SEED_INVARIANTS=$("$PY" - "$SEED_FILE" <<'PYEOF'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    seed = json.load(handle)
for ident in seed.get("oracle_invariants", []):
    print(ident)
PYEOF
)
while IFS= read -r ident; do
    [ -n "$ident" ] || continue
    if echo "$SEMANTIC_OUTPUT" | grep -qE "^\[FAIL\] ${ident}\b"; then
        fail "seeded invariant still violated: $ident"
    else
        echo "[PASS] seeded invariant satisfied: $ident"
    fi
done <<< "$SEED_INVARIANTS"

# 4. Runtime evidence binding, when supplied.
if [ -n "$PROVENANCE" ] || [ -n "$CONSOLE_LOG" ]; then
    if [ -z "$PROVENANCE" ] || [ -z "$CONSOLE_LOG" ]; then
        fail "runtime binding requires both the provenance file and the console log"
    elif [ ! -f "$PROVENANCE" ] || [ ! -f "$CONSOLE_LOG" ]; then
        fail "runtime binding input missing"
    else
        set +e
        BIND_OUTPUT=$("$PY" scripts/verify_runtime_binding.py \
            "$CANDIDATE" "$PROVENANCE" "$CONSOLE_LOG" 2>&1)
        BIND_RC=$?
        set -e
        if [ "$BIND_RC" -eq 0 ]; then
            echo "[PASS] runtime evidence is bound to the candidate artifact"
        elif [ "$BIND_RC" -eq 2 ]; then
            echo "ERROR: runtime evidence could not be evaluated" >&2
            echo "$BIND_OUTPUT" >&2
            echo "=== ASSESSMENT REFERENCE ERROR ===" >&2
            exit 2
        else
            fail "runtime evidence is not bound to the candidate artifact"
            echo "$BIND_OUTPUT" | grep -E '^\[FAIL\]' | head -n 6 >&2 || true
        fi
    fi
fi

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "=== ASSESSMENT REFERENCE PASS (M05 $ASSESSMENT candidate) ==="
    exit 0
fi
echo "=== ASSESSMENT REFERENCE REJECT: $FAILURES mismatch(es) ===" >&2
exit 1
