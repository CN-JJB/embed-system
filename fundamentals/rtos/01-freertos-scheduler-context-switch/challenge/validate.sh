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

# 2. Pinned ARM_CM3 port priority contract (portMIN_INTERRUPT_PRIORITY = 255UL written to SHPR3)
PORT_C="${MODULE_DIR}/../vendor/freertos/portable/GCC/ARM_CM3/port.c"
if ! grep -qE "portMIN_INTERRUPT_PRIORITY\s*\(\s*255UL\s*\)" "${PORT_C}"; then
    echo "FAIL: Pinned ARM_CM3 port must define portMIN_INTERRUPT_PRIORITY as 255UL!" >&2
    exit 1
fi
if ! grep -qE "portNVIC_SHPR3_REG\s*\|\=\s*portNVIC_PENDSV_PRI" "${PORT_C}"; then
    echo "FAIL: Pinned ARM_CM3 port must program PendSV priority into SHPR3!" >&2
    exit 1
fi
if ! grep -qE "portNVIC_SHPR3_REG\s*\|\=\s*portNVIC_SYSTICK_PRI" "${PORT_C}"; then
    echo "FAIL: Pinned ARM_CM3 port must program SysTick priority into SHPR3!" >&2
    exit 1
fi

# 3. Learner FreeRTOSConfig.h maps SVC/PendSV/SysTick handlers
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

# 4. Dynamic SystemCoreClock feeds configCPU_CLOCK_HZ, preemption enabled, and tick rate is 1 kHz
python3 -c "
import sys, re
cfg = open(sys.argv[1]).read()
if not re.search(r'#define\s+configCPU_CLOCK_HZ\s+\(?SystemCoreClock\)?\b', cfg):
    print('FAIL: configCPU_CLOCK_HZ in FreeRTOSConfig.h must dynamically evaluate SystemCoreClock!', file=sys.stderr)
    sys.exit(1)
if not re.search(r'#define\s+configUSE_PREEMPTION\s+1\b', cfg):
    print('FAIL: configUSE_PREEMPTION in FreeRTOSConfig.h must be enabled (1)!', file=sys.stderr)
    sys.exit(1)
m_tick = re.search(r'#define\s+configTICK_RATE_HZ\s+(.+)', cfg)
if not m_tick:
    print('FAIL: configTICK_RATE_HZ must be configured in FreeRTOSConfig.h!', file=sys.stderr)
    sys.exit(1)
t_str = m_tick.group(1).split('//')[0].split('/*')[0].strip()
t_str = re.sub(r'\b(TickType_t|uint32_t|uint16_t|int|UL|U|L)\b', '', t_str)
t_str = re.sub(r'[()]', ' ', t_str).strip()
try:
    tick_val = eval(t_str)
except Exception:
    tick_val = 0
if tick_val != 1000:
    print(f'FAIL: configTICK_RATE_HZ ({tick_val}) must be strictly configured to 1000 (1 kHz)!', file=sys.stderr)
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

# Set up isolated include directory with peripheral headers but WITHOUT module FreeRTOSConfig.h
mkdir -p "${TEMP_BUILD_DIR}/inc"
cp "${MODULE_DIR}/include/clock.h" "${TEMP_BUILD_DIR}/inc/"
cp "${MODULE_DIR}/include/gpio.h" "${TEMP_BUILD_DIR}/inc/"
cp "${MODULE_DIR}/include/system_stm32f1xx.h" "${TEMP_BUILD_DIR}/inc/"

CC="arm-none-eabi-gcc"
MCU_FLAGS="-mcpu=cortex-m3 -mthumb -mfloat-abi=soft"
CFLAGS="${MCU_FLAGS} -O2 -g3 -Wall -Wextra -Werror -ffunction-sections -fdata-sections -DSTM32F103xB -I${SUBMISSION_DIR} -I${TEMP_BUILD_DIR}/inc -I${MODULE_DIR}/../vendor/freertos/include -I${MODULE_DIR}/../vendor/freertos/portable/GCC/ARM_CM3 -I${MODULE_DIR}/../../mcu/vendor/cmsis/include"
LDFLAGS="${MCU_FLAGS} -T${MODULE_DIR}/linker/stm32f103c8tx_flash.ld -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections --specs=nano.specs --specs=nosys.specs"

