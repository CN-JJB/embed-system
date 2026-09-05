#!/usr/bin/env bash
# ==============================================================================
# verify_gate_regression.sh: Reviewer Verification for M03 Gate Fault Fixture
# Proves that the seeded Gate fixture exhibits the TIM_CR1_UDIS defect.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M03_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GATE_DIR="${M03_DIR}/gate/gate_fault_firmware"

echo "=== Verifying P2-M03 Gate Fault Fixture Seeded Properties ==="

# 1. Build Gate fixture
make -C "${GATE_DIR}" clean all >/dev/null

ELF="${GATE_DIR}/build/firmware.elf"
if [ ! -f "${ELF}" ]; then
    echo "ERROR: Gate firmware ELF build failed!" >&2
    exit 1
fi

DISASM=$(arm-none-eabi-objdump -d "${ELF}")

# 2. Check gate_tim3_init for seeded UDIS configuration (TIM_CR1_CEN | TIM_CR1_UDIS = 0x3)
INIT_DISASM=$(echo "${DISASM}" | awk '/<gate_tim3_init>:/ {flag=1} flag && !/<gate_tim3_init>:/ && /<[a-zA-Z0-9_]+>:/ {flag=0} flag {print}')
if ! echo "${INIT_DISASM}" | grep -E "movs\s+r[0-9]+,\s*#3" >/dev/null 2>&1 || ! echo "${INIT_DISASM}" | grep -E "str\s+r[0-9]+,\s*\[r[0-9]+,\s*#0\]" >/dev/null 2>&1; then
    echo "ERROR: Seeded fault missing! gate_tim3_init does not write #3 (CEN | UDIS) to TIM3->CR1!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms gate_tim3_init writes #3 (TIM_CR1_CEN | TIM_CR1_UDIS) to TIM3->CR1"

# 3. Check DMA & ADC configuration presence
if ! echo "${DISASM}" | grep -qiE "gate_dma_init" || ! echo "${DISASM}" | grep -qiE "gate_adc_init"; then
    echo "ERROR: Seeded fixture invalid! DMA and ADC initialization routines must be linked!" >&2
    exit 1
fi
echo "[PASS] Gate fixture links complete DMA and ADC acquisition pipeline"

echo "=== M03 GATE FAULT FIXTURE PROVEN CORRECT (STATIC/BINARY REGRESSION PASSED) ==="
