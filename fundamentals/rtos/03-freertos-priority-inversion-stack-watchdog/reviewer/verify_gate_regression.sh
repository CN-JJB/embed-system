#!/usr/bin/env bash
# ==============================================================================
# verify_gate_regression.sh: Regression Test Harness for P2-M06 Module Gate
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M06_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GATE_DIR="${M06_DIR}/gate/gate_fault_firmware"
GATE_MAIN="${GATE_DIR}/src/main.c"
GATE_IWDG="${GATE_DIR}/src/iwdg.c"

echo "=== Running P2-M06 Module Gate Regression Suite ==="

# 1. Clean build unpatched gate firmware
echo "Step 1: Building unpatched gate firmware..."
make -C "${GATE_DIR}" clean all >/dev/null 2>&1

# 2. Inspect unpatched source for defects:
if ! grep -qE "xSemaphoreCreateBinary\s*\(\s*\)" "${GATE_MAIN}"; then
    echo "ERROR: Expected binary semaphore defect not found in unpatched main.c!" >&2
    exit 1
fi
echo "[PASS] Defect correctly identified: communication buffer uses binary semaphore without inheritance"

if ! grep -qE "g_reported_watermark_bytes\s*=\s*\(uint32_t\)\s*wm_words\s*;" "${GATE_MAIN}"; then
    echo "ERROR: Expected watermark unit defect not found in unpatched main.c!" >&2
    exit 1
fi
echo "[PASS] Defect correctly identified: watermark reporting confuses words with bytes"

if ! grep -q "while ((IWDG->SR & IWDG_SR_PVU) != 0)" "${GATE_IWDG}"; then
    echo "ERROR: Expected unbounded IWDG status loop defect not found in unpatched iwdg.c!" >&2
    exit 1
fi
echo "[PASS] Defect correctly identified: iwdg_init() executes unbounded status polling"

# Backup original files and guarantee restoration
BACKUP_MAIN="$(mktemp)"
BACKUP_IWDG="$(mktemp)"
cp "${GATE_MAIN}" "${BACKUP_MAIN}"
cp "${GATE_IWDG}" "${BACKUP_IWDG}"

restore_gate_files() {
    cp "${BACKUP_MAIN}" "${GATE_MAIN}"
    cp "${BACKUP_IWDG}" "${GATE_IWDG}"
    rm -f "${BACKUP_MAIN}" "${BACKUP_IWDG}"
}
trap restore_gate_files EXIT

# 3. Apply reference patch
echo "Step 2: Applying reference patch to gate defect files..."
python3 -c "
path = '${GATE_MAIN}'
s = open(path).read()
s = s.replace('s_shared_buffer_sem = xSemaphoreCreateBinary();\n    xSemaphoreGive(s_shared_buffer_sem);',
              's_shared_buffer_sem = xSemaphoreCreateMutex();')
s = s.replace('g_reported_watermark_bytes = (uint32_t)wm_words;',
              'g_reported_watermark_bytes = (uint32_t)(wm_words * sizeof(StackType_t));')
open(path, 'w').write(s)

path2 = '${GATE_IWDG}'
s2 = open(path2).read()
s2 = s2.replace('while ((IWDG->SR & IWDG_SR_PVU) != 0) {\n        __NOP();\n    }',
                'uint32_t to = 100000U;\n    while ((IWDG->SR & IWDG_SR_PVU) != 0) { if (--to == 0) return false; }')
s2 = s2.replace('while ((IWDG->SR & IWDG_SR_RVU) != 0) {\n        __NOP();\n    }',
                'to = 100000U;\n    while ((IWDG->SR & IWDG_SR_RVU) != 0) { if (--to == 0) return false; }')
s2 = s2.replace('/* Reset flag retention policy */',
                'RCC->CSR |= RCC_CSR_RMVF;')
open(path2, 'w').write(s2)
"

# 4. Rebuild patched gate firmware
echo "Step 3: Recompiling patched gate firmware..."
make -C "${GATE_DIR}" clean all >/dev/null 2>&1

# 5. Verify patched binary
NM_OUT=$(arm-none-eabi-nm "${GATE_DIR}/build/firmware.elf")
if ! echo "${NM_OUT}" | grep -qE "xQueueCreateMutex"; then
    echo "ERROR: Patched ELF does not reference xQueueCreateMutex!" >&2
    exit 1
fi
echo "[PASS] Verification confirmed: Mutex with priority inheritance linked"

DISASM=$(arm-none-eabi-objdump -d "${GATE_DIR}/build/firmware.elf")
TELEM_DISASM=$(echo "${DISASM}" | awk '/<prvTelemetryTask>:/ {flag=1} flag && !/<prvTelemetryTask>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')
if ! echo "${TELEM_DISASM}" | grep -qiE "(lsl.*#2|mul)"; then
    echo "ERROR: prvTelemetryTask does not multiply watermark words by 4!" >&2
    exit 1
fi
echo "[PASS] Verification confirmed: Watermark words correctly converted to bytes (* 4 / LSL 2)"

echo "=== ALL P2-M06 GATE REGRESSION TESTS PASSED CLEANLY ==="
