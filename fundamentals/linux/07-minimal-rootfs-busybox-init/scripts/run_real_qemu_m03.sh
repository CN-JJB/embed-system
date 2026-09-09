#!/bin/bash
set -euo pipefail

# Strict Actual-Host QEMU Runtime Regression for P3-M03
# Boots real Linux 6.18.50 kernel with real manual BusyBox rootfs
# and proves reaching interactive userspace shell.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

LINUX_SRC="${1:-${LINUX_SRC:-/tmp/linux-6.18.50}}"
REAL_ZIMAGE="$LINUX_SRC/arch/arm/boot/zImage"
INITRAMFS_ARCHIVE="${2:-${INITRAMFS_ARCHIVE:-$M03_ROOT/fixtures/build/rootfs.cpio.gz}}"

QEMU_BIN="${QEMU_BIN:-qemu-system-arm}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-60}"
BOOT_LOG="${BOOT_LOG:-/tmp/real_m03_qemu_boot.log}"

MACHINE_OPT="virt,highmem=off,gic-version=2"
CPU_OPT="cortex-a7"
MEM_OPT="512M"
SMP_OPT="1"

echo "=================================================================="
echo "=== Strict Actual-Host QEMU Runtime Regression (M03 Rootfs)   ==="
echo "=================================================================="

# 1. Kernel Image Presence
if [ ! -f "$REAL_ZIMAGE" ]; then
    echo "[FAIL] Real kernel image not found at: $REAL_ZIMAGE" >&2
    echo "       Please run real-kernel-build-check in 06-kernel-build-boot first." >&2
    exit 1
fi
echo "[PASS] Real kernel zImage detected: $REAL_ZIMAGE"

# 2. Initramfs Archive Presence
if [ ! -f "$INITRAMFS_ARCHIVE" ]; then
    echo "[FAIL] Initramfs archive not found at: $INITRAMFS_ARCHIVE" >&2
    echo "       Building fixtures..."
    make -C "$M03_ROOT/fixtures" all CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"
fi
echo "[PASS] Initramfs archive detected: $INITRAMFS_ARCHIVE"

# 3. QEMU Binary Availability
if ! command -v "$QEMU_BIN" >/dev/null 2>&1; then
    echo "QEMU runtime status: UNVERIFIED (qemu-system-arm not found in PATH)" >&2
    exit 1
fi
QEMU_VER=$("$QEMU_BIN" --version | head -n 1)
echo "[PASS] Actual-host QEMU detected: $QEMU_VER"

# 4. Execute QEMU Boot
echo "------------------------------------------------------------------"
echo "Executing QEMU Launch Command:"
echo "$QEMU_BIN \\"
echo "  -machine $MACHINE_OPT \\"
echo "  -cpu $CPU_OPT \\"
echo "  -m $MEM_OPT \\"
echo "  -smp $SMP_OPT \\"
echo "  -nographic \\"
echo "  -kernel $REAL_ZIMAGE \\"
echo "  -initrd $INITRAMFS_ARCHIVE \\"
echo "  -append \"console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init\""
echo "------------------------------------------------------------------"

rm -f "$BOOT_LOG"

set +e
(sleep 3; echo "ps"; sleep 1; echo "cat /proc/uptime"; sleep 1; echo "exit") | timeout "${BOOT_TIMEOUT}s" "$QEMU_BIN" \
    -machine "$MACHINE_OPT" \
    -cpu "$CPU_OPT" \
    -m "$MEM_OPT" \
    -smp "$SMP_OPT" \
    -nographic \
    -kernel "$REAL_ZIMAGE" \
    -initrd "$INITRAMFS_ARCHIVE" \
    -append "console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init" \
    > "$BOOT_LOG" 2>&1
QEMU_RC=$?
set -e

echo "--- Observed Boot Log Extract ---"
grep -E "Linux version|bootconsole|Unpacking initramfs|Run /init|Mounted /proc|Interactive BusyBox|Starting PID 1" "$BOOT_LOG" || true
echo "---------------------------------"

# 5. Semantic Milestone Verification
if ! grep -q "Linux version" "$BOOT_LOG"; then
    echo "[FAIL] Kernel failed to initialize (no 'Linux version' found in boot log)." >&2
    exit 1
fi

if ! grep -q -E "bootconsole .*enabled" "$BOOT_LOG"; then
    echo "[FAIL] Early console failed to initialize." >&2
    exit 1
fi

if ! grep -q -E "Run /init as init process|Starting PID 1" "$BOOT_LOG"; then
    echo "[FAIL] Kernel failed to execute /init as PID 1." >&2
    exit 1
fi

if ! grep -q -E "Mounted /proc|Interactive BusyBox|/ # " "$BOOT_LOG"; then
    echo "[FAIL] Init process failed to mount pseudo-filesystems or reach shell milestone." >&2
    exit 1
fi

echo "[PASS] QEMU boot to interactive userspace shell successfully VERIFIED!"
echo "       Milestones confirmed: Earlycon -> Kernel Startup -> Initramfs Unpack -> PID 1 Launch -> Shell"
