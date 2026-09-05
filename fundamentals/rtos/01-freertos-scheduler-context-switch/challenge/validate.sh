#!/usr/bin/env bash
# ==============================================================================
# validate.sh: Student Submission Validator for Module P2-M04 Challenge
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGET_ARG="${1:-${SCRIPT_DIR}/starter}"

if [ -d "${TARGET_ARG}" ]; then
    SUBMISSION_DIR="$(cd "${TARGET_ARG}" && pwd)"
elif [ -f "${TARGET_ARG}" ]; then
    SUBMISSION_DIR="$(cd "$(dirname "${TARGET_ARG}")" && pwd)"
else
    echo "ERROR: Target path '${TARGET_ARG}' does not exist!" >&2
    exit 1
fi

APP_SRC="${SUBMISSION_DIR}/scheduler_app.c"
APP_HDR="${SUBMISSION_DIR}/scheduler_app.h"
APP_CFG="${SUBMISSION_DIR}/FreeRTOSConfig.h"

echo "=== Validating P2-M04 Challenge Implementation Bundle: ${SUBMISSION_DIR} ==="

if [ ! -f "${APP_SRC}" ]; then
    echo "ERROR: Missing required submission file 'scheduler_app.c' in '${SUBMISSION_DIR}'!" >&2
    exit 1
fi

if [ ! -f "${APP_HDR}" ]; then
    echo "ERROR: Missing required submission file 'scheduler_app.h' in '${SUBMISSION_DIR}'!" >&2
    exit 1
fi

if [ ! -f "${APP_CFG}" ]; then
    echo "ERROR: Missing learner-owned 'FreeRTOSConfig.h' in '${SUBMISSION_DIR}'!" >&2
    exit 1
fi

CLEAN_SRC="$(mktemp)"
CLEAN_CFG="$(mktemp)"
TEMP_BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "${CLEAN_SRC}" "${CLEAN_CFG}" "${TEMP_BUILD_DIR}"' EXIT

# Strip comments for AST/regex matching
python3 -c "
import sys, re
def strip_c(path, out_path):
    s = open(path).read()
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r'//.*', '', s)
    open(out_path, 'w').write(s)
strip_c(sys.argv[1], sys.argv[2])
strip_c(sys.argv[3], sys.argv[4])
" "${APP_SRC}" "${CLEAN_SRC}" "${APP_CFG}" "${CLEAN_CFG}"

# Check 0: Zero placeholder / TODO comments remaining in submission
if grep -qiE "\bTODO\b" "${APP_SRC}"; then
    echo "FAIL: Unimplemented TODO items remain in scheduler_app.c!" >&2
    exit 1
fi
if grep -qiE "\bTODO\b" "${APP_CFG}"; then
    echo "FAIL: Unimplemented TODO items remain in FreeRTOSConfig.h!" >&2
    exit 1
fi

# 1. Pinned FreeRTOS kernel source identity (V11.3.0)
FREERTOS_TASK_H="${MODULE_DIR}/../vendor/freertos/include/task.h"
FREERTOS_TASKS_C="${MODULE_DIR}/../vendor/freertos/tasks.c"
if [ ! -f "${FREERTOS_TASK_H}" ] || [ ! -f "${FREERTOS_TASKS_C}" ]; then
    echo "FAIL: Pinned FreeRTOS kernel sources missing!" >&2
    exit 1
fi
if ! grep -q 'tskKERNEL_VERSION_NUMBER\s*"V11.3.0"' "${FREERTOS_TASK_H}"; then
    echo "FAIL: FreeRTOS kernel version mismatch; must pin V11.3.0!" >&2
    exit 1
fi

# 2. Learner FreeRTOSConfig.h maps SVC/PendSV/SysTick handlers
python3 -c "
import sys, re
cfg = open(sys.argv[1]).read()
if not re.search(r'#define\s+vPortSVCHandler\s+SVC_Handler\b', cfg):
    print('FAIL: FreeRTOSConfig.h must map vPortSVCHandler to SVC_Handler!', file=sys.stderr)
    sys.exit(1)
