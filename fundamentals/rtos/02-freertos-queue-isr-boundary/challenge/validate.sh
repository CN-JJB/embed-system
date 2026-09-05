#!/usr/bin/env bash
# ==============================================================================
# validate.sh: Student Submission Validator for Module P2-M05 Challenge
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

APP_SRC="${SUBMISSION_DIR}/queue_app.c"
APP_HDR="${SUBMISSION_DIR}/queue_app.h"
APP_CFG="${SUBMISSION_DIR}/FreeRTOSConfig.h"

echo "=== Validating P2-M05 Challenge Implementation Bundle: ${SUBMISSION_DIR} ==="

if [ ! -f "${APP_SRC}" ]; then
    echo "ERROR: Missing required submission file 'queue_app.c' in '${SUBMISSION_DIR}'!" >&2
    exit 1
fi

if [ ! -f "${APP_HDR}" ]; then
    echo "ERROR: Missing required submission file 'queue_app.h' in '${SUBMISSION_DIR}'!" >&2
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
    echo "FAIL: Unimplemented TODO items remain in queue_app.c!" >&2
    exit 1
fi
if grep -qiE "\bTODO\b" "${APP_CFG}"; then
    echo "FAIL: Unimplemented TODO items remain in FreeRTOSConfig.h!" >&2
    exit 1
fi

# 1. Pinned FreeRTOS kernel source identity (V11.3.0)
FREERTOS_TASK_H="${MODULE_DIR}/../vendor/freertos/include/task.h"
if ! grep -q 'tskKERNEL_VERSION_NUMBER\s*"V11.3.0"' "${FREERTOS_TASK_H}"; then
    echo "FAIL: FreeRTOS kernel version mismatch; must pin V11.3.0!" >&2
    exit 1
fi

# 2. Learner FreeRTOSConfig.h priority boundary contracts
python3 -c "
import sys, re
cfg = open(sys.argv[1]).read()

m_bits = re.search(r'#define\s+configPRIO_BITS\s+(\d+)', cfg)
if not m_bits or int(m_bits.group(1)) != 4:
    sys.stderr.write('FAIL: configPRIO_BITS must be defined as 4 for STM32F103!\n')
    sys.exit(1)

m_prio = re.search(r'#define\s+configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY\s+(\d+)', cfg)
if not m_prio or int(m_prio.group(1)) != 5:
    sys.stderr.write('FAIL: configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY must be 5!\n')
    sys.exit(1)

if not re.search(r'#define\s+configMAX_SYSCALL_INTERRUPT_PRIORITY\s+.*configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY', cfg) and \
   not re.search(r'#define\s+configMAX_SYSCALL_INTERRUPT_PRIORITY\s+(0x50|80)\b', cfg):
    sys.stderr.write('FAIL: configMAX_SYSCALL_INTERRUPT_PRIORITY must shift library priority to 0x50!\n')
    sys.exit(1)

if not re.search(r'#define\s+vPortSVCHandler\s+SVC_Handler\b', cfg):
    sys.stderr.write('FAIL: FreeRTOSConfig.h must map vPortSVCHandler to SVC_Handler!\n')
    sys.exit(1)
if not re.search(r'#define\s+xPortPendSVHandler\s+PendSV_Handler\b', cfg):
    sys.stderr.write('FAIL: FreeRTOSConfig.h must map xPortPendSVHandler to PendSV_Handler!\n')
    sys.exit(1)
if not re.search(r'#define\s+xPortSysTickHandler\s+SysTick_Handler\b', cfg):
    sys.stderr.write('FAIL: FreeRTOSConfig.h must map xPortSysTickHandler to SysTick_Handler!\n')
    sys.exit(1)
" "${CLEAN_CFG}"

# 3. Source contracts in queue_app.c
python3 -c "
import sys, re
src = open(sys.argv[1]).read()

# Priority Grouping
if not re.search(r'NVIC_SetPriorityGrouping\s*\(\s*0\s*\)', src):
    sys.stderr.write('FAIL: Priority grouping 0 contract missing: must call NVIC_SetPriorityGrouping(0)!\n')
    sys.exit(1)

