#!/usr/bin/env bash
# ==============================================================================
# verify_mutations.sh: Positive Reference and Negative Mutation Runner for P2-M07
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VALIDATE_SH="${PROJECT_DIR}/scripts/verify_project.sh"
REF_DIR="${SCRIPT_DIR}/reference"
MUTATIONS_DIR="${SCRIPT_DIR}/mutations"

echo "=== Running P2-M07 Reviewer Mutation Verification Suite ==="

# Step 1: Verify positive control (reference implementation must pass)
echo -n "Testing positive control (reviewer reference bundle)... "
if bash "${VALIDATE_SH}" "${REF_DIR}" >/dev/null 2>&1; then
    echo "PASSED (Reference implementation correctly accepted)"
else
    echo "FAILED (Reference implementation unexpectedly rejected!)" >&2
    bash "${VALIDATE_SH}" "${REF_DIR}"
    exit 1
fi

# Step 2: Test negative mutations (all defective mutations must fail)
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

echo ""
echo "=== Mutation Suite Results ==="
echo "Correctly rejected: ${PASS_COUNT}"
echo "Falsely accepted:   ${FAIL_COUNT}"

if [ "${FAIL_COUNT}" -ne 0 ]; then
    echo "ERROR: Validator failed mutation regression suite!" >&2
    exit 1
fi

echo "=== ALL P2-M07 POSITIVE REFERENCE AND NEGATIVE MUTATION CHECKS PASSED ==="
