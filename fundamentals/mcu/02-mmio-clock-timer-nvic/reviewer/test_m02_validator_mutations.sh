#!/usr/bin/env bash
# ==============================================================================
# test_m02_validator_mutations.sh: Regression Test Suite for M02 Validator
# Verifies that validate.sh rejects all negative mutations and accepts reference.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M02_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VALIDATE="${M02_DIR}/challenge/validate.sh"
MUTATIONS_DIR="${SCRIPT_DIR}/mutations"
REF_DIR="${SCRIPT_DIR}/challenge-reference"
STARTER_DIR="${M02_DIR}/challenge/starter"

echo "=== Running P2-M02 Validator Mutation Regression Suite ==="

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

# 2. Negative mutation: ARR wrong (5 kHz instead of 10 kHz)
run_negative_test "arr_wrong" "${MUTATIONS_DIR}/mut_arr_wrong"

# 3. Negative mutation: Only 3 channels supported
run_negative_test "3_channels" "${MUTATIONS_DIR}/mut_3_channels"

# 4. Negative mutation: Non-atomic ODR RMW writes
run_negative_test "odr_rmw" "${MUTATIONS_DIR}/mut_odr_rmw"

# 5. Negative mutation: Omitted UIF interrupt flag clear
run_negative_test "no_uif_clear" "${MUTATIONS_DIR}/mut_no_uif_clear"

# 6. Negative mutation: Broken step wrap (wraps at 50 instead of 100)
run_negative_test "broken_wrap" "${MUTATIONS_DIR}/mut_broken_wrap"

# 7. Positive verification: Reference implementation
echo -n "Testing positive reference [challenge-reference]... "
if ! bash "${VALIDATE}" "${REF_DIR}" >/dev/null 2>&1; then
    echo "FAILED (Reference rejected by validator)!" >&2
    exit 1
fi
echo "PASSED (Reference Validated)"

echo "=== ALL P2-M02 VALIDATOR MUTATION TESTS PASSED ==="
