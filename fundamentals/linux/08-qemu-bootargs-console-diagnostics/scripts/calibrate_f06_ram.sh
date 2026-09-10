#!/bin/bash
set -euo pipefail

# Calibration & Empirical Verification Suite for Fault F06 (M04, REAL).
# Calibrates real Linux 6.18.50 low-memory boundaries on ARM Cortex-A7 QEMU
# using the REAL BusyBox initramfs. Synthetic archives are rejected.
#
# Each boundary is classified into exactly one terminal state:
#   QEMU-REFUSAL     — emulator exits before kernel starts
#   TIMEOUT-HANG     — kernel emits early warnings then stalls (timeout,
#                      no panic, no userspace)
#   OOM-PANIC        — kernel terminates in a memory deadlock panic
#   USERSPACE        — real BusyBox shell reached (control case)
# A bare 'cma: Failed to reserve' line alone NEVER classifies a hang; the
# verdict requires exit/timeout status plus the last semantic milestone.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
LINUX_DIR=$(cd "${M04_ROOT}/.." && pwd)
LINUX_SRC="${LINUX_SRC:-/tmp/linux-6.18.50}"
REAL_ZIMAGE="$LINUX_SRC/arch/arm/boot/zImage"
INITRD="$LINUX_DIR/07-minimal-rootfs-busybox-init/fixtures/build/real_rootfs.cpio.gz"
QEMU_BIN="${QEMU_BIN:-qemu-system-arm}"

echo "=================================================================="
echo "=== Calibrating Fault F06: Real Memory Boundaries (Linux 6.18) ==="
echo "=================================================================="

if [ ! -f "$REAL_ZIMAGE" ]; then
    echo "ERROR: Kernel zImage missing at: $REAL_ZIMAGE" >&2
    exit 1
fi
case "$INITRD" in *synthetic*)
    echo "ERROR: F06 calibration requires the REAL BusyBox initramfs, got synthetic: $INITRD" >&2
    exit 1
    ;;
esac
if [ ! -f "$INITRD" ]; then
    echo "ERROR: REAL initramfs missing at: $INITRD" >&2
    echo "Build it via the M03 real-rootfs-package target first." >&2
    exit 1
fi

TMP_LOG=$(mktemp /tmp/f06_calib_XXXXXX.log)
trap 'rm -f "$TMP_LOG"' EXIT

last_milestone() {
    local log="$1"
    if grep -q "REAL-BUSYBOX-INIT-READY" "$log"; then echo "userspace-ready";
    elif grep -q "Run /init as init process" "$log"; then echo "pid1-launch";
    elif grep -q "Trying to unpack rootfs image as initramfs" "$log"; then echo "initramfs-unpack";
    elif grep -q "printk: console \[ttyAMA0\] enabled" "$log"; then echo "console-handoff";
    elif grep -q "Kernel command line:" "$log"; then echo "cmdline-parsed";
    elif grep -q "Linux version" "$log"; then echo "kernel-start";
    elif grep -q "too large to fit in RAM" "$log"; then echo "qemu-refusal";
    elif grep -q "cma: Failed to reserve" "$log"; then echo "cma-reserve-fail";
    else echo "no-kernel-output"; fi
}

# --- Boundary 1: QEMU Hardware RAM Rejection (-m 8M, pre-boot contrast) ---
echo -n "[TEST] Boundary 1: QEMU pre-boot refusal (-m 8M) ... "
set +e
timeout 8s "$QEMU_BIN" \
    -machine virt,highmem=off,gic-version=2 \
    -cpu cortex-a7 \
    -m 8M \
    -smp 1 \
    -nographic \
    -kernel "$REAL_ZIMAGE" \
    > "$TMP_LOG" 2>&1
RC1=$?
set -e
if grep -q "is too large to fit in RAM" "$TMP_LOG" && [ "$RC1" -ne 0 ] && [ "$RC1" -ne 124 ]; then
    echo "PASS (state=QEMU-REFUSAL rc=$RC1 last=$(last_milestone "$TMP_LOG"))"
