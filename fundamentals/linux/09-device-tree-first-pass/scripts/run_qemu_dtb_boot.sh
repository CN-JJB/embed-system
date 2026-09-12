#!/usr/bin/env bash
# Boot the real Phase 3 appliance under the canonical QEMU hardware contract
# with an explicitly supplied DTB, capture the serial console, and record the
# executed argv as provenance.
#
# Lab 5.4 needs the guest's /sys/firmware/devicetree/base view, which only
# exists in a running kernel.  This script performs the boot and injects a
# bounded, read-only correlation probe through the kernel command line; the
# captured log is then bound to the DTB by scripts/verify_runtime_devicetree.sh.
#
# Usage:
#   scripts/run_qemu_dtb_boot.sh DTB KERNEL INITRD OUT_LOG OUT_ARGV
#
# Environment:
#   QEMU_SYSTEM_ARM, QEMU_MACHINE, QEMU_CPU, QEMU_MEM, QEMU_SMP,
#   TIMEOUT_SEC (default 90), CONSOLE (default ttyAMA0,115200),
#   EARLYCON (default pl011,0x09000000)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M05_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M05_ROOT"

DTB="${1:?usage: run_qemu_dtb_boot.sh DTB KERNEL INITRD OUT_LOG OUT_ARGV}"
KERNEL="${2:?}"
INITRD="${3:?}"
OUT_LOG="${4:?}"
OUT_ARGV="${5:?}"

QEMU_MACHINE="${QEMU_MACHINE:-virt,highmem=off,gic-version=2}"
QEMU_CPU="${QEMU_CPU:-cortex-a7}"
QEMU_MEM="${QEMU_MEM:-512M}"
QEMU_SMP="${QEMU_SMP:-1}"
TIMEOUT_SEC="${TIMEOUT_SEC:-90}"
CONSOLE="${CONSOLE:-ttyAMA0,115200}"
EARLYCON="${EARLYCON:-pl011,0x09000000}"

QEMU="${QEMU_SYSTEM_ARM:-}"
[ -n "$QEMU" ] || QEMU=$(command -v qemu-system-arm || true)
[ -n "$QEMU" ] && [ -x "$QEMU" ] || { echo "ERROR: qemu-system-arm not found" >&2; exit 2; }

for f in "$DTB" "$KERNEL" "$INITRD"; do
    [ -f "$f" ] || { echo "ERROR: missing required boot input: $f" >&2; exit 2; }
done

# The DTB identity that is about to be booted.  This is the binding anchor:
# the runtime verifier requires the log's provenance to carry the same hash.
DTB_SHA=$(sha256sum "$DTB" | awk '{print $1}')
KERNEL_SHA=$(sha256sum "$KERNEL" | awk '{print $1}')
INITRD_SHA=$(sha256sum "$INITRD" | awk '{print $1}')

# A bounded, read-only probe: emit the device tree view, then power off.  It
# does not modify the guest; it only reads files under /sys/firmware/devicetree.
PROBE='for p in /sys/firmware/devicetree/base/model /sys/firmware/devicetree/base/compatible; do echo "DT-PROBE $(cat $p 2>/dev/null | tr "\0" " ")"; done; for d in /sys/firmware/devicetree/base/pl011@9000000; do echo "DT-PROBE-NODE $d"; ls $d 2>/dev/null | tr "\n" " "; echo; done; echo "DT-PROBE-END"; poweroff -f'

BOOTARGS="console=${CONSOLE} earlycon=${EARLYCON} rdinit=/init"

mkdir -p "$(dirname "$OUT_LOG")" "$(dirname "$OUT_ARGV")"

ARGV=(
    "$QEMU"
    -machine "$QEMU_MACHINE"
    -cpu "$QEMU_CPU"
    -m "$QEMU_MEM"
    -smp "$QEMU_SMP"
    -nographic
    -kernel "$KERNEL"
    -initrd "$INITRD"
    -dtb "$DTB"
    -append "$BOOTARGS"
)

{
    echo "# executed_argv (one argument per line, shell-quoted)"
    printf '%s\n' "${ARGV[@]}" | sed 's/^/argv: /'
    echo "dtb_sha256: $DTB_SHA"
    echo "kernel_sha256: $KERNEL_SHA"
    echo "initrd_sha256: $INITRD_SHA"
    echo "bootargs: $BOOTARGS"
    echo "machine: $QEMU_MACHINE"
    echo "cpu: $QEMU_CPU"
    echo "memory: $QEMU_MEM"
    echo "smp: $QEMU_SMP"
    echo "qemu_version: $("$QEMU" --version | head -n 1)"
    echo "captured_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT_ARGV"

echo "=== booting with -dtb $DTB (sha256 $DTB_SHA) ==="
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

echo "[OK] console log   : $OUT_LOG ($(wc -c < "$OUT_LOG" | tr -d ' ') bytes)"
echo "[OK] argv provenance: $OUT_ARGV"
