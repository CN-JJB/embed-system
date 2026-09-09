#!/bin/bash
set -euo pipefail

# Strict Actual-Host QEMU Runtime Regression for P3-M03 (REAL BusyBox).
# Boots real Linux 6.18.50 kernel with the REAL BusyBox 1.36.1 rootfs
# and proves reaching a real BusyBox ash shell with real ps/mount.
#
# The SYNTHETIC pedagogical fixture (fixtures/build/synthetic_rootfs.cpio.gz)
# is NEVER a valid input here: this script defaults to and requires the
# real archive (fixtures/build/real_rootfs.cpio.gz) unless the caller
# explicitly overrides INITRAMFS_ARCHIVE.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

LINUX_SRC="${1:-${LINUX_SRC:-/tmp/linux-6.18.50}}"
REAL_ZIMAGE="$LINUX_SRC/arch/arm/boot/zImage"
INITRAMFS_ARCHIVE="${2:-${INITRAMFS_ARCHIVE:-$M03_ROOT/fixtures/build/real_rootfs.cpio.gz}}"

QEMU_BIN="${QEMU_BIN:-qemu-system-arm}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-60}"
BOOT_LOG="${BOOT_LOG:-/tmp/real_m03_qemu_boot.log}"

MACHINE_OPT="virt,highmem=off,gic-version=2"
CPU_OPT="cortex-a7"
MEM_OPT="512M"
SMP_OPT="1"

echo "=================================================================="
echo "=== Strict Actual-Host QEMU Runtime (M03 REAL BusyBox)         ==="
echo "=================================================================="

# 1. Kernel Image Presence
if [ ! -f "$REAL_ZIMAGE" ]; then
    echo "[FAIL] Real kernel image not found at: $REAL_ZIMAGE" >&2
    echo "       Please run real-kernel-build-check in 06-kernel-build-boot first." >&2
    exit 1
fi
echo "[PASS] Real kernel zImage detected: $REAL_ZIMAGE"

# 2. REAL initramfs archive presence (synthetic is explicitly rejected).
if [ ! -f "$INITRAMFS_ARCHIVE" ]; then
    echo "[FAIL] REAL initramfs archive not found at: $INITRAMFS_ARCHIVE" >&2
    echo "       Build it with:" >&2
    echo "         CROSS_COMPILE=<prefix> bash $M03_ROOT/scripts/build_real_busybox.sh" >&2
    echo "         bash $M03_ROOT/scripts/stage_real_rootfs.sh" >&2
    echo "         bash $M03_ROOT/scripts/package_initramfs.sh <real_rootfs> $INITRAMFS_ARCHIVE" >&2
    echo "       (SYNTHETIC fixture archives are NOT accepted as real runtime.)" >&2
    exit 1
fi
case "$INITRAMFS_ARCHIVE" in
    *synthetic*)
        echo "[FAIL] Refusing synthetic fixture archive as real BusyBox runtime: $INITRAMFS_ARCHIVE" >&2
        exit 1
        ;;
esac
echo "[PASS] REAL initramfs archive detected: $INITRAMFS_ARCHIVE"

# 2b. Real BusyBox identity inside the archive (semantic metadata check).
# Listing is captured before grepping: piping the lister straight into
# 'grep -q' closes the pipe early and races under 'set -o pipefail'.
TMP_IDENT=$(mktemp -d /tmp/m03_real_ident_XXXXXX)
trap 'rm -rf "$TMP_IDENT"' EXIT
RAW_IDENT="$TMP_IDENT/archive.cpio"
zcat "$INITRAMFS_ARCHIVE" > "$RAW_IDENT"
IDENT_LISTING=$(python3 "$M03_ROOT/scripts/pycpio.py" --list "$RAW_IDENT" || true)
if ! grep -qE '^(file|symlink).*bin/busybox' <<<"$IDENT_LISTING"; then
    echo "[FAIL] Archive does not contain a real /bin/busybox entry." >&2
    exit 1
fi
echo "[PASS] Archive contains /bin/busybox entry (real staging required)"

# 3. QEMU Binary Availability
if ! command -v "$QEMU_BIN" >/dev/null 2>&1; then
    echo "QEMU runtime status: UNVERIFIED (qemu-system-arm not found in PATH)" >&2
    exit 1
fi
QEMU_VER=$("$QEMU_BIN" --version | head -n 1)
echo "[PASS] Actual-host QEMU detected: $QEMU_VER"

# 4. Execute QEMU Boot with REAL BusyBox shell probes.
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
(sleep 4; echo "busybox | head -n 2"; sleep 1; echo "ps"; sleep 1; echo "cat /proc/mounts"; sleep 1; echo "cat /proc/uptime"; sleep 1; echo "mount"; sleep 1; echo "exit") | timeout "${BOOT_TIMEOUT}s" "$QEMU_BIN" \
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
grep -E "Linux version|bootconsole|Trying to unpack|Run /init|REAL-BUSYBOX|BusyBox v1.36.1|PID.*USER.*COMMAND" "$BOOT_LOG" || true
echo "---------------------------------"

# 5. Semantic Milestone Verification (REAL BusyBox only).
if ! grep -q "Linux version" "$BOOT_LOG"; then
    echo "[FAIL] Kernel failed to initialize (no 'Linux version' found in boot log)." >&2
    exit 1
fi

if ! grep -q -E "bootconsole .*enabled" "$BOOT_LOG"; then
    echo "[FAIL] Early console failed to initialize." >&2
    exit 1
fi

if ! grep -q -E "Run /init as init process" "$BOOT_LOG"; then
    echo "[FAIL] Kernel failed to execute /init as PID 1." >&2
    exit 1
fi

if ! grep -q "REAL-BUSYBOX-INIT-READY" "$BOOT_LOG"; then
    echo "[FAIL] Real BusyBox /init did not reach ready marker (synthetic archives rejected)." >&2
    exit 1
fi

# Real BusyBox multi-call identity inside the guest.
if ! grep -q "BusyBox v1.36.1" "$BOOT_LOG"; then
    echo "[FAIL] Guest did not report real BusyBox v1.36.1 identity." >&2
    exit 1
fi

# Real BusyBox ps header (PID USER TIME COMMAND), not the synthetic fake.
if ! grep -qE "PID +USER +TIME +COMMAND" "$BOOT_LOG"; then
    echo "[FAIL] Real BusyBox 'ps' response missing (PID USER TIME COMMAND)." >&2
    exit 1
fi

# Real mount state: proc + sysfs + devtmpfs actively mounted.
if ! grep -qE "none /proc proc|/proc proc" "$BOOT_LOG"; then
    echo "[FAIL] Guest mount state missing active proc mount." >&2
    exit 1
fi
if ! grep -qE "none /sys sysfs|/sys sysfs" "$BOOT_LOG"; then
    echo "[FAIL] Guest mount state missing active sysfs mount." >&2
    exit 1
fi
if ! grep -qE "none /dev devtmpfs|/dev devtmpfs" "$BOOT_LOG"; then
    echo "[FAIL] Guest mount state missing active devtmpfs mount." >&2
    exit 1
fi

# Synthetic masquerade guard.
if grep -q "SYNTHETIC" "$BOOT_LOG"; then
    echo "[FAIL] Synthetic fixture strings detected in supposed real runtime log." >&2
    exit 1
fi

echo "[PASS] QEMU boot to REAL BusyBox userspace shell successfully VERIFIED!"
echo "       Milestones: Earlycon -> Kernel -> Initramfs -> /init -> real ash -> real ps/mount"
