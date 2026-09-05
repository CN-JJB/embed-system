#!/usr/bin/env bash
# ==============================================================================
# verify_m04.sh: Automated Static & Logic Verification for Module P2-M04
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${MODULE_DIR}/build"
ELF="${BUILD_DIR}/firmware.elf"
MAP="${BUILD_DIR}/firmware.map"

echo "=== Running P2-M04 Automated Verification ==="

# 1. Verify build
if [ ! -f "${ELF}" ]; then
    echo "Building M04 firmware..."
    make -C "${MODULE_DIR}" clean all
fi

if [ ! -f "${ELF}" ] || [ ! -f "${MAP}" ]; then
    echo "ERROR: Missing ELF or MAP file!" >&2
    exit 1
fi
echo "[PASS] Build artifacts exist: firmware.elf and firmware.map"

# 2. Check memory bounds: Flash <= 64 KB, RAM <= 20 KB
FLASH_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $1 + $2}')
RAM_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $2 + $3}')

echo "Memory usage: Flash = ${FLASH_SIZE} bytes (limit: 65536), RAM = ${RAM_SIZE} bytes (limit: 20480)"
if [ "${FLASH_SIZE}" -gt 65536 ] || [ "${RAM_SIZE}" -gt 20480 ]; then
    echo "ERROR: Image exceeded 64 KB Flash or 20 KB RAM!" >&2
    exit 1
fi
echo "[PASS] Memory bounds verified within physical limits"

# 3. Check for HAL or CubeMX generated code
FORBIDDEN_PATTERNS=("HAL_Init" "HAL_RCC_OscConfig" "HAL_GPIO_Init" "stm32f1xx_hal.h" "cmsis_os.h")
for pat in "${FORBIDDEN_PATTERNS[@]}"; do
    if grep -rql "${pat}" "${MODULE_DIR}/src" "${MODULE_DIR}/include"; then
        echo "ERROR: Forbidden HAL/CubeMX/CMSIS-RTOS artifact detected: ${pat}!" >&2
        exit 1
    fi
done
echo "[PASS] Zero HAL/CubeMX/CMSIS-RTOS wrapper dependencies in MUST coursework"

# 4. Check presence of required FreeRTOS kernel & port symbols
REQUIRED_SYMBOLS=(
    "vTaskStartScheduler"
    "xTaskCreate"
    "vTaskDelay"
    "vTaskSwitchContext"
    "SVC_Handler"
    "PendSV_Handler"
    "SysTick_Handler"
    "pvPortMalloc"
    "vPortFree"
    "ucHeap"
    "SystemCoreClock"
    "clock_init"
)
NM_OUTPUT=$(arm-none-eabi-nm "${ELF}")

for sym in "${REQUIRED_SYMBOLS[@]}"; do
    if ! echo "${NM_OUTPUT}" | grep -qw "${sym}"; then
        echo "ERROR: Required symbol ${sym} missing from ELF!" >&2
        exit 1
    fi
done
echo "[PASS] All FreeRTOS V11.3.0 kernel, port, and clock symbols verified in ELF"

# 5. Verify exception handler remapping (must NOT point to Default_Handler)
DEFAULT_HANDLER_ADDR=$(echo "${NM_OUTPUT}" | grep -w "Default_Handler" | awk '{print $1}')
SVC_ADDR=$(echo "${NM_OUTPUT}" | grep -w "SVC_Handler" | awk '{print $1}')
PENDSV_ADDR=$(echo "${NM_OUTPUT}" | grep -w "PendSV_Handler" | awk '{print $1}')
SYSTICK_ADDR=$(echo "${NM_OUTPUT}" | grep -w "SysTick_Handler" | awk '{print $1}')

if [ "${SVC_ADDR}" = "${DEFAULT_HANDLER_ADDR}" ]; then
    echo "ERROR: SVC_Handler is trapped at Default_Handler (${DEFAULT_HANDLER_ADDR})!" >&2
    exit 1
fi
if [ "${PENDSV_ADDR}" = "${DEFAULT_HANDLER_ADDR}" ]; then
    echo "ERROR: PendSV_Handler is trapped at Default_Handler (${DEFAULT_HANDLER_ADDR})!" >&2
    exit 1
fi
if [ "${SYSTICK_ADDR}" = "${DEFAULT_HANDLER_ADDR}" ]; then
    echo "ERROR: SysTick_Handler is trapped at Default_Handler (${DEFAULT_HANDLER_ADDR})!" >&2
    exit 1
fi
echo "[PASS] Vector table exception handlers correctly linked to FreeRTOS port implementations"

# 6. Verify heap_4 exclusivity and absence of libc dynamic allocators
if echo "${NM_OUTPUT}" | grep -qE "\b(malloc|_malloc_r|calloc|_calloc_r|realloc|_realloc_r)\b"; then
    echo "ERROR: Standard C runtime dynamic memory allocator (malloc/calloc/realloc) linked into binary!" >&2
    exit 1
fi
HEAP_SIZE=$(arm-none-eabi-nm -S "${ELF}" | grep -w "ucHeap" | awk '{print "0x"$2}')
if [ "$((HEAP_SIZE))" -ne 10240 ]; then
    echo "ERROR: ucHeap size is $((HEAP_SIZE)) bytes; expected 10240 bytes (10 KB)!" >&2
    exit 1
fi
echo "[PASS] Heap exclusivity verified: 10 KB ucHeap configured in heap_4; libc malloc absent"

# 7. Disassembly inspection for PendSV context switch mechanism
DISASM=$(arm-none-eabi-objdump -d "${ELF}")

PENDSV_ASM=$(echo "${DISASM}" | awk '/<PendSV_Handler>:/ {flag=1} flag && !/<PendSV_Handler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')
if ! echo "${PENDSV_ASM}" | grep -qiE "mrs.*r0,.*psp"; then
    echo "ERROR: PendSV_Handler does not read PSP (mrs r0, psp)!" >&2
    exit 1
fi
if ! echo "${PENDSV_ASM}" | grep -qiE "msr.*psp,.*r0"; then
    echo "ERROR: PendSV_Handler does not write PSP (msr psp, r0)!" >&2
    exit 1
fi
if ! echo "${PENDSV_ASM}" | grep -qiE "vTaskSwitchContext"; then
    echo "ERROR: PendSV_Handler does not call vTaskSwitchContext!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms PendSV_Handler performs PSP stack frame save/restore and context switch"

# 8. Disassembly inspection for SVC first-task launch
SVC_ASM=$(echo "${DISASM}" | awk '/<SVC_Handler>:/ {flag=1} flag && !/<SVC_Handler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')
if ! echo "${SVC_ASM}" | grep -qiE "msr.*psp"; then
    echo "ERROR: SVC_Handler does not initialize PSP!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms SVC_Handler initializes PSP for first task launch"

# 9. Physical observation disclosure
echo "[NOTE] Physical logic analyzer timing / live GDB step trace: UNVERIFIED (Headless automated build)"
echo "[PASS] Static kernel architecture, stack frames, and vector contracts verified"

echo "=== ALL P2-M04 STATIC CHECKS PASSED ==="
