#!/usr/bin/env bash
# ==============================================================================
# verify_gate_regression.sh: Reviewer Verification for M02 Gate Fault Fixture
# Proves that the seeded Gate fixture exhibits the One-Pulse Mode (TIM_CR1_OPM) defect.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M02_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GATE_DIR="${M02_DIR}/gate/gate_fault_firmware"

echo "=== Verifying P2-M02 Gate Fault Fixture Seeded Properties ==="

# 1. Build Gate fixture
make -C "${GATE_DIR}" clean all >/dev/null

ELF="${GATE_DIR}/build/firmware.elf"
if [ ! -f "${ELF}" ]; then
    echo "ERROR: Gate firmware ELF build failed!" >&2
    exit 1
fi

DISASM=$(arm-none-eabi-objdump -d "${ELF}")

# 2. Check tim2_init_1khz for seeded One-Pulse Mode configuration (TIM_CR1_CEN | TIM_CR1_OPM = 0x9)
INIT_DISASM=$(echo "${DISASM}" | awk '/<tim2_init_1khz>:/ {flag=1} flag && !/<tim2_init_1khz>:/ && /<[a-zA-Z0-9_]+>:/ {flag=0} flag {print}')
if ! echo "${INIT_DISASM}" | grep -E "movs\s+r[0-9]+,\s*#9" >/dev/null 2>&1 || ! echo "${INIT_DISASM}" | grep -E "str\s+r[0-9]+,\s*\[r[0-9]+,\s*#0\]" >/dev/null 2>&1; then
    echo "ERROR: Seeded fault missing! tim2_init_1khz does not configure CR1 with #9 (TIM_CR1_CEN | TIM_CR1_OPM)!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms tim2_init_1khz writes #9 (TIM_CR1_CEN | TIM_CR1_OPM) to TIM2->CR1"

# 3. Check TIM2_IRQHandler to verify UIF is properly cleared (no interrupt storm; pure OPM fault)
ISR_DISASM=$(echo "${DISASM}" | awk '/<TIM2_IRQHandler>:/ {flag=1} flag && !/<TIM2_IRQHandler>:/ && /<[a-zA-Z0-9_]+>:/ {flag=0} flag {print}')
if ! echo "${ISR_DISASM}" | grep -E "str.*\[.*#16\]|strh.*\[.*#16\]" >/dev/null 2>&1; then
    echo "ERROR: Seeded fixture invalid! TIM2_IRQHandler must clear UIF (offset 16) so fault is purely One-Pulse Mode!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms TIM2_IRQHandler clears TIM2->SR (clean OPM halt, no interrupt storm)"

echo "=== M02 GATE FAULT FIXTURE PROVEN CORRECT (STATIC/BINARY REGRESSION PASSED) ==="
