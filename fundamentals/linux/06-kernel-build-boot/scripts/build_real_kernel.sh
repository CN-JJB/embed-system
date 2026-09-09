#!/bin/bash
set -euo pipefail

# Real Linux 6.18.50 Kernel Build & Artifact Audit (BUILD-ONLY TARGET)
# Pinned Commit: 7cfc41f8e80f11ffa8382ed1a505154ceffb79c7
#
# This target verifies source identity, configuration, compilation and
# artifact integrity only. It performs NO QEMU runtime validation; runtime
# evidence is produced exclusively by scripts/run_real_qemu.sh (strict).

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M02_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
LINUX_SRC="${1:-${LINUX_SRC:-/tmp/linux-6.18.50}}"

PINNED_COMMIT="7cfc41f8e80f11ffa8382ed1a505154ceffb79c7"

echo "=================================================================="
echo "=== Real Linux 6.18.50 Kernel Build & Artifact Audit           ==="
echo "=================================================================="

# 1. Verify Upstream Source Identity
echo "=== Step 1: Auditing Upstream Source Identity ==="
if [ ! -d "$LINUX_SRC" ] || [ ! -d "$LINUX_SRC/.git" ]; then
    echo "ERROR: Linux kernel source tree not found at: $LINUX_SRC" >&2
    echo "To clone the pinned kernel tree, run:" >&2
    echo "  git clone --depth 1 --branch v6.18.50 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git $LINUX_SRC" >&2
    exit 1
fi

ACTUAL_COMMIT=$(git -C "$LINUX_SRC" rev-parse HEAD)
if [ "$ACTUAL_COMMIT" != "$PINNED_COMMIT" ]; then
    echo "ERROR: Target source commit ($ACTUAL_COMMIT) does not match canonical pin ($PINNED_COMMIT)!" >&2
    exit 1
fi
echo "[PASS] Verified pinned Linux source commit: $ACTUAL_COMMIT"

# 2. Check Toolchain
echo "=== Step 2: Checking Cross-Compilation Toolchain ==="
CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "ERROR: Compiler '${CROSS_COMPILE}gcc' not found in PATH." >&2
    echo "For Ubuntu/Debian distro toolchain, pass: CROSS_COMPILE=arm-linux-gnueabihf- $0" >&2
    exit 1
fi

CC="${CROSS_COMPILE}gcc"
READELF="readelf"
NM="${CROSS_COMPILE}nm"
if ! command -v "$NM" >/dev/null 2>&1; then
    NM="nm"
fi

echo "[PASS] Toolchain prefix: $CROSS_COMPILE"
echo "       Compiler: $(command -v "$CC")"
echo "       Version:  $("$CC" --version | head -n 1)"
echo "       Machine:  $("$CC" -dumpmachine)"

# 3. Configure Kernel: multi_v7_defconfig + delta + olddefconfig
echo "=== Step 3: Configuring Kernel (multi_v7_defconfig + Phase 3 delta) ==="
DELTA_CONFIG="$M02_ROOT/fixtures/configs/phase3_delta.config"
[ -f "$DELTA_CONFIG" ] || { echo "ERROR: $DELTA_CONFIG missing!"; exit 1; }

make -C "$LINUX_SRC" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" multi_v7_defconfig >/dev/null
echo "[PASS] multi_v7_defconfig generated"

cat "$DELTA_CONFIG" >> "$LINUX_SRC/.config"
make -C "$LINUX_SRC" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" olddefconfig >/dev/null
echo "[PASS] Phase 3 delta applied and olddefconfig resolved"

# 4. Audit Effective Kernel Configuration
echo "=== Step 4: Auditing Effective .config ==="
bash "$M02_ROOT/scripts/verify_kernel_config.sh" "$LINUX_SRC/.config"
echo "[PASS] Effective .config strictly conforms to Phase 3 platform baseline"

# 5. Compile Real Kernel Artifacts
echo "=== Step 5: Compiling Real Kernel Artifacts (vmlinux, zImage, System.map) ==="
NPROCS=$(nproc 2>/dev/null || echo 4)
echo "Building with -j${NPROCS}..."
make -C "$LINUX_SRC" -j"$NPROCS" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" vmlinux zImage

