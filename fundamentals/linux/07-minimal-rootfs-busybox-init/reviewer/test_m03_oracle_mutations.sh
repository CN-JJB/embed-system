#!/bin/bash
set -euo pipefail

# P3-M03 Assessment Oracle Mutation Regression (REVIEWER-ONLY)
# Enforces, for the assessment oracle itself:
#   reviewer REFERENCE candidate -> intended PASS
#   defective fixture as submission -> intended semantic REJECT
#   mutated reference             -> intended semantic REJECT
#   crash / unrelated failure     -> must NOT be counted as a reject
# Every test is graded as PREP PASS / ORACLE EXECUTION PASS / INTENDED RESULT.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M03_ROOT"

CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "ERROR: Cross compiler '${CROSS_COMPILE}gcc' not found in PATH." >&2
    exit 1
fi

ORACLE="bash reviewer/oracle_m03.sh"
REJECT_PATTERN="ASSESSMENT MISMATCH"
PASS_PATTERN="ASSESSMENT REFERENCE PASS"

GEN_CHALLENGE="reviewer/scripts/generate_m03_challenge_fixtures.sh"
GEN_GATE="reviewer/scripts/generate_m03_gate_fixtures.sh"

TOTAL_TESTS=8
PASSED_TESTS=0

materialize() {
    bash "$GEN_CHALLENGE" challenge/fixtures "$CROSS_COMPILE"
    bash "$GEN_GATE" gate/fixtures "$CROSS_COMPILE"
}

run_oracle_expect() {
    local test_id="$1"
    local desc="$2"
    local candidate="$3"
    local expect_kind="$4"   # PASS | REJECT
    local out=""
    local rc=0

    echo "------------------------------------------------------------------"
    echo "Test ${test_id}: ${desc}"

    set +e
    out=$($ORACLE "$candidate" 2>&1)
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
                echo "[TEST ${test_id} FAIL] Oracle falsely PASSED a defective artifact!"
                echo "$out"
                return 1
            fi
            if ! echo "$out" | grep -Eq "$REJECT_PATTERN"; then
                echo "[TEST ${test_id} FAIL] Oracle reject output lacks semantic pattern '${REJECT_PATTERN}'."
                echo "  Exit code: $rc"
                echo "$out"
                return 1
            fi
            echo "  INTENDED RESULT: semantic REJECT (pattern matched, exit $rc)"
            ;;
    esac

    PASSED_TESTS=$((PASSED_TESTS + 1))
}

echo "=================================================================="
echo "=== P3-M03 Assessment Oracle Mutation Regression               ==="
echo "=================================================================="

materialize
echo "[PREP] Assessment fixtures + reviewer references materialized."

MUTWORK=$(mktemp -d /tmp/m03_oraclemut_XXXXXX)
trap 'rm -rf "$MUTWORK"' EXIT

# 1. Challenge reference must PASS.
run_oracle_expect "1" "Challenge reviewer reference" \
    "reviewer/reference/challenge_rootfs" "PASS"

# 2. Challenge defective fixture as submission must REJECT.
run_oracle_expect "2" "Challenge defective fixture (unrepaired)" \
    "challenge/fixtures/defective_rootfs" "REJECT"

# 3. Gate reference must PASS.
run_oracle_expect "3" "Gate reviewer reference" \
    "reviewer/reference/gate_rootfs" "PASS"

# 4. Gate defective fixture as submission must REJECT.
run_oracle_expect "4" "Gate defective fixture (unrepaired)" \
    "gate/fixtures/defective_rootfs" "REJECT"

# 5. Mutated reference: broken applet symlink must REJECT.
cp -a reviewer/reference/gate_rootfs "$MUTWORK/mut_broken_link"
ln -sf stale_target "$MUTWORK/mut_broken_link/bin/ls"
run_oracle_expect "5" "Mutated reference (broken applet symlink)" \
    "$MUTWORK/mut_broken_link" "REJECT"

# 6. Mutated reference: proc echo-decoy in the graded init must REJECT.
cp -a reviewer/reference/gate_rootfs "$MUTWORK/mut_decoy"
printf '#!/bin/sh\necho "mount -t proc none /proc"\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\nexec /bin/sh\n' > "$MUTWORK/mut_decoy/init"
chmod 755 "$MUTWORK/mut_decoy/init"
run_oracle_expect "6" "Mutated reference (proc echo-decoy, no active mount)" \
    "$MUTWORK/mut_decoy" "REJECT"

# 7. Mutated reference: wrong inittab console must REJECT.
cp -a reviewer/reference/challenge_rootfs "$MUTWORK/mut_inittab"
sed -i 's/^ttyAMA0::askfirst/ttyS0::askfirst/' "$MUTWORK/mut_inittab/etc/inittab"
run_oracle_expect "7" "Mutated reference (wrong inittab console)" \
    "$MUTWORK/mut_inittab" "REJECT"

# 8. Mutated reference: stripped init exec bit must REJECT.
cp -a reviewer/reference/gate_rootfs "$MUTWORK/mut_noexec"
chmod -x "$MUTWORK/mut_noexec/init"
chmod -x "$MUTWORK/mut_noexec/sbin/init" 2>/dev/null || true
run_oracle_expect "8" "Mutated reference (init not executable)" \
    "$MUTWORK/mut_noexec" "REJECT"

echo "=================================================================="
if [ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]; then
    echo "=== ALL $PASSED_TESTS P3-M03 ORACLE MUTATION CHECKS PASSED ==="
    exit 0
else
    echo "=== ORACLE MUTATION FAIL: $PASSED_TESTS/$TOTAL_TESTS passed ===" >&2
    exit 1
fi
