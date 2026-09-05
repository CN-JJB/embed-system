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
CLEAN_HDR="$(mktemp)"
TEMP_BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "${CLEAN_INV}" "${CLEAN_IWDG}" "${CLEAN_CFG}" "${CLEAN_HDR}" "${TEMP_BUILD_DIR}"' EXIT

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
strip_c(sys.argv[7], sys.argv[8])
" "${INV_SRC}" "${CLEAN_INV}" "${IWDG_SRC}" "${CLEAN_IWDG}" "${APP_CFG}" "${CLEAN_CFG}" "${INV_HDR}" "${CLEAN_HDR}"

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

# Independent bounded wait loops for PVU and RVU
def extract_while_body(s, flag_str):
    pos = s.find(flag_str)
    if pos == -1:
        return None
    while_pos = s.rfind('while', 0, pos)
    if while_pos == -1:
        return None
    brace_open = s.find('{', pos)
    if brace_open == -1:
        return None
    brace_level = 0
    body = []
    for ch in s[brace_open:]:
        if ch == '{':
            brace_level += 1
            if brace_level == 1:
                continue
        elif ch == '}':
            brace_level -= 1
            if brace_level == 0:
                break
        body.append(ch)
    return ''.join(body)

def verify_bounded_timeout_loop(loop_body, loop_name):
    if loop_body is None:
        sys.stderr.write(f'FAIL: iwdg.c must check {loop_name} status in a while loop!\n')
        sys.exit(1)

    # Disallow bare break without returning error
    if re.search(r'(?<!//)\bbreak\s*;', loop_body):
        sys.stderr.write(f'FAIL: iwdg.c {loop_name} loop must return failure on timeout exhaustion, not bare break!\n')
        sys.exit(1)

    bound_patterns = [
        r'if\s*\(\s*(?:--\s*timeout|timeout\s*--)\s*==\s*0\s*\)\s*(?:\{\s*)?return\s+(?:false|pdFALSE|0\b)\s*;',
        r'if\s*\(\s*!\s*(?:--\s*timeout|timeout\s*--)\s*\)\s*(?:\{\s*)?return\s+(?:false|pdFALSE|0\b)\s*;',
        r'(?:--\s*timeout|timeout\s*--)\s*;[^;}]*if\s*\(\s*timeout\s*==\s*0\s*\)\s*(?:\{\s*)?return\s+(?:false|pdFALSE|0\b)\s*;',
    ]
    if not any(re.search(pat, loop_body) for pat in bound_patterns):
        sys.stderr.write(f'FAIL: iwdg.c {loop_name} loop must causally bind timeout exhaustion (--timeout == 0) to returning false!\n')
        sys.exit(1)

pvu_body = extract_while_body(src, 'IWDG_SR_PVU')
verify_bounded_timeout_loop(pvu_body, 'IWDG_SR_PVU')

rvu_body = extract_while_body(src, 'IWDG_SR_RVU')
verify_bounded_timeout_loop(rvu_body, 'IWDG_SR_RVU')

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

# 4. Source contracts in inversion_app.c and inversion_app.h
python3 -c "
import sys, re
src = open(sys.argv[1]).read()
hdr = open(sys.argv[2]).read()

# Verify task priorities in header
if not re.search(r'#define\s+TASK_HIGH_PRIORITY\s+3\b', hdr):
    sys.stderr.write('FAIL: inversion_app.h must define TASK_HIGH_PRIORITY as 3!\n')
    sys.exit(1)
if not re.search(r'#define\s+TASK_MEDIUM_PRIORITY\s+2\b', hdr):
    sys.stderr.write('FAIL: inversion_app.h must define TASK_MEDIUM_PRIORITY as 2!\n')
    sys.exit(1)
if not re.search(r'#define\s+TASK_LOW_PRIORITY\s+1\b', hdr):
    sys.stderr.write('FAIL: inversion_app.h must define TASK_LOW_PRIORITY as 1!\n')
    sys.exit(1)

# Verify task creation priorities in inversion_app_init
# Verify task creation priorities in inversion_app_init
init_idx = src.find('inversion_app_init')
if init_idx == -1:
    sys.stderr.write('FAIL: inversion_app.c missing inversion_app_init()!\n')
    sys.exit(1)

brace = 0
in_body = False
init_body = []
for ch in src[init_idx:]:
    if ch == '{':
        brace += 1
        in_body = True
    elif ch == '}':
        brace -= 1
        if in_body and brace == 0:
            break
    if in_body:
        init_body.append(ch)
init_str = ''.join(init_body)

creates = list(re.finditer(r'xTaskCreate\s*\(([^;]+)\);', init_str, re.S))
found_low = False
found_med = False
found_high = False