REAL_VMLINUX="$LINUX_SRC/vmlinux"
REAL_ZIMAGE="$LINUX_SRC/arch/arm/boot/zImage"
REAL_SYSMAP="$LINUX_SRC/System.map"

[ -f "$REAL_VMLINUX" ] || { echo "ERROR: $REAL_VMLINUX failed to build!"; exit 1; }
[ -f "$REAL_ZIMAGE" ] || { echo "ERROR: $REAL_ZIMAGE failed to build!"; exit 1; }
[ -f "$REAL_SYSMAP" ] || { echo "ERROR: $REAL_SYSMAP failed to build!"; exit 1; }

# 6. Audit Real Artifacts
echo "=== Step 6: Auditing Real Kernel Image Artifacts ==="

# 6.1 vmlinux
VM_MACHINE=$("$READELF" -h "$REAL_VMLINUX" | awk -F: '/Machine:/ {print $2}' | xargs)
VM_ENTRY=$("$READELF" -h "$REAL_VMLINUX" | awk -F: '/Entry point/ {print $2}' | xargs)
echo "[PASS] Real vmlinux Machine: $VM_MACHINE (Entry: $VM_ENTRY)"
[[ "$VM_MACHINE" == *"ARM"* ]] || { echo "ERROR: vmlinux machine is not ARM!"; exit 1; }

for sym in stext start_kernel setup_arch console_init rest_init kernel_init; do
    grep -q " ${sym}$" "$REAL_SYSMAP" || { echo "ERROR: Symbol $sym missing in real System.map!"; exit 1; }
done
echo "[PASS] Core boot symbols confirmed in real kernel: stext, start_kernel, setup_arch, console_init, rest_init, kernel_init"

# 6.2 zImage
ZMAGIC=$(hexdump -s 0x24 -n 4 -e '"%08x"' "$REAL_ZIMAGE" 2>/dev/null || true)
if [ "$ZMAGIC" != "016f2818" ]; then
    echo "ERROR: Real zImage magic mismatch (got 0x$ZMAGIC, expected 0x016f2818)!" >&2
    exit 1
fi
echo "[PASS] Real zImage verified with official ARM boot magic (0x016f2818 at offset 0x24)"

# 6.3 System.map synchronization
V_START=$("$READELF" -s "$REAL_VMLINUX" | awk '$8 == "start_kernel" {print $2}')
M_START=$(awk '$3 == "start_kernel" {print $1}' "$REAL_SYSMAP")
NORM_V=$(echo "$V_START" | sed 's/^0x//; s/^0*//' | tr '[:upper:]' '[:lower:]')
NORM_M=$(echo "$M_START" | sed 's/^0x//; s/^0*//' | tr '[:upper:]' '[:lower:]')
if [ "$NORM_V" != "$NORM_M" ]; then
    echo "ERROR: System.map ($M_START) and vmlinux ($V_START) start_kernel address mismatch!" >&2
    exit 1
fi
echo "[PASS] Real System.map start_kernel address (0x$M_START) strictly synchronizes with vmlinux"

echo ""
echo "--- Real Artifact Fingerprints ---"
ls -lh "$REAL_VMLINUX" "$REAL_ZIMAGE" "$REAL_SYSMAP"
echo "SHA-256 (vmlinux):   $(sha256sum "$REAL_VMLINUX" | awk '{print $1}')"
echo "SHA-256 (zImage):    $(sha256sum "$REAL_ZIMAGE" | awk '{print $1}')"
echo "SHA-256 (System.map): $(sha256sum "$REAL_SYSMAP" | awk '{print $1}')"

echo ""
echo "=== REAL LINUX 6.18.50 BUILD & ARTIFACT AUDIT PASSED (VERIFIED) ==="
echo "=== QEMU runtime status: NOT EVALUATED BY THIS TARGET           ==="
echo "=== (run scripts/run_real_qemu.sh for strict runtime evidence) ==="
echo "=================================================================="
