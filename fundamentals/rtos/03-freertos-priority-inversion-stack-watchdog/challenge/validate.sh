#!/usr/bin/env bash
# ==============================================================================
# validate.sh: Student Submission Validator for Module P2-M06 Challenge
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

INV_SRC="${SUBMISSION_DIR}/inversion_app.c"
INV_HDR="${SUBMISSION_DIR}/inversion_app.h"
IWDG_SRC="${SUBMISSION_DIR}/iwdg.c"
IWDG_HDR="${SUBMISSION_DIR}/iwdg.h"
APP_CFG="${SUBMISSION_DIR}/FreeRTOSConfig.h"

echo "=== Validating P2-M06 Challenge Implementation Bundle: ${SUBMISSION_DIR} ==="

for req_file in "${INV_SRC}" "${INV_HDR}" "${IWDG_SRC}" "${IWDG_HDR}" "${APP_CFG}"; do
    if [ ! -f "${req_file}" ]; then
        echo "ERROR: Missing required submission file '$(basename "${req_file}")' in '${SUBMISSION_DIR}'!" >&2
        exit 1
    fi
done

CLEAN_INV="$(mktemp)"
CLEAN_IWDG="$(mktemp)"
CLEAN_CFG="$(mktemp)"
TEMP_BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "${CLEAN_INV}" "${CLEAN_IWDG}" "${CLEAN_CFG}" "${TEMP_BUILD_DIR}"' EXIT

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
strip_c(sys.argv[5], sys.argv[6])
" "${INV_SRC}" "${CLEAN_INV}" "${IWDG_SRC}" "${CLEAN_IWDG}" "${APP_CFG}" "${CLEAN_CFG}"

# Check 0: Zero placeholder / TODO comments remaining in submission
for f in "${INV_SRC}" "${IWDG_SRC}" "${APP_CFG}"; do
    if grep -qiE "\bTODO\b" "${f}"; then
        echo "FAIL: Unimplemented TODO items remain in $(basename "${f}")!" >&2
        exit 1
    fi
done

# 1. Pinned FreeRTOS kernel source identity (V11.3.0)
FREERTOS_TASK_H="${MODULE_DIR}/../vendor/freertos/include/task.h"
if ! grep -q 'tskKERNEL_VERSION_NUMBER\s*"V11.3.0"' "${FREERTOS_TASK_H}"; then
    echo "FAIL: FreeRTOS kernel version mismatch; must pin V11.3.0!" >&2
    exit 1
fi

# 2. FreeRTOSConfig.h contracts
python3 -c "
import sys, re
cfg = open(sys.argv[1]).read()

m_mut = re.search(r'#define\s+configUSE_MUTEXES\s+(\d+)', cfg)
if not m_mut or int(m_mut.group(1)) != 1:
    sys.stderr.write('FAIL: configUSE_MUTEXES must be set to 1 to enable priority inheritance!\n')
    sys.exit(1)

m_ovf = re.search(r'#define\s+configCHECK_FOR_STACK_OVERFLOW\s+(\d+)', cfg)
if not m_ovf or int(m_ovf.group(1)) != 2:
    sys.stderr.write('FAIL: configCHECK_FOR_STACK_OVERFLOW must be set to 2 (Method 2 canary check)!\n')
    sys.exit(1)

m_bits = re.search(r'#define\s+configPRIO_BITS\s+(\d+)', cfg)
if not m_bits or int(m_bits.group(1)) != 4:
    sys.stderr.write('FAIL: configPRIO_BITS must be defined as 4 for STM32F103!\n')
    sys.exit(1)

m_prio = re.search(r'#define\s+configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY\s+(\d+)', cfg)
if not m_prio or int(m_prio.group(1)) != 5:
    sys.stderr.write('FAIL: configLIBRARY_MAX_SYSCALL_INTERRUPT_PRIORITY must be 5!\n')
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

# 3. Source contracts in iwdg.c
python3 -c "
import sys, re
src = open(sys.argv[1]).read()

# Direct MMIO access to IWDG
if not re.search(r'IWDG\s*->\s*KR\s*=', src):
    sys.stderr.write('FAIL: iwdg.c must perform direct MMIO access to IWDG->KR!\n')
    sys.exit(1)

# Write unlock key 0x5555
if not re.search(r'IWDG\s*->\s*KR\s*=\s*(0x5555|IWDG_KEY_WRITE_EN|IWDG_KEY_ACCESS)', src):
    sys.stderr.write('FAIL: iwdg.c must write unlock key 0x5555 (IWDG_KEY_WRITE_EN) to IWDG->KR!\n')
    sys.exit(1)

# Reload key 0xAAAA and start key 0xCCCC
if not re.search(r'0xAAAA', src, re.I) or not re.search(r'0xCCCC', src, re.I):
    sys.stderr.write('FAIL: iwdg.c must use keys 0xAAAA (reload) and 0xCCCC (start)!\n')
    sys.exit(1)

# Bounded wait loops for PVU and RVU
pvu_match = re.search(r'while\s*\(\s*.*IWDG_SR_PVU.*\)', src)
if not pvu_match:
    sys.stderr.write('FAIL: iwdg.c must check IWDG_SR_PVU status before writing PR!\n')
    sys.exit(1)

rvu_match = re.search(r'while\s*\(\s*.*IWDG_SR_RVU.*\)', src)
if not rvu_match:
    sys.stderr.write('FAIL: iwdg.c must check IWDG_SR_RVU status before writing RLR!\n')
    sys.exit(1)

# Bounded timeout check inside while loops
if not re.search(r'timeout\s*--|--\s*timeout', src):
    sys.stderr.write('FAIL: iwdg.c must enforce bounded timeout loop counter when polling status flags!\n')
    sys.exit(1)

