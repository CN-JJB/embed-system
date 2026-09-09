#!/bin/bash
set -euo pipefail

# Automated QEMU Diagnostic Harness (M04)
# Boots the Linux kernel under controlled command-line or machine variations
# and captures console evidence for diagnostic analysis.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
LINUX_DIR=$(cd "${M04_ROOT}/.." && pwd)
LINUX_SRC="${LINUX_SRC:-/tmp/linux-6.18.50}"
REAL_ZIMAGE="${REAL_ZIMAGE:-$LINUX_SRC/arch/arm/boot/zImage}"
INITRD="${INITRD:-$LINUX_DIR/07-minimal-rootfs-busybox-init/fixtures/build/rootfs.cpio.gz}"

QEMU_BIN="${QEMU_BIN:-qemu-system-arm}"
TIMEOUT_SEC="${TIMEOUT_SEC:-10}"
BOOTARGS="${1:-console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init}"
OUTPUT_LOG="${2:-/tmp/qemu_diagnostic.log}"
EXTRA_QEMU_ARGS="${3:-}"

MACHINE="virt,highmem=off,gic-version=2"
CPU="cortex-a7"
MEM="512M"
SMP="1"

if [ ! -f "$REAL_ZIMAGE" ]; then
    echo "ERROR: Kernel zImage not found at: $REAL_ZIMAGE" >&2
    exit 1
fi

if [ ! -f "$INITRD" ]; then
    echo "ERROR: Initrd archive not found at: $INITRD" >&2
    exit 1
fi

rm -f "$OUTPUT_LOG"

set +e
timeout "${TIMEOUT_SEC}s" "$QEMU_BIN" \
    -machine "$MACHINE" \
    -cpu "$CPU" \
    -m "$MEM" \
    -smp "$SMP" \
    -nographic \
    -kernel "$REAL_ZIMAGE" \
    -initrd "$INITRD" \
    -append "$BOOTARGS" \
    $EXTRA_QEMU_ARGS \
    < /dev/null > "$OUTPUT_LOG" 2>&1
RC=$?
set -e

echo "[DIAGNOSTIC] QEMU finished with exit code $RC (Log: $OUTPUT_LOG)"
