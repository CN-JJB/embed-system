#!/bin/bash
set -euo pipefail

# Real-BusyBox PINNED QEMU boot harness for P3-M03.
#
# This is the shared pinned launch path used by BOTH the learner-safe
# reference run and the reviewer Gate. The ONLY per-submission variable is
# the initramfs archive under test (the learner's packaged candidate); the
# kernel, machine, CPU, RAM, SMP, display route, and kernel command line are
# pinned here, so the resulting console evidence is evidence about THAT
# archive rather than about a canonical substitute.
#
# Usage: run_real_busybox_candidate.sh <initramfs.cpio.gz> <console-log> <marker-file>
#
# Environment:
#   LINUX_SRC   : pinned Linux tree (default /tmp/linux-6.18.50)
#   BOOT_TIMEOUT: wall-clock budget in seconds (default 60)
#   QEMU_BIN    : qemu-system-arm
#
# The guest receives, in order:
#   1. a newline, satisfying BusyBox init's 'askfirst' console activation;
#   2. real BusyBox identity probes;
#   3. a shell-ordered probe whose per-line markers prove that the SUBMITTED
#      inittab produced the activated console, that the SUBMITTED rcS mounted
#      proc/sys/dev, that /sbin/init is PID 1, and that the interactive shell
#      is a real BusyBox shell. Probe output is framed by unique begin/end
#      markers so ordering inside the capture is evidenced, not assumed.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

ARCHIVE="${1:-}"
CONSOLE_LOG="${2:-}"
MARKER_FILE="${3:-}"

if [ -z "$ARCHIVE" ] || [ ! -f "$ARCHIVE" ]; then
    echo "ERROR: packaged initramfs archive required: '${ARCHIVE:-<empty>}'" >&2
    exit 1
fi
if [ -z "$CONSOLE_LOG" ] || [ -z "$MARKER_FILE" ]; then
    echo "ERROR: console-log and marker-file output paths are required." >&2
    exit 1
fi
case "$ARCHIVE" in
    *synthetic*)
        echo "REJECT: refusing the synthetic teaching fixture as a real BusyBox runtime candidate: $ARCHIVE" >&2
        exit 2
        ;;
esac

LINUX_SRC="${LINUX_SRC:-/tmp/linux-6.18.50}"
REAL_ZIMAGE="$LINUX_SRC/arch/arm/boot/zImage"
QEMU_BIN="${QEMU_BIN:-qemu-system-arm}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-60}"

LINUX_MACHINE="virt,highmem=off,gic-version=2"
LINUX_CPU="cortex-a7"
LINUX_MEM="512M"
LINUX_SMP="1"
LINUX_APPEND="console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/sbin/init"

if [ ! -f "$REAL_ZIMAGE" ]; then
    echo "ERROR: pinned real kernel zImage not found: $REAL_ZIMAGE" >&2
    echo "       Build it with: bash 06-kernel-build-boot/scripts/build_real_kernel.sh" >&2
    exit 1
fi
if ! command -v "$QEMU_BIN" >/dev/null 2>&1; then
    echo "ERROR: '$QEMU_BIN' not found in PATH (runtime UNVERIFIED)." >&2
    exit 1
fi

mkdir -p "$(dirname "$CONSOLE_LOG")" "$(dirname "$MARKER_FILE")"

echo "=================================================================="
echo "=== P3-M03 Real-BusyBox pinned candidate boot                  ==="
echo "=== archive under test: $ARCHIVE"
echo "=== pinned kernel:      $REAL_ZIMAGE"
echo "=== pinned invocation:  -machine $LINUX_MACHINE -cpu $LINUX_CPU -m $LINUX_MEM -smp $LINUX_SMP -nographic"
echo "=== pinned bootargs:    $LINUX_APPEND"
echo "=================================================================="

# The archive under test is the only submission-dependent input: its digest
# is recorded next to the console evidence so the capture is bound to it.
ARCHIVE_SHA=$(sha256sum "$ARCHIVE" | awk '{print $1}')
KERNEL_SHA=$(sha256sum "$REAL_ZIMAGE" | awk '{print $1}')

rm -f "$CONSOLE_LOG" "$MARKER_FILE"

set +e
(
    sleep 8
    printf '\n'
    sleep 3
    printf 'echo BUSYBOX-IDENTITY-BEGIN\n'
    sleep 1
    printf 'busybox | head -n 1\n'
    sleep 1
    printf 'echo BUSYBOX-IDENTITY-END\n'
    sleep 2
    printf 'echo MOUNTS-BEGIN\n'
    sleep 1
    printf 'cat /proc/mounts\n'
    sleep 2
    printf 'echo MOUNTS-END\n'
    sleep 1
    printf 'echo PID1-BEGIN\n'
    sleep 1
    printf 'cat /proc/1/comm\n'
    sleep 1
    printf 'readlink /proc/1/exe\n'
    sleep 1
    printf 'echo PID1-END\n'
    sleep 1
    printf 'echo PS-BEGIN\n'
    sleep 1
    printf 'ps\n'
    sleep 2
    printf 'echo PS-END\n'
    sleep 1
    printf 'echo SHELL-PROBE-OK\n'
    sleep 2
    printf 'exit\n'
    sleep 2
) | timeout "${BOOT_TIMEOUT}s" "$QEMU_BIN" \
        -machine "$LINUX_MACHINE" \
        -cpu "$LINUX_CPU" \
        -m "$LINUX_MEM" \
        -smp "$LINUX_SMP" \
        -nographic \
        -kernel "$REAL_ZIMAGE" \
        -initrd "$ARCHIVE" \
        -append "$LINUX_APPEND" \
        > "$CONSOLE_LOG" 2>&1
QEMU_RC=$?
set -e

cat > "$MARKER_FILE" <<EOF
# P3-M03 real-BusyBox candidate runtime provenance.
ARCHIVE=$ARCHIVE
ARCHIVE_SHA256=$ARCHIVE_SHA
KERNEL=$REAL_ZIMAGE
KERNEL_SHA256=$KERNEL_SHA
MACHINE=$LINUX_MACHINE
CPU=$LINUX_CPU
MEM=$LINUX_MEM
SMP=$LINUX_SMP
NOGRAPHIC=true
BOOTARGS=$LINUX_APPEND
QEMU_BIN=$(command -v "$QEMU_BIN")
TIMEOUT_SEC=$BOOT_TIMEOUT
QEMU_EXIT=$QEMU_RC
EOF

echo "[CANDIDATE-BOOT] console log: $CONSOLE_LOG (qemu exit $QEMU_RC)"
echo "[CANDIDATE-BOOT] provenance:  $MARKER_FILE"
echo "[CANDIDATE-BOOT] archive sha256: $ARCHIVE_SHA"
