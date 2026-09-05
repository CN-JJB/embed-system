#!/usr/bin/env bash
# ==============================================================================
# test_m03_validator_mutations.sh: Regression suite testing validator against mutations
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M03_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VALIDATE_SH="${M03_DIR}/challenge/validate.sh"
MUTATIONS_DIR="${SCRIPT_DIR}/mutations"

echo "=== Running P2-M03 Challenge Validator Negative Mutation Suite ==="

PASS_COUNT=0
FAIL_COUNT=0

for mut in "${MUTATIONS_DIR}"/*; do
    if [ -d "${mut}" ]; then
        mut_name="$(basename "${mut}")"
        echo -n "Testing mutation [${mut_name}]... "
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

echo "=== ALL P2-M03 VALIDATOR MUTATIONS REJECTED SUCCESSFULLY ==="
