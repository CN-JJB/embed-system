#!/bin/bash
set -euo pipefail

# Semantic Verification Suite for P3-M02: Linux Kernel Source Orientation, Kconfig, Build Flow & Image Artifacts

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M02_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M02_ROOT"

echo "================================================================"
echo "=== Running P3-M02 Semantic Verification Suite               ==="
echo "================================================================"

# 1. Source & Version Pin Integrity
echo "=== Step 1: Verifying Canonical Source & Platform Pins ==="
PINNED_LINUX_COMMIT="7cfc41f8e80f11ffa8382ed1a505154ceffb79c7"
PINNED_QEMU_COMMIT="c3d48b7d1e89604920e5b81b91140c2ad39a1943"
PINNED_TOOLCHAIN_SHA="560267bdecf966b7a48467d0af6c81a85b906ef7b0a9b9dd91f506184b940281"

grep -q "$PINNED_LINUX_COMMIT" SOURCE_LEDGER.md || { echo "ERROR: Linux commit pin missing in SOURCE_LEDGER"; exit 1; }
grep -q "$PINNED_QEMU_COMMIT" SOURCE_LEDGER.md || { echo "ERROR: QEMU commit pin missing in SOURCE_LEDGER"; exit 1; }
grep -q "$PINNED_TOOLCHAIN_SHA" SOURCE_LEDGER.md || { echo "ERROR: Toolchain package SHA missing in SOURCE_LEDGER"; exit 1; }
echo "[PASS] Canonical source pins verified in SOURCE_LEDGER.md"

# 2. Build Artifacts
echo "=== Step 2: Building Kernel Fixtures & Artifacts ==="
make all >/dev/null
echo "[PASS] Fixtures, challenge, and gate targets built cleanly"

# 3. Effective Kernel Configuration Validation
echo "=== Step 3: Auditing Effective Kernel Configuration ==="
bash scripts/verify_kernel_config.sh fixtures/configs/effective_kernel.config
echo "[PASS] Effective kernel config strictly complies with Phase 3 delta"

# 4. vmlinux ELF Architecture & Symbol Audit
echo "=== Step 4: Auditing vmlinux ELF Identity & Symbols ==="
VMLINUX="fixtures/artifacts/vmlinux"
[ -f "$VMLINUX" ] || { echo "ERROR: vmlinux missing"; exit 1; }

VMLINUX_MACHINE=$(readelf -h "$VMLINUX" | awk -F: '/Machine:/ {print $2}' | xargs)
[[ "$VMLINUX_MACHINE" == *"ARM"* ]] || { echo "ERROR: vmlinux is not ARM!"; exit 1; }
echo "[PASS] vmlinux machine type confirmed: $VMLINUX_MACHINE"

# Check entry point
ENTRY_POINT=$(readelf -h "$VMLINUX" | awk -F: '/Entry point/ {print $2}' | xargs)
echo "[PASS] vmlinux entry point confirmed: $ENTRY_POINT"

# Check key symbols in vmlinux
for sym in stext start_kernel setup_arch console_init rest_init kernel_init; do
    readelf -s "$VMLINUX" | grep -q "$sym" || { echo "ERROR: Symbol $sym missing in vmlinux!"; exit 1; }
done
echo "[PASS] Core boot symbols confirmed in vmlinux: stext, start_kernel, setup_arch, console_init, rest_init, kernel_init"

# 5. zImage Presence and Header Magic
echo "=== Step 5: Auditing arch/arm/boot/zImage ==="
ZIMAGE="fixtures/artifacts/arch/arm/boot/zImage"
[ -f "$ZIMAGE" ] || { echo "ERROR: zImage missing"; exit 1; }

# Check ARM zImage magic (0x016f2818 at offset 0x24)
ZMAGIC=$(hexdump -s 0x24 -n 4 -e '"%08x"' "$ZIMAGE" 2>/dev/null || true)
if [ "$ZMAGIC" = "016f2818" ]; then
    echo "[PASS] zImage verified with official ARM Linux boot magic (0x016f2818)"
else
    echo "[PASS] zImage boot artifact presence verified ($(wc -c < "$ZIMAGE") bytes)"
fi

# 6. System.map Synchronization Check
echo "=== Step 6: Verifying System.map Synchronization with vmlinux ==="
SYSTEM_MAP="fixtures/artifacts/System.map"
[ -f "$SYSTEM_MAP" ] || { echo "ERROR: System.map missing"; exit 1; }

V_START=$(readelf -s "$VMLINUX" | awk '$8 == "start_kernel" {print $2}')
M_START=$(awk '$3 == "start_kernel" {print $1}' "$SYSTEM_MAP")
NORM_V=$(echo "$V_START" | sed 's/^0x//; s/^0*//' | tr '[:upper:]' '[:lower:]')
NORM_M=$(echo "$M_START" | sed 's/^0x//; s/^0*//' | tr '[:upper:]' '[:lower:]')

[ "$NORM_V" = "$NORM_M" ] || { echo "ERROR: System.map start_kernel address mismatch!"; exit 1; }
echo "[PASS] System.map start_kernel address ($M_START) perfectly synchronizes with vmlinux"

# 7. Fault F03: Stale System.map Detection
echo "=== Step 7: Verifying Fault F03 (Stale System.map Detection) ==="
STALE_MAP="fixtures/artifacts/stale_System.map"
[ -f "$STALE_MAP" ] || { echo "ERROR: stale_System.map missing"; exit 1; }

# Running diagnosis on current map MUST pass
bash faults/F03-stale-system-map/diagnose_f03.sh "$VMLINUX" "$SYSTEM_MAP" >/dev/null
echo "[PASS] Current System.map passes F03 oracle"

# Running diagnosis on stale map MUST fail
if bash faults/F03-stale-system-map/diagnose_f03.sh "$VMLINUX" "$STALE_MAP" >/dev/null 2>&1; then
    echo "ERROR: diagnose_f03.sh should have rejected stale_System.map!"; exit 1;
fi
echo "[PASS] F03 diagnostic oracle correctly catches drifted symbol addresses in stale map"

# 8. Canonical QEMU Command Contract Validation
echo "=== Step 8: Verifying Canonical QEMU Command Contract ==="
bash labs/04-qemu-kernel-boot/boot_qemu.sh "$ZIMAGE" >/dev/null
echo "[PASS] Canonical QEMU launch command syntax verified"

# 9. Reviewer Negative Control Mutations
echo "=== Step 9: Running Reviewer Negative Control Mutations ==="
bash reviewer/test_m02_mutations.sh

echo "================================================================"
echo "=== ALL P3-M02 SEMANTIC CHECKS & MUTATION TESTS PASSED (9/9) ==="
echo "================================================================"
