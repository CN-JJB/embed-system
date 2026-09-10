#!/bin/bash
set -euo pipefail

# P3-M03 Assessment Oracle Mutation Regression (REVIEWER-ONLY, Round 2)
#
# Enforces, for the scored M03 contract:
#   reviewer REFERENCE candidate -> intended PASS
#   defective fixture as submission -> intended semantic REJECT
#   mutated reference -> intended semantic REJECT
#   crash / unrelated failure -> must NOT be counted as a reject
#   real-BusyBox scored runtime (packaged archive actually booted) -> PASS
#   static-only correctness that does not survive the packaged archive
#   runtime -> REJECT
#
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
GRADE_GATE="bash reviewer/grade_m03_gate.sh"
RUNTIME_VERIFY="bash scripts/verify_busybox_candidate_runtime.sh"
# The oracle/grade entry points report "ASSESSMENT MISMATCH"; the runtime and
# artifact verifiers report "REJECT". Either is a semantic (non-crash) reject.
REJECT_PATTERN="ASSESSMENT MISMATCH|REJECT"
PASS_PATTERN="ASSESSMENT REFERENCE PASS"

GEN_CHALLENGE="reviewer/scripts/generate_m03_challenge_fixtures.sh"
GEN_GATE="reviewer/scripts/generate_m03_gate_fixtures.sh"

CH_REF="reviewer/reference/challenge_rootfs"
GATE_REF="reviewer/reference/gate_rootfs"
GATE_REF_ARCHIVE="reviewer/reference/gate_rootfs.cpio.gz"

TOTAL_TESTS=0
PASSED_TESTS=0

materialize() {
    bash "$GEN_CHALLENGE" challenge/fixtures "$CROSS_COMPILE"
    bash "$GEN_GATE" gate/fixtures "$CROSS_COMPILE"
}

# --- generic "run a reviewer entry point and expect a verdict" harness -----
# run_expect <id> <desc> <PASS|REJECT> [PASS_PATTERN=<regex>] <cmd...>
# A leading PASS_PATTERN=... token overrides the default success regex (the
# runtime verifier reports success with its own wording).
run_expect() {
    local test_id="$1" desc="$2" expect_kind="$3"
    shift 3
    local expect_pass_pattern="$PASS_PATTERN"
    if [ "${1:-}" != "${1#PASS_PATTERN=}" ]; then
        expect_pass_pattern="${1#PASS_PATTERN=}"
        shift
    fi
    local out="" rc=0
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo "------------------------------------------------------------------"
    echo "Test ${test_id}: ${desc}"

    set +e
    out=$("$@" 2>&1)
    rc=$?
    set -e

    if [ "$rc" -ge 128 ]; then
        echo "[TEST ${test_id} FAIL] Entry point crashed with signal $((rc - 128))!"
        echo "$out"
        return 1
    fi
    echo "  ORACLE EXECUTION: PASS (no crash, exit $rc)"

    case "$expect_kind" in
        PASS)
            if [ "$rc" -ne 0 ] || ! echo "$out" | grep -qE "$expect_pass_pattern"; then
                echo "[TEST ${test_id} FAIL] Expected PASS (exit 0, pattern '${expect_pass_pattern}')."
                echo "  Exit code: $rc"
                echo "$out"
                return 1
            fi
            echo "  INTENDED RESULT: PASS (reference accepted)"
            ;;
        REJECT)
            if [ "$rc" -eq 0 ]; then
                echo "[TEST ${test_id} FAIL] Falsely PASSED a defective artifact!"
                echo "$out"
                return 1
            fi
            if ! echo "$out" | grep -Eq "$REJECT_PATTERN"; then
                echo "[TEST ${test_id} FAIL] Reject output lacks semantic pattern '${REJECT_PATTERN}'."
                echo "  Exit code: $rc"
                echo "$out"
                return 1
            fi
            echo "  INTENDED RESULT: semantic REJECT (pattern matched, exit $rc)"
            ;;
    esac

    PASSED_TESTS=$((PASSED_TESTS + 1))
}

