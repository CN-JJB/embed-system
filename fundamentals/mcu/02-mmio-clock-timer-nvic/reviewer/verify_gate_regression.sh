#!/usr/bin/env bash
# ==============================================================================
# verify_gate_regression.sh: Reviewer Verification for M02 Gate Fault Fixture
# Proves that the seeded Gate fixture exhibits the timer prescaler and uncleared flag defects.
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

# 2. Check TIM2_IRQHandler for omission of SR clear
ISR_DISASM=$(echo "${DISASM}" | awk '/<TIM2_IRQHandler>:/,/(^$|^[0-9a-f]+ <)/')
# In STM32F1, TIM2_BASE is 0x40000000, SR is offset 0x10.
# A clear would write ~TIM_SR_UIF (0xFFFE) to offset 0x10.
# The seeded fault deliberately omits this write.
if echo "${ISR_DISASM}" | grep -E "str.*\[.*#16\]|strh.*\[.*#16\]" >/dev/null 2>&1; then
    echo "ERROR: Seeded fault missing! TIM2_IRQHandler unexpectedly contains a store to offset 16 (SR)!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms TIM2_IRQHandler omits clearing TIM2->SR (seeded interrupt storm)"

# 3. Check tim2_init_1khz for incorrect prescaler math (division by 2,000,000)
# GCC optimizes (timclk / 2 / 1000000) into unsigned division by 2,000,000 via reciprocal
# multiplication with magic constant 0x431bde83.
INIT_DISASM=$(echo "${DISASM}" | grep -A 35 "<tim2_init_1khz>:")
if ! echo "${INIT_DISASM}" | grep -qi "431bde83"; then
    echo "ERROR: Seeded fault missing! tim2_init_1khz does not divide by 2,000,000 (missing reciprocal 0x431bde83)!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms tim2_init_1khz divides by 2,000,000 (reciprocal 0x431bde83 for halved clock assumption)"

echo "=== M02 GATE FAULT FIXTURE PROVEN CORRECT (STATIC/BINARY REGRESSION PASSED) ==="