if not re.search(r'#define\s+xPortPendSVHandler\s+PendSV_Handler\b', cfg):
    print('FAIL: FreeRTOSConfig.h must map xPortPendSVHandler to PendSV_Handler!', file=sys.stderr)
    sys.exit(1)
if not re.search(r'#define\s+xPortSysTickHandler\s+SysTick_Handler\b', cfg):
    print('FAIL: FreeRTOSConfig.h must map xPortSysTickHandler to SysTick_Handler!', file=sys.stderr)
    sys.exit(1)
" "${CLEAN_CFG}"

# 3. Dynamic SystemCoreClock feeds configCPU_CLOCK_HZ and tick rate is 1 kHz
python3 -c "
import sys, re
cfg = open(sys.argv[1]).read()
if not re.search(r'#define\s+configCPU_CLOCK_HZ\s+\(?SystemCoreClock\)?\b', cfg):
    print('FAIL: configCPU_CLOCK_HZ in FreeRTOSConfig.h must dynamically evaluate SystemCoreClock!', file=sys.stderr)
    sys.exit(1)
if not re.search(r'#define\s+configTICK_RATE_HZ\s+.*?\b1000\b', cfg):
    print('FAIL: configTICK_RATE_HZ must be configured to 1000 (1 kHz)!', file=sys.stderr)
    sys.exit(1)
" "${CLEAN_CFG}"

# SysTick reload arithmetic verification:
# 72 MHz: 72000000 / 1000 - 1 = 71999
# 64 MHz fallback: 64000000 / 1000 - 1 = 63999
python3 -c "
c72 = 72000000 // 1000 - 1
c64 = 64000000 // 1000 - 1
assert c72 == 71999, f'72MHz tick math error: {c72}'
assert c64 == 63999, f'64MHz tick math error: {c64}'
"

# 4. configKERNEL_INTERRUPT_PRIORITY is lowest implemented priority (0xF0 / 255)
python3 -c "
import sys, re
cfg = open(sys.argv[1]).read()
if not re.search(r'#define\s+configKERNEL_INTERRUPT_PRIORITY[\s\\\n]+.*(configLIBRARY_LOWEST_INTERRUPT_PRIORITY|255|0x[fF]0)', cfg):
    print('FAIL: configKERNEL_INTERRUPT_PRIORITY must be lowest interrupt priority (0xF0 / 255)!', file=sys.stderr)
    sys.exit(1)
" "${CLEAN_CFG}"

# 5. Heap configuration contract in FreeRTOSConfig.h
python3 -c "
import sys, re
cfg = open(sys.argv[1]).read()
if not re.search(r'#define\s+configSUPPORT_DYNAMIC_ALLOCATION\s+1\b', cfg):
    print('FAIL: configSUPPORT_DYNAMIC_ALLOCATION must be enabled (1) for heap_4!', file=sys.stderr)
    sys.exit(1)

m_heap = re.search(r'#define\s+configTOTAL_HEAP_SIZE\s+(.+)', cfg)
if not m_heap:
    print('FAIL: configTOTAL_HEAP_SIZE must be explicitly configured in FreeRTOSConfig.h!', file=sys.stderr)
    sys.exit(1)

val_str = m_heap.group(1).split('//')[0].split('/*')[0].strip()
val_str = re.sub(r'\b(size_t|uint32_t|uint16_t|int|UL|U|L)\b', '', val_str)
val_str = re.sub(r'[()]', ' ', val_str)
try:
    val = eval(val_str.strip())
except Exception:
    val = 0

if val < 2048:
    print(f'FAIL: configTOTAL_HEAP_SIZE ({val} B) is insufficient (< 2048 B) for dual tasks + idle task!', file=sys.stderr)
    sys.exit(1)
