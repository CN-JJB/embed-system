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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M02_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CMSIS_DIR="${M02_DIR}/../vendor/cmsis/include"
TEST_BUILD_DIR="${M02_DIR}/build/challenge_test"

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

rm -rf "${TEST_BUILD_DIR}"
mkdir -p "${TEST_BUILD_DIR}"

# 3. Deterministic Host-Side Logic & State Validation
# Compiles and executes test_harness_host with native GCC to test duty cycle bounds,
# channel validation, 100-step wrap, and non-ODR write verification.
HOST_BIN="${TEST_BUILD_DIR}/test_pwm_host"
echo "Compiling host-side logic test harness..."
if ! gcc -O2 -Wall -Wextra -Wno-int-to-pointer-cast \
    -I"${SUBMISSION_DIR}" -I"${CMSIS_DIR}" \
    "${M02_DIR}/reviewer/test_harness_host.c" \
    -o "${HOST_BIN}" 2>"${TEST_BUILD_DIR}/host_build.log"; then
    echo "ERROR: Host-side unit test compilation failed!" >&2
    cat "${TEST_BUILD_DIR}/host_build.log" >&2
    exit 1
fi

echo "Running host-side logic and boundary verification..."
if ! "${HOST_BIN}" >"${TEST_BUILD_DIR}/host_run.log" 2>&1; then
    echo "ERROR: Host-side logic assertion failed!" >&2
    cat "${TEST_BUILD_DIR}/host_run.log" >&2
    exit 1
fi
echo "[PASS] Host-side logic verified (channels 0..3, duty 0..100%, 100-step wrap, no ODR write)"

# 4. Reviewer-Controlled Cross-Compilation for ARM Target
TEST_ELF="${TEST_BUILD_DIR}/firmware_test.elf"
TEST_MAP="${TEST_BUILD_DIR}/firmware_test.map"

echo "Cross-compiling learner submission with reviewer test harness..."
if ! arm-none-eabi-gcc -mcpu=cortex-m3 -mthumb -mfloat-abi=soft \
    -O2 -g3 -Wall -Wextra -Werror \
    -ffunction-sections -fdata-sections \
    -DSTM32F103xB -I"${SUBMISSION_DIR}" -I"${M02_DIR}/include" -I"${CMSIS_DIR}" \
    -T"${M02_DIR}/linker/stm32f103c8tx_flash.ld" \
    -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections \
    -Wl,-Map="${TEST_MAP}",--cref --specs=nano.specs --specs=nosys.specs \
    "${SUBMISSION_DIR}/pwm.c" \
    "${M02_DIR}/reviewer/challenge-reference/main.c" \
    "${M02_DIR}/src/clock.c" \
    "${M02_DIR}/src/system_stm32f1xx.c" \
    "${M02_DIR}/src/runtime_glue.c" \
    "${M02_DIR}/src/startup_stm32f103c8.s" \
    -o "${TEST_ELF}" 2>"${TEST_BUILD_DIR}/arm_build.log"; then
    echo "ERROR: Target ARM compilation or link failed!" >&2
    cat "${TEST_BUILD_DIR}/arm_build.log" >&2
    exit 1
fi
echo "[PASS] Target ARM firmware compiled and linked cleanly with -nostartfiles and -Werror"

# 5. Inspect Memory Footprint & Interface Symbols
FLASH_SIZE=$(arm-none-eabi-size -B "${TEST_ELF}" | awk 'NR==2 {print $1 + $2}')
RAM_SIZE=$(arm-none-eabi-size -B "${TEST_ELF}" | awk 'NR==2 {print $2 + $3}')
if [ "${FLASH_SIZE}" -gt 65536 ] || [ "${RAM_SIZE}" -gt 20480 ]; then
    echo "ERROR: Memory footprint exceeds physical device bounds!" >&2
    exit 1
fi
echo "[PASS] Footprint verified (Flash: ${FLASH_SIZE}/65536, RAM: ${RAM_SIZE}/20480)"

NM_OUT=$(arm-none-eabi-nm "${TEST_ELF}")
for sym in "pwm_init" "pwm_set_duty" "pwm_step" "TIM2_IRQHandler"; do
    if ! echo "${NM_OUT}" | grep -qw "${sym}"; then
        echo "ERROR: Required symbol '${sym}' missing from symbol table!" >&2
        exit 1
    fi
