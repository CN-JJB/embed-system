#!/usr/bin/env bash
# ==============================================================================
# verify_project.sh: Automated Static, Architectural & Contract Validator
# for Phase 2 P2-M07 STM32 FreeRTOS Acquisition Node Integration Project
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Support optional directory argument (e.g. for testing mutations / submissions)
TARGET_ARG="${1:-${PROJECT_DIR}}"

if [ -d "${TARGET_ARG}" ]; then
    BUNDLE_DIR="$(cd "${TARGET_ARG}" && pwd)"
else
    echo "ERROR: Target path '${TARGET_ARG}' is not a directory!" >&2
    exit 1
fi

echo "=== Running P2-M07 Project Verification for: ${BUNDLE_DIR} ==="

TEMP_BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "${TEMP_BUILD_DIR}"' EXIT

# If verifying an external bundle, prepare temporary build directory overlaying project
if [ "${BUNDLE_DIR}" != "${PROJECT_DIR}" ]; then
    cp -r "${PROJECT_DIR}"/* "${TEMP_BUILD_DIR}/"
    # Copy overlay files from bundle into appropriate subdirectories
    for f in "${BUNDLE_DIR}"/*; do
        if [ -f "$f" ]; then
            fname="$(basename "$f")"
            if [ -f "${TEMP_BUILD_DIR}/src/${fname}" ]; then
                cp "$f" "${TEMP_BUILD_DIR}/src/${fname}"
            elif [ -f "${TEMP_BUILD_DIR}/include/${fname}" ]; then
                cp "$f" "${TEMP_BUILD_DIR}/include/${fname}"
            else
                cp "$f" "${TEMP_BUILD_DIR}/src/${fname}"
            fi
        fi
    done
    WORK_DIR="${TEMP_BUILD_DIR}"
else
    WORK_DIR="${PROJECT_DIR}"
fi

REPO_ROOT="$(cd "${PROJECT_DIR}/../.." && pwd)"

# Clean and build firmware
make -C "${WORK_DIR}" ROOT_DIR="${REPO_ROOT}" clean >/dev/null 2>&1 || true
if ! make -C "${WORK_DIR}" ROOT_DIR="${REPO_ROOT}" build >/dev/null 2>&1; then
    echo "ERROR: Project failed to compile/link cleanly under strict toolchain flags!" >&2
    make -C "${WORK_DIR}" ROOT_DIR="${REPO_ROOT}" build
    exit 1
fi

ELF="${WORK_DIR}/build/firmware.elf"
MAP="${WORK_DIR}/build/firmware.map"
ASM="${WORK_DIR}/build/firmware.asm"

if [ ! -f "${ELF}" ] || [ ! -f "${MAP}" ] || [ ! -f "${ASM}" ]; then
    echo "ERROR: Build artifacts missing in ${WORK_DIR}/build!" >&2
    exit 1
fi
echo "[PASS] Strict target compilation and link passed"

# 1. Check memory bounds: STM32F103C8T6 (64 KB Flash, 20 KB SRAM)
FLASH_LIMIT=65536
RAM_LIMIT=20480

TEXT_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $1}')
DATA_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $2}')
BSS_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $3}')

TOTAL_FLASH=$((TEXT_SIZE + DATA_SIZE))
TOTAL_RAM=$((DATA_SIZE + BSS_SIZE))

echo "Memory usage: Flash = ${TOTAL_FLASH} / ${FLASH_LIMIT} bytes, RAM = ${TOTAL_RAM} / ${RAM_LIMIT} bytes"

if [ "${TOTAL_FLASH}" -gt "${FLASH_LIMIT}" ]; then
    echo "ERROR: Firmware size (${TOTAL_FLASH} bytes) exceeds 64 KB Flash limit!" >&2
    exit 1
fi

if [ "${TOTAL_RAM}" -gt "${RAM_LIMIT}" ]; then
    echo "ERROR: RAM consumption (${TOTAL_RAM} bytes) exceeds 20 KB SRAM limit!" >&2
    exit 1
fi
echo "[PASS] Memory bounds strictly within 64 KB Flash / 20 KB SRAM"

# 2. Check for prohibited HAL / CubeMX / CMSIS-RTOS wrappers
if grep -rqsE "(HAL_Init|HAL_ADC_|HAL_DMA_|HAL_IWDG_|osDelay|cmsis_os\.h)" "${WORK_DIR}/src" "${WORK_DIR}/include"; then
    echo "ERROR: Prohibited HAL / CubeMX / CMSIS-RTOS wrapper code detected!" >&2
    exit 1
fi
echo "[PASS] Zero HAL/CubeMX/CMSIS-RTOS wrapper dependencies in MUST scope"

# 3. Check FreeRTOS V11.3.0 kernel pin
TASK_H="${PROJECT_DIR}/../../fundamentals/rtos/vendor/freertos/include/task.h"
if ! grep -q 'tskKERNEL_VERSION_NUMBER\s*"V11.3.0"' "${TASK_H}"; then
    echo "ERROR: FreeRTOS kernel version mismatch; must pin V11.3.0!" >&2
    exit 1
fi
echo "[PASS] Pinned FreeRTOS kernel V11.3.0 verified"

# 4. Check FreeRTOS heap_4 exclusivity and absence of libc dynamic allocators
NM_OUT=$(arm-none-eabi-nm "${ELF}")

if ! echo "${NM_OUT}" | grep -qE "[0-9a-fA-F]+\s+[Bb]\s+ucHeap$"; then
    echo "ERROR: FreeRTOS ucHeap array missing from .bss!" >&2
    exit 1
fi

if echo "${NM_OUT}" | grep -qE "\b(malloc|_malloc_r|calloc|_calloc_r|realloc|_realloc_r|free|_free_r)\b"; then
    echo "ERROR: Prohibited libc dynamic memory allocator linked into binary!" >&2
    exit 1
fi
echo "[PASS] Heap exclusivity verified: ucHeap in heap_4; libc dynamic allocators absent"

# 5. Check FreeRTOSConfig configuration: stack overflow hook level 2 and mutexes enabled
CONFIG_H="${WORK_DIR}/include/FreeRTOSConfig.h"
if ! grep -qE "configCHECK_FOR_STACK_OVERFLOW\s+2\b" "${CONFIG_H}"; then
    echo "ERROR: configCHECK_FOR_STACK_OVERFLOW must be set to 2!" >&2
    exit 1
fi
if ! grep -qE "configUSE_MUTEXES\s+1\b" "${CONFIG_H}"; then
    echo "ERROR: configUSE_MUTEXES must be set to 1!" >&2
    exit 1
fi
echo "[PASS] FreeRTOSConfig.h confirms configCHECK_FOR_STACK_OVERFLOW=2 and configUSE_MUTEXES=1"

# 6. Execute Python-based AST and contract analysis on project source code
python3 - "${WORK_DIR}" "${ELF}" "${ASM}" << 'PYEOF'
import sys, os, re

work_dir = sys.argv[1]
elf_path = sys.argv[2]
asm_path = sys.argv[3]

def read_clean_file(path):
    if not os.path.exists(path):
        return ""
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    # Remove C and C++ comments
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.S)
    content = re.sub(r'//.*', '', content)
    return content

main_c = read_clean_file(os.path.join(work_dir, "src/main.c"))
dma_c = read_clean_file(os.path.join(work_dir, "src/dma.c"))
dma_h = read_clean_file(os.path.join(work_dir, "include/dma.h"))
adc_c = read_clean_file(os.path.join(work_dir, "src/adc.c"))
timer_c = read_clean_file(os.path.join(work_dir, "src/timer.c"))
usart_c = read_clean_file(os.path.join(work_dir, "src/usart.c"))
iwdg_c = read_clean_file(os.path.join(work_dir, "src/iwdg.c"))
node_c = read_clean_file(os.path.join(work_dir, "src/node_app.c"))

# Check Priority Grouping: NVIC_SetPriorityGrouping(0)
if not re.search(r'NVIC_SetPriorityGrouping\s*\(\s*0\s*\)', main_c):
    print("ERROR: main.c must configure NVIC_SetPriorityGrouping(0) for FreeRTOS!", file=sys.stderr)
    sys.exit(1)

# Check TIM3 TRGO configuration: 1 kHz update rate & TRGO on update
if not re.search(r'TIM_CR2_MMS_1|TIM_CR2_MMS\s*=\s*0?x?0?2|0b010', timer_c):
    print("ERROR: timer.c does not set TIM3 TRGO output to Update event (MMS=010)!", file=sys.stderr)
    sys.exit(1)

# Check ADC1 Trigger & Prescaler: EXTSEL=100 (TIM3 TRGO), EXTTRIG=1, DMA=1, ADCPRE=/6, SMP0=55.5 cycles
if not re.search(r'ADC_CR2_EXTSEL_2|0b100|0x00040000', adc_c):
    print("ERROR: adc.c does not select TIM3 TRGO (EXTSEL=100)!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'ADC_CR2_EXTTRIG', adc_c):
    print("ERROR: adc.c does not enable external trigger (EXTTRIG)!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'ADC_CR2_DMA', adc_c):
    print("ERROR: adc.c does not enable ADC DMA request generation!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'RCC_CFGR_ADCPRE_DIV6', adc_c):
    print("ERROR: adc.c does not configure ADCPRE /6 for 12 MHz ADCCLK!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'ADC_SMPR2_SMP0', adc_c):
    print("ERROR: adc.c does not configure PA0 SMP0 sample time!", file=sys.stderr)
    sys.exit(1)

# Check DMA1 Channel 1 Circular Mode and Configuration
if not re.search(r'DMA_CCR_CIRC', dma_c):
    print("ERROR: dma.c does not enable DMA circular mode (DMA_CCR_CIRC)!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'DMA_CCR_MINC', dma_c):
    print("ERROR: dma.c does not enable memory increment (DMA_CCR_MINC)!", file=sys.stderr)
    sys.exit(1)

# Check DMA sample pool is persistent static storage and correctly bound
if not re.search(r'(volatile\s+)?uint16_t\s+g_adc_pool\s*\[\s*2\s*\]\s*\[\s*(64|ADC_BUFFER_HALF_SIZE)\s*\]', dma_c):
    print("ERROR: dma.c missing persistent static storage uint16_t g_adc_pool[2][64]!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'DMA1_Channel1->CMAR\s*=\s*\(uint32_t\)\s*g_adc_pool\b', dma_c):
    print("ERROR: DMA1 Channel 1 destination address does not bind to persistent pool g_adc_pool!", file=sys.stderr)
    sys.exit(1)

# Check DMA IRQ priority within FreeRTOS syscall band (priority >= 5, canonical 6)
prio_match = re.search(r'NVIC_SetPriority\s*\(\s*DMA1_Channel1_IRQn\s*,\s*([0-9]+)\s*\)', dma_c)
if not prio_match:
    print("ERROR: dma.c missing NVIC_SetPriority for DMA1_Channel1_IRQn!", file=sys.stderr)
    sys.exit(1)
prio_val = int(prio_match.group(1))
if prio_val < 5:
    print(f"ERROR: DMA1 IRQ priority {prio_val} violates FreeRTOS syscall-safe boundary (must be >= 5)!", file=sys.stderr)
    sys.exit(1)

# Check DMA1 ISR requirements
isr_match = re.search(r'void\s+DMA1_Channel1_IRQHandler\s*\(\s*void\s*\)\s*\{(.*?)\n\}', dma_c, re.S)
if not isr_match:
    print("ERROR: DMA1_Channel1_IRQHandler not found in dma.c!", file=sys.stderr)
    sys.exit(1)
isr_body = isr_match.group(1)

# Must NOT use task-context queue API in ISR
if re.search(r'\bxQueueSend\s*\(', isr_body) or re.search(r'\bxQueueGenericSend\s*\(', isr_body):
    print("ERROR: DMA ISR illegally calls task-context xQueueSend instead of FromISR API!", file=sys.stderr)
    sys.exit(1)

# Must use xQueueSendFromISR
if not re.search(r'xQueueSendFromISR\s*\(', isr_body):
    print("ERROR: DMA ISR does not call xQueueSendFromISR!", file=sys.stderr)
    sys.exit(1)

# Must initialize xHigherPriorityTaskWoken to pdFALSE / 0
wake_init = re.findall(r'xHigherPriorityTaskWoken\s*=\s*(pdFALSE|0)\b', isr_body)
if not wake_init:
    print("ERROR: DMA ISR does not initialize xHigherPriorityTaskWoken to pdFALSE/0!", file=sys.stderr)
    sys.exit(1)

# Must call portYIELD_FROM_ISR
if not re.search(r'portYIELD_FROM_ISR\s*\(\s*xHigherPriorityTaskWoken\s*\)', isr_body):
    print("ERROR: DMA ISR does not call portYIELD_FROM_ISR(xHigherPriorityTaskWoken)!", file=sys.stderr)
    sys.exit(1)

# Must emit both HT (buffer 0) and TC (buffer 1) tokens
if not re.search(r'msg\.(buffer_)?index\s*=\s*0\b', isr_body) or not re.search(r'msg\.(buffer_)?index\s*=\s*1\b', isr_body):
    print("ERROR: DMA ISR does not emit both buffer index 0 (HT) and 1 (TC) tokens!", file=sys.stderr)
    sys.exit(1)

# Must check xQueueSendFromISR return value and handle queue drops
if not re.search(r'xResult\s*==\s*pdPASS|xQueueSendFromISR\s*\(.*?\)\s*==\s*pdPASS|!=\s*pdPASS|g_acq_drops\+\+', isr_body):
    print("ERROR: DMA ISR ignores queue-full / failure return code from xQueueSendFromISR!", file=sys.stderr)
    sys.exit(1)

# Check Task Pipeline and Priorities
# Process=3, Comm=2, Compute=2, Health=1
if not re.search(r'xTaskCreate\s*\(.*?prvTaskProcess.*?TASK_PROCESS_PRIORITY', node_c, re.S) and not re.search(r'xTaskCreate\s*\(.*?prvTaskProcess.*?,\s*3\s*,', node_c, re.S):
    print("ERROR: Task_Process must be created with priority 3!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'xTaskCreate\s*\(.*?prvTaskComm.*?TASK_COMM_PRIORITY', node_c, re.S) and not re.search(r'xTaskCreate\s*\(.*?prvTaskComm.*?,\s*2\s*,', node_c, re.S):
    print("ERROR: Task_Comm must be created with priority 2!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'xTaskCreate\s*\(.*?prvTaskCompute.*?TASK_COMPUTE_PRIORITY', node_c, re.S) and not re.search(r'xTaskCreate\s*\(.*?prvTaskCompute.*?,\s*2\s*,', node_c, re.S):
    print("ERROR: Task_Compute must be created with priority 2!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'xTaskCreate\s*\(.*?prvTaskHealth.*?TASK_HEALTH_PRIORITY', node_c, re.S) and not re.search(r'xTaskCreate\s*\(.*?prvTaskHealth.*?,\s*1\s*,', node_c, re.S):
    print("ERROR: Task_Health must be created with priority 1!", file=sys.stderr)
    sys.exit(1)

# Process task must block on xAcqQueue with portMAX_DELAY
proc_task = re.search(r'void\s+prvTaskProcess\s*\(\s*void\s*\*pvParameters\s*\)\s*\{(.*?)\n\}', node_c, re.S)
if not proc_task:
    print("ERROR: prvTaskProcess not found in node_app.c!", file=sys.stderr)
    sys.exit(1)
proc_body = proc_task.group(1)

if not re.search(r'xQueueReceive\s*\(\s*xAcqQueue\s*,.*?,\s*portMAX_DELAY\s*\)', proc_body):
    print("ERROR: Task_Process does not block on xAcqQueue with portMAX_DELAY!", file=sys.stderr)
    sys.exit(1)

# Normal acquisition fast path must NOT take an application mutex
for m in re.finditer(r'xSemaphoreTake\s*\(\s*([^,]+)\s*,', proc_body):
    sem_arg = m.group(1).strip()
    if sem_arg != "g_diag_resource":
        print(f"ERROR: Application mutex illegally inserted into normal acquisition fast path: '{sem_arg}'!", file=sys.stderr)
        sys.exit(1)

# Comm task must output via direct USART1 registers
if not re.search(r'USART1->SR', usart_c) or not re.search(r'USART1->DR', usart_c):
    print("ERROR: usart.c does not access direct hardware registers USART1->SR and USART1->DR!", file=sys.stderr)
    sys.exit(1)

# Health task must NOT refresh IWDG unconditionally
health_task = re.search(r'void\s+prvTaskHealth\s*\(\s*void\s*\*pvParameters\s*\)\s*\{(.*?)\n\}', node_c, re.S)
if not health_task:
    print("ERROR: prvTaskHealth not found in node_app.c!", file=sys.stderr)
    sys.exit(1)
health_body = health_task.group(1)

if not re.search(r'if\s*\(.*?progress_ok.*?iwdg_refresh', health_body, re.S):
    print("ERROR: Health task refreshes IWDG unconditionally without checking acquisition progress!", file=sys.stderr)
    sys.exit(1)

# Steady-state memory: no dynamic allocation / creation calls outside node_app_init()
node_init_match = re.search(r'void\s+node_app_init\s*\(\s*void\s*\)\s*\{(.*?)\n\}', node_c, re.S)
if not node_init_match:
    print("ERROR: node_app_init() not found in node_app.c!", file=sys.stderr)
    sys.exit(1)

non_init_code = node_c[:node_init_match.start()] + node_c[node_init_match.end():]
if re.search(r'\b(pvPortMalloc|vPortFree|xTaskCreate|xQueueCreate|xSemaphoreCreate)\b', non_init_code):
    print("ERROR: Prohibited dynamic allocation / creation call detected outside node_app_init()!", file=sys.stderr)
    sys.exit(1)

# Stack watermark API used with sizeof(StackType_t)
if not re.search(r'uxTaskGetStackHighWaterMark.*?sizeof\s*\(\s*StackType_t\s*\)', node_c, re.S):
    print("ERROR: Stack high-water mark not converted using sizeof(StackType_t)!", file=sys.stderr)
    sys.exit(1)

# Diagnostic ordering: High notification / block opportunity MUST precede Medium release
diag_func = re.search(r'void\s+(prvRunDiagnosticComparison|node_app_run_diagnostic)\s*\(\s*void\s*\)\s*\{(.*?)\n\}', node_c, re.S)
if not diag_func:
    print("ERROR: Diagnostic comparison function not found!", file=sys.stderr)
    sys.exit(1)
diag_body = diag_func.group(2)

# Verify High release precedes Medium release in Run A
high_pos = diag_body.find("xTaskNotifyGive(g_task_process_handle)")
med_pos = diag_body.find("xTaskNotifyGive(g_task_compute_handle)")
if high_pos == -1 or med_pos == -1 or high_pos > med_pos:
    print("ERROR: Diagnostic High notification/block opportunity must precede Medium release!", file=sys.stderr)
    sys.exit(1)

# Diagnostic Low workload must strictly NOT contain vTaskDelay
low_workload = re.search(r'void\s+(?:__attribute__\(\(.*?\)\)\s+)?inversion_execute_low_workload\s*\(\s*void\s*\)\s*\{(.*?)\n\}', node_c, re.S)
if not low_workload:
    print("ERROR: inversion_execute_low_workload function not found!", file=sys.stderr)
    sys.exit(1)
if re.search(r'\bvTaskDelay\b', low_workload.group(1)):
    print("ERROR: inversion_execute_low_workload illegally contains vTaskDelay!", file=sys.stderr)
    sys.exit(1)

# DWT cycle measurement provenance:
# Stored results (run_a and run_b) must derive from DWT delta and must NOT be overwritten by tick / 0
dwt_proc = re.search(r'uint32_t\s+start_cycles\s*=\s*dwt_get_cycles\s*\(\s*\);.*?uint32_t\s+duration_cycles\s*=\s*dwt_get_cycles\s*\(\s*\)\s*-\s*start_cycles;', proc_body, re.S)
if not dwt_proc:
    print("ERROR: Task_Process does not compute duration_cycles from dwt_get_cycles() delta!", file=sys.stderr)
    sys.exit(1)

# Check all assignments to g_diag_high_wait_cycles_run_a and run_b across the file
for var_name in ["g_diag_high_wait_cycles_run_a", "g_diag_high_wait_cycles_run_b"]:
    matches = list(re.finditer(rf'{var_name}\s*=\s*([^;]+);', node_c))
    if not matches:
        print(f"ERROR: No assignment to {var_name} found in node_app.c!", file=sys.stderr)
        sys.exit(1)
    # The last assignment to var_name must be duration_cycles
    last_val = matches[-1].group(1).strip()
    if last_val != "duration_cycles":
        print(f"ERROR: {var_name} assignment provenance violated! Last assignment was '{last_val}', expected 'duration_cycles'!", file=sys.stderr)
        sys.exit(1)

PYEOF

echo "[PASS] Python source, AST, priority, and synchronization contracts verified"

# 7. Disassembly verification of peripheral base addresses
# TIM3: 0x40000400, USART1: 0x40013800, ADC1: 0x40012400, DMA1: 0x40020000, IWDG: 0x40003000, DWT: 0xE0001004
DISASM="${ASM}"

if ! grep -qiE "(40000400|0x40000400)" "${DISASM}"; then
    echo "ERROR: Disassembly missing direct register access to TIM3 at 0x40000400!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms direct register access to TIM3 (0x40000400)"

if ! grep -qiE "(40012400|0x40012400)" "${DISASM}"; then
    echo "ERROR: Disassembly missing direct register access to ADC1 at 0x40012400!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms direct register access to ADC1 (0x40012400)"

if ! grep -qiE "(40020000|0x40020000)" "${DISASM}"; then
    echo "ERROR: Disassembly missing direct register access to DMA1 at 0x40020000!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms direct register access to DMA1 (0x40020000)"

if ! grep -qiE "(40013800|0x40013800)" "${DISASM}"; then
    echo "ERROR: Disassembly missing direct register access to USART1 at 0x40013800!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms direct register access to USART1 (0x40013800)"

if ! grep -qiE "(40003000|0x40003000)" "${DISASM}"; then
    echo "ERROR: Disassembly missing direct register access to IWDG at 0x40003000!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms direct register access to IWDG (0x40003000)"

if ! grep -qiE "(e0001004|e0001000)" "${DISASM}"; then
    echo "ERROR: Disassembly missing direct access to Cortex-M3 DWT CYCCNT (0xE0001004/0xE0001000)!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms direct register access to DWT Cycle Counter (0xE0001004)"

# 8. Check that inversion_execute_low_workload in disassembly contains NO vTaskDelay
LOW_DISASM=$(awk '/<inversion_execute_low_workload>:/ {flag=1} flag && !/<inversion_execute_low_workload>:/ && /^[0-9a-f]+ </ {flag=0} flag {print}' "${DISASM}")
if echo "${LOW_DISASM}" | grep -qE "b[l]?(\.w)?.*<vTaskDelay>"; then
    echo "ERROR: Disassembly reveals vTaskDelay call inside inversion_execute_low_workload!" >&2
    exit 1
fi
echo "[PASS] Disassembly confirms inversion_execute_low_workload is purely CPU-runnable without vTaskDelay"

echo "[NOTE] Physical hardware timing, logic analyzer waveforms, and GDB register dumps: DESIGN TARGET / UNVERIFIED"
echo "=== ALL P2-M07 STATIC & ARCHITECTURAL CONTRACT CHECKS PASSED ==="