if val > 16384:
    print(f'FAIL: configTOTAL_HEAP_SIZE ({val} B) exceeds safe 20 KB SRAM budget (> 16 KB)!', file=sys.stderr)
    sys.exit(1)
" "${CLEAN_CFG}"

# 6. Prohibited libc malloc in application source
if grep -qE "\bmalloc\s*\(" "${CLEAN_SRC}"; then
    echo "FAIL: Prohibited call to standard libc malloc() detected in scheduler_app.c!" >&2
    exit 1
fi

# 7. Stack size, return code validation, and priority relationship
python3 -c "
import sys, re
src = open(sys.argv[1]).read()
matches = re.findall(r'xTaskCreate\s*\(\s*[^,]+,\s*[^,]+,\s*([^,]+),', src)
for m in matches:
    arg = m.strip()
    if arg.isdigit() and int(arg) < 128:
        print(f'FAIL: Task stack size ({arg}) is undersized below 128 words!', file=sys.stderr)
        sys.exit(1)
" "${CLEAN_SRC}"

if ! grep -qE "(pdPASS|xResult|status)" "${CLEAN_SRC}"; then
    echo "FAIL: Return codes from xTaskCreate() must be validated!" >&2
    exit 1
fi

python3 -c "
import sys, re
src = open(sys.argv[1]).read()
m_a = re.search(r'xTaskCreate\s*\(\s*prvTaskA[^,]*,\s*\"[^\"]*\",\s*[^,]*,\s*[^,]*,\s*([^,]+),', src)
m_b = re.search(r'xTaskCreate\s*\(\s*prvTaskB[^,]*,\s*\"[^\"]*\",\s*[^,]*,\s*[^,]*,\s*([^,]+),', src)
if m_a and m_b:
    p_a = m_a.group(1).strip()
    p_b = m_b.group(1).strip()
    if ('TASK_B_PRIORITY' in p_a and 'TASK_A_PRIORITY' in p_b) or ('1' in p_a and '2' in p_b):
        print('FAIL: Inverted task priorities: Task A must have higher priority than Task B!')
        sys.exit(1)
" "${CLEAN_SRC}"

# 8. Task A must block via periodic vTaskDelay(pdMS_TO_TICKS(5))
if ! grep -qE "\bvTaskDelay\s*\(\s*(pdMS_TO_TICKS\s*\(\s*5\s*\)|5)\s*\)" "${CLEAN_SRC}"; then
    echo "FAIL: Task A must transition to Blocked via vTaskDelay(pdMS_TO_TICKS(5))!" >&2
    exit 1
fi

# 9. vTaskStartScheduler must be called
if ! grep -qE "\bvTaskStartScheduler\s*\(\s*\)" "${CLEAN_SRC}"; then
    echo "FAIL: vTaskStartScheduler() must be called to start scheduling!" >&2
    exit 1
fi

# 10. Build verification test harness
cat << 'EOF' > "${TEMP_BUILD_DIR}/test_main.c"
#include "scheduler_app.h"
#include "clock.h"
#include "stm32f103xb.h"

int main(void)
{
    scheduler_app_init_and_start(CLOCK_PROFILE_72MHZ_HSE);
    while (1) {
        __NOP();
    }
    return 0;
}
EOF

# Set up isolated include directory with peripheral headers but WITHOUT module FreeRTOSConfig.h
# This guarantees FreeRTOS sources strictly include the learner's submitted FreeRTOSConfig.h
mkdir -p "${TEMP_BUILD_DIR}/inc"
cp "${MODULE_DIR}/include/clock.h" "${TEMP_BUILD_DIR}/inc/"
cp "${MODULE_DIR}/include/gpio.h" "${TEMP_BUILD_DIR}/inc/"
cp "${MODULE_DIR}/include/system_stm32f1xx.h" "${TEMP_BUILD_DIR}/inc/"