done
echo "[PASS] Required interface symbols verified: pwm_init, pwm_set_duty, pwm_step, TIM2_IRQHandler"

if echo "${NM_OUT}" | grep -iE "HAL_" >/dev/null 2>&1; then
    echo "ERROR: Forbidden HAL symbols detected in ELF symbol table!" >&2
    exit 1
fi
echo "[PASS] Zero HAL symbols verified in binary"

# 6. Disassembly Inspection of Actual Learner Register Configuration
DISASM=$(arm-none-eabi-objdump -d "${TEST_ELF}")

INIT_DISASM=$(echo "${DISASM}" | awk '/<pwm_init>:/ {flag=1} flag && !/<pwm_init>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')
ISR_DISASM=$(echo "${DISASM}" | awk '/<TIM2_IRQHandler>:/ {flag=1} flag && !/<TIM2_IRQHandler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')
STEP_DISASM=$(echo "${DISASM}" | awk '/<pwm_step>:/ {flag=1} flag && !/<pwm_step>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')

# Check TIM2 ARR configuration in pwm_init (must store 99 / 0x63 for 10 kHz tick under 72 MHz)
if ! echo "${INIT_DISASM}" | grep -qiE "str.*\[.*#44\]"; then
    echo "ERROR: pwm_init does not write to TIM2->ARR (offset 44)!" >&2
    exit 1
fi
if ! echo "${INIT_DISASM}" | grep -qiE "movs?\s+r[0-9],\s*#99(\s|$)|\s*#0x63"; then
    echo "ERROR: pwm_init does not load ARR=99 (required for 10 kHz tick under 72 MHz)!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms TIM2 ARR configured for 10 kHz tick (ARR=99)"

# Check TIM2 DIER UIE enable in pwm_init (store to offset 12)
if ! echo "${INIT_DISASM}" | grep -qiE "str.*\[.*#12\]"; then
    echo "ERROR: pwm_init does not configure TIM2->DIER for update interrupt!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms TIM2->DIER configured for update interrupt"

# Check UIF acknowledgement in TIM2_IRQHandler (store to offset 16 of TIM2)
if ! echo "${ISR_DISASM}" | grep -qiE "str.*\[.*#16\]"; then
    echo "ERROR: TIM2_IRQHandler does not acknowledge/clear UIF in TIM2->SR (offset 16)!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms TIM2_IRQHandler clears UIF interrupt flag"

# Check atomic BSRR / BRR register writes in pwm_step / ISR
# GPIOA base is 0x40010800; BSRR is offset 16 (#16), BRR is offset 20 (#20)
if ! echo "${STEP_DISASM}" | grep -qiE "str.*\[.*#16\]" && ! echo "${STEP_DISASM}" | grep -qiE "str.*\[.*#20\]"; then
    echo "ERROR: pwm_step does not execute store to GPIOA BSRR/BRR registers!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms atomic stores to GPIOA BSRR / BRR"

# Check strict absence of ODR store in pwm_step (offset 12 / #12 of GPIOA)
if echo "${STEP_DISASM}" | grep -qiE "str.*\[.*#12\]"; then
    echo "ERROR: Non-atomic store to GPIOA->ODR (offset 12) detected in pwm_step!" >&2
    exit 1
fi
echo "[PASS] Confirmed zero ODR stores in PWM step (no RMW race hazards)"

# Check 4-channel iteration / comparison
if ! echo "${STEP_DISASM}" | grep -qiE "cmp.*#4"; then
    echo "ERROR: pwm_step does not iterate over strictly 4 PWM channels!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms 4-channel iteration"

# Check 100-step wrap comparison
if ! echo "${STEP_DISASM}" | grep -qiE "cmp.*#100|cmp.*#0x64"; then
    echo "ERROR: pwm_step does not verify 100-step wrap boundary!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms 100-step wrap comparison"

# 7. Physical Evidence Statement
echo "[NOTE] Physical PWM output waveform: UNVERIFIED (Headless automated build; requires target oscilloscope)"

echo "=== CHALLENGE VALIDATION PASSED FOR: ${SUBMISSION_DIR} ==="
