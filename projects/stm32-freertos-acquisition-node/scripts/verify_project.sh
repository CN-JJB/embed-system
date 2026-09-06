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
            elif [ -f "${TEMP_BUILD_DIR}/${fname}" ]; then
                cp "$f" "${TEMP_BUILD_DIR}/${fname}"
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
node_h = read_clean_file(os.path.join(work_dir, "include/node_app.h"))

# Check Priority Grouping: NVIC_SetPriorityGrouping(0)
if not re.search(r'NVIC_SetPriorityGrouping\s*\(\s*0\s*\)', main_c):
    print("ERROR: main.c must configure NVIC_SetPriorityGrouping(0) for FreeRTOS!", file=sys.stderr)
    sys.exit(1)

# Check TIM3 TRGO configuration: 1 kHz update rate & TRGO on update
if not re.search(r'TIM_CR2_MMS_1|TIM_CR2_MMS\s*=\s*0?x?0?2|0b010', timer_c):
    print("ERROR: timer.c does not set TIM3 TRGO output to Update event (MMS=010)!", file=sys.stderr)
    sys.exit(1)

# Check TIM3 ARR / PSC formula (F7)
psc_ok = re.search(r'TIM3->PSC\s*=\s*.*?tim_clock_hz', timer_c) or (re.search(r'psc\s*=\s*.*?tim_clock_hz', timer_c) and re.search(r'TIM3->PSC\s*=\s*psc', timer_c))
arr_ok = re.search(r'TIM3->ARR\s*=\s*999\b', timer_c) or (re.search(r'arr\s*=\s*.*?(999|1000000|1000\b)', timer_c) and re.search(r'TIM3->ARR\s*=\s*arr\b', timer_c))
if not (psc_ok and arr_ok):
    print("ERROR: timer.c must compute TIM3 PSC dynamically from tim_clock_hz and ARR to 999 (1 kHz)!", file=sys.stderr)
    sys.exit(1)

# Check ADC1 Trigger & Prescaler: EXTSEL=100 (TIM3 TRGO), EXTTRIG=1, DMA=1, ADCPRE=/6, SMP0=55.5 cycles (F7)
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

# ADC SMP0 55.5 cycles: SMP0_0 and SMP0_2 bits set
if not ((re.search(r'ADC_SMPR2_SMP0_0', adc_c) and re.search(r'ADC_SMPR2_SMP0_2', adc_c)) or re.search(r'0b101|0x05', adc_c)):
    print("ERROR: adc.c does not configure PA0 SMP0 to 55.5 cycles (SMP0[2:0] = 101)!", file=sys.stderr)
    sys.exit(1)

# ADC bounded calibration loops (F7)
if not re.search(r'while\s*\(\s*\(?\s*ADC1->CR2\s*&\s*ADC_CR2_RSTCAL.*?\)\s*\{[^}]*timeout', adc_c, re.S) or \
   not re.search(r'while\s*\(\s*\(?\s*ADC1->CR2\s*&\s*ADC_CR2_CAL.*?\)\s*\{[^}]*timeout', adc_c, re.S):
    print("ERROR: adc.c must use bounded timeout loops for RSTCAL and CAL calibration!", file=sys.stderr)
    sys.exit(1)

