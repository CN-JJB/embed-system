#!/usr/bin/env bash
# ==============================================================================
# validate.sh: Automated Validation for P2-M01 Challenge Submissions
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
M01_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CMSIS_DIR="${M01_DIR}/../vendor/cmsis/include"
TEST_BUILD_DIR="${M01_DIR}/build/challenge_test"

echo "=== Validating P2-M01 Challenge Submission: ${SUBMISSION_DIR} ==="

# 1. Inspect Linker Script
LDSCRIPT=$(find "${SUBMISSION_DIR}" -maxdepth 1 -name "*.ld" | head -n 1)
if [ -z "${LDSCRIPT}" ] || [ ! -f "${LDSCRIPT}" ]; then
    echo "ERROR: No linker script (*.ld) found in '${SUBMISSION_DIR}'!" >&2
    exit 1
fi
echo "[PASS] Found linker script: $(basename "${LDSCRIPT}")"

# Verify 64 KB Flash and 20 KB RAM memory sizing
if ! grep -qiE "FLASH.*(64K|0x10000)" "${LDSCRIPT}"; then
    echo "ERROR: Linker script must declare FLASH region with 64K capacity!" >&2
    exit 1
fi
if ! grep -qiE "RAM.*(20K|0x5000)" "${LDSCRIPT}"; then
    echo "ERROR: Linker script must declare RAM region with 20K capacity!" >&2
    exit 1
fi
echo "[PASS] Linker script declares 64 KB Flash and 20 KB RAM memory bounds"

# Verify overflow assertions guard
if ! grep -qi "ASSERT" "${LDSCRIPT}"; then
    echo "ERROR: Linker script must include ASSERT statements to guard against overflow!" >&2
    exit 1
fi
echo "[PASS] Linker overflow assertions (ASSERT) verified"

# 2. Inspect Startup Assembly
STARTUP_SRC=$(find "${SUBMISSION_DIR}" -maxdepth 1 -name "*.s" | head -n 1)
if [ -z "${STARTUP_SRC}" ] || [ ! -f "${STARTUP_SRC}" ]; then
    echo "ERROR: No startup assembly file (*.s) found in '${SUBMISSION_DIR}'!" >&2
    exit 1
fi
echo "[PASS] Found startup assembly: $(basename "${STARTUP_SRC}")"

# Verify Reset_Handler sequence requirements
if ! grep -q "SystemInit" "${STARTUP_SRC}"; then
    echo "ERROR: Startup code must call SystemInit!" >&2
    exit 1
fi
if ! grep -q "_sdata" "${STARTUP_SRC}" || ! grep -q "_sidata" "${STARTUP_SRC}"; then
    echo "ERROR: Startup code must implement .data copy loop from Flash to RAM!" >&2
    exit 1
fi
if ! grep -q "_sbss" "${STARTUP_SRC}" || ! grep -q "_ebss" "${STARTUP_SRC}"; then
    echo "ERROR: Startup code must implement .bss zeroing loop in RAM!" >&2
    exit 1
fi
if ! grep -q "__libc_init_array" "${STARTUP_SRC}"; then
    echo "ERROR: Startup code must call __libc_init_array!" >&2
    exit 1
fi
if ! grep -q "main" "${STARTUP_SRC}"; then
    echo "ERROR: Startup code must branch to main!" >&2
    exit 1
fi
echo "[PASS] Startup assembly contains complete reset sequence (SystemInit, data copy, bss zero, init_array, main)"

# 3. Build submission against test harness using strict flags (-nostartfiles, -Wall, -Wextra, -Werror)
rm -rf "${TEST_BUILD_DIR}"
mkdir -p "${TEST_BUILD_DIR}"

TEST_ELF="${TEST_BUILD_DIR}/submission_test.elf"
TEST_MAP="${TEST_BUILD_DIR}/submission_test.map"

echo "Compiling and linking submission with test harness..."
arm-none-eabi-gcc -mcpu=cortex-m3 -mthumb -mfloat-abi=soft \
    -O2 -g3 -Wall -Wextra -Werror \
    -ffunction-sections -fdata-sections \
    -DSTM32F103xB -I"${M01_DIR}/include" -I"${CMSIS_DIR}" \
    -T"${LDSCRIPT}" -nostartfiles -Wl,-e,Reset_Handler \
    -Wl,--gc-sections -Wl,-Map="${TEST_MAP}",--cref \
    --specs=nano.specs --specs=nosys.specs \
    "${STARTUP_SRC}" \
    "${M01_DIR}/src/main.c" \
    "${M01_DIR}/src/system_stm32f1xx.c" \
    "${M01_DIR}/src/runtime_glue.c" \
    -o "${TEST_ELF}"

