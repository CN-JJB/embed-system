#!/bin/bash
set -euo pipefail

# Calibration & Empirical Verification Suite for Fault F06: Insufficient RAM (M04)
# Calibrates actual Linux 6.18.50 LTS memory limits on ARM Cortex-A7 QEMU virtual platform.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
LINUX_DIR=$(cd "${M04_ROOT}/.." && pwd)
LINUX_SRC="${LINUX_SRC:-/tmp/linux-6.18.50}"
REAL_ZIMAGE="$LINUX_SRC/arch/arm/boot/zImage"
INITRD="$LINUX_DIR/07-minimal-rootfs-busybox-init/fixtures/build/rootfs.cpio.gz"
QEMU_BIN="${QEMU_BIN:-qemu-system-arm}"

echo "=================================================================="
echo "=== Calibrating Fault F06: Real Memory Boundaries (Linux 6.18) ==="
echo "=================================================================="

if [ ! -f "$REAL_ZIMAGE" ]; then
    echo "ERROR: Kernel zImage missing at: $REAL_ZIMAGE" >&2
    exit 1
fi

TMP_LOG=$(mktemp /tmp/f06_calib_XXXXXX.log)
trap 'rm -f "$TMP_LOG"' EXIT

# --- Boundary 1: QEMU Hardware RAM Rejection (-m 8M) ---
echo -n "[TEST] Boundary 1: QEMU hardware RAM constraint (-m 8M) ... "
set +e
timeout 5s "$QEMU_BIN" \
    -machine virt,highmem=off,gic-version=2 \
    -cpu cortex-a7 \
    -m 8M \
    -smp 1 \
    -nographic \
    -kernel "$REAL_ZIMAGE" \
    > "$TMP_LOG" 2>&1
set -e
if grep -q "is too large to fit in RAM" "$TMP_LOG"; then
    echo "PASS (Confirmed: QEMU startup refusal: RAM 8M < kernel image size)"
else
    echo "FAIL (Unexpected output)"
    cat "$TMP_LOG"
    exit 1
fi

# --- Boundary 2: Early Bootmem / CMA Reservation Hang (mem=8M) ---
echo -n "[TEST] Boundary 2: Kernel early bootmem constraint (mem=8M) ... "
set +e
timeout 6s "$QEMU_BIN" \
    -machine virt,highmem=off,gic-version=2 \
    -cpu cortex-a7 \
    -m 512M \
    -smp 1 \
    -nographic \
    -kernel "$REAL_ZIMAGE" \
    -initrd "$INITRD" \
    -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init mem=8M" \
    > "$TMP_LOG" 2>&1
set -e
if grep -q "cma: Failed to reserve" "$TMP_LOG"; then
    echo "PASS (Confirmed: Kernel hangs in early bootmem allocation)"
else
    echo "FAIL (Expected early cma failure)"
    cat "$TMP_LOG"
    exit 1
fi

# --- Boundary 3: Dynamic OOM Deadlock Kernel Panic (mem=32M) ---
echo -n "[TEST] Boundary 3: Dynamic OOM Deadlock Kernel Panic (mem=32M) ... "
set +e
timeout 6s "$QEMU_BIN" \
    -machine virt,highmem=off,gic-version=2 \
    -cpu cortex-a7 \
    -m 512M \
    -smp 1 \
    -nographic \
    -kernel "$REAL_ZIMAGE" \
    -initrd "$INITRD" \
    -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init mem=32M" \
    > "$TMP_LOG" 2>&1
set -e
if grep -q "Kernel panic - not syncing: System is deadlocked on memory" "$TMP_LOG"; then
    echo "PASS (Confirmed: Genuine OOM deadlock panic reproduced)"
else
    echo "FAIL (Expected OOM deadlock panic)"
    cat "$TMP_LOG"
    exit 1
fi

echo "=================================================================="
echo "=== F06 CALIBRATION VERIFIED: ALL 3 MEMORY FAILURE STATES PASS ==="
echo "=================================================================="
