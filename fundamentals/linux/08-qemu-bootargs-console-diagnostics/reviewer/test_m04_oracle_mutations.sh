#!/bin/bash
set -euo pipefail

# P3-M04 Assessment Oracle Mutation Regression (REVIEWER-ONLY)
#
# Enforces, for the assessment oracle itself:
#   reviewer REFERENCE manifest (+ fresh executed-argv-bound runtime) -> PASS
#   opaque starter/broken manifests as submission                    -> REJECT
#   executed-argv document that disagrees with the manifest
#       (the "declarations are a decoy, the invocation differs" class)  -> REJECT
#   wrong machine / CPU / RAM / SMP / bootargs actually executed        -> REJECT
#   canonical reference log substituted for another candidate run      -> REJECT
#   forged, truncated, or non-executed logs                            -> REJECT
#   infrastructure failure -> must NOT be reported as a semantic REJECT
#
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

LINUX_SRC="${LINUX_SRC:-/tmp/linux-6.18.50}"
REAL_ZIMAGE="$LINUX_SRC/arch/arm/boot/zImage"
REAL_INITRD="$LINUX_DIR/07-minimal-rootfs-busybox-init/fixtures/build/real_rootfs.cpio.gz"

TOTAL_TESTS=0
PASSED_TESTS=0

materialize() {
    bash "$GEN_CHALLENGE" challenge/fixtures
    bash "$GEN_GATE" gate/fixtures
}