# NVIC_SetPriority for TIM2 >= 5
prio_match = re.search(r'NVIC_SetPriority\s*\(\s*TIM2_IRQn\s*,\s*(\d+)\s*\)', src)
if not prio_match:
    sys.stderr.write('FAIL: TIM2 NVIC priority configuration missing!\n')
    sys.exit(1)
prio_val = int(prio_match.group(1))
if prio_val < 5 or prio_val > 15:
    sys.stderr.write(f'FAIL: Invalid TIM2 priority {prio_val}! Must be within [5..15] to respect syscall boundary!\n')
    sys.exit(1)

# Queue creation size: 10 items, 4 bytes
if not re.search(r'xQueueCreate\s*\(\s*(QUEUE_APP_LENGTH|10)\s*,\s*(QUEUE_APP_ITEM_SIZE|sizeof\s*\(\s*uint32_t\s*\)|4)\s*\)', src):
    sys.stderr.write('FAIL: xQueueCreate must specify length 10 and item size sizeof(uint32_t)!\n')
    sys.exit(1)

# Consumer task priority: must be > 1 (e.g. 3)
task_match = re.search(r'xTaskCreate\s*\([^,]+,[^,]+,[^,]+,[^,]+,\s*(\d+)\s*,', src)
if not task_match or int(task_match.group(1)) <= 1:
    sys.stderr.write('FAIL: Consumer task priority must be set higher than 1 (recommended: 3)!\n')
    sys.exit(1)

# Consumer blocking receive
if not re.search(r'xQueueReceive\s*\([^,]+,[^,]+,\s*portMAX_DELAY\s*\)', src):
    sys.stderr.write('FAIL: Consumer task must block on queue using portMAX_DELAY!\n')
    sys.exit(1)

# Prohibit libc malloc in application source
if re.search(r'\b(malloc|calloc|realloc|free)\s*\(', src):
    sys.stderr.write('FAIL: Prohibited call to standard libc dynamic allocator (malloc/calloc/realloc/free) detected in queue_app.c!\n')
    sys.exit(1)

# TIM2_IRQHandler contracts
isr_idx = src.find('TIM2_IRQHandler')
if isr_idx == -1:
    sys.stderr.write('FAIL: TIM2_IRQHandler definition missing in queue_app.c!\n')
    sys.exit(1)
isr_body = src[isr_idx:]

# Flag acknowledgment
if not re.search(r'TIM2\s*->\s*SR\s*=', isr_body):
    sys.stderr.write('FAIL: TIM2_IRQHandler must acknowledge interrupt by clearing TIM2->SR flag!\n')
    sys.exit(1)

# Prohibit task API in ISR
if re.search(r'\bxQueueSend\s*\(', isr_body):
    sys.stderr.write('FAIL: Prohibited task API xQueueSend() called from ISR! Must use xQueueSendFromISR()!\n')
    sys.exit(1)

# Must call xQueueSendFromISR
if not re.search(r'xQueueSendFromISR\s*\([^,]+,[^,]+,\s*&([a-zA-Z0-9_]+)\s*\)', isr_body):
    sys.stderr.write('FAIL: TIM2_IRQHandler must call xQueueSendFromISR with &xHigherPriorityTaskWoken!\n')
    sys.exit(1)

# Queue full drop handling
if not re.search(r'g_isr_dropped_count\s*(\+\+|\+=)', isr_body) and not re.search(r'errQUEUE_FULL', isr_body):
    sys.stderr.write('FAIL: TIM2_IRQHandler must handle queue full condition by tracking g_isr_dropped_count!\n')
    sys.exit(1)

# portYIELD_FROM_ISR
if not re.search(r'portYIELD_FROM_ISR\s*\(', isr_body):
    sys.stderr.write('FAIL: TIM2_IRQHandler must invoke portYIELD_FROM_ISR() to request deferred context switch!\n')
    sys.exit(1)
" "${CLEAN_SRC}"

# 4. Strict Compilation and Link against FreeRTOS V11.3.0
TEST_MAIN="${TEMP_BUILD_DIR}/test_main.c"
cat << 'EOF' > "${TEST_MAIN}"
#include "clock.h"
#include "gpio.h"
#include "queue_app.h"
#include "FreeRTOS.h"
#include "task.h"