for c in creates:
    args = [a.strip() for a in c.group(1).split(',')]
    if len(args) < 6:
        continue
    fn_name = args[0]
    task_name = args[1]
    prio_str = args[4]
    handle_str = args[5]

    if 'prvTaskLow' in fn_name or 'Low' in task_name:
        if prio_str not in ('1', 'TASK_LOW_PRIORITY'):
            sys.stderr.write(f'FAIL: Task Low priority must be 1 (got {prio_str})!\n')
            sys.exit(1)
        if 'g_task_low_handle' not in handle_str:
            sys.stderr.write('FAIL: Task Low must pass &g_task_low_handle!\n')
            sys.exit(1)
        found_low = True
    elif 'prvTaskMedium' in fn_name or 'Medium' in task_name:
        if prio_str not in ('2', 'TASK_MEDIUM_PRIORITY'):
            sys.stderr.write(f'FAIL: Task Medium priority must be 2 (got {prio_str})!\n')
            sys.exit(1)
        if 'g_task_medium_handle' not in handle_str:
            sys.stderr.write('FAIL: Task Medium must pass &g_task_medium_handle!\n')
            sys.exit(1)
        found_med = True
    elif 'prvTaskHigh' in fn_name or 'High' in task_name:
        if prio_str not in ('3', 'TASK_HIGH_PRIORITY'):
            sys.stderr.write(f'FAIL: Task High priority must be 3 (got {prio_str})!\n')
            sys.exit(1)
        if 'g_task_high_handle' not in handle_str:
            sys.stderr.write('FAIL: Task High must pass &g_task_high_handle!\n')
            sys.exit(1)
        found_high = True

if not found_low:
    sys.stderr.write('FAIL: inversion_app_init() must create Task Low (priority 1, handle &g_task_low_handle)!\n')
    sys.exit(1)
if not found_med:
    sys.stderr.write('FAIL: inversion_app_init() must create Task Medium (priority 2, handle &g_task_medium_handle)!\n')
    sys.exit(1)
if not found_high:
    sys.stderr.write('FAIL: inversion_app_init() must create Task High (priority 3, handle &g_task_high_handle)!\n')
    sys.exit(1)

# Verify deterministic sequencing in prvTaskLow
low_idx = src.find('prvTaskLow')
if low_idx == -1:
    sys.stderr.write('FAIL: inversion_app.c missing prvTaskLow()!\n')
    sys.exit(1)

brace = 0
in_body = False
body = []
for ch in src[low_idx:]:
    if ch == '{':
        brace += 1
        in_body = True
    elif ch == '}':
        brace -= 1
        if in_body and brace == 0:
            break
    if in_body:
        body.append(ch)
low_str = ''.join(body)

# Run A sequencing
idx_cb = low_str.find('xSemaphoreCreateBinary')
if idx_cb == -1:
    sys.stderr.write('FAIL: Run A must instantiate binary semaphore via xSemaphoreCreateBinary()!\n')
    sys.exit(1)
idx_take_a = low_str.find('xSemaphoreTake', idx_cb)
if idx_take_a == -1:
    sys.stderr.write('FAIL: Run A must acquire binary semaphore via xSemaphoreTake()!\n')
    sys.exit(1)
idx_give_init = low_str.find('xSemaphoreGive', idx_cb)
if idx_give_init == -1 or idx_give_init > idx_take_a:
    sys.stderr.write('FAIL: Run A must initialize binary semaphore token via xSemaphoreGive() before xSemaphoreTake()!\n')
    sys.exit(1)

m_notif_high_a = re.search(r'xTaskNotifyGive\s*\(\s*g_task_high_handle\s*\)', low_str[idx_take_a:])
m_notif_med_a = re.search(r'xTaskNotifyGive\s*\(\s*g_task_medium_handle\s*\)', low_str[idx_take_a:])
if not m_notif_high_a or not m_notif_med_a:
    sys.stderr.write('FAIL: Run A must call xTaskNotifyGive for both High and Medium tasks!\n')
    sys.exit(1)
idx_notif_high_a = idx_take_a + m_notif_high_a.start()
idx_notif_med_a = idx_take_a + m_notif_med_a.start()
if idx_notif_high_a > idx_notif_med_a:
    sys.stderr.write('FAIL: Run A must notify Task High before Task Medium via xTaskNotifyGive()!\n')
    sys.exit(1)

idx_work_a = low_str.find('inversion_execute_low_workload', idx_notif_med_a)
if idx_work_a == -1:
    sys.stderr.write('FAIL: Run A must execute workload after notifying High and Medium!\n')
    sys.exit(1)