echo "[PASS] Submission compiled and linked cleanly with -nostartfiles and -Werror"

# 4. Binary and Architectural Inspection
# Check memory footprint
FLASH_SIZE=$(arm-none-eabi-size -B "${TEST_ELF}" | awk 'NR==2 {print $1 + $2}')
RAM_SIZE=$(arm-none-eabi-size -B "${TEST_ELF}" | awk 'NR==2 {print $2 + $3}')
if [ "${FLASH_SIZE}" -gt 65536 ] || [ "${RAM_SIZE}" -gt 20480 ]; then
    echo "ERROR: Memory footprint exceeds physical device bounds!" >&2
    exit 1
fi
echo "[PASS] Footprint fits within physical limits (Flash: ${FLASH_SIZE}/65536, RAM: ${RAM_SIZE}/20480)"

# Check vector table MSP (Vector 0)
VEC0_RAW=$(arm-none-eabi-readelf -x .isr_vector "${TEST_ELF}" | awk '/0x08000000/ {print $2}')
VEC0_ADDR="0x${VEC0_RAW:6:2}${VEC0_RAW:4:2}${VEC0_RAW:2:2}${VEC0_RAW:0:2}"
if [ "${VEC0_ADDR}" != "0x20005000" ]; then
    echo "ERROR: Vector 0 (initial MSP) is ${VEC0_ADDR}, expected 0x20005000!" >&2
    exit 1
fi
echo "[PASS] Vector 0 correctly sets initial MSP to 0x20005000"

# Check vector table Reset vector (Vector 1)
RESET_SYM_ADDR=$(arm-none-eabi-nm -n "${TEST_ELF}" | grep " Reset_Handler" | head -n 1 | awk '{print $1}')
EXPECTED_RESET_VEC=$((0x${RESET_SYM_ADDR} | 1))

VEC1_RAW=$(arm-none-eabi-readelf -x .isr_vector "${TEST_ELF}" | awk '/0x08000000/ {print $3}')
VEC1_ADDR="0x${VEC1_RAW:6:2}${VEC1_RAW:4:2}${VEC1_RAW:2:2}${VEC1_RAW:0:2}"
VEC1_INT=$((VEC1_ADDR))

if [ "${VEC1_INT}" -ne "${EXPECTED_RESET_VEC}" ]; then
    echo "ERROR: Vector 1 (0x$(printf '%x' ${VEC1_INT})) does not match Thumb Reset_Handler (0x$(printf '%x' ${EXPECTED_RESET_VEC}))!" >&2
    exit 1
fi
echo "[PASS] Vector 1 directly verified as Thumb Reset_Handler: 0x$(printf '%x' ${VEC1_INT})"

# Check ELF entry point
ENTRY_POINT=$(arm-none-eabi-readelf -h "${TEST_ELF}" | grep "Entry point address" | awk '{print $4}')
ACTUAL_ENTRY=$((ENTRY_POINT))
if [ "${ACTUAL_ENTRY}" -ne "${EXPECTED_RESET_VEC}" ]; then
    echo "ERROR: ELF entry point does not match Thumb Reset_Handler!" >&2
    exit 1
fi
echo "[PASS] ELF header entry point correctly points to Thumb Reset_Handler"

# Check required sections
REQUIRED_SECTIONS=(".isr_vector" ".text" ".rodata" ".init_array" ".data" ".bss")
SECTION_LIST=$(arm-none-eabi-objdump -h "${TEST_ELF}" | awk '{print $2}')
for sec in "${REQUIRED_SECTIONS[@]}"; do
    if ! echo "${SECTION_LIST}" | grep -qw "${sec}"; then
        echo "ERROR: Required section ${sec} missing from ELF!" >&2
        exit 1
    fi
done
echo "[PASS] All required ELF sections verified: ${REQUIRED_SECTIONS[*]}"

# Check forbidden CRT symbols
FORBIDDEN_SYMBOLS=("_start" "malloc" "free")
NM_OUTPUT=$(arm-none-eabi-nm "${TEST_ELF}")
for sym in "${FORBIDDEN_SYMBOLS[@]}"; do
    if echo "${NM_OUTPUT}" | grep -qw "${sym}"; then
        echo "ERROR: Forbidden CRT symbol ${sym} present in bare-metal binary!" >&2
        exit 1
    fi
done
echo "[PASS] Zero unintended CRT symbols present"

echo "=== CHALLENGE VALIDATION PASSED FOR: ${SUBMISSION_DIR} ==="