int main(void)
{
    clock_init(CLOCK_PROFILE_72MHZ_HSE);
    gpio_init();
    queue_app_init();
    timer2_init(100);
    timer2_start();
    vTaskStartScheduler();
    while (1) {}
    return 0;
}
EOF

TEST_ELF="${TEMP_BUILD_DIR}/submission.elf"
arm-none-eabi-gcc \
    -mcpu=cortex-m3 -mthumb -mfloat-abi=soft -O2 -g3 -Wall -Wextra -Werror \
    -ffunction-sections -fdata-sections -DSTM32F103xB \
    -I"${SUBMISSION_DIR}" \
    -I"${MODULE_DIR}/include" \
    -I"${MODULE_DIR}/../vendor/freertos/include" \
    -I"${MODULE_DIR}/../vendor/freertos/portable/GCC/ARM_CM3" \
    -I"${MODULE_DIR}/../../mcu/vendor/cmsis/include" \
    -T"${MODULE_DIR}/linker/stm32f103c8tx_flash.ld" \
    -nostartfiles -Wl,-e,Reset_Handler -Wl,--gc-sections \
    --specs=nano.specs --specs=nosys.specs \
    "${TEST_MAIN}" \
    "${APP_SRC}" \
    "${MODULE_DIR}/src/clock.c" \
    "${MODULE_DIR}/src/gpio.c" \
    "${MODULE_DIR}/src/system_stm32f1xx.c" \
    "${MODULE_DIR}/src/runtime_glue.c" \
    "${MODULE_DIR}/src/startup_stm32f103c8.s" \
    "${MODULE_DIR}/../vendor/freertos/tasks.c" \
    "${MODULE_DIR}/../vendor/freertos/list.c" \
    "${MODULE_DIR}/../vendor/freertos/queue.c" \
    "${MODULE_DIR}/../vendor/freertos/portable/GCC/ARM_CM3/port.c" \
    "${MODULE_DIR}/../vendor/freertos/portable/MemMang/heap_4.c" \
    -o "${TEST_ELF}"

# 5. Verify ELF symbols
NM_OUT=$(arm-none-eabi-nm "${TEST_ELF}")

if ! echo "${NM_OUT}" | grep -qE "xQueueGenericSendFromISR"; then
    echo "FAIL: xQueueGenericSendFromISR symbol not found in linked ELF!" >&2
    exit 1
fi
if ! echo "${NM_OUT}" | grep -qE "xQueueReceive"; then
    echo "FAIL: xQueueReceive symbol not found in linked ELF!" >&2
    exit 1
fi
if ! echo "${NM_OUT}" | grep -qE "TIM2_IRQHandler"; then
    echo "FAIL: TIM2_IRQHandler symbol not found in linked ELF!" >&2
    exit 1
fi
if echo "${NM_OUT}" | grep -qE "\b(malloc|calloc|realloc|free)$"; then
    echo "FAIL: Prohibited libc dynamic memory allocators linked!" >&2
    exit 1
fi

# 6. Disassembly verification: TIM2_IRQHandler and portYIELD_FROM_ISR
DISASM=$(arm-none-eabi-objdump -d "${TEST_ELF}")
TIM2_DISASM=$(echo "${DISASM}" | awk '/<TIM2_IRQHandler>:/ {flag=1} flag && !/<TIM2_IRQHandler>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}')

if ! echo "${TIM2_DISASM}" | grep -qE "b[l]?(\.w)?.*<xQueueGenericSendFromISR>"; then
    echo "FAIL: TIM2_IRQHandler disassembly does not call xQueueGenericSendFromISR!" >&2
    exit 1
fi
if ! echo "${TIM2_DISASM}" | grep -qiE "(ed04|0x10000000|268435456)"; then
    echo "FAIL: TIM2_IRQHandler does not write to SCB->ICSR (portYIELD_FROM_ISR)!" >&2
    exit 1
fi

echo "[PASS] All P2-M05 challenge architectural, AST, compile, and disassembly checks PASSED!"
