#!/usr/bin/env bash
# ==============================================================================
# test_m06_validator_mutations.sh: Positive & Negative Regression Suite
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M06_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VALIDATE_SH="${M06_DIR}/challenge/validate.sh"
REF_DIR="${SCRIPT_DIR}/challenge-reference"
MUTATIONS_DIR="${SCRIPT_DIR}/mutations"

echo "=== Running P2-M06 Challenge Validator Regression Suite ==="

# Step 1: Test positive control (reviewer reference solution bundle must pass)
echo -n "Testing positive control (reviewer reference bundle)... "
if bash "${VALIDATE_SH}" "${REF_DIR}" >/dev/null 2>&1; then
    echo "PASSED (Reference solution correctly accepted)"
else
    echo "FAILED (Reference solution was unexpectedly rejected!)" >&2
    bash "${VALIDATE_SH}" "${REF_DIR}"
    exit 1
fi

# Step 2: Test negative mutations (all defective mutation bundles must fail)
PASS_COUNT=0
FAIL_COUNT=0

for mut in "${MUTATIONS_DIR}"/mut*; do
    if [ -d "${mut}" ]; then
        mut_name="$(basename "${mut}")"
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

echo "=== ALL P2-M06 POSITIVE AND NEGATIVE VALIDATOR CHECKS PASSED ==="
