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

# 2. Inspect disassembly for Idle hook calling vTaskDelay defect
DISASM=$(arm-none-eabi-objdump -d "${GATE_DIR}/build/firmware.elf")
IDLE_DISASM=$(echo "${DISASM}" | awk '/<vApplicationIdleHook>:/ {flag=1} flag && !/<vApplicationIdleHook>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')

if echo "${IDLE_DISASM}" | grep -qE "b[l]?(\.w)?.*<vTaskDelay>"; then
    echo "[PASS] Defect correctly identified: vApplicationIdleHook calls vTaskDelay (violates Idle task never-block invariant)"
else
    echo "ERROR: Expected defect (vApplicationIdleHook calling vTaskDelay) not found in unpatched binary!" >&2
    exit 1
fi

# Backup original file and guarantee restoration even if a later command fails (Leader commit c79cbcdc)
BACKUP_CONFIG="$(mktemp)"
cp "${CONFIG_H}" "${BACKUP_CONFIG}"
restore_gate_config() {
    cp "${BACKUP_CONFIG}" "${CONFIG_H}"
    rm -f "${BACKUP_CONFIG}"
}
trap restore_gate_config EXIT

# 3. Apply reference patch (disable configUSE_IDLE_HOOK)
echo "Step 2: Applying reference patch to FreeRTOSConfig.h..."
sed -i 's/#define configUSE_IDLE_HOOK\s*1/#define configUSE_IDLE_HOOK                     0/' "${CONFIG_H}"

# 4. Build patched firmware
echo "Step 3: Building patched gate firmware..."
make -C "${GATE_DIR}" clean all >/dev/null 2>&1

# 5. Inspect patched binary: vApplicationIdleHook must not call vTaskDelay
PATCHED_DISASM=$(arm-none-eabi-objdump -d "${GATE_DIR}/build/firmware.elf")
if echo "${PATCHED_DISASM}" | grep -qE "<vApplicationIdleHook>:"; then
    PATCHED_IDLE=$(echo "${PATCHED_DISASM}" | awk '/<vApplicationIdleHook>:/ {flag=1} flag && !/<vApplicationIdleHook>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')
    if echo "${PATCHED_IDLE}" | grep -qE "b[l]?(\.w)?.*<vTaskDelay>"; then
        echo "ERROR: Patched binary still calls vTaskDelay from Idle hook!" >&2
        exit 1
    fi
fi
echo "[PASS] Patch verified: Idle task never enters Blocked state (Idle hook disabled / non-blocking)"

# 6. Revert patch to preserve gate challenge state for students
echo "Step 4: Reverting patch to restore pristine gate challenge..."
restore_gate_config
trap - EXIT
make -C "${GATE_DIR}" clean all >/dev/null 2>&1

echo "=== ALL P2-M04 GATE REGRESSION CHECKS PASSED ==="
