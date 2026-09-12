#!/usr/bin/env bash
# Boot a Buildroot-generated appliance under the canonical QEMU hardware
# contract and capture bound runtime evidence (P3-M06, Lab 6.3).
#
# Usage:
#   scripts/run_buildroot_appliance.sh OUTPUT_DIR OUT_LOG OUT_PROVENANCE
#
# Environment:
#   QEMU_SYSTEM_ARM, QEMU_MACHINE, QEMU_CPU, QEMU_MEM, QEMU_SMP,
#   TIMEOUT_SEC (default 120)
#
# The launch path is explicit and reproducible: kernel artifact, optional DTB,
# rootfs image, machine/cpu/RAM flags, kernel command line and console path are
# all recorded as provenance before the boot is attempted.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M06_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M06_ROOT"

OUTPUT_DIR="${1:?usage: run_buildroot_appliance.sh OUTPUT_DIR OUT_LOG OUT_PROVENANCE}"
OUT_LOG="${2:?}"
OUT_PROVENANCE="${3:?}"

QEMU_MACHINE="${QEMU_MACHINE:-virt,highmem=off,gic-version=2}"
QEMU_CPU="${QEMU_CPU:-cortex-a7}"
QEMU_MEM="${QEMU_MEM:-512M}"
QEMU_SMP="${QEMU_SMP:-1}"
TIMEOUT_SEC="${TIMEOUT_SEC:-120}"

QEMU="${QEMU_SYSTEM_ARM:-}"
[ -n "$QEMU" ] || QEMU=$(command -v qemu-system-arm || true)
[ -n "$QEMU" ] && [ -x "$QEMU" ] || { echo "ERROR: qemu-system-arm not found" >&2; exit 2; }

IMAGES="$OUTPUT_DIR/images"
[ -d "$IMAGES" ] || { echo "ERROR: no images directory: $IMAGES" >&2; exit 2; }

KERNEL=""
for candidate in "$IMAGES/zImage" "$IMAGES/Image" "$IMAGES/vmlinux"; do
    [ -f "$candidate" ] && { KERNEL="$candidate"; break; }
done
[ -n "$KERNEL" ] || { echo "ERROR: no kernel image in $IMAGES" >&2; exit 2; }

INITRD=""
for candidate in "$IMAGES/rootfs.cpio.gz" "$IMAGES/rootfs.cpio"; do
    [ -f "$candidate" ] && { INITRD="$candidate"; break; }
done

DTB=""
[ -f "$IMAGES/qemu-virt.dtb" ] && DTB="$IMAGES/qemu-virt.dtb"
[ -z "$DTB" ] && [ -f "$M06_ROOT/fixtures/qemu-virt.dtb" ] && DTB=""

mkdir -p "$(dirname "$OUT_LOG")" "$(dirname "$OUT_PROVENANCE")"

if [ -n "$INITRD" ]; then
    ROOTARGS="console=ttyAMA0,115200 earlycon=pl011,0x09000000 rdinit=/init"
else
    ROOTARGS="console=ttyAMA0,115200 earlycon=pl011,0x09000000 root=/dev/vda rw"
fi

ARGV=("$QEMU" -machine "$QEMU_MACHINE" -cpu "$QEMU_CPU" -m "$QEMU_MEM" -smp "$QEMU_SMP" -nographic
      -kernel "$KERNEL")
[ -n "$DTB" ] && ARGV+=(-dtb "$DTB")
if [ -n "$INITRD" ]; then
    ARGV+=(-initrd "$INITRD")
else
    ARGV+=(-drive "file=$IMAGES/rootfs.ext4,format=raw,id=hd0" -device virtio-blk-device,drive=hd0)
fi
ARGV+=(-append "$ROOTARGS")

{
    echo "# executed_argv"
    printf 'argv: %s\n' "${ARGV[@]}"
    echo "machine: $QEMU_MACHINE"
    echo "cpu: $QEMU_CPU"
    echo "memory: $QEMU_MEM"
    echo "smp: $QEMU_SMP"
    echo "bootargs: $ROOTARGS"
    echo "kernel: $KERNEL"
    echo "kernel_sha256: $(sha256sum "$KERNEL" | awk '{print $1}')"
    [ -n "$DTB" ] && echo "dtb: $DTB" && echo "dtb_sha256: $(sha256sum "$DTB" | awk '{print $1}')"
    [ -n "$INITRD" ] && echo "initrd: $INITRD" && echo "initrd_sha256: $(sha256sum "$INITRD" | awk '{print $1}')"
    echo "qemu_version: $("$QEMU" --version | head -n 1)"
    echo "captured_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT_PROVENANCE"

echo "=== booting the appliance (timeout ${TIMEOUT_SEC}s) ==="
set +e
if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SEC" "${ARGV[@]}" </dev/null >"$OUT_LOG" 2>&1
else
    "${ARGV[@]}" </dev/null >"$OUT_LOG" 2>&1 &
    QPID=$!
    ( sleep "$TIMEOUT_SEC"; kill "$QPID" 2>/dev/null ) &
    wait "$QPID"
fi
set -e

echo "[OK] console log    : $OUT_LOG"
echo "[OK] argv provenance: $OUT_PROVENANCE"
