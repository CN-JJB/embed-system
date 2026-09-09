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
# REAL BusyBox initramfs is the default runtime. The SYNTHETIC teaching
# fixture (synthetic_rootfs.cpio.gz) is NEVER a valid diagnostic input.
INITRD="${INITRD:-$LINUX_DIR/07-minimal-rootfs-busybox-init/fixtures/build/real_rootfs.cpio.gz}"

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

# Guest userspace probes. When the boot reaches a real BusyBox shell, these
# commands produce the userspace response evidence the runtime verifier
# binds to (BusyBox identity, ps, mounts). For fault runs (panic/hang/
# silent console) the probes simply receive no response, which is itself
# diagnostic. Set DIAG_PROBE=0 for a purely passive capture.
DIAG_PROBE="${DIAG_PROBE:-1}"

set +e
if [ "$DIAG_PROBE" = "0" ]; then
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
else
( sleep 5; echo "busybox | head -n 2"; sleep 1; echo "ps"; sleep 1; echo "cat /proc/mounts"; sleep 1; echo "exit"; sleep 1 ) | timeout "${TIMEOUT_SEC}s" "$QEMU_BIN" \
    -machine "$MACHINE" \
    -cpu "$CPU" \
    -m "$MEM" \
    -smp "$SMP" \
    -nographic \
    -kernel "$REAL_ZIMAGE" \
    -initrd "$INITRD" \
    -append "$BOOTARGS" \
    $EXTRA_QEMU_ARGS \
    > "$OUTPUT_LOG" 2>&1
RC=$?
fi
set -e

echo "[DIAGNOSTIC] QEMU finished with exit code $RC (Log: $OUTPUT_LOG)"