# Check DMA1 Channel 1 Circular Mode and Configuration (F7)
if not re.search(r'DMA_CCR_CIRC', dma_c):
    print("ERROR: dma.c does not enable DMA circular mode (DMA_CCR_CIRC)!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'DMA_CCR_MINC', dma_c):
    print("ERROR: dma.c does not enable memory increment (DMA_CCR_MINC)!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'DMA1_Channel1->CNDTR\s*=\s*(128|ADC_BUFFER_TOTAL_SIZE)\b', dma_c):
    print("ERROR: dma.c must configure DMA1_Channel1->CNDTR = 128 (ADC_BUFFER_TOTAL_SIZE)!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'DMA_CCR_PSIZE_0', dma_c) or not re.search(r'DMA_CCR_MSIZE_0', dma_c):
    print("ERROR: dma.c must configure 16-bit PSIZE and MSIZE for ADC halfword transfers!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'DMA_CCR_HTIE', dma_c) or not re.search(r'DMA_CCR_TCIE', dma_c):
    print("ERROR: dma.c must enable both HTIE and TCIE interrupts!", file=sys.stderr)
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

# F4: Wake flag last write before FromISR send must be pdFALSE / 0
send_positions = [m.start() for m in re.finditer(r'xQueueSendFromISR\b', isr_body)]
if not send_positions:
    print("ERROR: No xQueueSendFromISR call found in DMA ISR!", file=sys.stderr)
    sys.exit(1)
for pos in send_positions:
    prefix = isr_body[:pos]
    assigns = list(re.finditer(r'xHigherPriorityTaskWoken\s*=\s*([^;]+);', prefix))
    if assigns:
        last_val = assigns[-1].group(1).strip()
        if last_val not in ["pdFALSE", "0"]:
            print(f"ERROR: xHigherPriorityTaskWoken last set to '{last_val}' before xQueueSendFromISR (must be pdFALSE/0)!", file=sys.stderr)
            sys.exit(1)

# Must call portYIELD_FROM_ISR
if not re.search(r'portYIELD_FROM_ISR\s*\(\s*xHigherPriorityTaskWoken\s*\)', isr_body):
    print("ERROR: DMA ISR does not call portYIELD_FROM_ISR(xHigherPriorityTaskWoken)!", file=sys.stderr)
    sys.exit(1)

# F6: HTIF1 and TCIF1 branch bindings
ht_match = re.search(r'if\s*\(\s*isr\s*&\s*DMA_ISR_HTIF1\s*\)\s*\{(.*?)\n\s*\}', isr_body, re.S)
if not ht_match:
    print("ERROR: DMA1 ISR missing HTIF1 check!", file=sys.stderr)
    sys.exit(1)
ht_body = ht_match.group(1)
if not re.search(r'DMA_IFCR_CHTIF1', ht_body):
    print("ERROR: HTIF1 branch does not clear flag with DMA_IFCR_CHTIF1!", file=sys.stderr)
    sys.exit(1)
if re.search(r'DMA_IFCR_CTCIF1', ht_body):
    print("ERROR: HTIF1 branch illegally references DMA_IFCR_CTCIF1!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'msg\.(buffer_)?index\s*=\s*0\b', ht_body):
    print("ERROR: HTIF1 branch must emit buffer index 0!", file=sys.stderr)
    sys.exit(1)
if re.search(r'msg\.(buffer_)?index\s*=\s*1\b', ht_body):
    print("ERROR: HTIF1 branch illegally emits buffer index 1!", file=sys.stderr)
    sys.exit(1)

tc_match = re.search(r'if\s*\(\s*isr\s*&\s*DMA_ISR_TCIF1\s*\)\s*\{(.*?)\n\s*\}', isr_body, re.S)
if not tc_match:
    print("ERROR: DMA1 ISR missing TCIF1 check!", file=sys.stderr)
    sys.exit(1)
tc_body = tc_match.group(1)
if not re.search(r'DMA_IFCR_CTCIF1', tc_body):
    print("ERROR: TCIF1 branch does not clear flag with DMA_IFCR_CTCIF1!", file=sys.stderr)
    sys.exit(1)
if re.search(r'DMA_IFCR_CHTIF1', tc_body):
    print("ERROR: TCIF1 branch illegally references DMA_IFCR_CHTIF1!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'msg\.(buffer_)?index\s*=\s*1\b', tc_body):
    print("ERROR: TCIF1 branch must emit buffer index 1!", file=sys.stderr)
    sys.exit(1)
if re.search(r'msg\.(buffer_)?index\s*=\s*0\b', tc_body):
    print("ERROR: TCIF1 branch illegally emits buffer index 0!", file=sys.stderr)
    sys.exit(1)

# F5: Must check xQueueSendFromISR return value and bind g_acq_drops++ strictly to failure path
drops_in_success = re.search(r'xResult\s*==\s*pdPASS\s*\)\s*\{[^}]*g_acq_drops\+\+', isr_body, re.S)
if drops_in_success:
    print("ERROR: g_acq_drops++ illegally present in xResult == pdPASS success branch!", file=sys.stderr)
    sys.exit(1)
drops_in_fail = re.search(r'(else\s*\{[^}]*g_acq_drops\+\+|!=\s*pdPASS\s*\)\s*\{[^}]*g_acq_drops\+\+)', isr_body, re.S)
if not drops_in_fail:
    print("ERROR: g_acq_drops++ must be incremented on xQueueSendFromISR failure!", file=sys.stderr)
    sys.exit(1)

# F1: Check Task Priority Macros and exact xTaskCreate bindings
# Check macro definitions in node_h
m_prio = re.search(r'#define\s+TASK_PROCESS_PRIORITY\s+([0-9]+)', node_h)
if not m_prio or int(m_prio.group(1)) != 3:
    print("ERROR: TASK_PROCESS_PRIORITY must be defined as 3 in node_app.h!", file=sys.stderr)
    sys.exit(1)
m_prio = re.search(r'#define\s+TASK_COMM_PRIORITY\s+([0-9]+)', node_h)
if not m_prio or int(m_prio.group(1)) != 2:
    print("ERROR: TASK_COMM_PRIORITY must be defined as 2 in node_app.h!", file=sys.stderr)
    sys.exit(1)
m_prio = re.search(r'#define\s+TASK_COMPUTE_PRIORITY\s+([0-9]+)', node_h)
if not m_prio or int(m_prio.group(1)) != 2:
    print("ERROR: TASK_COMPUTE_PRIORITY must be defined as 2 in node_app.h!", file=sys.stderr)
    sys.exit(1)
m_prio = re.search(r'#define\s+TASK_HEALTH_PRIORITY\s+([0-9]+)', node_h)
if not m_prio or int(m_prio.group(1)) != 1:
    print("ERROR: TASK_HEALTH_PRIORITY must be defined as 1 in node_app.h!", file=sys.stderr)
    sys.exit(1)

# Check xTaskCreate calls binding task functions, priority macros, and handles:
if not re.search(r'xTaskCreate\s*\(\s*prvTaskProcess\s*,[^,]+,[^,]+,[^,]+,\s*(TASK_PROCESS_PRIORITY|3)\s*,\s*&g_task_process_handle\s*\)', node_c):
    print("ERROR: xTaskCreate for prvTaskProcess must bind TASK_PROCESS_PRIORITY and &g_task_process_handle!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'xTaskCreate\s*\(\s*prvTaskComm\s*,[^,]+,[^,]+,[^,]+,\s*(TASK_COMM_PRIORITY|2)\s*,\s*&g_task_comm_handle\s*\)', node_c):
    print("ERROR: xTaskCreate for prvTaskComm must bind TASK_COMM_PRIORITY and &g_task_comm_handle!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'xTaskCreate\s*\(\s*prvTaskCompute\s*,[^,]+,[^,]+,[^,]+,\s*(TASK_COMPUTE_PRIORITY|2)\s*,\s*&g_task_compute_handle\s*\)', node_c):
    print("ERROR: xTaskCreate for prvTaskCompute must bind TASK_COMPUTE_PRIORITY and &g_task_compute_handle!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'xTaskCreate\s*\(\s*prvTaskHealth\s*,[^,]+,[^,]+,[^,]+,\s*(TASK_HEALTH_PRIORITY|1)\s*,\s*&g_task_health_handle\s*\)', node_c):
    print("ERROR: xTaskCreate for prvTaskHealth must bind TASK_HEALTH_PRIORITY and &g_task_health_handle!", file=sys.stderr)
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

# F2: Normal acquisition fast path must NOT take an application mutex
acq_recv_match = re.search(r'if\s*\(\s*xQueueReceive\s*\(\s*xAcqQueue.*?\)\s*==\s*pdPASS\s*\)\s*\{(.*?)\n\s*\}', proc_body, re.S)
if acq_recv_match:
    acq_body = acq_recv_match.group(1)
    if re.search(r'xSemaphoreTake\b|xMutexTake\b', acq_body):
        print("ERROR: Mutex / Semaphore take illegally placed inside sample processing loop in Task_Process!", file=sys.stderr)
        sys.exit(1)

for m in re.finditer(r'xSemaphoreTake\s*\(\s*([^,]+)\s*,', proc_body):
    sem_arg = m.group(1).strip()
    if sem_arg != "g_diag_resource":
        print(f"ERROR: Application mutex illegally inserted into normal acquisition fast path: '{sem_arg}'!", file=sys.stderr)
        sys.exit(1)

# Comm task must output via direct USART1 registers
if not re.search(r'USART1->SR', usart_c) or not re.search(r'USART1->DR', usart_c):
    print("ERROR: usart.c does not access direct hardware registers USART1->SR and USART1->DR!", file=sys.stderr)
    sys.exit(1)

# F8: USART BRR calculation and dynamic clock usage
if re.search(r'72000000', usart_c):
    print("ERROR: usart.c must not hardcode 72000000; must use dynamic pclk2_hz parameter!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'USART1->BRR\s*=\s*\(?\s*pclk2_hz\s*\+\s*\(?\s*(baud\s*/\s*2U?|57600U?)\s*\)?\s*\)?\s*/\s*(baud|115200U?)', usart_c):
    print("ERROR: usart.c does not implement rounded BRR calculation (pclk2_hz + baud/2) / baud!", file=sys.stderr)
    sys.exit(1)

# F8: main.c clock configuration, HSE fallback to HSI, and dynamic frequencies
if not re.search(r'clock_init\s*\(\s*CLOCK_PROFILE_72MHZ_HSE\s*\)', main_c) or \
   not re.search(r'clock_init\s*\(\s*CLOCK_PROFILE_64MHZ_HSI\s*\)', main_c):
    print("ERROR: main.c must attempt CLOCK_PROFILE_72MHZ_HSE and fall back to CLOCK_PROFILE_64MHZ_HSI!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'clock_get_frequencies\s*\(\s*&freqs\s*\)', main_c):
    print("ERROR: main.c must retrieve dynamic peripheral bus frequencies via clock_get_frequencies(&freqs)!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'usart1_init\s*\(\s*freqs\.pclk2_hz\s*\)', main_c) or \
   not re.search(r'adc1_init\s*\(\s*freqs\.pclk2_hz\s*\)', main_c) or \
   not re.search(r'tim3_trgo_init_1khz\s*\(\s*freqs\.timclk1_hz\s*\)', main_c):
    print("ERROR: main.c must pass dynamic frequencies freqs.pclk2_hz and freqs.timclk1_hz to peripheral drivers!", file=sys.stderr)
    sys.exit(1)

# F8 / F10: main.c IWDG prescaler /32 and reload <= 1500 (<= 1200 ms timeout), and checked return
if not re.search(r'iwdg_init\s*\(\s*(IWDG_PRESCALER_32|0x03|3)\s*,\s*([0-9]+)\s*\)', main_c):
    print("ERROR: main.c must configure IWDG with prescaler /32!", file=sys.stderr)
    sys.exit(1)
iwdg_m = re.search(r'iwdg_init\s*\(\s*(?:IWDG_PRESCALER_32|0x03|3)\s*,\s*([0-9]+)\s*\)', main_c)
if iwdg_m and int(iwdg_m.group(1)) > 1500:
    print("ERROR: IWDG reload value exceeds 1200 ms design target timeout!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'if\s*\(\s*!\s*iwdg_init\b', main_c):
    print("ERROR: main.c does not check return value of iwdg_init()!", file=sys.stderr)
    sys.exit(1)

# F3: Health task must gate IWDG refresh behind progress_ok && stack_ok && heap_ok
health_task = re.search(r'void\s+prvTaskHealth\s*\(\s*void\s*\*pvParameters\s*\)\s*\{(.*?)\n\}', node_c, re.S)
if not health_task:
    print("ERROR: prvTaskHealth not found in node_app.c!", file=sys.stderr)
    sys.exit(1)
health_body = health_task.group(1)

iwdg_gate = re.search(r'if\s*\((.*?)\)\s*\{[^{}]*iwdg_refresh\s*\(\s*\);', health_body, re.S)
if not iwdg_gate:
    print("ERROR: Health task does not guard iwdg_refresh inside an if condition!", file=sys.stderr)
    sys.exit(1)
gate_cond = iwdg_gate.group(1)
if not (re.search(r'\bprogress_ok\b', gate_cond) and re.search(r'\bstack_ok\b', gate_cond) and re.search(r'\bheap_ok\b', gate_cond)):
    print("ERROR: Health task must gate iwdg_refresh on all three audits: progress_ok && stack_ok && heap_ok!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'g_steady_free_heap', health_body) or not re.search(r'g_steady_min_ever_heap', health_body):
    print("ERROR: Health task must check steady-state heap baseline g_steady_free_heap and g_steady_min_ever_heap!", file=sys.stderr)
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

# Deterministic High abort: xTaskAbortDelay called and asserted pdPASS
if not re.search(r'xTaskAbortDelay\s*\(\s*g_task_process_handle\s*\)', diag_body):
    print("ERROR: Diagnostic comparison must call xTaskAbortDelay(g_task_process_handle)!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'configASSERT\s*\(\s*(xRes\s*==\s*pdPASS|xTaskAbortDelay\s*\(\s*g_task_process_handle\s*\)\s*==\s*pdPASS)\s*\)', diag_body):
    print("ERROR: Diagnostic comparison must assert that xTaskAbortDelay returns pdPASS!", file=sys.stderr)
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

# F9: Source Pin Metadata Validation in SOURCE_LEDGER.md
ledger_path = os.path.join(work_dir, "SOURCE_LEDGER.md")
if not os.path.exists(ledger_path):
    ledger_path = os.path.join(os.path.dirname(work_dir), "SOURCE_LEDGER.md")
if os.path.exists(ledger_path):
    ledger_txt = open(ledger_path, "r", encoding="utf-8", errors="ignore").read()
    if not re.search(r'9b777ae5', ledger_txt):
        print("ERROR: SOURCE_LEDGER.md missing FreeRTOS kernel pin commit 9b777ae5!", file=sys.stderr)
        sys.exit(1)
    if not re.search(r'2b7495b8', ledger_txt):
        print("ERROR: SOURCE_LEDGER.md missing CMSIS_5 pin commit 2b7495b8!", file=sys.stderr)
        sys.exit(1)
    if not re.search(r'8a76309e', ledger_txt):
        print("ERROR: SOURCE_LEDGER.md missing cmsis-device-f1 pin commit 8a76309e!", file=sys.stderr)
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
