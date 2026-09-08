#!/bin/bash
set -euo pipefail

# P3-M02 Assessment Oracle Mutation Regression (REVIEWER-ONLY)
# Enforces, for the assessment oracle itself:
#   REFERENCE fixture  -> intended PASS
#   mutated artifact   -> intended semantic REJECT
#   crash / unrelated failure -> must NOT be counted as a successful reject

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M02_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M02_ROOT"

CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "ERROR: Cross compiler '${CROSS_COMPILE}gcc' not found in PATH." >&2
    exit 1
fi

ORACLE="bash reviewer/oracle_m02.sh"
REJECT_PATTERN="ASSESSMENT MISMATCH"
PASS_PATTERN="ASSESSMENT REFERENCE PASS"

GEN_CHALLENGE="reviewer/scripts/generate_m02_challenge_fixtures.sh"
GEN_GATE="reviewer/scripts/generate_m02_gate_fixtures.sh"

TOTAL_TESTS=7
PASSED_TESTS=0

materialize() {
    bash "$GEN_CHALLENGE" challenge/fixtures "$CROSS_COMPILE"
    bash "$GEN_GATE" gate/fixtures "$CROSS_COMPILE"
}

run_oracle_expect() {
    local test_id="$1"
    local desc="$2"
    local prep_cmd="$3"
    local expect_kind="$4"   # PASS | REJECT | GUARD
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

# Test 2: challenge config mutated — expected deviation removed
run_oracle_expect \
    2 \
    "Challenge config mutated (seeded deviation removed)" \
    "materialize; sed -i 's/^CONFIG_ARM_LPAE=y/# CONFIG_ARM_LPAE is not set/' challenge/fixtures/candidate_effective.config" \
    "REJECT"

# Test 3: challenge System.map mutated — expected drift repaired
run_oracle_expect \
    3 \
    "Challenge System.map mutated (seeded drift repaired)" \
    "materialize; \$(command -v ${CROSS_COMPILE}nm || echo nm) -n challenge/fixtures/candidate_vmlinux | awk '{print \$1, \$2, \$3}' > challenge/fixtures/candidate_System.map" \
    "REJECT"

# Test 4: gate config mutated — expected deviation removed
run_oracle_expect \
    4 \
    "Gate config mutated (seeded deviation removed)" \
    "materialize; sed -i 's/^# CONFIG_VIRTIO_BLK is not set/CONFIG_VIRTIO_BLK=y/' gate/fixtures/gate_effective.config" \
    "REJECT"

# Test 5: gate System.map mutated — drift moved to a different symbol
run_oracle_expect \
    5 \
    "Gate System.map mutated (drift moved to an unintended symbol)" \
    "materialize; \$(command -v ${CROSS_COMPILE}nm || echo nm) -n gate/fixtures/gate_vmlinux | awk '{if (\$3 == \"start_kernel\") print \"c0809000\", \$2, \$3; else print \$1, \$2, \$3}' > gate/fixtures/gate_System.map" \
    "REJECT"

# Test 6: gate zImage mutated — magic corrupted
run_oracle_expect \
    6 \
    "Gate zImage mutated (boot magic corrupted)" \
    "materialize; python3 -c 'import struct; b = bytearray(64); struct.pack_into(\"<I\", b, 0x24, 0xdeadbeef); open(\"gate/fixtures/gate_zImage\", \"wb\").write(b)'" \
    "REJECT"

# Test 7: guard — unrelated oracle failure must not be counted as a semantic reject
# (bogus toolchain makes the oracle exit nonzero with an environment error that
#  does NOT carry the semantic reject pattern)
echo "------------------------------------------------------------------"
echo "Test 7: Unrelated oracle failure must not count as semantic reject"
if ! materialize >/dev/null 2>&1; then
    echo "[TEST 7 FAIL] Fixture prep stage failed!"
    exit 1
fi
echo "  PREP: PASS"

set +e
GUARD_OUT=$(CROSS_COMPILE=guard-nonexistent-toolchain- bash reviewer/oracle_m02.sh 2>&1)
GUARD_RC=$?
set -e

if [ "$GUARD_RC" -ge 128 ]; then
    echo "[TEST 7 FAIL] Oracle crashed with signal $((GUARD_RC - 128))!"
    echo "$GUARD_OUT"
    exit 1
fi
if [ "$GUARD_RC" -eq 0 ]; then
    echo "[TEST 7 FAIL] Oracle falsely PASSED a broken environment!"
    echo "$GUARD_OUT"
    exit 1
fi
if echo "$GUARD_OUT" | grep -Eq "$REJECT_PATTERN"; then
    echo "[TEST 7 FAIL] Unrelated failure was miscounted as a semantic reject!"
    echo "$GUARD_OUT"
    exit 1
fi
echo "  GUARD RESULT: unrelated failure correctly NOT counted as semantic reject (exit $GUARD_RC)"
PASSED_TESTS=$((PASSED_TESTS + 1))

echo "------------------------------------------------------------------"
if [ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]; then
    echo "=== ALL P3-M02 ASSESSMENT ORACLE REGRESSION TESTS PASSED (${PASSED_TESTS}/${TOTAL_TESTS}) ==="
    exit 0
else
    echo "=== ERROR: Only ${PASSED_TESTS}/${TOTAL_TESTS} oracle regression tests passed! ===" >&2
    exit 1
fi
