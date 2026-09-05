#!/usr/bin/env bash
# ==============================================================================
# validate.sh: Student Submission Validator for Module P2-M04 Challenge
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_SRC="${1:-${MODULE_DIR}/challenge/app_tasks.c}"

echo "=== Validating P2-M04 Challenge Implementation: ${TARGET_SRC} ==="

if [ ! -f "${TARGET_SRC}" ]; then
    echo "ERROR: Target file '${TARGET_SRC}' does not exist!" >&2
    exit 1
fi

CLEAN_SRC="$(mktemp)"
TEMP_BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "${CLEAN_SRC}" "${TEMP_BUILD_DIR}"' EXIT

# Strip comments for robust AST-like pattern matching
python3 -c "import sys, re; s = open(sys.argv[1]).read(); s = re.sub(r'/\*.*?\*/', '', s, flags=re.S); s = re.sub(r'//.*', '', s); open(sys.argv[2], 'w').write(s)" "${TARGET_SRC}" "${CLEAN_SRC}"

# 1. Static Rule Checks

# Check A: Must NOT link or call standard libc malloc
if grep -qE "\bmalloc\s*\(" "${CLEAN_SRC}"; then
    echo "FAIL: Prohibited call to standard libc malloc() detected!" >&2
    exit 1
fi

# Check B: Must use absolute periodic delay (vTaskDelayUntil)
if ! grep -qE "\bvTaskDelayUntil\s*\(" "${CLEAN_SRC}"; then
    echo "FAIL: Must use vTaskDelayUntil() to prevent cumulative timing drift!" >&2
    exit 1
fi

# Check C: Must track stack high-water mark
if ! grep -qE "\buxTaskGetStackHighWaterMark\s*\(" "${CLEAN_SRC}"; then
    echo "FAIL: Must query stack headroom using uxTaskGetStackHighWaterMark()!" >&2
    exit 1
fi

# Check D: Must use critical sections for thread-safe telemetry read/write
if ! grep -qE "\btaskENTER_CRITICAL\s*\(" "${CLEAN_SRC}" || ! grep -qE "\btaskEXIT_CRITICAL\s*\(" "${CLEAN_SRC}"; then
    echo "FAIL: Must protect shared telemetry struct with taskENTER_CRITICAL / taskEXIT_CRITICAL!" >&2
    exit 1
fi

# Check E: Must validate task creation return status (not ignore error codes)
if ! grep -qE "(pdPASS|status|errCOULD_NOT_ALLOCATE_REQUIRED_MEMORY)" "${CLEAN_SRC}"; then
    echo "FAIL: Return codes from xTaskCreate() must be validated for memory allocation failure!" >&2
    exit 1
fi

# Check F: Must size stacks to TASK_STACK_SIZE_WORDS (128)
if grep -qE "xTaskCreate\s*\([^,]+,[^,]+,\s*(16|32|64)\s*," "${CLEAN_SRC}"; then
    echo "FAIL: Task stack depth is undersized below 128 words!" >&2
    exit 1
fi

# Check G: Priority check: Telemetry must have priority 2, Worker priority 1
if grep -qE "xTaskCreate\s*\(\s*vTelemetryTask\s*,[^,]+,[^,]+,[^,]+,\s*1\s*," "${CLEAN_SRC}"; then
    echo "FAIL: Telemetry task must have higher priority (2) than Worker task (1)!" >&2
    exit 1
fi

# Check H: Period check: Telemetry must be 50 ms
if ! grep -qE "(TELEMETRY_PERIOD_MS|pdMS_TO_TICKS\s*\(\s*50\s*\))" "${CLEAN_SRC}"; then
    echo "FAIL: Telemetry task period must be TELEMETRY_PERIOD_MS (50 ms)!" >&2
    exit 1
fi

# Check I: Zero placeholder/TODO comments remaining in original source
if grep -qiE "TODO:" "${TARGET_SRC}"; then
    echo "FAIL: Unimplemented TODO items remain in submission!" >&2
    exit 1
fi

# 2. Firmware Compilation Check
CC="arm-none-eabi-gcc"
MCU_FLAGS="-mcpu=cortex-m3 -mthumb -mfloat-abi=soft"
CFLAGS="${MCU_FLAGS} -O2 -g3 -Wall -Wextra -Werror -ffunction-sections -fdata-sections -DSTM32F103xB -I${MODULE_DIR}/include -I${MODULE_DIR}/challenge -I${MODULE_DIR}/../vendor/freertos/include -I${MODULE_DIR}/../vendor/freertos/portable/GCC/ARM_CM3 -I${MODULE_DIR}/../../mcu/vendor/cmsis/include"
LDFLAGS="${MCU_FLAGS} -T${MODULE_DIR}/linker/stm32f103c8tx_flash.ld -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections --specs=nano.specs --specs=nosys.specs"

SRCS=(
    "${TARGET_SRC}"
    "${MODULE_DIR}/src/clock.c"
    "${MODULE_DIR}/src/gpio.c"
    "${MODULE_DIR}/src/system_stm32f1xx.c"
    "${MODULE_DIR}/src/runtime_glue.c"
    "${MODULE_DIR}/src/startup_stm32f103c8.s"
    "${MODULE_DIR}/../vendor/freertos/tasks.c"
    "${MODULE_DIR}/../vendor/freertos/list.c"
    "${MODULE_DIR}/../vendor/freertos/queue.c"
    "${MODULE_DIR}/../vendor/freertos/portable/GCC/ARM_CM3/port.c"
    "${MODULE_DIR}/../vendor/freertos/portable/MemMang/heap_4.c"
)

# Test harness main
cat << 'EOF' > "${TEMP_BUILD_DIR}/test_main.c"
#include "app_tasks.h"
#include "clock.h"
#include "gpio.h"

int main(void)
{
    clock_init(CLOCK_PROFILE_72MHZ_HSE);
    gpio_init();

    if (!app_tasks_init()) {
        for (;;) { __asm volatile ("bkpt #1"); }
    }

    vTaskStartScheduler();

    for (;;) { __asm volatile ("wfi"); }
}
EOF

${CC} ${CFLAGS} ${LDFLAGS} "${SRCS[@]}" "${TEMP_BUILD_DIR}/test_main.c" -o "${TEMP_BUILD_DIR}/firmware.elf"

# Check memory budget
FLASH_BYTES=$(arm-none-eabi-size -B "${TEMP_BUILD_DIR}/firmware.elf" | awk 'NR==2 {print $1 + $2}')
RAM_BYTES=$(arm-none-eabi-size -B "${TEMP_BUILD_DIR}/firmware.elf" | awk 'NR==2 {print $2 + $3}')

if [ "${FLASH_BYTES}" -gt 65536 ]; then
    echo "FAIL: Binary exceeded 64 KB Flash (${FLASH_BYTES} bytes)!" >&2
    exit 1
fi
if [ "${RAM_BYTES}" -gt 20480 ]; then
    echo "FAIL: Binary exceeded 20 KB SRAM (${RAM_BYTES} bytes)!" >&2
    exit 1
fi

echo "[PASS] Code compiles cleanly under -Wall -Wextra -Werror"
echo "[PASS] Memory footprint verified: Flash = ${FLASH_BYTES} B, RAM = ${RAM_BYTES} B"
echo "[PASS] Challenge submission passed all static and compilation contracts!"
exit 0
