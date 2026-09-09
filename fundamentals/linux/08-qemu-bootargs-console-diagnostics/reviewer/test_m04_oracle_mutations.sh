#!/bin/bash
set -euo pipefail

# P3-M04 Assessment Oracle Mutation Regression (REVIEWER-ONLY)
# Enforces, for the assessment oracle itself:
#   reviewer REFERENCE config (+ fresh runtime log) -> intended PASS
#   opaque starter/broken fixture as submission      -> intended REJECT
#   mutated config / forged or mismatched log        -> intended REJECT
#   crash / unrelated failure -> must NOT be counted as a reject
# Every test is graded as PREP PASS / ORACLE EXECUTION PASS / INTENDED RESULT.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
LINUX_DIR=$(cd "${M04_ROOT}/.." && pwd)
cd "$M04_ROOT"

ORACLE="bash reviewer/oracle_m04.sh"
REJECT_PATTERN="ASSESSMENT MISMATCH"
PASS_PATTERN="ASSESSMENT REFERENCE PASS"

GEN_CHALLENGE="reviewer/scripts/generate_m04_challenge_fixtures.sh"
GEN_GATE="reviewer/scripts/generate_m04_gate_fixtures.sh"

TOTAL_TESTS=8
PASSED_TESTS=0

materialize() {
    bash "$GEN_CHALLENGE" challenge/fixtures
    bash "$GEN_GATE" gate/fixtures
}

run_oracle_expect() {
    local test_id="$1"
    local desc="$2"
    local expect_kind="$3"   # PASS | REJECT
    shift 3
    local out=""
    local rc=0

    echo "------------------------------------------------------------------"
    echo "Test ${test_id}: ${desc}"

    set +e
    out=$($ORACLE "$@" 2>&1)
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
echo "=== P3-M04 Assessment Oracle Mutation Regression               ==="
echo "=================================================================="

materialize
echo "[PREP] Assessment fixtures + reviewer references materialized."

MUTWORK=$(mktemp -d /tmp/m04_oraclemut_XXXXXX)
trap 'rm -rf "$MUTWORK"' EXIT

# 1. Gate reviewer reference config must PASS (contract only).
run_oracle_expect "1" "Gate reviewer reference config" \
    "PASS" "reviewer/reference/gate_launch.sh"

# 2. Gate opaque starter as submission must REJECT.
run_oracle_expect "2" "Gate opaque starter (unrepaired)" \
    "REJECT" "gate/fixtures/starter_launch.sh"

# 3. Challenge opaque broken config as submission must REJECT.
run_oracle_expect "3" "Challenge opaque broken config (unrepaired)" \
    "REJECT" "challenge/fixtures/broken_launch.sh"

# 4. Challenge reviewer reference config must PASS (contract only).
run_oracle_expect "4" "Challenge reviewer reference config" \
    "PASS" "reviewer/reference/challenge_launch.sh"

# 5. Fresh runtime capture for the canonical reference, then oracle with
# log binding must PASS (proves actual execution, not a stock log).
LINUX_SRC="${LINUX_SRC:-/tmp/linux-6.18.50}"
REAL_ZIMAGE="$LINUX_SRC/arch/arm/boot/zImage"
REAL_INITRD="$LINUX_DIR/07-minimal-rootfs-busybox-init/fixtures/build/real_rootfs.cpio.gz"
if [ ! -f "$REAL_ZIMAGE" ] || [ ! -f "$REAL_INITRD" ]; then
    echo "[TEST 5 FAIL] Re-execution requires real kernel + real initramfs." >&2
    exit 1
fi
if ! command -v qemu-system-arm >/dev/null 2>&1; then
    echo "[TEST 5 FAIL] qemu-system-arm not found in PATH." >&2
    exit 1
fi
REF_BOOTARGS=$(grep -E '^[[:space:]]*BOOTARGS=' reviewer/reference/gate_launch.sh | tail -n 1 | sed -E 's/^[^=]*=["'"'"']?//; s/["'"'"']$//')
TIMEOUT_SEC=40 bash scripts/run_qemu_diagnostic.sh "$REF_BOOTARGS" "$MUTWORK/ref_boot.log" >/dev/null 2>&1 || true
run_oracle_expect "5" "Canonical reference + fresh runtime log binding" \
    "PASS" "reviewer/reference/gate_launch.sh" "$MUTWORK/ref_boot.log"

# 6. Mutated config (wrong console) must REJECT even with the good log.
sed 's/console=ttyAMA0,115200/console=ttyS0,115200/' reviewer/reference/gate_launch.sh > "$MUTWORK/mut_console.sh"
chmod 755 "$MUTWORK/mut_console.sh"
run_oracle_expect "6" "Mutated config (wrong console) + good log" \
    "REJECT" "$MUTWORK/mut_console.sh" "$MUTWORK/ref_boot.log"

# 7. Forged milestone text as candidate log must REJECT.
printf '%s\n' \
    "Linux version 6.18.50" \
    "CPU: ARMv7 Processor" \
    "Kernel command line: $REF_BOOTARGS" \
    "printk: console [ttyAMA0] enabled" \
    "Trying to unpack rootfs image as initramfs" \
    "Run /init as init process" \
    "REAL-BUSYBOX-INIT-READY" > "$MUTWORK/forged.log"
run_oracle_expect "7" "Good config + forged milestone log" \
    "REJECT" "reviewer/reference/gate_launch.sh" "$MUTWORK/forged.log"

# 8. Truncated real log (kernel prefix without userspace) must REJECT: the
# runtime portion cannot be satisfied by a partial capture.
head -n 40 "$MUTWORK/ref_boot.log" > "$MUTWORK/truncated.log"
run_oracle_expect "8" "Good config + truncated log (no userspace evidence)" \
    "REJECT" "reviewer/reference/gate_launch.sh" "$MUTWORK/truncated.log"

echo "=================================================================="
if [ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]; then
    echo "=== ALL $PASSED_TESTS P3-M04 ORACLE MUTATION CHECKS PASSED ==="
    exit 0
else
    echo "=== ORACLE MUTATION FAIL: $PASSED_TESTS/$TOTAL_TESTS passed ===" >&2
    exit 1
fi
