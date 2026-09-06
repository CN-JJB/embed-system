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

# Step 2: Test negative mutations (all defective mutations must compile, then be rejected by validator)
PASS_COUNT=0
COMPILE_FAIL_COUNT=0
ACCEPT_FAIL_COUNT=0

for mut in "${MUTATIONS_DIR}"/mut*; do
    if [ -d "${mut}" ]; then
        mut_name="$(basename "${mut}")"
        echo -n "Testing negative mutation [${mut_name}]... "

        # 1. Overlay compilation and linking MUST pass
        if ! bash "${VALIDATE_SH}" "${mut}" --build-only >/dev/null 2>&1; then
            echo "FAILED (Mutation failed compile/link! Negative controls must be compilable code)"
            COMPILE_FAIL_COUNT=$((COMPILE_FAIL_COUNT + 1))
            continue
        fi

        # 2. Semantic validator MUST reject the defect
        if bash "${VALIDATE_SH}" "${mut}" >/dev/null 2>&1; then
            echo "FAILED (Validator falsely ACCEPTED defective mutation!)"
            ACCEPT_FAIL_COUNT=$((ACCEPT_FAIL_COUNT + 1))
        else
            echo "COMPILE PASS / VALIDATOR REJECT"
            PASS_COUNT=$((PASS_COUNT + 1))
        fi
    fi
done

echo ""
echo "=== Mutation Suite Results ==="
echo "COMPILE PASS / VALIDATOR REJECT: ${PASS_COUNT}"
echo "Compilation failed (invalid mut): ${COMPILE_FAIL_COUNT}"
echo "Falsely accepted by validator:   ${ACCEPT_FAIL_COUNT}"

if [ "${COMPILE_FAIL_COUNT}" -ne 0 ] || [ "${ACCEPT_FAIL_COUNT}" -ne 0 ]; then
    echo "ERROR: Mutation regression suite failed!" >&2
    exit 1
fi

echo "=== ALL P2-M07 POSITIVE REFERENCE AND NEGATIVE MUTATION CHECKS PASSED ==="
