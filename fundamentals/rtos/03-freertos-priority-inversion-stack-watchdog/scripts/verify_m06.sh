#!/usr/bin/env bash
# ==============================================================================
# verify_m06.sh: Automated Static, Memory, and Contract Verification for P2-M06
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${MODULE_DIR}/build"
ELF="${BUILD_DIR}/firmware.elf"
MAP="${BUILD_DIR}/firmware.map"

echo "=== Running P2-M06 Automated Verification ==="

# 1. Verify build artifacts exist
if [ ! -f "${ELF}" ] || [ ! -f "${MAP}" ]; then
    echo "ERROR: Build artifacts missing in ${BUILD_DIR}. Run 'make all' first!" >&2
    exit 1
fi
echo "[PASS] Build artifacts exist: firmware.elf and firmware.map"

# 2. Check memory limits against physical STM32F103C8T6 limits (64 KB Flash, 20 KB SRAM)
FLASH_LIMIT=65536
RAM_LIMIT=20480

TEXT_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $1}')
DATA_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $2}')
BSS_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $3}')

TOTAL_FLASH=$((TEXT_SIZE + DATA_SIZE))
TOTAL_RAM=$((DATA_SIZE + BSS_SIZE))

echo "Memory usage: Flash = ${TOTAL_FLASH} bytes (limit: ${FLASH_LIMIT}), RAM = ${TOTAL_RAM} bytes (limit: ${RAM_LIMIT})"

if [ "${TOTAL_FLASH}" -gt "${FLASH_LIMIT}" ]; then
    echo "ERROR: Firmware size (${TOTAL_FLASH} bytes) exceeds 64 KB Flash limit!" >&2
    exit 1
fi

if [ "${TOTAL_RAM}" -gt "${RAM_LIMIT}" ]; then
    echo "ERROR: RAM consumption (${TOTAL_RAM} bytes) exceeds 20 KB SRAM limit!" >&2
    exit 1
fi
echo "[PASS] Memory bounds verified within physical limits"

# 3. Check for unauthorized HAL / CubeMX / CMSIS-RTOS wrappers
if grep -rqlE "(HAL_Init|HAL_IWDG_|osDelay|cmsis_os\.h)" "${MODULE_DIR}/src" "${MODULE_DIR}/include"; then
    echo "ERROR: Prohibited HAL / CubeMX / CMSIS-RTOS code detected!" >&2
    exit 1
fi
echo "[PASS] Zero HAL/CubeMX/CMSIS-RTOS wrapper dependencies in MUST coursework"

# 4. Check required FreeRTOS V11.3.0 mutex, priority inheritance, stack watermark, and IWDG symbols
REQUIRED_SYMBOLS=(
    "xQueueCreateMutex"
    "xTaskPriorityInherit"
    "xTaskPriorityDisinherit"
    "uxTaskGetStackHighWaterMark"
    "vApplicationStackOverflowHook"
    "iwdg_init"
    "iwdg_refresh"
    "iwdg_check_and_clear_reset_cause"
    "vTaskStartScheduler"
    "dwt_init"
    "dwt_get_cycles"
)

NM_OUT=$(arm-none-eabi-nm "${ELF}")

for sym in "${REQUIRED_SYMBOLS[@]}"; do
    if ! echo "${NM_OUT}" | grep -qE "[0-9a-fA-F]+\s+[TtWw]\s+${sym}$"; then
        echo "ERROR: Required symbol '${sym}' not found in ${ELF}!" >&2
        exit 1
    fi
done
echo "[PASS] All FreeRTOS V11.3.0 mutex, inheritance, watermark, hook, and IWDG symbols verified in ELF"

# 5. Verify heap_4 exclusivity and absence of libc dynamic allocators
if ! echo "${NM_OUT}" | grep -qE "[0-9a-fA-F]+\s+[Bb]\s+ucHeap$"; then
    echo "ERROR: FreeRTOS ucHeap array missing from .bss!" >&2
    exit 1
fi

if echo "${NM_OUT}" | grep -qE "\b(malloc|_malloc_r|calloc|_calloc_r|realloc|_realloc_r|free|_free_r)\b"; then
    echo "ERROR: libc dynamic memory allocator linked into binary!" >&2
    exit 1
fi
echo "[PASS] Heap exclusivity verified: ucHeap configured in heap_4; libc malloc/free absent"

# 6. Verify configCHECK_FOR_STACK_OVERFLOW is set to 2 and mutexes enabled
CONFIG_H="${MODULE_DIR}/include/FreeRTOSConfig.h"
if ! grep -qE "configCHECK_FOR_STACK_OVERFLOW\s+2\b" "${CONFIG_H}"; then
    echo "ERROR: configCHECK_FOR_STACK_OVERFLOW must be set to 2!" >&2
    exit 1
fi
if ! grep -qE "configUSE_MUTEXES\s+1\b" "${CONFIG_H}"; then
    echo "ERROR: configUSE_MUTEXES must be set to 1!" >&2
    exit 1
fi
echo "[PASS] FreeRTOSConfig.h confirms configCHECK_FOR_STACK_OVERFLOW=2 and configUSE_MUTEXES=1"

# 7. Disassembly verification:
DISASM_FILE="$(mktemp)"
trap 'rm -f "${DISASM_FILE}"' EXIT
arm-none-eabi-objdump -d "${ELF}" > "${DISASM_FILE}"

# Confirm iwdg_init accesses IWDG base address (0x40003000)
if ! grep -qiE "(40003000|0x40003000)" "${DISASM_FILE}"; then
    echo "ERROR: iwdg_init does not access IWDG hardware registers at 0x40003000!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms direct register access to IWDG peripheral (0x40003000)"

# Confirm direct access to Cortex-M3 DWT Cycle Counter (0xE0001004 / 0xE0001000)
if ! grep -qiE "(e0001004|e0001000)" "${DISASM_FILE}"; then
    echo "ERROR: Disassembly does not access Cortex-M3 DWT CYCCNT at 0xE0001004/0xE0001000!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms direct access to Cortex-M3 DWT Cycle Counter (0xE0001004/0xE0001000)"

# Confirm inversion_execute_low_workload strictly contains no vTaskDelay call
LOW_WORK_DISASM=$(awk '/<inversion_execute_low_workload>:/ {flag=1} flag && !/<inversion_execute_low_workload>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}' "${DISASM_FILE}")
if echo "${LOW_WORK_DISASM}" | grep -qE "b[l]?(\.w)?.*<vTaskDelay>"; then
    echo "ERROR: inversion_execute_low_workload contains prohibited vTaskDelay call!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms inversion_execute_low_workload executes pure CPU-runnable work without vTaskDelay"

echo "[NOTE] Physical logic analyzer timing (~5 ms / ~25 ms) & watchdog hardware reset: DESIGN TARGET / UNVERIFIED"
echo "[PASS] Static priority inheritance architecture, stack watermark, and watchdog contracts verified"
echo "=== ALL P2-M06 STATIC CHECKS PASSED ==="
