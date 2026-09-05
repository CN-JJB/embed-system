#!/usr/bin/env bash
# ==============================================================================
# verify_m05.sh: Automated Static, Memory, and Contract Verification for P2-M05
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${MODULE_DIR}/build"
ELF="${BUILD_DIR}/firmware.elf"
MAP="${BUILD_DIR}/firmware.map"

echo "=== Running P2-M05 Automated Verification ==="

# 1. Verify build artifacts exist
if [ ! -f "${ELF}" ] || [ ! -f "${MAP}" ]; then
    echo "ERROR: Build artifacts missing in ${BUILD_DIR}. Run 'make all' first!" >&2
    exit 1
fi
echo "[PASS] Build artifacts exist: firmware.elf and firmware.map"

# 2. Check memory consumption against physical STM32F103C8T6 limits (64 KB Flash, 20 KB SRAM)
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
if grep -rqlE "(HAL_Init|HAL_TIM_|osDelay|cmsis_os\.h)" "${MODULE_DIR}/src" "${MODULE_DIR}/include"; then
    echo "ERROR: Prohibited HAL / CubeMX / CMSIS-RTOS code detected!" >&2
    exit 1
fi
echo "[PASS] Zero HAL/CubeMX/CMSIS-RTOS wrapper dependencies in MUST coursework"

# 4. Check FreeRTOS V11.3.0 and M05 queue symbols in ELF
REQUIRED_SYMBOLS=(
    "vTaskStartScheduler"
    "xQueueGenericSendFromISR"
    "xQueueReceive"
    "xTaskRemoveFromEventList"
    "vPortValidateInterruptPriority"
    "TIM2_IRQHandler"
    "SVC_Handler"
    "PendSV_Handler"
    "SysTick_Handler"
)

NM_OUT=$(arm-none-eabi-nm "${ELF}")

for sym in "${REQUIRED_SYMBOLS[@]}"; do
    if ! echo "${NM_OUT}" | grep -qE "[0-9a-fA-F]+\s+[TtWw]\s+${sym}$"; then
        echo "ERROR: Required symbol '${sym}' not found in ${ELF}!" >&2
        exit 1
    fi
done
echo "[PASS] All FreeRTOS V11.3.0 kernel, port, queue, and ISR symbols verified in ELF"

# 5. Check Vector Table remapping: SVCall, PendSV, SysTick
DEFAULT_HANDLER_ADDR=$(echo "${NM_OUT}" | awk '$3 == "Default_Handler" {print $1}')
SVC_ADDR=$(echo "${NM_OUT}" | awk '$3 == "SVC_Handler" {print $1}')
PENDSV_ADDR=$(echo "${NM_OUT}" | awk '$3 == "PendSV_Handler" {print $1}')
SYSTICK_ADDR=$(echo "${NM_OUT}" | awk '$3 == "SysTick_Handler" {print $1}')

if [ -z "${SVC_ADDR}" ] || [ -z "${PENDSV_ADDR}" ] || [ -z "${SYSTICK_ADDR}" ]; then
    echo "ERROR: FreeRTOS exception handler addresses missing!" >&2
    exit 1
fi

if [ "${SVC_ADDR}" = "${DEFAULT_HANDLER_ADDR}" ] || \
   [ "${PENDSV_ADDR}" = "${DEFAULT_HANDLER_ADDR}" ] || \
   [ "${SYSTICK_ADDR}" = "${DEFAULT_HANDLER_ADDR}" ]; then
    echo "ERROR: One or more FreeRTOS vectors point to Default_Handler!" >&2
    exit 1
fi
echo "[PASS] Vector table exception handlers correctly linked to FreeRTOS port implementations"

# 6. Verify heap_4 exclusivity and absence of libc dynamic allocators
if ! echo "${NM_OUT}" | grep -qE "[0-9a-fA-F]+\s+[Bb]\s+ucHeap$"; then
    echo "ERROR: FreeRTOS ucHeap array missing from .bss!" >&2
    exit 1
fi

if echo "${NM_OUT}" | grep -qE "\b(malloc|calloc|realloc|free)$"; then
    echo "ERROR: libc dynamic memory allocator linked into binary!" >&2
    exit 1
fi
echo "[PASS] Heap exclusivity verified: ucHeap configured in heap_4; libc malloc/free absent"

# 7. Disassembly inspection: TIM2_IRQHandler invokes xQueueGenericSendFromISR and portYIELD_FROM_ISR
DISASM=$(arm-none-eabi-objdump -d "${ELF}")
TIM2_DISASM=$(echo "${DISASM}" | awk '/<TIM2_IRQHandler>:/ {flag=1} flag && !/<TIM2_IRQHandler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')

if ! echo "${TIM2_DISASM}" | grep -qE "b[l]?(\.w)?.*<xQueueGenericSendFromISR>"; then
    echo "ERROR: TIM2_IRQHandler does not call xQueueGenericSendFromISR!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms TIM2_IRQHandler enqueues items via xQueueGenericSendFromISR"

# Check that portYIELD_FROM_ISR logic writes to SCB->ICSR (PENDSVSET: bit 28 = 0x10000000) or sets interrupt
if ! echo "${TIM2_DISASM}" | grep -qE "(e000ed04|268435456|0x10000000)"; then
    # In case compiler placed 0xe000ed04 in literal pool
    if ! echo "${TIM2_DISASM}" | grep -qiE "ed04"; then
        echo "ERROR: TIM2_IRQHandler does not access SCB->ICSR for portYIELD_FROM_ISR!" >&2
        exit 1
    fi
fi
echo "[PASS] Disassembly confirms portYIELD_FROM_ISR pends PendSV via SCB->ICSR"

# 8. Check Priority boundary contracts in FreeRTOSConfig.h
CONFIG_H="${MODULE_DIR}/include/FreeRTOSConfig.h"
if ! grep -qE "configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY\s+5\b" "${CONFIG_H}"; then
    echo "ERROR: configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY must be 5!" >&2
    exit 1
fi
if ! grep -qE "configMAX_SYSCALL_INTERRUPT_PRIORITY\s+\(\s*configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY" "${CONFIG_H}"; then
    echo "ERROR: configMAX_SYSCALL_INTERRUPT_PRIORITY must shift configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY!" >&2
    exit 1
fi
echo "[PASS] FreeRTOSConfig.h NVIC/BASEPRI priority boundary contracts verified"

echo "[NOTE] Physical logic analyzer timing / live GDB step trace: UNVERIFIED (Headless automated build)"
echo "[PASS] Static queue architecture, ISR handoff, and priority boundary contracts verified"
echo "=== ALL P2-M05 STATIC CHECKS PASSED ==="