# 7. Compile-time assertions for learner header constants:
# Truly evaluates TASK_STACK_SIZE_WORDS >= 128U and TASK_A_PRIORITY > TASK_B_PRIORITY
cat << 'EOF' > "${TEMP_BUILD_DIR}/check_constants.c"
#include "scheduler_app.h"

_Static_assert(TASK_STACK_SIZE_WORDS >= 128U, "TASK_STACK_SIZE_WORDS must be >= 128 words");
_Static_assert(TASK_A_PRIORITY > TASK_B_PRIORITY, "TASK_A_PRIORITY must be strictly greater than TASK_B_PRIORITY");

int dummy_check(void) { return 0; }
EOF

if ! ${CC} ${CFLAGS} -c "${TEMP_BUILD_DIR}/check_constants.c" -o "${TEMP_BUILD_DIR}/check_constants.o" 2>"${TEMP_BUILD_DIR}/assert_err.log"; then
    echo "FAIL: Header contract assertion failed in scheduler_app.h!" >&2
    cat "${TEMP_BUILD_DIR}/assert_err.log" >&2
    exit 1
fi

# 8. Structural & Semantic analysis of scheduler_app.c:
# - prvTaskA body contains vTaskDelay(pdMS_TO_TICKS(5))
# - scheduler_app_init_and_start creates prvTaskA and prvTaskB
# - Both xTaskCreate return codes checked against pdPASS
# - vTaskStartScheduler called inside scheduler_app_init_and_start after task creation
python3 -c "
import sys, re
src = open(sys.argv[1]).read()