run_oracle_expect() {
    local test_id="$1" desc="$2" expect_kind="$3"
    shift 3
    local out="" rc=0
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

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
echo "=== P3-M04 Assessment Oracle Mutation Regression (Round 2)     ==="
echo "=================================================================="

materialize
echo "[PREP] Assessment manifests + reviewer references materialized."

MUTWORK=$(mktemp -d /tmp/m04_oraclemut_XXXXXX)
trap 'rm -rf "$MUTWORK"' EXIT

REF_MANIFEST="reviewer/reference/gate_manifest.conf"

# ---------------------------------------------------------------- contract
# 1. Reviewer reference manifest must PASS (contract only, no runtime).
run_oracle_expect "1" "Reviewer reference manifest (contract)" \
    "PASS" "$REF_MANIFEST"

# 2. Opaque Gate starter (unrepaired) must REJECT.
run_oracle_expect "2" "Gate opaque starter manifest (unrepaired)" \
    "REJECT" "gate/fixtures/starter_manifest.conf"

# 3. Opaque Challenge starter (unrepaired) must REJECT.
run_oracle_expect "3" "Challenge opaque broken manifest (unrepaired)" \
    "REJECT" "challenge/fixtures/broken_manifest.conf"

# 4. Challenge reviewer reference must PASS (contract only).
run_oracle_expect "4" "Challenge reviewer reference manifest" \
    "PASS" "reviewer/reference/challenge_manifest.conf"

# ------------------------------------------------- executed runtime binding
if [ ! -f "$REAL_ZIMAGE" ] || [ ! -f "$REAL_INITRD" ]; then
    echo "[PREP FAIL] Runtime binding tests require the pinned real kernel and real BusyBox initramfs." >&2
    echo "            kernel: $REAL_ZIMAGE" >&2
    echo "            initrd: $REAL_INITRD" >&2
    exit 1
fi
if ! command -v qemu-system-arm >/dev/null 2>&1; then
    echo "[PREP FAIL] qemu-system-arm not found in PATH." >&2
    exit 1
fi

# PREP: fresh candidate-bound capture of the canonical reference manifest,
# produced ONLY through the trusted manifest runner.
REF_LOG="$MUTWORK/ref_boot.log"
REF_ARGV="$MUTWORK/ref_boot.argv"
echo "[PREP] Capturing fresh canonical candidate-bound runtime evidence..."
TIMEOUT_SEC="${TIMEOUT_SEC:-60}" bash scripts/run_candidate_manifest.sh \
    "$REF_MANIFEST" "$REF_LOG" "$REF_ARGV" >/dev/null 2>&1 || true
if [ ! -s "$REF_LOG" ] || [ ! -s "$REF_ARGV" ]; then
    echo "[PREP FAIL] Fresh canonical runtime capture was not produced." >&2
    exit 1
fi
echo "[PREP] Fresh canonical capture OK ($(wc -l < "$REF_LOG") log lines)."

# 5. Canonical reference manifest + its own executed argv + fresh log -> PASS.
run_oracle_expect "5" "Canonical reference manifest + own executed argv + fresh runtime" \
    "PASS" "$REF_MANIFEST" "$REF_ARGV" "$REF_LOG"

# 6. Canonical archive substituted: the canonical log presented as evidence
#    for a DIFFERENT candidate manifest (the learner never ran it).
mkdir -p "$MUTWORK/other_candidate"
sed 's/^MEM=512M$/MEM=512M/' "$REF_MANIFEST" > "$MUTWORK/other_candidate/manifest.conf"
printf '%s\n' \
    "# executed-candidate provenance for a DIFFERENT manifest" \
    "MACHINE=virt,highmem=off,gic-version=2" \
    "CPU=cortex-a7" \
    "MEM=256M" \
    "SMP=1" \
    "NOGRAPHIC=true" \
    "BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init" \
    "KERNEL=$REAL_ZIMAGE" \
    "INITRD=$REAL_INITRD" \
    "ARGV_FINGERPRINT=deadbeef" \
    "TIMEOUT_SEC=60" > "$MUTWORK/other_candidate/other.argv"
run_oracle_expect "6" "Canonical log + foreign executed-argv as evidence for this manifest" \
    "REJECT" "$MUTWORK/other_candidate/manifest.conf" "$MUTWORK/other_candidate/other.argv" "$REF_LOG"

# --------------------------------------- executed-argv override (host side)
# 7. DECOY MACHINE: manifest declares canonical machine, executed argv used
#    the wrong machine (vexpress-a9) -> REJECT.
sed 's/^MACHINE=virt,highmem=off,gic-version=2$/MACHINE=vexpress-a9/' \
    "$REF_ARGV" > "$MUTWORK/argv_wrong_machine.argv"
run_oracle_expect "7" "Correct MACHINE declaration but wrong machine actually executed" \
    "REJECT" "$REF_MANIFEST" "$MUTWORK/argv_wrong_machine.argv" "$REF_LOG"

# 8. DECOY CPU: canonical CPU declared, invocation omitted/overrode it.
sed 's/^CPU=cortex-a7$/CPU=cortex-a15/' "$REF_ARGV" > "$MUTWORK/argv_wrong_cpu.argv"
run_oracle_expect "8" "Correct CPU declaration but different CPU actually executed" \
    "REJECT" "$REF_MANIFEST" "$MUTWORK/argv_wrong_cpu.argv" "$REF_LOG"

# 9. DECOY MEM: canonical MEM declared, another RAM value actually executed.
sed 's/^MEM=512M$/MEM=256M/' "$REF_ARGV" > "$MUTWORK/argv_wrong_mem.argv"
run_oracle_expect "9" "Correct MEM declaration but different RAM actually executed" \
    "REJECT" "$REF_MANIFEST" "$MUTWORK/argv_wrong_mem.argv" "$REF_LOG"

# 10. DECOY SMP: canonical SMP declared, another SMP value actually executed.
sed 's/^SMP=1$/SMP=2/' "$REF_ARGV" > "$MUTWORK/argv_wrong_smp.argv"
run_oracle_expect "10" "Correct SMP declaration but different SMP actually executed" \
    "REJECT" "$REF_MANIFEST" "$MUTWORK/argv_wrong_smp.argv" "$REF_LOG"

# 11. DECOY highmem/GIC: machine sub-dimensions cannot be dropped silently.
sed 's/^MACHINE=virt,highmem=off,gic-version=2$/MACHINE=virt,gic-version=2/' \
    "$REF_ARGV" > "$MUTWORK/argv_no_highmem.argv"
run_oracle_expect "11" "Correct machine declaration but highmem=off not executed" \
    "REJECT" "$REF_MANIFEST" "$MUTWORK/argv_no_highmem.argv" "$REF_LOG"

# 12. Executed argv points at the synthetic teaching fixture instead of the
#     real initramfs -> REJECT.
sed "s#^INITRD=.*#INITRD=/tmp/synthetic_rootfs.cpio.gz#" \
    "$REF_ARGV" > "$MUTWORK/argv_synthetic.argv"
run_oracle_expect "12" "Executed initrd is the synthetic teaching fixture" \
    "REJECT" "$REF_MANIFEST" "$MUTWORK/argv_synthetic.argv" "$REF_LOG"

# ----------------------------------------- guest-evidence mismatch controls
# 13. Logged guest RAM does not match the executed -m value.
sed 's/\(Memory: \)[0-9]*K\/\([0-9]*\)K available/\1 200000K\/204800K available/' \
    "$REF_LOG" > "$MUTWORK/log_wrong_ram.log"
run_oracle_expect "13" "Guest RAM evidence does not match executed -m" \
    "REJECT" "$REF_MANIFEST" "$REF_ARGV" "$MUTWORK/log_wrong_ram.log"

# 14. Logged guest command line does not match the executed BOOTARGS.
sed 's/console=ttyAMA0,115200/console=ttyS0,115200/' \
    "$REF_LOG" > "$MUTWORK/log_wrong_cmdline.log"
run_oracle_expect "14" "Logged command line mismatches executed bootargs" \
    "REJECT" "$REF_MANIFEST" "$REF_ARGV" "$MUTWORK/log_wrong_cmdline.log"

# 15. Forged milestone text (ordered strings only, no real capture).
printf '%s\n' \
    "Booting Linux on physical CPU 0x0" \
    "Linux version 6.18.50" \
    "printk: legacy bootconsole [pl11] enabled" \
    "Kernel command line: earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init" \
    "Memory: 508312K/524288K available" \
    "printk: console [ttyAMA0] enabled" \
    "printk: legacy bootconsole [pl11] disabled" \
    "Trying to unpack rootfs image as initramfs" \
    "Freeing unused kernel image (initmem) memory" \
    "Run /init as init process" \
    "=== REAL-BUSYBOX-INIT-READY ===" \
    "BusyBox v1.36.1 multi-call binary." \
    "PID   USER     TIME  COMMAND" > "$MUTWORK/forged.log"
run_oracle_expect "15" "Good manifest + forged milestone log" \
    "REJECT" "$REF_MANIFEST" "$REF_ARGV" "$MUTWORK/forged.log"

# 16. Truncated real log (kernel prefix without userspace evidence).
head -n 40 "$REF_LOG" > "$MUTWORK/truncated.log"
run_oracle_expect "16" "Good manifest + truncated log (no userspace evidence)" \
    "REJECT" "$REF_MANIFEST" "$REF_ARGV" "$MUTWORK/truncated.log"

# --------------------------------------------- manifest schema/conflict set
# 17. Unknown manifest key (a runner could not honour it) -> REJECT.
cp "$REF_MANIFEST" "$MUTWORK/unknown_key.conf"
echo "EXTRA_QEMU_ARGS=-serial mon:stdio" >> "$MUTWORK/unknown_key.conf"
run_oracle_expect "17" "Manifest declares an unknown launch key" \
    "REJECT" "$MUTWORK/unknown_key.conf"

# 18. Duplicate definition of a scored key -> REJECT.
cp "$REF_MANIFEST" "$MUTWORK/dup_key.conf"
echo "SMP=2" >> "$MUTWORK/dup_key.conf"
run_oracle_expect "18" "Manifest duplicates a scored key" \
    "REJECT" "$MUTWORK/dup_key.conf"

# 19. Missing required key -> REJECT.
grep -v '^NOGRAPHIC=' "$REF_MANIFEST" > "$MUTWORK/missing_key.conf"
run_oracle_expect "19" "Manifest omits a required key" \
    "REJECT" "$MUTWORK/missing_key.conf"

# 20. Non-declarative shell content in the manifest -> REJECT.
cp "$REF_MANIFEST" "$MUTWORK/shell_content.conf"
echo 'qemu-system-arm -machine vexpress-a9 -cpu cortex-a15 -m 256M -smp 2' >> "$MUTWORK/shell_content.conf"
run_oracle_expect "20" "Manifest smuggles a shell invocation alongside declarations" \
    "REJECT" "$MUTWORK/shell_content.conf"

# 21. Command-substitution attempt in a value -> REJECT.
cp "$REF_MANIFEST" "$MUTWORK/subst.conf"
sed -i 's#^MEM=512M$#MEM=$(echo 256M)#' "$MUTWORK/subst.conf"
run_oracle_expect "21" "Manifest value uses command substitution" \
    "REJECT" "$MUTWORK/subst.conf"

# 21b. Exact-BOOTARGS (Round 3): canonical three tokens + harmless-looking
#      extra token (loglevel=8) -> REJECT. The scored manifest allows no
#      additional kernel args.
sed 's#^BOOTARGS=.*#BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init loglevel=8#' \
    "$REF_MANIFEST" > "$MUTWORK/extra_harmless.conf"
run_oracle_expect "21b" "Canonical BOOTARGS plus harmless extra token (loglevel=8)" \
    "REJECT" "$MUTWORK/extra_harmless.conf"

# 21c. Exact-BOOTARGS (Round 3): canonical three tokens + behavior-changing
#      extra token (init=/bin/sh) -> REJECT.
sed 's#^BOOTARGS=.*#BOOTARGS=earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init init=/bin/sh#' \
    "$REF_MANIFEST" > "$MUTWORK/extra_behavior.conf"
run_oracle_expect "21c" "Canonical BOOTARGS plus behavior-changing extra token (init=/bin/sh)" \
    "REJECT" "$MUTWORK/extra_behavior.conf"

# ------------------------------------------- infrastructure failure control
# 22. Unrelated tool failure must NOT be reported as a semantic REJECT.
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo "------------------------------------------------------------------"
echo "Test 22: Unrelated environment failure is not a semantic REJECT"
set +e
INFRA_OUT=$(TIMEOUT_SEC=5 QEMU_BIN=qemu-system-does-not-exist \
    bash scripts/run_candidate_manifest.sh "$REF_MANIFEST" \
    "$MUTWORK/infra.log" "$MUTWORK/infra.argv" 2>&1)
INFRA_RC=$?
set -e
if [ "$INFRA_RC" -eq 0 ]; then
    echo "[TEST 22 FAIL] Missing QEMU reported success."
    echo "$INFRA_OUT"
    exit 1
fi
if echo "$INFRA_OUT" | grep -q "REJECT"; then
    echo "[TEST 22 FAIL] Missing QEMU was reported as a semantic REJECT (must be an environment failure)."
    echo "$INFRA_OUT"
    exit 1
fi
echo "  ORACLE EXECUTION: PASS (no crash, exit $INFRA_RC)"
echo "  INTENDED RESULT: environment failure, NOT a semantic REJECT"
PASSED_TESTS=$((PASSED_TESTS + 1))

echo "=================================================================="
if [ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]; then
    echo "=== ALL $PASSED_TESTS P3-M04 ORACLE MUTATION CHECKS PASSED ==="
    exit 0
fi
echo "=== ORACLE MUTATION FAIL: $PASSED_TESTS/$TOTAL_TESTS passed ===" >&2
exit 1