CC="arm-none-eabi-gcc"
MCU_FLAGS="-mcpu=cortex-m3 -mthumb -mfloat-abi=soft"
CFLAGS="${MCU_FLAGS} -O2 -g3 -Wall -Wextra -Werror -ffunction-sections -fdata-sections -DSTM32F103xB -I${SUBMISSION_DIR} -I${TEMP_BUILD_DIR}/inc -I${MODULE_DIR}/../vendor/freertos/include -I${MODULE_DIR}/../vendor/freertos/portable/GCC/ARM_CM3 -I${MODULE_DIR}/../../mcu/vendor/cmsis/include"
LDFLAGS="${MCU_FLAGS} -T${MODULE_DIR}/linker/stm32f103c8tx_flash.ld -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections --specs=nano.specs --specs=nosys.specs"

SRCS=(
    "${APP_SRC}"
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

ELF="${TEMP_BUILD_DIR}/firmware.elf"
if ! ${CC} ${CFLAGS} ${LDFLAGS} "${SRCS[@]}" "${TEMP_BUILD_DIR}/test_main.c" -o "${ELF}" 2>"${TEMP_BUILD_DIR}/build_err.log"; then
    echo "FAIL: Firmware compilation failed!" >&2
    cat "${TEMP_BUILD_DIR}/build_err.log" >&2
    exit 1
fi

# 11. Check memory bounds: Flash <= 64 KB, RAM <= 20 KB
FLASH_BYTES=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $1 + $2}')
RAM_BYTES=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $2 + $3}')
if [ "${FLASH_BYTES}" -gt 65536 ]; then
    echo "FAIL: Image exceeded 64 KB Flash (${FLASH_BYTES} B)!" >&2
    exit 1
fi
if [ "${RAM_BYTES}" -gt 20480 ]; then
    echo "FAIL: Image exceeded 20 KB RAM (${RAM_BYTES} B)!" >&2
    exit 1
fi

# 12. Vector table entries 11, 14, 15 and handler symbol resolution
NM_OUT=$(arm-none-eabi-nm "${ELF}")
DEF_ADDR=$(echo "${NM_OUT}" | grep -w "Default_Handler" | awk '{print $1}')
SVC_ADDR=$(echo "${NM_OUT}" | grep -w "SVC_Handler" | awk '{print $1}')
PEND_ADDR=$(echo "${NM_OUT}" | grep -w "PendSV_Handler" | awk '{print $1}')
TICK_ADDR=$(echo "${NM_OUT}" | grep -w "SysTick_Handler" | awk '{print $1}')

if [ -z "${SVC_ADDR}" ] || [ -z "${PEND_ADDR}" ] || [ -z "${TICK_ADDR}" ]; then
    echo "FAIL: FreeRTOS exception handler symbols missing from ELF!" >&2
    exit 1
fi

if [ "${SVC_ADDR}" = "${DEF_ADDR}" ] || [ "${PEND_ADDR}" = "${DEF_ADDR}" ] || [ "${TICK_ADDR}" = "${DEF_ADDR}" ]; then
    echo "FAIL: Exception handlers trapped at Default_Handler!" >&2
    exit 1
fi

# Verify vector table entries 11, 14, 15 directly from binary image
BIN_FILE="${TEMP_BUILD_DIR}/firmware.bin"
arm-none-eabi-objcopy -O binary "${ELF}" "${BIN_FILE}"
python3 -c "
import sys, struct
with open('${BIN_FILE}', 'rb') as f:
    bin_bytes = f.read(256)

def_addr = int('${DEF_ADDR}', 16) | 1
svc_addr = int('${SVC_ADDR}', 16) | 1
pend_addr = int('${PEND_ADDR}', 16) | 1
tick_addr = int('${TICK_ADDR}', 16) | 1