run_oracle_expect() {
    local test_id="$1" desc="$2" candidate="$3" expect_kind="$4"
    run_expect "$test_id" "$desc" "$expect_kind" $ORACLE "$candidate"
}

echo "=================================================================="
echo "=== P3-M03 Assessment Oracle Mutation Regression (Round 2)     ==="
echo "=================================================================="

materialize
echo "[PREP] Real-BusyBox assessment fixtures + reviewer references materialized."
bash scripts/validate_real_busybox.sh "$GATE_REF" >/dev/null
echo "[PREP] Reviewer reference carries a verified real BusyBox artifact."

MUTWORK=$(mktemp -d /tmp/m03_oraclemut_XXXXXX)
trap 'rm -rf "$MUTWORK"' EXIT

# ============================ STATIC CONTRACT =============================
run_oracle_expect "1" "Challenge reviewer reference" "$CH_REF" "PASS"
run_oracle_expect "2" "Challenge defective fixture (unrepaired)" \
    "challenge/fixtures/defective_rootfs" "REJECT"
run_oracle_expect "3" "Gate reviewer reference" "$GATE_REF" "PASS"
run_oracle_expect "4" "Gate defective fixture (unrepaired)" \
    "gate/fixtures/defective_rootfs" "REJECT"

# 5. Synthetic multicall substituted for real BusyBox -> REJECT.
SYNTH_BIN="$MUTWORK/synthetic_multicall"
"${CROSS_COMPILE}gcc" -static -Wall -Werror -O2 \
    fixtures/src/synthetic_multicall.c -o "$SYNTH_BIN"
cp -a "$GATE_REF" "$MUTWORK/mut_synthetic"
rm -f "$MUTWORK/mut_synthetic/bin/busybox"
cp "$SYNTH_BIN" "$MUTWORK/mut_synthetic/bin/busybox"
chmod 755 "$MUTWORK/mut_synthetic/bin/busybox"
rm -f "$MUTWORK/mut_synthetic/sbin/init"
ln -sf ../bin/busybox "$MUTWORK/mut_synthetic/sbin/init"
run_oracle_expect "5" "Synthetic multicall renamed as bin/busybox (real-BusyBox masquerade)" \
    "$MUTWORK/mut_synthetic" "REJECT"

# 6. Valid static ARM NON-BusyBox binary masquerading as BusyBox -> REJECT.
NONBB_SRC="$MUTWORK/notbusybox.c"
cat > "$NONBB_SRC" << 'EOF'
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    (void)argc; (void)argv;
    printf("init: starting up\n");
    return 0;
}
EOF
"${CROSS_COMPILE}gcc" -static -O2 "$NONBB_SRC" -o "$MUTWORK/notbusybox"
cp -a "$GATE_REF" "$MUTWORK/mut_nonbusybox"
rm -f "$MUTWORK/mut_nonbusybox/bin/busybox"
cp "$MUTWORK/notbusybox" "$MUTWORK/mut_nonbusybox/bin/busybox"
chmod 755 "$MUTWORK/mut_nonbusybox/bin/busybox"
rm -f "$MUTWORK/mut_nonbusybox/sbin/init"
ln -sf ../bin/busybox "$MUTWORK/mut_nonbusybox/sbin/init"
run_oracle_expect "6" "Static ARM non-BusyBox binary masquerading as BusyBox" \
    "$MUTWORK/mut_nonbusybox" "REJECT"

# 7. Broken applet symlink -> REJECT.
cp -a "$GATE_REF" "$MUTWORK/mut_broken_link"
ln -sf stale_target "$MUTWORK/mut_broken_link/bin/ls"
run_oracle_expect "7" "Mutated reference (broken applet symlink)" \
    "$MUTWORK/mut_broken_link" "REJECT"

# 8. Static inittab that looks plausible but cannot activate the console.
cp -a "$CH_REF" "$MUTWORK/mut_inittab_console"
sed -i 's/^ttyAMA0::askfirst/ttyS0::askfirst/' "$MUTWORK/mut_inittab_console/etc/inittab"
run_oracle_expect "8" "Mutated reference (wrong inittab console)" \
    "$MUTWORK/mut_inittab_console" "REJECT"

