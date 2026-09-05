#!/usr/bin/env bash
# ==============================================================================
# verify_gate_regression.sh: Regression Test Harness for P2-M04 Module Gate
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M04_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GATE_DIR="${M04_DIR}/gate/gate_fault_firmware"
CONFIG_H="${GATE_DIR}/include/FreeRTOSConfig.h"

echo "=== Running P2-M04 Module Gate Regression Suite ==="

# 1. Clean build unpatched gate firmware
echo "Step 1: Building unpatched gate firmware..."
make -C "${GATE_DIR}" clean all >/dev/null 2>&1

# 2. Inspect disassembly for unshifted BASEPRI defect
DISASM=$(arm-none-eabi-objdump -d "${GATE_DIR}/build/firmware.elf")
PENDSV_DISASM=$(echo "${DISASM}" | awk '/<PendSV_Handler>:/ {flag=1} flag && !/<PendSV_Handler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')

if echo "${PENDSV_DISASM}" | grep -qE "mov\.w\s+r0,\s+#5"; then
    echo "[PASS] Defect correctly identified: PendSV_Handler sets BASEPRI to unshifted 5 (evaluates to 0 on Cortex-M3)"
else
    echo "ERROR: Expected defect 'mov.w r0, #5' not found in unpatched binary!" >&2
    exit 1
fi

# Backup original file
cp "${CONFIG_H}" "${CONFIG_H}.bak"

# 3. Apply reference patch
echo "Step 2: Applying reference patch to FreeRTOSConfig.h..."
sed -i 's/#define configMAX_SYSCALL_INTERRUPT_PRIORITY    5/#define configMAX_SYSCALL_INTERRUPT_PRIORITY    (configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY << (8 - configPRIO_BITS))/' "${CONFIG_H}"

# 4. Build patched firmware
echo "Step 3: Building patched gate firmware..."
make -C "${GATE_DIR}" clean all >/dev/null 2>&1

# 5. Inspect patched disassembly
PATCHED_DISASM=$(arm-none-eabi-objdump -d "${GATE_DIR}/build/firmware.elf")
PATCHED_PENDSV=$(echo "${PATCHED_DISASM}" | awk '/<PendSV_Handler>:/ {flag=1} flag && !/<PendSV_Handler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')

if echo "${PATCHED_PENDSV}" | grep -qE "mov\.w\s+r0,\s+#80"; then
    echo "[PASS] Patch verified: PendSV_Handler correctly programs BASEPRI to 0x50 (shifted priority 5)"
else
    echo "ERROR: Patched binary does not program BASEPRI with 0x50 (80)!" >&2
    # Restore original file before exiting
    mv "${CONFIG_H}.bak" "${CONFIG_H}"
    exit 1
fi

# 6. Revert patch to preserve gate challenge state for students
echo "Step 4: Reverting patch to restore pristine gate challenge..."
mv "${CONFIG_H}.bak" "${CONFIG_H}"
make -C "${GATE_DIR}" clean all >/dev/null 2>&1

echo "=== ALL P2-M04 GATE REGRESSION CHECKS PASSED ==="