def extract_fn_body(name, text):
    m = re.search(r'\b' + name + r'\s*\([^)]*\)\s*\{', text)
    if not m:
        return None
    start = m.end()
    depth = 1
    for i in range(start, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return text[start:i]
    return None

# 8.1 prvTaskA body validation
task_a_body = extract_fn_body('prvTaskA', src)
if task_a_body is None:
    print('FAIL: prvTaskA() function definition not found in scheduler_app.c!', file=sys.stderr)
    sys.exit(1)
if not re.search(r'\bvTaskDelay\s*\(\s*(pdMS_TO_TICKS\s*\(\s*5\s*\)|5)\s*\)', task_a_body):
    print('FAIL: prvTaskA body must call vTaskDelay(pdMS_TO_TICKS(5)) to transition to Blocked state!', file=sys.stderr)
    sys.exit(1)

# 8.2 scheduler_app_init_and_start body validation
fn_body = extract_fn_body('scheduler_app_init_and_start', src)
if fn_body is None:
    print('FAIL: scheduler_app_init_and_start() function definition not found!', file=sys.stderr)
    sys.exit(1)

# 8.3 Required xTaskCreate for prvTaskA inside scheduler_app_init_and_start
m_a = re.search(r'xTaskCreate\s*\(\s*prvTaskA\s*,\s*\"[^\"]*\"\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)', fn_body)
if not m_a:
    print('FAIL: scheduler_app_init_and_start() must explicitly call xTaskCreate() for prvTaskA!', file=sys.stderr)
    sys.exit(1)

# 8.4 Required xTaskCreate for prvTaskB inside scheduler_app_init_and_start
m_b = re.search(r'xTaskCreate\s*\(\s*prvTaskB\s*,\s*\"[^\"]*\"\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\)', fn_body)
if not m_b:
    print('FAIL: scheduler_app_init_and_start() must explicitly call xTaskCreate() for prvTaskB!', file=sys.stderr)
    sys.exit(1)

# 8.5 Stack argument check (numeric literals if not macro)
for name, m in [('Task A', m_a), ('Task B', m_b)]:
    stack_arg = m.group(1).strip()
    if stack_arg.isdigit() and int(stack_arg) < 128:
        print(f'FAIL: {name} stack argument ({stack_arg}) is undersized below 128 words!', file=sys.stderr)
        sys.exit(1)

# 8.6 Priority argument relationship in xTaskCreate call
p_a = m_a.group(3).strip()
p_b = m_b.group(3).strip()
if p_a == p_b:
    print('FAIL: Task A and Task B must have distinct priorities!', file=sys.stderr)
    sys.exit(1)
if ('TASK_B_PRIORITY' in p_a and 'TASK_A_PRIORITY' in p_b) or (p_a.isdigit() and p_b.isdigit() and int(p_a) < int(p_b)):
    print('FAIL: Inverted task priorities: Task A must have higher priority than Task B!', file=sys.stderr)
    sys.exit(1)

# 8.7 vTaskStartScheduler inside scheduler_app_init_and_start
pos_sched = fn_body.find('vTaskStartScheduler')
if pos_sched == -1:
    print('FAIL: vTaskStartScheduler() must be called inside scheduler_app_init_and_start()!', file=sys.stderr)
    sys.exit(1)

pos_a = fn_body.find('prvTaskA')
pos_b = fn_body.find('prvTaskB')
if pos_a > pos_sched or pos_b > pos_sched:
    print('FAIL: Both tasks must be created before vTaskStartScheduler() is invoked!', file=sys.stderr)
    sys.exit(1)

# 8.8 Return code validation for BOTH task creations
pass_checks = len(re.findall(r'\bpdPASS\b', fn_body))
if pass_checks < 2:
    print(f'FAIL: Return codes from both xTaskCreate() calls must be validated against pdPASS (found {pass_checks} checks; expected >= 2)!', file=sys.stderr)
    sys.exit(1)
" "${CLEAN_SRC}"

# 9. Build verification test harness
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

# 10. Check memory bounds: Flash <= 64 KB, RAM <= 20 KB
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

# 11. Vector table entries 11, 14, 15 and handler symbol resolution
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

# 12. Verify heap_4 exclusivity and learner config's heap size contract
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

# 13. Strict absence of standard libc dynamic memory allocators (malloc, calloc, realloc, free)
if echo "${NM_OUT}" | grep -qE "\b(malloc|_malloc_r|calloc|_calloc_r|realloc|_realloc_r|free|_free_r)\b"; then
    echo "FAIL: Prohibited libc dynamic memory allocators (malloc/free) linked into binary!" >&2
    exit 1
fi

# 14. Disassembly inspection of PendSV, SVC, and SHPR3 write in scheduler startup
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

# Upstream pinned ARM_CM3 port priority contract:
# portMIN_INTERRUPT_PRIORITY is hardcoded to 255UL in port.c.
# PendSV and SysTick priorities are directly programmed via SHPR3 in xPortStartScheduler.
PORT_C="${MODULE_DIR}/../vendor/freertos/portable/GCC/ARM_CM3/port.c"
if ! grep -qE "#define\s+portMIN_INTERRUPT_PRIORITY\s+\(\s*255UL\s*\)" "${PORT_C}"; then
    echo "FAIL: Upstream pinned port.c must define portMIN_INTERRUPT_PRIORITY as 255UL!" >&2
    exit 1
fi
if ! grep -qE "portNVIC_SHPR3_REG\s*\|=\s*portNVIC_PENDSV_PRI" "${PORT_C}"; then
    echo "FAIL: Upstream pinned port.c must configure PendSV priority via SHPR3!" >&2
    exit 1
fi
if ! grep -qE "portNVIC_SHPR3_REG\s*\|=\s*portNVIC_SYSTICK_PRI" "${PORT_C}"; then
    echo "FAIL: Upstream pinned port.c must configure SysTick priority via SHPR3!" >&2
    exit 1
fi

SCHED_ASM=$(echo "${DISASM}" | awk '/<xPortStartScheduler>:/ {flag=1} flag && !/<xPortStartScheduler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')
if ! echo "${SCHED_ASM}" | grep -qiE "(16711680|0xff0000)"; then
    echo "FAIL: Scheduler start path does not configure PendSV minimum priority (255UL << 16)!" >&2
    exit 1
fi
if ! echo "${SCHED_ASM}" | grep -qiE "(4278190080|0xff000000)"; then
    echo "FAIL: Scheduler start path does not configure SysTick minimum priority (255UL << 24)!" >&2
    exit 1
fi

echo "[PASS] All 14 P2-M04 scheduler and context integration verification points satisfied!"
exit 0
