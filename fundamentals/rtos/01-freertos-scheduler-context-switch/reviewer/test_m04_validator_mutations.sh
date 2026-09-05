#!/usr/bin/env bash
# ==============================================================================
# test_m04_validator_mutations.sh: Positive & Negative Regression Suite
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M04_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VALIDATE_SH="${M04_DIR}/challenge/validate.sh"
REF_SRC="${SCRIPT_DIR}/challenge-reference/scheduler_app.c"
MUTATIONS_DIR="${SCRIPT_DIR}/mutations"

echo "=== Running P2-M04 Challenge Validator Regression Suite ==="

# Step 1: Test positive control (reviewer reference solution must pass)
echo -n "Testing positive control (reviewer reference)... "
if bash "${VALIDATE_SH}" "${REF_SRC}" >/dev/null 2>&1; then
    echo "PASSED (Reference solution correctly accepted)"
else
    echo "FAILED (Reference solution was unexpectedly rejected!)" >&2
    bash "${VALIDATE_SH}" "${REF_SRC}"
    exit 1
fi

# Step 2: Test negative mutations (all defective mutations must fail)
PASS_COUNT=0
FAIL_COUNT=0

for mut in "${MUTATIONS_DIR}"/mut*.c; do
    if [ -f "${mut}" ]; then
        mut_name="$(basename "${mut}" .c)"
        echo -n "Testing negative mutation [${mut_name}]... "
        if bash "${VALIDATE_SH}" "${mut}" >/dev/null 2>&1; then
            echo "FAILED (Validator falsely ACCEPTED defective mutation!)"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        else
            echo "PASSED (Validator correctly REJECTED mutation)"
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
    fi
done

echo "Mutation test results: ${PASS_COUNT} correctly rejected, ${FAIL_COUNT} falsely accepted."
if [ "${FAIL_COUNT}" -ne 0 ]; then
    echo "ERROR: Challenge validator failed mutation regression!" >&2
    exit 1
fi

echo "=== ALL P2-M04 POSITIVE AND NEGATIVE VALIDATOR CHECKS PASSED ==="
