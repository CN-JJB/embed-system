#!/usr/bin/env bash
# ==============================================================================
# test_m01_validator_mutations.sh: Regression Test Suite for M01 Validator
# Verifies that validate.sh rejects negative mutations and accepts valid reference.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M01_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VALIDATE="${M01_DIR}/challenge/validate.sh"
MUTATIONS_DIR="${SCRIPT_DIR}/mutations"
REF_DIR="${SCRIPT_DIR}/challenge-reference"
STARTER_DIR="${M01_DIR}/challenge/starter"

echo "=== Running P2-M01 Validator Mutation Regression Suite ==="

run_negative_test() {
    local mut_name="$1"
    local target_dir="$2"
    echo -n "Testing negative mutation [${mut_name}]... "
    if bash "${VALIDATE}" "${target_dir}" >/dev/null 2>&1; then
        echo "FAILED (Unexpected PASS)!" >&2
        exit 1
    fi
    echo "PASSED (Correctly Rejected)"
}

# 1. Negative mutation: Incomplete starter scaffold
run_negative_test "starter_scaffold" "${STARTER_DIR}"

# 2. Negative mutation: Missing data copy loop (comment trick)
run_negative_test "no_data_copy" "${MUTATIONS_DIR}/mut_no_data_copy"

# 3. Negative mutation: Missing BSS zeroing loop (comment trick)
run_negative_test "no_bss_zero" "${MUTATIONS_DIR}/mut_no_bss_zero"

# 4. Negative mutation: Missing __libc_init_array call
run_negative_test "no_init_array" "${MUTATIONS_DIR}/mut_no_init_array"

# 5. Negative mutation: Missing main transfer
run_negative_test "no_main_transfer" "${MUTATIONS_DIR}/mut_no_main"

# 6. Negative mutation: Invalid vector 1
run_negative_test "invalid_vector1" "${MUTATIONS_DIR}/mut_invalid_vector1"

# 7. Positive verification: Reference implementation
echo -n "Testing positive reference [challenge-reference]... "
if ! bash "${VALIDATE}" "${REF_DIR}" >/dev/null 2>&1; then
    echo "FAILED (Reference rejected by validator)!" >&2
    exit 1
fi
echo "PASSED (Reference Validated)"

echo "=== ALL P2-M01 VALIDATOR MUTATION TESTS PASSED ==="
