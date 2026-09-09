#!/bin/bash
set -euo pipefail

# P3-M01 Assessment Oracle Mutation Regression (REVIEWER-ONLY)
# Enforces, for the assessment oracle itself:
#   REFERENCE fixture  -> intended PASS
#   mutated artifact   -> intended semantic REJECT
#   crash / unrelated failure -> must NOT be counted as a successful reject
#
# Round 3 adversarial additions:
#   - ARM ET_DYN / shared object (no PT_INTERP) presented where a static
#     executable is expected -> REJECT
#   - dynamic target candidate requesting an unintended interpreter contract
#     -> REJECT where the Gate classification requires the glibc loader
#
# Every test is graded as PREP PASS / ORACLE EXECUTION PASS / INTENDED RESULT.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M01_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M01_ROOT"

CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "ERROR: Cross compiler '${CROSS_COMPILE}gcc' not found in PATH." >&2
    exit 1
fi
HOST_CC="${HOST_CC:-gcc}"
command -v "$HOST_CC" >/dev/null 2>&1 || { echo "ERROR: Host compiler '$HOST_CC' not found in PATH." >&2; exit 1; }

ORACLE="bash reviewer/oracle_m01.sh"
REJECT_PATTERN="CLASSIFICATION MISMATCH"
PASS_PATTERN="ASSESSMENT REFERENCE PASS"

GEN_CHALLENGE="reviewer/scripts/generate_m01_challenge_fixtures.sh"
GEN_GATE="reviewer/scripts/generate_m01_gate_fixtures.sh"

TOTAL_TESTS=6
PASSED_TESTS=0

materialize() {
    bash "$GEN_CHALLENGE" challenge/fixtures "$CROSS_COMPILE"
    bash "$GEN_GATE" gate/fixtures "$CROSS_COMPILE"
}

run_oracle_expect() {
    local test_id="$1"
    local desc="$2"
    local prep_cmd="$3"
    local expect_kind="$4"   # PASS | REJECT
    local out=""
    local rc=0

    echo "------------------------------------------------------------------"
    echo "Test ${test_id}: ${desc}"

    if ! eval "$prep_cmd" >/dev/null 2>&1; then
        echo "[TEST ${test_id} FAIL] Fixture prep stage failed!"
        return 1
    fi
    echo "  PREP: PASS"

    set +e
    out=$($ORACLE 2>&1)
    rc=$?
    set -e

    if [ "$rc" -ge 128 ]; then
        echo "[TEST ${test_id} FAIL] Oracle crashed with signal $((rc - 128))!"
        echo "$out"
        return 1
    fi
    echo "  ORACLE EXECUTION: PASS (no crash, exit $rc)"

    case "$expect_kind" in
        PASS)
            if [ "$rc" -ne 0 ] || ! echo "$out" | grep -q "$PASS_PATTERN"; then
                echo "[TEST ${test_id} FAIL] Expected oracle PASS (exit 0, pattern '${PASS_PATTERN}')."
                echo "  Exit code: $rc"
                echo "$out"
                return 1
            fi
            echo "  INTENDED RESULT: PASS (reference accepted)"
            ;;
        REJECT)
            if [ "$rc" -eq 0 ]; then
                echo "[TEST ${test_id} FAIL] Oracle falsely PASSED a mutated artifact!"
                echo "$out"
                return 1
            fi
            if ! echo "$out" | grep -Eq "$REJECT_PATTERN"; then
                echo "[TEST ${test_id} FAIL] Oracle reject output does not match intended semantic pattern '${REJECT_PATTERN}'."
                echo "  Exit code: $rc"
                echo "$out"
                return 1
            fi
            echo "  INTENDED RESULT: semantic REJECT (pattern matched, exit $rc)"
            ;;
    esac

    PASSED_TESTS=$((PASSED_TESTS + 1))
    return 0
}

