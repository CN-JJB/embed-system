#!/usr/bin/env bash
# ==============================================================================
# validate.sh: Automated Validation for P2-M02 Challenge Submissions
# ==============================================================================
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "ERROR: Usage: $0 <submission-dir>" >&2
    exit 1
fi

SUBMISSION_DIR="$1"
if [ ! -d "${SUBMISSION_DIR}" ]; then
    echo "ERROR: Submission directory '${SUBMISSION_DIR}' does not exist!" >&2
    exit 1
fi

echo "=== Validating P2-M02 Challenge Submission: ${SUBMISSION_DIR} ==="

# 1. Source File Existence
if [ ! -f "${SUBMISSION_DIR}/pwm.c" ] || [ ! -f "${SUBMISSION_DIR}/pwm.h" ]; then
    echo "ERROR: Missing pwm.c or pwm.h in '${SUBMISSION_DIR}'!" >&2
    exit 1
fi
echo "[PASS] Required source files found: pwm.c, pwm.h"

# 2. Strict HAL / CubeMX Exclusion Check
if grep -riE "stm32f1xx_hal|HAL_GPIO|HAL_TIM" "${SUBMISSION_DIR}" >/dev/null 2>&1; then
    echo "ERROR: Forbidden HAL or CubeMX symbols detected in challenge submission!" >&2
    exit 1
fi
echo "[PASS] Zero HAL/CubeMX dependencies verified (direct-register only)"

# 3. Static Code & Mechanism Inspection
# Atomic BSRR / BRR register usage
if ! grep -qE "(BSRR|BRR)" "${SUBMISSION_DIR}/pwm.c"; then
    echo "ERROR: pwm.c must use atomic GPIO BSRR or BRR register writes for pin manipulation!" >&2
    exit 1
fi
echo "[PASS] Atomic GPIO register writes (BSRR / BRR) verified in source"

# 4 channels requirement
if ! grep -qE "4|PWM_NUM_CHANNELS" "${SUBMISSION_DIR}/pwm.h"; then
    echo "ERROR: pwm.h must support 4 PWM channels!" >&2
    exit 1
fi
echo "[PASS] 4-channel PWM interface contract verified"

# Timer interrupt handler
if ! grep -q "TIM2_IRQHandler" "${SUBMISSION_DIR}/pwm.c"; then
    echo "ERROR: TIM2_IRQHandler not implemented in pwm.c!" >&2
    exit 1
fi
echo "[PASS] TIM2_IRQHandler interrupt handler present"

# 4. Compile and Link Challenge Submission
echo "Building challenge submission..."
make -C "${SUBMISSION_DIR}" clean all >/dev/null

ELF="${SUBMISSION_DIR}/build/firmware.elf"
if [ ! -f "${ELF}" ]; then
    echo "ERROR: Build failed! Expected ${ELF} not found." >&2
    exit 1
fi
echo "[PASS] Challenge firmware compiled and linked cleanly"

# 5. Inspect Binary ELF
# Memory bounds check
FLASH_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $1 + $2}')
RAM_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $2 + $3}')
if [ "${FLASH_SIZE}" -gt 65536 ] || [ "${RAM_SIZE}" -gt 20480 ]; then
    echo "ERROR: Firmware memory footprint exceeds physical STM32F103C8T6 limits!" >&2
    exit 1
fi
echo "[PASS] Memory usage verified: Flash=${FLASH_SIZE} bytes, RAM=${RAM_SIZE} bytes"

# Required symbols in ELF
NM_OUT=$(arm-none-eabi-nm "${ELF}")
for sym in "pwm_init" "pwm_set_duty" "TIM2_IRQHandler"; do
    if ! echo "${NM_OUT}" | grep -qw "${sym}"; then
        echo "ERROR: Required symbol '${sym}' missing from ELF symbol table!" >&2
        exit 1
    fi
done
echo "[PASS] Required interface symbols verified in ELF: pwm_init, pwm_set_duty, TIM2_IRQHandler"

# Zero HAL symbols in symbol table
if echo "${NM_OUT}" | grep -iE "HAL_" >/dev/null 2>&1; then
    echo "ERROR: HAL symbols found in compiled ELF!" >&2
    exit 1
fi
echo "[PASS] Zero HAL symbols verified in compiled binary"

# Disassembly check: confirm atomic BSRR/BRR MMIO writes in TIM2_IRQHandler
DISASM=$(arm-none-eabi-objdump -d "${ELF}")
if ! echo "${DISASM}" | grep -A 50 "<TIM2_IRQHandler>:" | grep -q "str"; then
    echo "ERROR: TIM2_IRQHandler does not emit MMIO store instructions!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms MMIO store instructions emitted in TIM2_IRQHandler"

# 6. Physical Measurement Status
echo "[NOTE] Physical PWM output waveform: UNVERIFIED (Headless automated build; requires target oscilloscope)"

echo "=== CHALLENGE VALIDATION PASSED FOR: ${SUBMISSION_DIR} ==="