v_svc = struct.unpack('<I', bin_bytes[44:48])[0]
v_pend = struct.unpack('<I', bin_bytes[56:60])[0]
v_tick = struct.unpack('<I', bin_bytes[60:64])[0]

if v_svc == def_addr or v_pend == def_addr or v_tick == def_addr:
    print('FAIL: Vector table entry points to Default_Handler!')
    sys.exit(1)

if v_svc != svc_addr:
    print(f'FAIL: Vector 11 (0x{v_svc:x}) does not match SVC_Handler (0x{svc_addr:x})!')
    sys.exit(1)
if v_pend != pend_addr:
    print(f'FAIL: Vector 14 (0x{v_pend:x}) does not match PendSV_Handler (0x{pend_addr:x})!')
    sys.exit(1)
if v_tick != tick_addr:
    print(f'FAIL: Vector 15 (0x{v_tick:x}) does not match SysTick_Handler (0x{tick_addr:x})!')
    sys.exit(1)
"

# 13. Verify heap_4 exclusivity and learner config's heap size contract
if ! echo "${NM_OUT}" | grep -qw "ucHeap"; then
    echo "FAIL: heap_4 allocator (ucHeap) missing from binary!" >&2
    exit 1
fi

HEAP_SIZE=$(arm-none-eabi-nm -S "${ELF}" | grep -w "ucHeap" | awk '{print "0x"$2}')
EXPECTED_HEAP_SIZE=$(python3 -c "
import sys, re
cfg = open(sys.argv[1]).read()
m = re.search(r'#define\s+configTOTAL_HEAP_SIZE\s+(.+)', cfg)
val_str = m.group(1).split('//')[0].split('/*')[0].strip()
val_str = re.sub(r'\b(size_t|uint32_t|uint16_t|int|UL|U|L)\b', '', val_str)
val_str = re.sub(r'[()]', ' ', val_str)
print(eval(val_str.strip()))
" "${CLEAN_CFG}")

if [ "$((HEAP_SIZE))" -ne "${EXPECTED_HEAP_SIZE}" ]; then
    echo "FAIL: ucHeap size ($((HEAP_SIZE)) B) does not match learner FreeRTOSConfig.h (${EXPECTED_HEAP_SIZE} B)!" >&2
    exit 1
fi

# Check absence of libc dynamic allocators
if echo "${NM_OUT}" | grep -qE "\b(malloc|_malloc_r|calloc|_calloc_r|realloc|_realloc_r)\b"; then
    echo "FAIL: Prohibited libc dynamic memory allocators linked into binary!" >&2
    exit 1
fi

# 14. Disassembly inspection of PendSV and SVC
DISASM=$(arm-none-eabi-objdump -d "${ELF}")
PENDSV_ASM=$(echo "${DISASM}" | awk '/<PendSV_Handler>:/ {flag=1} flag && !/<PendSV_Handler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')
if ! echo "${PENDSV_ASM}" | grep -qiE "mrs.*r0,.*psp"; then
    echo "FAIL: PendSV does not read PSP (mrs r0, psp)!" >&2
    exit 1
fi
if ! echo "${PENDSV_ASM}" | grep -qiE "msr.*psp,.*r0"; then
    echo "FAIL: PendSV does not write PSP (msr psp, r0)!" >&2
    exit 1
fi
if ! echo "${PENDSV_ASM}" | grep -qiE "vTaskSwitchContext"; then
    echo "FAIL: PendSV does not call vTaskSwitchContext!" >&2
    exit 1
fi

SVC_ASM=$(echo "${DISASM}" | awk '/<SVC_Handler>:/ {flag=1} flag && !/<SVC_Handler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')
if ! echo "${SVC_ASM}" | grep -qiE "msr.*psp"; then
    echo "FAIL: SVC_Handler does not initialize PSP!" >&2
    exit 1
fi

echo "[PASS] All 14 P2-M04 scheduler and context integration verification points satisfied!"
exit 0