# 9. Competing askfirst entry -> REJECT.
cp -a "$CH_REF" "$MUTWORK/mut_inittab_dup"
printf 'ttyS0::askfirst:-/bin/sh\n' >> "$MUTWORK/mut_inittab_dup/etc/inittab"
run_oracle_expect "9" "Mutated reference (competing askfirst console entry)" \
    "$MUTWORK/mut_inittab_dup" "REJECT"

# 10. Non-executable rcS -> REJECT.
cp -a "$GATE_REF" "$MUTWORK/mut_rcs_noexec"
chmod 644 "$MUTWORK/mut_rcs_noexec/etc/init.d/rcS"
run_oracle_expect "10" "Mutated reference (rcS not executable)" \
    "$MUTWORK/mut_rcs_noexec" "REJECT"

# 11. rcS proc echo-decoy (documented but not executed) -> REJECT.
cp -a "$GATE_REF" "$MUTWORK/mut_rcs_decoy"
printf '#!/bin/sh\necho "mount -t proc none /proc"\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\n' \
    > "$MUTWORK/mut_rcs_decoy/etc/init.d/rcS"
chmod 755 "$MUTWORK/mut_rcs_decoy/etc/init.d/rcS"
run_oracle_expect "11" "Mutated reference (rcS proc echo-decoy, no active mount)" \
    "$MUTWORK/mut_rcs_decoy" "REJECT"

# 12. /init proc mount turned into a comment (static plausibility only).
cp -a "$GATE_REF" "$MUTWORK/mut_init_decoy"
printf '#!/bin/sh\n# mount -t proc none /proc\nmount -t sysfs none /sys\nmount -t devtmpfs none /dev 2>/dev/null || true\nexec /bin/sh\n' \
    > "$MUTWORK/mut_init_decoy/init"
chmod 755 "$MUTWORK/mut_init_decoy/init"
run_oracle_expect "12" "Mutated reference (/init proc mount commented out)" \
    "$MUTWORK/mut_init_decoy" "REJECT"

# 13. /init not executable -> REJECT.
cp -a "$GATE_REF" "$MUTWORK/mut_init_noexec"
chmod -x "$MUTWORK/mut_init_noexec/init"
run_oracle_expect "13" "Mutated reference (/init not executable)" \
    "$MUTWORK/mut_init_noexec" "REJECT"

# 14. Staging/archive divergence: staging is correct but the packaged archive
#     carries a different (defective) tree -> REJECT.
DIVERGE_TREE="$MUTWORK/diverge_tree"
cp -a "$GATE_REF" "$DIVERGE_TREE"
chmod 644 "$DIVERGE_TREE/etc/init.d/rcS"
bash scripts/package_initramfs.sh "$DIVERGE_TREE" "$MUTWORK/divergent.cpio.gz" >/dev/null
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo "------------------------------------------------------------------"
echo "Test 14: Staging correct but packaged archive broken (staging/archive divergence)"
set +e
DIV_OUT=$($ORACLE "$GATE_REF" "$MUTWORK/divergent.cpio.gz" 2>&1)
DIV_RC=$?
set -e
if [ "$DIV_RC" -ge 128 ]; then
    echo "[TEST 14 FAIL] Oracle crashed with signal $((DIV_RC - 128))!"
    echo "$DIV_OUT"
    exit 1
fi
echo "  ORACLE EXECUTION: PASS (no crash, exit $DIV_RC)"
if [ "$DIV_RC" -ne 0 ] && echo "$DIV_OUT" | grep -Eq "$REJECT_PATTERN"; then
    echo "  INTENDED RESULT: semantic REJECT (archive diverges from staging)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "[TEST 14 FAIL] A staging-correct/archive-broken submission was not rejected."
    echo "$DIV_OUT"
    exit 1
fi

# 15. Broken packaged archive (truncated gzip) -> REJECT at archive level.
head -c 4096 "$GATE_REF_ARCHIVE" > "$MUTWORK/truncated.cpio.gz"
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo "------------------------------------------------------------------"
echo "Test 15: Packaged archive truncated/corrupt"
set +e
TR_OUT=$($ORACLE "$GATE_REF" "$MUTWORK/truncated.cpio.gz" 2>&1)
TR_RC=$?
set -e
if [ "$TR_RC" -ge 128 ]; then
    echo "[TEST 15 FAIL] Oracle crashed with signal $((TR_RC - 128))!"
    echo "$TR_OUT"
    exit 1
