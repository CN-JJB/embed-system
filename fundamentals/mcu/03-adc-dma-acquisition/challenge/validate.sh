#!/usr/bin/env bash
# ==============================================================================
# validate.sh: Automated Validation for P2-M03 Challenge Submissions
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
M03_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CMSIS_DIR="${M03_DIR}/../vendor/cmsis/include"
TEST_BUILD_DIR="${M03_DIR}/build/challenge_test"

echo "=== Validating P2-M03 Challenge Submission: ${SUBMISSION_DIR} ==="

# 1. Source File Existence
if [ ! -f "${SUBMISSION_DIR}/acquisition.c" ] || [ ! -f "${SUBMISSION_DIR}/acquisition.h" ]; then
    echo "ERROR: Missing acquisition.c or acquisition.h in '${SUBMISSION_DIR}'!" >&2
    exit 1
fi
echo "[PASS] Required source files found: acquisition.c, acquisition.h"

# 2. Strict HAL / CubeMX Exclusion Check
if grep -riE "stm32f1xx_hal|HAL_ADC|HAL_DMA|HAL_TIM" "${SUBMISSION_DIR}" >/dev/null 2>&1; then
    echo "ERROR: Forbidden HAL or CubeMX symbols detected in challenge submission!" >&2
    exit 1
fi
echo "[PASS] Zero HAL/CubeMX dependencies verified (direct-register only)"

rm -rf "${TEST_BUILD_DIR}"
mkdir -p "${TEST_BUILD_DIR}"

# 3. Deterministic Host-Side Logic & State Validation
HOST_BIN="${TEST_BUILD_DIR}/test_acq_host"
echo "Compiling host-side logic test harness..."
if ! gcc -O2 -Wall -Wextra -Wno-int-to-pointer-cast \
    -I"${SUBMISSION_DIR}" -I"${CMSIS_DIR}" \
    "${M03_DIR}/reviewer/test_harness_host.c" \
    -o "${HOST_BIN}" 2>"${TEST_BUILD_DIR}/host_build.log"; then
    echo "ERROR: Host-side unit test compilation failed!" >&2
    cat "${TEST_BUILD_DIR}/host_build.log" >&2
    exit 1
fi

echo "Running host-side MMIO and pipeline verification..."
if ! "${HOST_BIN}" >"${TEST_BUILD_DIR}/host_run.log" 2>&1; then
    echo "ERROR: Host-side logic assertion failed!" >&2
    cat "${TEST_BUILD_DIR}/host_run.log" >&2
    exit 1
fi
echo "[PASS] Host-side MMIO verified (clocks, TIM3 PSC/ARR/MMS, ADCPRE, SMP0, EXTSEL, DMA1 CPAR/CMAR/CNDTR/CCR, ISR)"

# 4. Reviewer-Controlled Cross-Compilation for ARM Target
TEST_ELF="${TEST_BUILD_DIR}/firmware_test.elf"
TEST_MAP="${TEST_BUILD_DIR}/firmware_test.map"

echo "Cross-compiling learner submission with reviewer test harness..."
if ! arm-none-eabi-gcc -mcpu=cortex-m3 -mthumb -mfloat-abi=soft \
    -O2 -g3 -Wall -Wextra -Werror \
    -ffunction-sections -fdata-sections \
    -DSTM32F103xB -I"${SUBMISSION_DIR}" -I"${M03_DIR}/include" -I"${CMSIS_DIR}" \
    -T"${M03_DIR}/linker/stm32f103c8tx_flash.ld" \
    -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections \
    -Wl,-Map="${TEST_MAP}",--cref --specs=nano.specs --specs=nosys.specs \
    "${SUBMISSION_DIR}/acquisition.c" \
    "${M03_DIR}/reviewer/challenge-reference/main.c" \
    "${M03_DIR}/src/system_stm32f1xx.c" \
    "${M03_DIR}/src/runtime_glue.c" \
    "${M03_DIR}/src/startup_stm32f103c8.s" \
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
for sym in "acquisition_pipeline_init" "DMA1_Channel1_IRQHandler" "g_acq_buffer" "g_acq_ht_events" "g_acq_tc_events"; do
    if ! echo "${NM_OUT}" | grep -qw "${sym}"; then
        echo "ERROR: Required symbol '${sym}' missing from symbol table!" >&2
        exit 1
    fi
done
echo "[PASS] Required interface symbols verified in ELF"

# Verify buffer size is 256 bytes
BUF_SIZE=$(arm-none-eabi-nm -S "${TEST_ELF}" | grep -w "g_acq_buffer" | awk '{print "0x"$2}')
if [ "$((BUF_SIZE))" -ne 256 ]; then
    echo "ERROR: g_acq_buffer size in ELF is not 256 bytes!" >&2
    exit 1
fi
echo "[PASS] Persistent static buffer size verified: 256 bytes (128 samples * 16-bit)"

# 6. Disassembly Inspection of Learner Implementation
DISASM=$(arm-none-eabi-objdump -d "${TEST_ELF}")
INIT_DISASM=$(echo "${DISASM}" | awk '/<acquisition_pipeline_init>:/ {flag=1} flag && !/<acquisition_pipeline_init>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')
ISR_DISASM=$(echo "${DISASM}" | awk '/<DMA1_Channel1_IRQHandler>:/ {flag=1} flag && !/<DMA1_Channel1_IRQHandler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')

# Check TIM3 ARR configuration (must load 99 / 0x63 for 10 kHz)
if ! echo "${INIT_DISASM}" | grep -qiE "mov(\.w)?\s+(r[0-9]+|lr|ip),\s*#99(\s|$)|\s*#0x63"; then
    echo "ERROR: acquisition_pipeline_init does not load ARR=99 for 10 kHz!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms ARR=99 configured for 10 kHz update triggers"

# Check TIM3 MMS configuration (offset 4 of TIM3)
if ! echo "${INIT_DISASM}" | grep -qiE "str.*\[.*#4\]"; then
    echo "ERROR: acquisition_pipeline_init does not configure TIM3->CR2 (offset 4)!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms TIM3->CR2 MMS configuration"

# Check ADC1 CR2 configuration (offset 8 of ADC1)
if ! echo "${INIT_DISASM}" | grep -qiE "str.*\[.*#8\]"; then
    echo "ERROR: acquisition_pipeline_init does not configure ADC1->CR2 (offset 8)!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms ADC1->CR2 configuration write"

# Check DMA1_Channel1 CCR configuration (offset 0)
if ! echo "${INIT_DISASM}" | grep -qiE "str.*\[.*#0\]"; then
    echo "ERROR: acquisition_pipeline_init does not configure DMA1_Channel1->CCR (offset 0)!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms DMA1_Channel1->CCR configuration write"

# Check DMA1_Channel1_IRQHandler flag clear in IFCR (offset 4 of DMA1)
if ! echo "${ISR_DISASM}" | grep -qiE "str.*\[.*#4\]"; then
    echo "ERROR: DMA1_Channel1_IRQHandler does not write to DMA1->IFCR (offset 4)!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms DMA1_Channel1_IRQHandler clears flags in DMA1->IFCR"

# 7. Physical Evidence Statement
echo "[NOTE] Physical ADC sampling waveform: UNVERIFIED (Headless automated build; requires target oscilloscope)"

echo "=== CHALLENGE VALIDATION PASSED FOR: ${SUBMISSION_DIR} ==="
