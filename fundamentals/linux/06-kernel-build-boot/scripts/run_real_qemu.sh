#!/bin/bash
set -euo pipefail

# Strict Actual-Host QEMU Runtime Regression (RUNTIME-ONLY TARGET)
# ---------------------------------------------------------------
# Separated from build/artifact verification (scripts/build_real_kernel.sh).
#
# Strict semantics:
#   - QEMU missing while this target is requested -> UNVERIFIED, exit FAIL
#     (an explicit skip is only legitimate when the runtime target is not
#      requested at all, which is the build-only target's territory)
#   - QEMU present but command fails          -> FAIL
#   - expected kernel milestone not reached   -> FAIL
#   - expected milestone reached              -> VERIFIED
#
# The boot always uses the canonical machine contract explicitly:
#   -machine virt,highmem=off,gic-version=2 -cpu cortex-a7 -m 512M -smp 1

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M02_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
LINUX_SRC="${1:-${LINUX_SRC:-/tmp/linux-6.18.50}}"

PINNED_COMMIT="7cfc41f8e80f11ffa8382ed1a505154ceffb79c7"
QEMU_BIN="${QEMU_BIN:-qemu-system-arm}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-120}"
BOOT_LOG="${BOOT_LOG:-/tmp/real_kernel_qemu_boot.log}"

MACHINE_OPT="virt,highmem=off,gic-version=2"
CPU_OPT="cortex-a7"
MEM_OPT="512M"
SMP_OPT="1"

REAL_ZIMAGE="$LINUX_SRC/arch/arm/boot/zImage"

echo "=================================================================="
echo "=== Strict Actual-Host QEMU Runtime Regression (M02)          ==="
echo "=================================================================="

# 1. Source identity of the kernel being booted
if [ ! -d "$LINUX_SRC/.git" ]; then
    echo "[FAIL] Linux kernel source tree not found at: $LINUX_SRC" >&2
    echo "       Run scripts/build_real_kernel.sh first, or pass the tree path." >&2
    exit 1
fi
ACTUAL_COMMIT=$(git -C "$LINUX_SRC" rev-parse HEAD)
if [ "$ACTUAL_COMMIT" != "$PINNED_COMMIT" ]; then
    echo "[FAIL] Kernel tree commit ($ACTUAL_COMMIT) does not match canonical pin ($PINNED_COMMIT)." >&2
    exit 1
fi
echo "[PASS] Kernel source identity: $ACTUAL_COMMIT (Linux 6.18.50 pin)"

# 2. Boot image must exist
if [ ! -f "$REAL_ZIMAGE" ]; then
    echo "[FAIL] Real zImage not found at $REAL_ZIMAGE." >&2
    echo "       Run scripts/build_real_kernel.sh (real-kernel-build-check) first." >&2
    exit 1
fi
echo "[PASS] Real zImage present: $REAL_ZIMAGE"

# 3. QEMU availability — requested runtime target, so absence is NOT a pass
if ! command -v "$QEMU_BIN" >/dev/null 2>&1; then
    echo "------------------------------------------------------------------"
    echo "QEMU runtime status: UNVERIFIED"
    echo "qemu-system-arm was NOT found in PATH, but this strict runtime"
    echo "target was explicitly requested. Refusing to report PASS."
    echo "------------------------------------------------------------------" >&2
    exit 1
fi
QEMU_VER=$("$QEMU_BIN" --version | head -n 1)
echo "[PASS] Actual-host QEMU detected: $QEMU_VER"

# 4. Boot with the exact canonical machine contract
echo "------------------------------------------------------------------"
echo "Executing exact command:"
echo "$QEMU_BIN \\"
echo "  -machine $MACHINE_OPT \\"
echo "  -cpu $CPU_OPT \\"
echo "  -m $MEM_OPT \\"
echo "  -smp $SMP_OPT \\"
echo "  -nographic \\"
echo "  -kernel $REAL_ZIMAGE \\"
echo "  -append \"console=ttyAMA0 earlycon=pl011,0x09000000\""
echo "------------------------------------------------------------------"

rm -f "$BOOT_LOG"

set +e
timeout "${BOOT_TIMEOUT}s" "$QEMU_BIN" \
    -machine "$MACHINE_OPT" \
    -cpu "$CPU_OPT" \
    -m "$MEM_OPT" \
    -smp "$SMP_OPT" \
    -nographic \
    -kernel "$REAL_ZIMAGE" \
    -append "console=ttyAMA0 earlycon=pl011,0x09000000" \
    > "$BOOT_LOG" 2>&1
QEMU_RC=$?
set -e

echo "--- Observed QEMU Boot Log Extract ---"
grep -E "Booting Linux|Linux version|CPU: ARMv7|Kernel command line|Kernel panic.*VFS|Unable to mount root fs" "$BOOT_LOG" | head -n 20 || true

# 5. Milestone verdict (strict)
if grep -q "Kernel panic" "$BOOT_LOG" && grep -q "VFS: Unable to mount root fs" "$BOOT_LOG"; then
    echo "------------------------------------------------------------------"
    echo "Observed milestone: VFS root mount panic (expected M02 termination)."
    echo "QEMU runtime status: VERIFIED (actual-host $QEMU_VER)"
    echo "Canonical QEMU 11.1.1 runtime: UNVERIFIED (11.1.1 itself not executed)"
    echo "=== STRICT ACTUAL-HOST QEMU RUNTIME REGRESSION PASSED ==="
    exit 0
fi

echo "[FAIL] Expected kernel milestone NOT reached within ${BOOT_TIMEOUT}s (QEMU exit code: $QEMU_RC)." >&2
if [ "$QEMU_RC" -ne 0 ] && [ "$QEMU_RC" -ne 124 ]; then
    echo "[FAIL] QEMU command failed with exit code $QEMU_RC." >&2
fi
echo "Full boot log captured at: $BOOT_LOG" >&2
echo "--- Tail of boot log ---" >&2
tail -n 25 "$BOOT_LOG" >&2 || true
exit 1
