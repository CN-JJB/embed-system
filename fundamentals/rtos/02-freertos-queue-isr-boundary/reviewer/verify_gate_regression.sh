#!/usr/bin/env bash
# ==============================================================================
# verify_gate_regression.sh: Regression Test Harness for P2-M05 Module Gate
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M05_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GATE_DIR="${M05_DIR}/gate/gate_fault_firmware"
GATE_MAIN="${GATE_DIR}/src/main.c"

echo "=== Running P2-M05 Module Gate Regression Suite ==="

# 1. Clean build unpatched gate firmware
echo "Step 1: Building unpatched gate firmware..."
make -C "${GATE_DIR}" clean all >/dev/null 2>&1

# 2. Inspect unpatched disassembly for defects:
DISASM=$(arm-none-eabi-objdump -d "${GATE_DIR}/build/firmware.elf")
TIM2_DISASM=$(echo "${DISASM}" | awk '/<TIM2_IRQHandler>:/ {flag=1} flag && !/<TIM2_IRQHandler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')

# In unpatched binary, portYIELD_FROM_ISR is missing (no write to SCB->ICSR 0xe000ed04)
if echo "${TIM2_DISASM}" | grep -qiE "(ed04|0x10000000|268435456)"; then
    echo "ERROR: Expected missing yield defect not found in unpatched binary!" >&2
    exit 1
fi
echo "[PASS] Defect correctly identified: TIM2_IRQHandler omits portYIELD_FROM_ISR"

# Check that NVIC_SetPriority was called with priority 3 in main.c
if ! grep -qE "NVIC_SetPriority\s*\(\s*TIM2_IRQn\s*,\s*3\s*\)" "${GATE_MAIN}"; then
    echo "ERROR: Expected priority defect (priority 3) not found in unpatched main.c!" >&2
    exit 1
fi
echo "[PASS] Defect correctly identified: TIM2 priority set to logical 3 (violates syscall threshold 5)"

# Check that queue receive uses non-blocking 0 timeout
if ! grep -qE "xQueueReceive\s*\(\s*s_telemetry_queue\s*,\s*&packet\s*,\s*0\s*\)" "${GATE_MAIN}"; then
    echo "ERROR: Expected polling defect (timeout 0) not found in unpatched main.c!" >&2
    exit 1
fi
echo "[PASS] Defect correctly identified: consumer task spins with timeout 0 causing CPU starvation"

# Backup original file and guarantee restoration even if a later command fails
BACKUP_MAIN="$(mktemp)"
cp "${GATE_MAIN}" "${BACKUP_MAIN}"
restore_gate_main() {
    cp "${BACKUP_MAIN}" "${GATE_MAIN}"
    rm -f "${BACKUP_MAIN}"
}
trap restore_gate_main EXIT

# 3. Apply reference patch to gate_fault_firmware/src/main.c
echo "Step 2: Applying reference patch to gate main.c..."
python3 -c "
path = '${GATE_MAIN}'
s = open(path).read()
s = s.replace('NVIC_SetPriority(TIM2_IRQn, 3);', 'NVIC_SetPriority(TIM2_IRQn, 6);')
s = s.replace('xQueueReceive(s_telemetry_queue, &packet, 0)', 'xQueueReceive(s_telemetry_queue, &packet, portMAX_DELAY)')
s = s.replace('(void)xHigherPriorityTaskWoken;', 'portYIELD_FROM_ISR(xHigherPriorityTaskWoken);')
open(path, 'w').write(s)
"

# 4. Build patched firmware
echo "Step 3: Building patched gate firmware..."
make -C "${GATE_DIR}" clean all >/dev/null 2>&1

# 5. Inspect patched binary: TIM2_IRQHandler must invoke portYIELD_FROM_ISR
PATCHED_DISASM=$(arm-none-eabi-objdump -d "${GATE_DIR}/build/firmware.elf")
PATCHED_TIM2=$(echo "${PATCHED_DISASM}" | awk '/<TIM2_IRQHandler>:/ {flag=1} flag && !/<TIM2_IRQHandler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')

if ! echo "${PATCHED_TIM2}" | grep -qiE "(ed04|0x10000000|268435456)"; then
    echo "ERROR: Patched binary does not write to SCB->ICSR for portYIELD_FROM_ISR!" >&2
    exit 1
fi
echo "[PASS] Patch verified: TIM2_IRQHandler correctly invokes portYIELD_FROM_ISR"

# 6. Revert patch to preserve gate challenge state for students
echo "Step 4: Reverting patch to restore pristine gate challenge..."
restore_gate_main
trap - EXIT

echo "=== ALL P2-M05 GATE REGRESSION CHECKS PASSED ==="