fi
echo "  ORACLE EXECUTION: PASS (no crash, exit $TR_RC)"
if [ "$TR_RC" -ne 0 ] && echo "$TR_OUT" | grep -Eq "$REJECT_PATTERN"; then
    echo "  INTENDED RESULT: semantic REJECT (broken archive)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo "[TEST 15 FAIL] A corrupt archive was not rejected."
    echo "$TR_OUT"
    exit 1
fi

# ====================== REAL-BUSYBOX SCORED RUNTIME =======================
LINUX_SRC="${LINUX_SRC:-/tmp/linux-6.18.50}"
REAL_ZIMAGE="$LINUX_SRC/arch/arm/boot/zImage"
if [ ! -f "$REAL_ZIMAGE" ]; then
    echo "[PREP FAIL] Runtime tests require the pinned real kernel: $REAL_ZIMAGE" >&2
    exit 1
fi
if ! command -v qemu-system-arm >/dev/null 2>&1; then
    echo "[PREP FAIL] qemu-system-arm not found in PATH." >&2
    exit 1
fi
[ -f "$GATE_REF_ARCHIVE" ] || { echo "[PREP FAIL] reference archive missing: $GATE_REF_ARCHIVE" >&2; exit 1; }

echo "[PREP] Booting the reviewer reference packaged archive (real-BusyBox Gate runtime)..."
REF_RUNDIR="$MUTWORK/ref_runtime"
mkdir -p "$REF_RUNDIR"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-60}" bash scripts/run_real_busybox_candidate.sh \
    "$GATE_REF_ARCHIVE" "$REF_RUNDIR/ref.log" "$REF_RUNDIR/ref.argv" >/dev/null 2>&1 || true

# 16. The packaged real-BusyBox reference archive reaches real BusyBox init
#     as PID 1 with the submitted inittab/rcS semantics -> PASS.
run_expect "16" "Reviewer reference packaged archive + real-BusyBox runtime" \
    "PASS" "PASS_PATTERN=Submitted archive booted REAL BusyBox" \
    $RUNTIME_VERIFY "$REF_RUNDIR/ref.log" "$REF_RUNDIR/ref.argv" "$GATE_REF_ARCHIVE"

# 17. The scored Gate entry point boots the learner-submitted archive and
#     verifies it end-to-end -> PASS. Proves the Gate is runtime-bound to the
#     PACKAGED candidate rather than graded statically.
run_expect "17" "Gate end-to-end (static + packaged-archive runtime) on the reference" \
    "PASS" $GRADE_GATE "$GATE_REF" "$GATE_REF_ARCHIVE"

# 18. Stock canonical archive cannot substitute for a different submission:
#     the canonical reference's runtime evidence must not verify against a
#     candidate whose own archive is defective.
STA_ARCHIVE="$MUTWORK/static_only.cpio.gz"
bash scripts/package_initramfs.sh "$MUTWORK/mut_init_decoy" "$STA_ARCHIVE" >/dev/null
run_expect "18" "Canonical reference runtime evidence used for a different candidate archive" \
    "REJECT" $RUNTIME_VERIFY "$REF_RUNDIR/ref.log" "$REF_RUNDIR/ref.argv" "$STA_ARCHIVE"

# 19. Static inittab/rcS looks correct but the packaged runtime does not
#     actually execute it: the archive's rcS mounts nothing -> REJECT.
NOEXEC_TREE="$MUTWORK/noexec_tree"
cp -a "$GATE_REF" "$NOEXEC_TREE"
printf '#!/bin/sh\necho "=== Embedded Linux System Initialized (real BusyBox) ==="\n' \
    > "$NOEXEC_TREE/etc/init.d/rcS"