# Test 1: reference fixture set -> oracle must PASS
run_oracle_expect \
    1 \
    "Reference assessment fixtures accepted by oracle" \
    "materialize" \
    "PASS"

# Test 2: static-expected challenge fixture replaced with a dynamically linked ARM executable
run_oracle_expect \
    2 \
    "Static-expected fixture mutated to a dynamically linked ARM executable" \
    "materialize; echo 'int main(void){return 0;}' | ${CROSS_COMPILE}gcc -x c - -no-pie -O2 -o challenge/fixtures/unknown_3" \
    "REJECT"

# Test 3: static-expected challenge fixture replaced with an ARM ET_DYN shared object (no PT_INTERP)
run_oracle_expect \
    3 \
    "Static-expected fixture mutated to an ARM ET_DYN shared object without PT_INTERP" \
    "materialize; echo 'int probe(void){return 1;}' | ${CROSS_COMPILE}gcc -shared -fPIC -x c - -O2 -o challenge/fixtures/unknown_3" \
    "REJECT"

# Test 4: dynamic-expected gate fixture mutated to request an unintended interpreter contract
# (-no-pie keeps ET_EXEC form so the oracle must reject on the CONTRACT itself)
run_oracle_expect \
    4 \
    "Dynamic-expected gate fixture mutated to an unintended interpreter contract" \
    "materialize; echo 'int main(void){return 0;}' | ${CROSS_COMPILE}gcc -x c - -no-pie -O2 -Wl,--dynamic-linker=/lib/ld-musl-armhf.so.1 -o gate/fixtures/candidate_alpha" \
    "REJECT"

# Test 5: static-expected gate fixture mutated to a host-compiled binary
run_oracle_expect \
    5 \
    "Static-expected gate fixture mutated to a host-compiled binary" \
    "materialize; echo 'int main(void){return 0;}' | $HOST_CC -x c - -O2 -o gate/fixtures/candidate_beta" \
    "REJECT"

# Test 6: guard — unrelated oracle failure must not be counted as a semantic reject
# (bogus toolchain makes the oracle exit nonzero with an environment error that
#  does NOT carry the semantic reject pattern)
echo "------------------------------------------------------------------"
echo "Test 6: Unrelated oracle failure must not count as semantic reject"
if ! materialize >/dev/null 2>&1; then
    echo "[TEST 6 FAIL] Fixture prep stage failed!"
    exit 1
fi
echo "  PREP: PASS"

set +e
GUARD_OUT=$(CROSS_COMPILE=guard-nonexistent-toolchain- bash reviewer/oracle_m01.sh 2>&1)
GUARD_RC=$?
set -e

if [ "$GUARD_RC" -ge 128 ]; then
    echo "[TEST 6 FAIL] Oracle crashed with signal $((GUARD_RC - 128))!"
    echo "$GUARD_OUT"
    exit 1
fi
if [ "$GUARD_RC" -eq 0 ]; then
    echo "[TEST 6 FAIL] Oracle falsely PASSED a broken environment!"
    echo "$GUARD_OUT"
    exit 1
fi
if echo "$GUARD_OUT" | grep -Eq "$REJECT_PATTERN"; then
    echo "[TEST 6 FAIL] Unrelated failure was miscounted as a semantic reject!"
    echo "$GUARD_OUT"
    exit 1
fi
echo "  GUARD RESULT: unrelated failure correctly NOT counted as semantic reject (exit $GUARD_RC)"
PASSED_TESTS=$((PASSED_TESTS + 1))

echo "------------------------------------------------------------------"
if [ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]; then
    echo "=== ALL P3-M01 ASSESSMENT ORACLE REGRESSION TESTS PASSED (${PASSED_TESTS}/${TOTAL_TESTS}) ==="
    exit 0
else
    echo "=== ERROR: Only ${PASSED_TESTS}/${TOTAL_TESTS} oracle regression tests passed! ===" >&2
    exit 1
fi
