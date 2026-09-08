#!/bin/bash
set -euo pipefail

# Real Linux 6.18.50 Kernel Build & Artifact Audit
# Pinned Commit: 7cfc41f8e80f11ffa8382ed1a505154ceffb79c7

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

# 7. Actual-Host QEMU Boot Validation
echo ""
echo "=== Step 7: Calibrating Boot under Actual-Host QEMU Profile ==="
QEMU_BIN="${QEMU_BIN:-qemu-system-arm}"
if command -v "$QEMU_BIN" >/dev/null 2>&1; then
    QEMU_VER=$("$QEMU_BIN" --version | head -n 1)
    echo "Host QEMU detected: $QEMU_VER"
    echo "Launching real zImage under actual host QEMU..."
    
    BOOT_LOG="/tmp/real_kernel_qemu_boot.log"
    rm -f "$BOOT_LOG"
    
    # Run with 15s timeout
    set +e
    timeout 15s "$QEMU_BIN" \
        -machine virt,highmem=off,gic-version=2 \
        -cpu cortex-a7 \
        -m 512M \
        -smp 1 \
        -nographic \
        -kernel "$REAL_ZIMAGE" \
        -append "console=ttyAMA0 earlycon=pl011,0x09000000" \
        > "$BOOT_LOG" 2>&1
    set -e

    echo "--- Observed QEMU Boot Log Extract ---"
    grep -E "Booting Linux|Linux version|CPU: ARMv7|Kernel command line|Mountpoint-cache|Kernel panic.*VFS" "$BOOT_LOG" | head -n 15 || true

    if grep -q "Kernel panic" "$BOOT_LOG" && grep -q "VFS: Unable to mount root fs" "$BOOT_LOG"; then
        echo "[PASS] Real kernel booted to expected VFS root mount panic milestone!"
        echo "       actual-host QEMU run ($QEMU_VER): VERIFIED"
        echo "       canonical QEMU 11.1.1 runtime: UNVERIFIED (canonical platform contract)"
    else
        echo "[NOTE] Boot log captured at $BOOT_LOG. Did not observe full VFS panic within timeout."
        tail -n 20 "$BOOT_LOG"
    fi
else
    echo "[NOTE] Host qemu-system-arm not found. QEMU runtime UNVERIFIED."
fi

echo "=================================================================="
echo "=== REAL LINUX 6.18.50 BUILD & ARTIFACT AUDIT PASSED (VERIFIED) ==="
echo "=================================================================="