chmod 755 "$NOEXEC_TREE/etc/init.d/rcS"
NOEXEC_ARCHIVE="$MUTWORK/noexec.cpio.gz"
bash scripts/package_initramfs.sh "$NOEXEC_TREE" "$NOEXEC_ARCHIVE" >/dev/null
NOEXEC_RUNDIR="$MUTWORK/noexec_runtime"
mkdir -p "$NOEXEC_RUNDIR"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-60}" bash scripts/run_real_busybox_candidate.sh \
    "$NOEXEC_ARCHIVE" "$NOEXEC_RUNDIR/boot.log" "$NOEXEC_RUNDIR/boot.argv" >/dev/null 2>&1 || true
run_expect "19" "Packaged runtime does not actually execute the declared mounts" \
    "REJECT" $RUNTIME_VERIFY "$NOEXEC_RUNDIR/boot.log" "$NOEXEC_RUNDIR/boot.argv" "$NOEXEC_ARCHIVE"

# 20. Synthetic archive presented as a real-BusyBox candidate -> REJECT.
SYNTH_TREE="$MUTWORK/synthetic_tree"
cp -a "$GATE_REF" "$SYNTH_TREE"
rm -f "$SYNTH_TREE/bin/busybox"
cp "$SYNTH_BIN" "$SYNTH_TREE/bin/busybox"
chmod 755 "$SYNTH_TREE/bin/busybox"
bash scripts/package_initramfs.sh "$SYNTH_TREE" "$MUTWORK/synthetic_candidate.cpio.gz" >/dev/null
run_expect "20" "Synthetic multicall packaged and submitted as a real-BusyBox candidate" \
    "REJECT" $RUNTIME_VERIFY "$REF_RUNDIR/ref.log" "$REF_RUNDIR/ref.argv" "$MUTWORK/synthetic_candidate.cpio.gz"

# 21. Forged runtime log (milestone text only, no captured session).
printf '%s\n' \
    "Booting Linux on physical CPU 0x0" \
    "Linux version 6.18.50" \
    "Kernel command line: console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/sbin/init" \
    "printk: console [ttyAMA0] enabled" \
    "Trying to unpack rootfs image as initramfs" \
    "Freeing unused kernel image (initmem) memory" \
    "Run /sbin/init as init process" \
    "=== Embedded Linux System Initialized (real BusyBox) ===" \
    "Please press Enter to activate this console." \
    "BusyBox v1.36.1 multi-call binary." \
    "PID   USER     TIME  COMMAND" > "$MUTWORK/forged.log"
run_expect "21" "Forged runtime log for a real-BusyBox candidate" \
    "REJECT" $RUNTIME_VERIFY "$MUTWORK/forged.log" "$REF_RUNDIR/ref.argv" "$GATE_REF_ARCHIVE"

# 22. Runtime evidence captured for a DIFFERENT archive -> REJECT.
run_expect "22" "Runtime provenance bound to a different archive" \
    "REJECT" $RUNTIME_VERIFY "$REF_RUNDIR/ref.log" "$REF_RUNDIR/ref.argv" "$NOEXEC_ARCHIVE"

# 23. Infrastructure failure must NOT be reported as a semantic REJECT.
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo "------------------------------------------------------------------"
echo "Test 23: Unrelated environment failure is not a semantic REJECT"
MISSING_DIR="$MUTWORK/no-such-candidate"
set +e
INFRA_OUT=$($ORACLE "$MISSING_DIR" 2>&1)
INFRA_RC=$?
set -e
if [ "$INFRA_RC" -eq 0 ]; then
    echo "[TEST 23 FAIL] Missing candidate directory reported success."
    echo "$INFRA_OUT"
    exit 1
fi
echo "  ORACLE EXECUTION: PASS (clean failure, exit $INFRA_RC)"
echo "  INTENDED RESULT: environment failure surfaced without a crash"
PASSED_TESTS=$((PASSED_TESTS + 1))

echo "=================================================================="
if [ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]; then
    echo "=== ALL $PASSED_TESTS P3-M03 ORACLE MUTATION CHECKS PASSED ==="
    exit 0
fi
echo "=== ORACLE MUTATION FAIL: $PASSED_TESTS/$TOTAL_TESTS passed ===" >&2
exit 1