# Reset cause check and clear via RCC->CSR
if not re.search(r'RCC\s*->\s*CSR\s*&.*RCC_CSR_IWDGRSTF', src):
    sys.stderr.write('FAIL: iwdg.c must check RCC_CSR_IWDGRSTF in RCC->CSR!\n')
    sys.exit(1)
if not re.search(r'RCC\s*->\s*CSR\s*\|=.*RCC_CSR_RMVF', src):
    sys.stderr.write('FAIL: iwdg.c must clear reset flags using RCC_CSR_RMVF!\n')
    sys.exit(1)

# Prohibit libc malloc
if re.search(r'\b(malloc|calloc|realloc|free)\s*\(', src):
    sys.stderr.write('FAIL: Prohibited call to libc dynamic memory allocator in iwdg.c!\n')
    sys.exit(1)
" "${CLEAN_IWDG}"

# 4. Source contracts in inversion_app.c
python3 -c "
import sys, re
src = open(sys.argv[1]).read()

# Verify Run A uses binary semaphore and Run B uses mutex
if not re.search(r'xSemaphoreCreateBinary\s*\(', src):
    sys.stderr.write('FAIL: inversion_app.c must instantiate a binary semaphore for Run A!\n')
    sys.exit(1)

if not re.search(r'xSemaphoreCreateMutex\s*\(', src):
    sys.stderr.write('FAIL: inversion_app.c must instantiate a mutex for Run B (priority inheritance)!\n')
    sys.exit(1)

# Watermark byte conversion: must multiply words by 4 or sizeof(StackType_t)
if not re.search(r'uxTaskGetStackHighWaterMark\s*\(', src):
    sys.stderr.write('FAIL: inversion_app.c must call uxTaskGetStackHighWaterMark()!\n')
    sys.exit(1)

if not re.search(r'(sizeof\s*\(\s*StackType_t\s*\)|\*\s*4|\b<<\s*2)', src):
    sys.stderr.write('FAIL: inversion_app.c must convert watermark words to bytes (* 4 or * sizeof(StackType_t))!\n')
    sys.exit(1)

# Check that low workload does NOT call vTaskDelay
low_fn_idx = src.find('inversion_execute_low_workload')
if low_fn_idx != -1:
    brace_level = 0
    in_body = False
    fn_body = []
    for ch in src[low_fn_idx:]:
        if ch == '{':
            brace_level += 1
            in_body = True
        elif ch == '}':
            brace_level -= 1
            if in_body and brace_level == 0:
                break
        if in_body:
            fn_body.append(ch)
    body_str = ''.join(fn_body)
    if re.search(r'\bvTaskDelay\s*\(', body_str):
        sys.stderr.write('FAIL: inversion_execute_low_workload() must execute pure CPU work without vTaskDelay()!\n')
        sys.exit(1)

# Prohibit libc malloc in application source
if re.search(r'\b(malloc|calloc|realloc|free)\s*\(', src):
    sys.stderr.write('FAIL: Prohibited call to standard libc dynamic allocator in inversion_app.c!\n')
    sys.exit(1)
" "${CLEAN_INV}"

# 5. Strict Compilation and Link against FreeRTOS V11.3.0
TEST_MAIN="${TEMP_BUILD_DIR}/test_main.c"
cat << 'EOF' > "${TEST_MAIN}"
#include "clock.h"
#include "gpio.h"
#include "inversion_app.h"
#include "iwdg.h"
#include "FreeRTOS.h"
#include "task.h"

int main(void)
{
    clock_init(CLOCK_PROFILE_72MHZ_HSE);
    gpio_init();
    iwdg_check_and_clear_reset_cause();
    iwdg_init(4, 1250);
    inversion_app_init();
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
    "${INV_SRC}" \
    "${IWDG_SRC}" \
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

# 6. Verify ELF symbols
NM_OUT=$(arm-none-eabi-nm "${TEST_ELF}")

for sym in "xTaskPriorityInherit" "xTaskPriorityDisinherit" "uxTaskGetStackHighWaterMark" "vApplicationStackOverflowHook" "iwdg_init" "iwdg_refresh"; do
    if ! echo "${NM_OUT}" | grep -qE "\b${sym}\b"; then
        echo "FAIL: Required symbol '${sym}' not found in linked ELF!" >&2
        exit 1
    fi
done

if echo "${NM_OUT}" | grep -qE "\b(malloc|calloc|realloc|free)$"; then
    echo "FAIL: Prohibited libc dynamic memory allocators linked into ELF!" >&2
    exit 1
fi

# 7. Disassembly verification
DISASM_FILE="${TEMP_BUILD_DIR}/submission.disasm"
arm-none-eabi-objdump -d "${TEST_ELF}" > "${DISASM_FILE}"

# Check direct MMIO to IWDG peripheral (0x40003000)
if ! grep -qE "(40003000|0x40003000)" "${DISASM_FILE}"; then
    echo "FAIL: Disassembly does not contain direct memory-mapped access to IWDG (0x40003000)!" >&2
    exit 1
fi

# Check that inversion_execute_low_workload does not call vTaskDelay
LOW_DISASM=$(awk '/<inversion_execute_low_workload>:/ {flag=1} flag && !/<inversion_execute_low_workload>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}' "${DISASM_FILE}")
if echo "${LOW_DISASM}" | grep -qE "b[l]?(\.w)?.*<vTaskDelay>"; then
    echo "FAIL: inversion_execute_low_workload disassembly contains a call to vTaskDelay!" >&2
    exit 1
fi

echo "[PASS] All P2-M06 challenge architectural, AST, compile, and disassembly checks PASSED!"