else
    echo "FAIL (expected QEMU-REFUSAL, rc=$RC1)"
    cat "$TMP_LOG"
    exit 1
fi

# --- Boundary 2: Early bootmem stall (mem=8M, timeout-hang) ---
echo -n "[TEST] Boundary 2: Kernel early-memory stall (mem=8M) ... "
set +e
timeout 12s "$QEMU_BIN" \
    -machine virt,highmem=off,gic-version=2 \
    -cpu cortex-a7 \
    -m 512M \
    -smp 1 \
    -nographic \
    -kernel "$REAL_ZIMAGE" \
    -initrd "$INITRD" \
    -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init mem=8M" \
    > "$TMP_LOG" 2>&1
RC2=$?
set -e
# Strict hang verdict: timeout + cma/initrd warnings + NO panic + NO userspace.
if [ "$RC2" -eq 124 ] \
    && grep -q "cma: Failed to reserve" "$TMP_LOG" \
    && ! grep -q "Kernel panic" "$TMP_LOG" \
    && ! grep -q "Run /init as init process" "$TMP_LOG" \
    && ! grep -q "REAL-BUSYBOX" "$TMP_LOG"; then
    echo "PASS (state=TIMEOUT-HANG rc=124 last=$(last_milestone "$TMP_LOG"))"
else
    echo "FAIL (expected TIMEOUT-HANG rc=124 without panic/userspace, got rc=$RC2)"
    tail -n 10 "$TMP_LOG"
    exit 1
fi

# --- Boundary 3: Deterministic OOM deadlock panic (mem=32M, PRIMARY F06) ---
echo -n "[TEST] Boundary 3: OOM deadlock panic (mem=32M, PRIMARY) ... "
set +e
timeout 25s "$QEMU_BIN" \
    -machine virt,highmem=off,gic-version=2 \
    -cpu cortex-a7 \
    -m 512M \
    -smp 1 \
    -nographic \
    -kernel "$REAL_ZIMAGE" \
    -initrd "$INITRD" \
    -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init mem=32M" \
    > "$TMP_LOG" 2>&1
RC3=$?
set -e
if grep -q "Kernel panic - not syncing: System is deadlocked on memory" "$TMP_LOG" \
    && grep -q "Out of memory and no killable processes" "$TMP_LOG" \
    && ! grep -q "Run /init as init process" "$TMP_LOG"; then
    echo "PASS (state=OOM-PANIC rc=$RC3 last=oom-panic)"
else
    echo "FAIL (expected OOM-PANIC without userspace)"
    tail -n 10 "$TMP_LOG"
    exit 1
fi

# --- Control: canonical memory reaches real userspace ---
echo -n "[TEST] Control: canonical -m 512M reaches real userspace ... "
set +e
( sleep 4; echo "busybox | head -n 1"; sleep 1; echo "exit"; sleep 1 ) | timeout 30s "$QEMU_BIN" \
    -machine virt,highmem=off,gic-version=2 \
    -cpu cortex-a7 \
    -m 512M \
    -smp 1 \
    -nographic \
    -kernel "$REAL_ZIMAGE" \
    -initrd "$INITRD" \
    -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init" \
    > "$TMP_LOG" 2>&1
RC4=$?
set -e
if grep -q "REAL-BUSYBOX-INIT-READY" "$TMP_LOG" && grep -q "BusyBox v" "$TMP_LOG"; then
    echo "PASS (state=USERSPACE last=userspace-ready)"
else
    echo "FAIL (control did not reach real userspace)"
    tail -n 10 "$TMP_LOG"
    exit 1
fi

echo "=================================================================="
echo "=== F06 CALIBRATION VERIFIED: REFUSAL / HANG / PANIC / USERSPACE =="
echo "=== PRIMARY learner fault: mem=32M OOM deadlock panic (deterministic) =="
echo "=================================================================="