idx_give_rel_a = low_str.find('xSemaphoreGive', idx_work_a)
if idx_give_rel_a == -1:
    sys.stderr.write('FAIL: Run A must release binary semaphore after executing workload!\n')
    sys.exit(1)

# Run B sequencing
idx_cm = low_str.find('xSemaphoreCreateMutex', idx_give_rel_a)
if idx_cm == -1:
    sys.stderr.write('FAIL: Run B must instantiate mutex via xSemaphoreCreateMutex()!\n')
    sys.exit(1)
idx_take_b = low_str.find('xSemaphoreTake', idx_cm)
if idx_take_b == -1:
    sys.stderr.write('FAIL: Run B must acquire mutex via xSemaphoreTake()!\n')
    sys.exit(1)

m_notif_high_b = re.search(r'xTaskNotifyGive\s*\(\s*g_task_high_handle\s*\)', low_str[idx_take_b:])
m_notif_med_b = re.search(r'xTaskNotifyGive\s*\(\s*g_task_medium_handle\s*\)', low_str[idx_take_b:])
if not m_notif_high_b or not m_notif_med_b:
    sys.stderr.write('FAIL: Run B must call xTaskNotifyGive for both High and Medium tasks!\n')
    sys.exit(1)
idx_notif_high_b = idx_take_b + m_notif_high_b.start()
idx_notif_med_b = idx_take_b + m_notif_med_b.start()
if idx_notif_high_b > idx_notif_med_b:
    sys.stderr.write('FAIL: Run B must notify Task High before Task Medium via xTaskNotifyGive()!\n')
    sys.exit(1)

idx_work_b = low_str.find('inversion_execute_low_workload', idx_notif_med_b)
if idx_work_b == -1:
    sys.stderr.write('FAIL: Run B must execute workload after notifying High and Medium!\n')
    sys.exit(1)
idx_give_rel_b = low_str.find('xSemaphoreGive', idx_work_b)
if idx_give_rel_b == -1:
    sys.stderr.write('FAIL: Run B must release mutex after executing workload!\n')
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

# Learner-owned vApplicationStackOverflowHook definition (not prototype)
hook_match = re.search(r'\bvoid\s+vApplicationStackOverflowHook\s*\([^)]*\)\s*\{', src)
if not hook_match:
    sys.stderr.write('FAIL: inversion_app.c must define learner-owned vApplicationStackOverflowHook() with an actual function body!\n')
    sys.exit(1)

brace_start = hook_match.end() - 1
brace = 0
hook_body = []
for ch in src[brace_start:]:
    if ch == '{':
        brace += 1
    elif ch == '}':
        brace -= 1
        if brace == 0:
            break
    if brace > 0:
        hook_body.append(ch)
hook_str = ''.join(hook_body)
if '__disable_irq' not in hook_str:
    sys.stderr.write('FAIL: vApplicationStackOverflowHook() must call __disable_irq()!\n')
    sys.exit(1)

# DWT cycle counting functions
if not re.search(r'\bdwt_init\s*\(\s*(void)?\s*\)', src):
    sys.stderr.write('FAIL: inversion_app.c must implement dwt_init()!\n')
    sys.exit(1)
if not re.search(r'\bdwt_get_cycles\s*\(\s*(void)?\s*\)', src):
    sys.stderr.write('FAIL: inversion_app.c must implement dwt_get_cycles()!\n')
    sys.exit(1)

# Verify prvTaskHigh uses DWT cycle counter before and after resource acquisition
high_idx = src.find('prvTaskHigh')
if high_idx == -1:
    sys.stderr.write('FAIL: inversion_app.c missing prvTaskHigh()!\n')
    sys.exit(1)

brace = 0
in_body = False
high_body = []
for ch in src[high_idx:]:
    if ch == '{':
        brace += 1
        in_body = True
    elif ch == '}':
        brace -= 1
        if in_body and brace == 0:
            break
    if in_body:
        high_body.append(ch)
high_str = ''.join(high_body)

take_match = re.search(r'xSemaphoreTake\s*\(\s*g_shared_resource', high_str)
if not take_match:
    sys.stderr.write('FAIL: prvTaskHigh() must acquire g_shared_resource via xSemaphoreTake()!\n')
    sys.exit(1)

pre_take = high_str[:take_match.start()]
post_take = high_str[take_match.end():]

if not re.search(r'dwt_get_cycles\s*\(\s*\)', pre_take):
    sys.stderr.write('FAIL: prvTaskHigh() must call dwt_get_cycles() before acquiring g_shared_resource!\n')
    sys.exit(1)

if not re.search(r'dwt_get_cycles\s*\(\s*\)', post_take):
    sys.stderr.write('FAIL: prvTaskHigh() must call dwt_get_cycles() after acquiring g_shared_resource!\n')
    sys.exit(1)

if not re.search(r'g_high_wait_cycles_run_a\s*=', post_take) or not re.search(r'g_high_wait_cycles_run_b\s*=', post_take):
    sys.stderr.write('FAIL: prvTaskHigh() must record DWT cycle duration into g_high_wait_cycles_run_a and g_high_wait_cycles_run_b!\n')
    sys.exit(1)

# Prohibit libc malloc in application source
if re.search(r'\b(malloc|calloc|realloc|free)\s*\(', src):
    sys.stderr.write('FAIL: Prohibited call to standard libc dynamic allocator in inversion_app.c!\n')
    sys.exit(1)
" "${CLEAN_INV}" "${CLEAN_HDR}"

# 5. Strict Compilation and Link against FreeRTOS V11.3.0
TEST_MAIN="${TEMP_BUILD_DIR}/test_main.c"
cat << 'EOF' > "${TEST_MAIN}"
#include "clock.h"
#include "gpio.h"
#include "inversion_app.h"
#include "iwdg.h"
#include "FreeRTOS.h"
#include "task.h"

_Static_assert(TASK_HIGH_PRIORITY == 3, "TASK_HIGH_PRIORITY must be 3");
_Static_assert(TASK_MEDIUM_PRIORITY == 2, "TASK_MEDIUM_PRIORITY must be 2");
_Static_assert(TASK_LOW_PRIORITY == 1, "TASK_LOW_PRIORITY must be 1");

int main(void)
{
    clock_init(CLOCK_PROFILE_72MHZ_HSE);
    gpio_init();
    dwt_init();
    iwdg_check_and_clear_reset_cause();
    iwdg_init(4, 1250);
    inversion_app_init();
    vTaskStartScheduler();
    while (1) {}
    return 0;
}
EOF

# Compile inversion_app.c separately to verify strong definition of vApplicationStackOverflowHook
INV_OBJ="${TEMP_BUILD_DIR}/inversion_app.o"
arm-none-eabi-gcc \
    -mcpu=cortex-m3 -mthumb -mfloat-abi=soft -O2 -g3 -Wall -Wextra -Werror \
    -ffunction-sections -fdata-sections -DSTM32F103xB \
    -I"${SUBMISSION_DIR}" \
    -I"${MODULE_DIR}/include" \
    -I"${MODULE_DIR}/../vendor/freertos/include" \
    -I"${MODULE_DIR}/../vendor/freertos/portable/GCC/ARM_CM3" \
    -I"${MODULE_DIR}/../../mcu/vendor/cmsis/include" \
    -c "${INV_SRC}" -o "${INV_OBJ}"

if ! arm-none-eabi-nm "${INV_OBJ}" | grep -qE "\bT\s+vApplicationStackOverflowHook\b"; then
    echo "FAIL: inversion_app.o does not provide a strong definition (type T) for vApplicationStackOverflowHook!" >&2
    exit 1
fi

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
    "${INV_OBJ}" \
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

for sym in "xTaskPriorityInherit" "xTaskPriorityDisinherit" "uxTaskGetStackHighWaterMark" "vApplicationStackOverflowHook" "iwdg_init" "iwdg_refresh" "dwt_init" "dwt_get_cycles"; do
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

# Check direct access to Cortex-M3 DWT Cycle Counter (0xE0001004 / 0xE0001000)
if ! grep -qiE "(e0001004|e0001000)" "${DISASM_FILE}"; then
    echo "FAIL: Disassembly does not contain direct access to Cortex-M3 DWT CYCCNT (0xE0001004/0xE0001000)!" >&2
    exit 1
fi

# Check that inversion_execute_low_workload does not call vTaskDelay
LOW_DISASM=$(awk '/<inversion_execute_low_workload>:/ {flag=1} flag && !/<inversion_execute_low_workload>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}' "${DISASM_FILE}")
if echo "${LOW_DISASM}" | grep -qE "b[l]?(\.w)?.*<vTaskDelay>"; then
    echo "FAIL: inversion_execute_low_workload disassembly contains a call to vTaskDelay!" >&2
    exit 1
fi

# Check that prvTaskHigh calls dwt_get_cycles
HIGH_DISASM=$(awk '/<prvTaskHigh>:/ {flag=1} flag && !/<prvTaskHigh>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}' "${DISASM_FILE}")
if ! echo "${HIGH_DISASM}" | grep -qE "b[l]?(\.w)?.*<dwt_get_cycles>"; then
    echo "FAIL: prvTaskHigh disassembly does not call dwt_get_cycles!" >&2
    exit 1
fi

echo "[PASS] All P2-M06 challenge architectural, AST, compile, and disassembly checks PASSED!"
