#!/usr/bin/env bash
# ==============================================================================
# verify_project.sh: Automated Static, Architectural & Contract Validator
# for Phase 2 P2-M07 STM32 FreeRTOS Acquisition Node Integration Project
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUILD_ONLY=0
TARGET_ARG="${PROJECT_DIR}"

for arg in "$@"; do
    if [ "$arg" = "--build-only" ]; then
        BUILD_ONLY=1
    elif [ -d "$arg" ]; then
        TARGET_ARG="$arg"
    fi
done

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

if [ "${BUILD_ONLY}" -eq 1 ]; then
    echo "[PASS] Target compilation and link succeeded (--build-only)"
    exit 0
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

def extract_brace_block(text, start_pos):
    open_pos = text.find('{', start_pos)
    if open_pos == -1:
        return None, -1
    depth = 0
    in_single = False
    in_double = False
    for i in range(open_pos, len(text)):
        c = text[i]
        if c == "'" and not in_double:
            in_single = not in_single
        elif c == '"' and not in_single:
            in_double = not in_double
        elif not in_single and not in_double:
            if c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    return text[open_pos+1:i], i + 1
    return None, -1

main_c = read_clean_file(os.path.join(work_dir, "src/main.c"))
dma_c = read_clean_file(os.path.join(work_dir, "src/dma.c"))
dma_h = read_clean_file(os.path.join(work_dir, "include/dma.h"))
adc_c = read_clean_file(os.path.join(work_dir, "src/adc.c"))
timer_c = read_clean_file(os.path.join(work_dir, "src/timer.c"))
usart_c = read_clean_file(os.path.join(work_dir, "src/usart.c"))
iwdg_c = read_clean_file(os.path.join(work_dir, "src/iwdg.c"))
node_c = read_clean_file(os.path.join(work_dir, "src/node_app.c"))
node_h = read_clean_file(os.path.join(work_dir, "include/node_app.h"))

asm_txt = ""
if os.path.exists(asm_path):
    with open(asm_path, "r", encoding="utf-8", errors="ignore") as f:
        asm_txt = f.read()

# Check Priority Grouping: NVIC_SetPriorityGrouping(0)
if not re.search(r'NVIC_SetPriorityGrouping\s*\(\s*0\s*\)', main_c):
    print("ERROR: main.c must configure NVIC_SetPriorityGrouping(0) for FreeRTOS!", file=sys.stderr)
    sys.exit(1)

# Check TIM3 ARR / PSC formula
psc_ok = re.search(r'TIM3->PSC\s*=\s*.*?tim_clock_hz', timer_c) or (re.search(r'psc\s*=\s*.*?tim_clock_hz', timer_c) and re.search(r'TIM3->PSC\s*=\s*psc', timer_c))
arr_ok = re.search(r'TIM3->ARR\s*=\s*999\b', timer_c) or (re.search(r'arr\s*=\s*.*?(999|1000000|1000\b)', timer_c) and re.search(r'TIM3->ARR\s*=\s*arr\b', timer_c))
if not (psc_ok and arr_ok):
    print("ERROR: timer.c must compute TIM3 PSC dynamically from tim_clock_hz and ARR to 999 (1 kHz)!", file=sys.stderr)
    sys.exit(1)

# TIM3 Preload: Reject both MMS=000 (Reset mode where UG emits TRGO) and MMS=010 (Update mode) during init
init_match = re.search(r'void\s+tim3_trgo_init_1khz\s*\([^)]*\)\s*\{', timer_c)
if not init_match:
    print("ERROR: tim3_trgo_init_1khz not found in timer.c!", file=sys.stderr)
    sys.exit(1)
init_body, _ = extract_brace_block(timer_c, init_match.start())
if not init_body:
    print("ERROR: Failed to extract tim3_trgo_init_1khz body!", file=sys.stderr)
    sys.exit(1)

ug_pos = init_body.find("TIM_EGR_UG")
if ug_pos == -1:
    print("ERROR: tim3_trgo_init_1khz missing TIM_EGR_UG shadow preload!", file=sys.stderr)
    sys.exit(1)
init_prefix = init_body[:ug_pos]

# Bind actual pre-UG TIM3->CR2 register write to effective MMS=001:
# Must reject MMS=010 (Update mode leak)
# Must reject MMS=000 (Reset mode leak per RM0008)
# Must reject decoy/standalone TIM_CR2_MMS_0 tokens that are not part of TIM3->CR2 write!
# Must perform ordered analysis of MMS writes and reject any subsequent clear or overwrite before UG!

cr2_writes = list(re.finditer(r'TIM3->CR2\s*([|&=^]?=)\s*([^;]+);', init_prefix))
if not cr2_writes:
    print("ERROR: tim3_trgo_init_1khz does not configure TIM3->CR2 before EGR_UG!", file=sys.stderr)
    sys.exit(1)

# Ordered analysis of MMS field state leading up to TIM_EGR_UG
# Possible states: '000' (Reset), '001' (Enable), '010' (Update), 'OTHER', 'UNKNOWN'
effective_mms = "000"

for w in cr2_writes:
    op = w.group(1)
    rhs = w.group(2).strip()

    has_mms1 = bool(re.search(r'TIM_CR2_MMS_1\b|0b010\b|(?<![0-9a-zA-Z_])0x20\b', rhs))
    has_mms2 = bool(re.search(r'TIM_CR2_MMS_2\b|0b100\b|(?<![0-9a-zA-Z_])0x40\b', rhs))
    has_mms0 = bool(re.search(r'TIM_CR2_MMS_0\b|0b001\b|(?<![0-9a-zA-Z_])0x10\b', rhs))
    clears_mms = bool(re.search(r'~(?:TIM_CR2_MMS\b|0x70\b|112\b|0b1110000\b)', rhs) or re.search(r'0xffffff8f|0xFFFFFF8F', rhs))

    if op == '&=':
        if clears_mms:
            effective_mms = "000"
        else:
            # Masking other bits leaves MMS unchanged
            pass
    elif op == '|=':
        if has_mms1:
            effective_mms = "010"
        elif has_mms2:
            effective_mms = "OTHER"
        elif has_mms0:
            if effective_mms in ("000", "001"):
                effective_mms = "001"
            else:
                effective_mms = "OTHER"
        else:
            # Setting non-MMS bits leaves MMS unchanged
            pass
    elif op == '=':
        if has_mms1:
            effective_mms = "010"
        elif has_mms2:
            effective_mms = "OTHER"
        elif has_mms0:
            if not has_mms1 and not has_mms2:
                effective_mms = "001"
            else:
                effective_mms = "OTHER"
        elif clears_mms:
            effective_mms = "000"
        elif rhs in ("0", "0U", "0x0", "0x00"):
            effective_mms = "000"
        else:
            effective_mms = "UNKNOWN"
    else:
        effective_mms = "UNKNOWN"

if effective_mms != "001":
    if effective_mms == "010":
        print("ERROR: tim3_trgo_init_1khz sets/leaves effective MMS=Update (010) before EGR_UG, causing trigger leak to ADC1 before diagnostic!", file=sys.stderr)
    elif effective_mms == "000":
        print("ERROR: tim3_trgo_init_1khz leaves effective MMS=Reset (000) before EGR_UG, which drives TRGO on STM32F1! Effective MMS must resolve to 001 (Enable mode with CEN=0).", file=sys.stderr)
    else:
        print(f"ERROR: tim3_trgo_init_1khz leaves invalid/unknown effective MMS ({effective_mms}) before EGR_UG! Effective MMS must resolve to 001 (Enable mode with CEN=0).", file=sys.stderr)
    sys.exit(1)

# Disassembly check of tim3_trgo_init_1khz for effective MMS=001 (bit 4 set in final CR2 write before EGR_UG)
if asm_txt:
    t_match = re.search(r'<tim3_trgo_init_1khz>:(.*?)(?:\n[0-9a-fA-F]+ <|\Z)', asm_txt, re.S)
    if t_match:
        t_asm = t_match.group(1)
        egr_match = re.search(r'str(?:\.w)?\s+r[0-9]+,\s*\[r[0-9]+,\s*#(?:20|0x14)\]', t_asm)
        egr_pos = egr_match.start() if egr_match else t_asm.find("[r2, #20]")
        if egr_pos == -1:
            egr_pos = len(t_asm)
        t_prefix = t_asm[:egr_pos]

        # Find all stores to TIM3->CR2 (offset 4) before EGR store
        cr2_stores = list(re.finditer(r'str(?:\.w)?\s+(r[0-9]+),\s*\[r[0-9]+,\s*#(?:4|0x04)\]', t_prefix))
        if not cr2_stores:
            print("ERROR: Disassembly of tim3_trgo_init_1khz does not show any write to TIM3->CR2 before EGR_UG!", file=sys.stderr)
            sys.exit(1)

        # The last store to TIM3->CR2 before EGR must store a register with MMS=001 (bit 4 set / 16)
        last_cr2_store = cr2_stores[-1]
        stored_reg = last_cr2_store.group(1)
        prev_pos = cr2_stores[-2].end() if len(cr2_stores) > 1 else 0
        last_store_segment = t_prefix[prev_pos:last_cr2_store.start()]

        bit4_match = re.search(rf'orr(?:\.w)?\s+{stored_reg},\s*[a-z0-9]+,\s*#16\b|mov[w|s]?\s+{stored_reg},\s*#(?:16|0x10)\b', last_store_segment)
        has_effective_bit4 = False
        if bit4_match:
            post_bit4 = last_store_segment[bit4_match.end():]
            if re.search(rf'bic(?:\.w)?\s+{stored_reg},\s*.*#(?:112|0x70)\b|mov[w|s]?\s+{stored_reg},\s*#0\b', post_bit4):
                has_effective_bit4 = False
            elif re.search(rf'orr(?:\.w)?\s+{stored_reg},\s*.*#(?:32|0x20)\b', post_bit4):
                has_effective_bit4 = False
            else:
                has_effective_bit4 = True

        if not has_effective_bit4:
            print("ERROR: Disassembly of tim3_trgo_init_1khz does not show effective MMS=001 (bit 4 set) in final TIM3->CR2 write before EGR_UG!", file=sys.stderr)
            sys.exit(1)

if re.search(r'TIM_CR1_CEN', init_body):
    print("ERROR: tim3_trgo_init_1khz must not enable TIM_CR1_CEN! Counter must only start via tim3_trgo_start() after diagnostics!", file=sys.stderr)
    sys.exit(1)

# tim3_trgo_start must configure MMS=Update (MMS_1) and enable CEN
start_match = re.search(r'void\s+tim3_trgo_start\s*\([^)]*\)\s*\{', timer_c)
if not start_match:
    print("ERROR: tim3_trgo_start not found in timer.c!", file=sys.stderr)
    sys.exit(1)
start_body, _ = extract_brace_block(timer_c, start_match.start())
if not start_body or not re.search(r'TIM_CR2_MMS_1|0b010', start_body) or not re.search(r'TIM_CR1_CEN', start_body):
    print("ERROR: tim3_trgo_start must configure MMS=Update and enable CEN!", file=sys.stderr)
    sys.exit(1)

# tim3_trgo_start must NOT be called in main.c
if re.search(r'\btim3_trgo_start\s*\(', main_c):
    print("ERROR: tim3_trgo_start() illegally called in main.c before diagnostic completion!", file=sys.stderr)
    sys.exit(1)

# tim3_trgo_start must be called strictly after prvRunDiagnosticComparison in node_app.c
diag_call_pos = node_c.find("prvRunDiagnosticComparison()")
start_call_pos = node_c.find("tim3_trgo_start()")
if start_call_pos == -1:
    print("ERROR: tim3_trgo_start() is never called in node_app.c!", file=sys.stderr)
    sys.exit(1)
if diag_call_pos != -1 and start_call_pos < diag_call_pos:
    print("ERROR: tim3_trgo_start() called before prvRunDiagnosticComparison()! Timer must only start after diagnostic completes!", file=sys.stderr)
    sys.exit(1)

# ADC1 Trigger, Prescaler, Calibration
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

# ADC SMP0 exact register write binding (55.5 cycles = 101b = 5)
# Must reject decoy-token references that write wrong values into ADC1->SMPR2
smpr2_writes = list(re.finditer(r'ADC1->SMPR2\s*\|?=\s*([^;]+);', adc_c))
smp0_bound_correctly = False
for m in smpr2_writes:
    rhs = m.group(1).strip()
    has_0 = "ADC_SMPR2_SMP0_0" in rhs
    has_2 = "ADC_SMPR2_SMP0_2" in rhs
    has_1 = "ADC_SMPR2_SMP0_1" in rhs
    # Check if RHS directly or via macros specifies 101b without bit 1
    if (has_0 and has_2 and not has_1) or ("0b101" in rhs) or (rhs == "5") or (rhs == "0x5"):
        smp0_bound_correctly = True
        break
if not smp0_bound_correctly:
    print("ERROR: adc.c does not bind exact SMP0=101 (55.5 cycles) to ADC1->SMPR2 write! Decoy tokens rejected.", file=sys.stderr)
    sys.exit(1)

# Disassembly check of adc1_init for SMP0=5
if asm_txt:
    adc_match = re.search(r'<adc1_init>:(.*?)(?:\n[0-9a-fA-F]+ <|\Z)', asm_txt, re.S)
    if adc_match and not re.search(r'orr(?:\.w)?\s+r[0-9]+,\s*r[0-9]+,\s*#5\b', adc_match.group(1)):
        print("ERROR: Disassembly of adc1_init does not show SMP0 configured to 5 (101b / 55.5 cycles)!", file=sys.stderr)
        sys.exit(1)

# ADC bounded calibration loops
if not re.search(r'while\s*\(\s*\(?\s*ADC1->CR2\s*&\s*ADC_CR2_RSTCAL.*?\)\s*\{[^}]*timeout', adc_c, re.S) or \
   not re.search(r'while\s*\(\s*\(?\s*ADC1->CR2\s*&\s*ADC_CR2_CAL.*?\)\s*\{[^}]*timeout', adc_c, re.S):
    print("ERROR: adc.c must use bounded timeout loops for RSTCAL and CAL calibration!", file=sys.stderr)
    sys.exit(1)

# DMA Channel 1 Configuration & Exact Width / CNDTR Register Bindings
if not re.search(r'DMA_CCR_CIRC', dma_c) or not re.search(r'DMA_CCR_MINC', dma_c):
    print("ERROR: dma.c does not enable CIRC and MINC!", file=sys.stderr)
    sys.exit(1)

# Check exact CNDTR assignment in dma.c and buffer sizes in dma.h
half_match = re.search(r'#define\s+ADC_BUFFER_HALF_SIZE\s+([0-9]+)', dma_h)
if not half_match or int(half_match.group(1)) != 64:
    print("ERROR: include/dma.h must define ADC_BUFFER_HALF_SIZE as 64!", file=sys.stderr)
    sys.exit(1)
total_match = re.search(r'#define\s+ADC_BUFFER_TOTAL_SIZE\s+([0-9]+|(?:\(?\s*ADC_BUFFER_HALF_SIZE\s*\*\s*2U?\s*\)?))', dma_h)
if not total_match:
    print("ERROR: include/dma.h must define ADC_BUFFER_TOTAL_SIZE as 128!", file=sys.stderr)
    sys.exit(1)
if total_match.group(1).isdigit() and int(total_match.group(1)) != 128:
    print("ERROR: include/dma.h ADC_BUFFER_TOTAL_SIZE must be 128!", file=sys.stderr)
    sys.exit(1)

cndtr_match = re.search(r'DMA1_Channel1->CNDTR\s*=\s*([^;]+);', dma_c)
if not cndtr_match:
    print("ERROR: dma.c missing DMA1_Channel1->CNDTR assignment!", file=sys.stderr)
    sys.exit(1)
cndtr_val = cndtr_match.group(1).strip()
if cndtr_val not in ["ADC_BUFFER_TOTAL_SIZE", "128", "128U", "(ADC_BUFFER_HALF_SIZE * 2U)", "(ADC_BUFFER_HALF_SIZE * 2)"]:
    print(f"ERROR: DMA1_Channel1->CNDTR assigned '{cndtr_val}' instead of ADC_BUFFER_TOTAL_SIZE (128)! Decoy tokens rejected.", file=sys.stderr)
    sys.exit(1)

# Check exact DMA CCR write binding (PSIZE=01, MSIZE=01)
ccr_assign_match = re.search(r'DMA1_Channel1->CCR\s*=\s*([^;]+);', dma_c)
if not ccr_assign_match:
    print("ERROR: dma.c missing DMA1_Channel1->CCR configuration assignment!", file=sys.stderr)
    sys.exit(1)
ccr_expr = ccr_assign_match.group(1)
if "DMA_CCR_PSIZE_0" not in ccr_expr or "DMA_CCR_MSIZE_0" not in ccr_expr:
    print("ERROR: DMA1_Channel1->CCR assignment does not configure 16-bit PSIZE and MSIZE! Decoy tokens rejected.", file=sys.stderr)
    sys.exit(1)
if "DMA_CCR_PSIZE_1" in ccr_expr or "DMA_CCR_MSIZE_1" in ccr_expr:
    print("ERROR: DMA1_Channel1->CCR assignment configures 32-bit PSIZE/MSIZE!", file=sys.stderr)
    sys.exit(1)

# Disassembly check of dma1_channel1_init for CCR bits and CNDTR value
if asm_txt:
    dma_match = re.search(r'<dma1_channel1_init>:(.*?)(?:\n[0-9a-fA-F]+ <|\Z)', asm_txt, re.S)
    if dma_match:
        d_asm = dma_match.group(1)
        # Check CCR value has bit 8 (0x100) and bit 10 (0x400) set, bits 9 and 11 clear
        ccr_found = False
        for mov_m in re.finditer(r'mov[w|s]?\s+r[0-9]+,\s*#([0-9]+)', d_asm):
            val = int(mov_m.group(1))
            if ((val >> 8) & 3) == 1 and ((val >> 10) & 3) == 1:
                ccr_found = True
                break
        if not ccr_found:
            print("ERROR: Disassembly of dma1_channel1_init does not show 16-bit PSIZE/MSIZE configured in CCR!", file=sys.stderr)
            sys.exit(1)
        if not re.search(r'mov[s]?\s+r[0-9]+,\s*#128\b', d_asm):
            print("ERROR: Disassembly of dma1_channel1_init does not show CNDTR loaded with 128!", file=sys.stderr)
            sys.exit(1)

if not re.search(r'DMA_CCR_HTIE', dma_c) or not re.search(r'DMA_CCR_TCIE', dma_c):
    print("ERROR: dma.c must enable both HTIE and TCIE interrupts!", file=sys.stderr)
    sys.exit(1)

# DMA pool static persistence and CMAR binding
if not re.search(r'(volatile\s+)?uint16_t\s+g_adc_pool\s*\[\s*2\s*\]\s*\[\s*(64|ADC_BUFFER_HALF_SIZE)\s*\]', dma_c):
    print("ERROR: dma.c missing persistent static storage uint16_t g_adc_pool[2][64]!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'DMA1_Channel1->CMAR\s*=\s*\(uint32_t\)\s*g_adc_pool\b', dma_c):
    print("ERROR: DMA1 Channel 1 destination address does not bind to persistent pool g_adc_pool!", file=sys.stderr)
    sys.exit(1)

# DMA IRQ priority
prio_match = re.search(r'NVIC_SetPriority\s*\(\s*DMA1_Channel1_IRQn\s*,\s*([0-9]+)\s*\)', dma_c)
if not prio_match or int(prio_match.group(1)) < 5:
    print("ERROR: DMA1 IRQ priority must be >= 5 for FreeRTOS syscall safety!", file=sys.stderr)
    sys.exit(1)

# DMA ISR verification
isr_match = re.search(r'void\s+DMA1_Channel1_IRQHandler\s*\(\s*void\s*\)\s*\{', dma_c)
if not isr_match:
    print("ERROR: DMA1_Channel1_IRQHandler not found in dma.c!", file=sys.stderr)
    sys.exit(1)
isr_body, _ = extract_brace_block(dma_c, isr_match.start())
if not isr_body:
    print("ERROR: Failed to extract DMA1_Channel1_IRQHandler body!", file=sys.stderr)
    sys.exit(1)

if re.search(r'\bxQueueSend\s*\(', isr_body) or re.search(r'\bxQueueGenericSend\s*\(', isr_body):
    print("ERROR: DMA ISR illegally calls task-context xQueueSend instead of FromISR API!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'xQueueSendFromISR\s*\(', isr_body):
    print("ERROR: DMA ISR does not call xQueueSendFromISR!", file=sys.stderr)
    sys.exit(1)

# Wake flag check
send_positions = [m.start() for m in re.finditer(r'xQueueSendFromISR\b', isr_body)]
for pos in send_positions:
    prefix = isr_body[:pos]
    assigns = list(re.finditer(r'xHigherPriorityTaskWoken\s*=\s*([^;]+);', prefix))
    if assigns and assigns[-1].group(1).strip() not in ["pdFALSE", "0"]:
        print("ERROR: xHigherPriorityTaskWoken not pdFALSE/0 before xQueueSendFromISR!", file=sys.stderr)
        sys.exit(1)

if not re.search(r'portYIELD_FROM_ISR\s*\(\s*xHigherPriorityTaskWoken\s*\)', isr_body):
    print("ERROR: DMA ISR does not call portYIELD_FROM_ISR(xHigherPriorityTaskWoken)!", file=sys.stderr)
    sys.exit(1)

# HT and TC independent flags and drop accounting
ht_match = re.search(r'if\s*\(\s*isr\s*&\s*DMA_ISR_HTIF1\s*\)\s*\{', isr_body)
tc_match = re.search(r'if\s*\(\s*isr\s*&\s*DMA_ISR_TCIF1\s*\)\s*\{', isr_body)
if not ht_match or not tc_match:
    print("ERROR: DMA1 ISR missing HTIF1 or TCIF1 check!", file=sys.stderr)
    sys.exit(1)
ht_body, _ = extract_brace_block(isr_body, ht_match.start())
tc_body, _ = extract_brace_block(isr_body, tc_match.start())

for b_name, b_text, c_flag, bad_flag, b_idx, bad_idx in [
    ("HTIF1", ht_body, "DMA_IFCR_CHTIF1", "DMA_IFCR_CTCIF1", "0", "1"),
    ("TCIF1", tc_body, "DMA_IFCR_CTCIF1", "DMA_IFCR_CHTIF1", "1", "0")
]:
    if not re.search(c_flag, b_text) or re.search(bad_flag, b_text):
        print(f"ERROR: {b_name} interrupt flag clearing violation!", file=sys.stderr)
        sys.exit(1)
    if not re.search(rf'msg\.(buffer_)?index\s*=\s*{b_idx}\b', b_text) or re.search(rf'msg\.(buffer_)?index\s*=\s*{bad_idx}\b', b_text):
        print(f"ERROR: {b_name} buffer index emit violation!", file=sys.stderr)
        sys.exit(1)
    
    res_m = re.search(r'if\s*\(\s*xResult\s*==\s*pdPASS\s*\)\s*\{', b_text)
    if not res_m:
        print(f"ERROR: {b_name} missing 'if (xResult == pdPASS)' check!", file=sys.stderr)
        sys.exit(1)
    p_body, p_end = extract_brace_block(b_text, res_m.start())
    if re.search(r'g_acq_drops\+\+', p_body):
        print(f"ERROR: {b_name} illegally increments drops on queue success!", file=sys.stderr)
        sys.exit(1)
    e_m = re.search(r'else\s*\{', b_text[p_end:])
    if not e_m:
        print(f"ERROR: {b_name} missing else handler for queue drop!", file=sys.stderr)
        sys.exit(1)
    f_body, _ = extract_brace_block(b_text[p_end:], e_m.start())
    if not f_body or not re.search(r'g_acq_drops\+\+', f_body):
        print(f"ERROR: {b_name} does not increment g_acq_drops on queue failure!", file=sys.stderr)
        sys.exit(1)

# Task Priorities & Creation
m_prio = re.search(r'#define\s+TASK_PROCESS_PRIORITY\s+3\b', node_h)
if not m_prio:
    print("ERROR: TASK_PROCESS_PRIORITY must be 3!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'#define\s+TASK_COMM_PRIORITY\s+2\b', node_h) or not re.search(r'#define\s+TASK_COMPUTE_PRIORITY\s+2\b', node_h) or not re.search(r'#define\s+TASK_HEALTH_PRIORITY\s+1\b', node_h):
    print("ERROR: Task priorities mismatch in node_app.h!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'xTaskCreate\s*\(\s*prvTaskProcess\s*,[^,]+,[^,]+,[^,]+,\s*(TASK_PROCESS_PRIORITY|3)\s*,\s*&g_task_process_handle\s*\)', node_c):
    print("ERROR: prvTaskProcess task creation binding violation!", file=sys.stderr)
    sys.exit(1)

# Fast path semaphore audit
proc_task = re.search(r'void\s+prvTaskProcess\s*\(\s*void\s*\*pvParameters\s*\)\s*\{', node_c)
proc_body, _ = extract_brace_block(node_c, proc_task.start())
if not re.search(r'xQueueReceive\s*\(\s*xAcqQueue\s*,.*?,\s*portMAX_DELAY\s*\)', proc_body):
    print("ERROR: Task_Process does not block on xAcqQueue with portMAX_DELAY!", file=sys.stderr)
    sys.exit(1)

acq_recv_match = re.search(r'if\s*\(\s*xQueueReceive\s*\(\s*xAcqQueue.*?\)\s*==\s*pdPASS\s*\)\s*\{', proc_body)
acq_body, _ = extract_brace_block(proc_body, acq_recv_match.start())
if re.search(r'\b(xSemaphoreTake|xMutexTake|xSemaphoreTakeRecursive)\b', acq_body):
    print("ERROR: Mutex / Semaphore take illegally placed inside sample processing loop in Task_Process!", file=sys.stderr)
    sys.exit(1)

diag_block_match = re.search(r'if\s*\(\s*ulTaskNotifyTake\s*\(', proc_body)
if diag_block_match:
    diag_proc_body, _ = extract_brace_block(proc_body, diag_block_match.start())
    all_sem_takes = len(re.findall(r'\bxSemaphoreTake\b', proc_body))
    diag_sem_takes = len(re.findall(r'\bxSemaphoreTake\b', diag_proc_body or ""))
    if all_sem_takes != diag_sem_takes:
        print("ERROR: Application semaphore take detected outside diagnostic branch in Task_Process!", file=sys.stderr)
        sys.exit(1)

node_sem_takes = len(re.findall(r'\b(xSemaphoreTake|xMutexTake|xSemaphoreTakeRecursive)\b', node_c))
if node_sem_takes != 3:
    print(f"ERROR: Found {node_sem_takes} semaphore/mutex take calls in node_app.c (expected exactly 3)!", file=sys.stderr)
    sys.exit(1)

# USART registers and rounded BRR
if not re.search(r'USART1->SR', usart_c) or not re.search(r'USART1->DR', usart_c):
    print("ERROR: usart.c does not access direct hardware registers USART1->SR and USART1->DR!", file=sys.stderr)
    sys.exit(1)
if re.search(r'72000000', usart_c):
    print("ERROR: usart.c must not hardcode 72000000!", file=sys.stderr)
    sys.exit(1)
if not re.search(r'USART1->BRR\s*=\s*\(?\s*pclk2_hz\s*\+\s*\(?\s*(baud\s*/\s*2U?|57600U?)\s*\)?\s*\)?\s*/\s*(baud|115200U?)', usart_c):
    print("ERROR: usart.c does not implement rounded BRR calculation!", file=sys.stderr)
    sys.exit(1)

# Deterministic clock failure path: HSE failure must attempt HSI, and HSI failure MUST trap in non-returning loop
hse_match = re.search(r'if\s*\(\s*!\s*clock_init\s*\(\s*CLOCK_PROFILE_72MHZ_HSE\s*\)\s*\)\s*\{', main_c)
if not hse_match:
    print("ERROR: main.c must attempt CLOCK_PROFILE_72MHZ_HSE and check failure!", file=sys.stderr)
    sys.exit(1)
hse_fallback_body, _ = extract_brace_block(main_c, hse_match.start())
if not hse_fallback_body:
    print("ERROR: Failed to extract HSE failure branch in main.c!", file=sys.stderr)
    sys.exit(1)

hsi_check_match = re.search(r'if\s*\(\s*!\s*clock_init\s*\(\s*CLOCK_PROFILE_64MHZ_HSI\s*\)\s*\)\s*\{', hse_fallback_body)
if not hsi_check_match:
    print("ERROR: main.c must check failure of CLOCK_PROFILE_64MHZ_HSI inside HSE fallback branch!", file=sys.stderr)
    sys.exit(1)
hsi_fail_body, _ = extract_brace_block(hse_fallback_body, hsi_check_match.start())
if not hsi_fail_body or not re.search(r'for\s*\(\s*;\s*;\s*\)|while\s*\(\s*(1|true)\s*\)|system_fail\s*\(', hsi_fail_body):
    print("ERROR: Failure of both HSE and HSI must enter a non-returning deterministic trap (for(;;) or while(1))!", file=sys.stderr)
    sys.exit(1)

all_hsi_calls = len(re.findall(r'clock_init\s*\(\s*CLOCK_PROFILE_64MHZ_HSI\s*\)', main_c))
fallback_hsi_calls = len(re.findall(r'clock_init\s*\(\s*CLOCK_PROFILE_64MHZ_HSI\s*\)', hse_fallback_body or ""))
if all_hsi_calls != fallback_hsi_calls or all_hsi_calls == 0:
    print("ERROR: CLOCK_PROFILE_64MHZ_HSI must only be called within HSE failure fallback branch!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'clock_get_frequencies\s*\(\s*&freqs\s*\)', main_c):
    print("ERROR: main.c must retrieve dynamic peripheral bus frequencies via clock_get_frequencies(&freqs)!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'usart1_init\s*\(\s*freqs\.pclk2_hz\s*\)', main_c) or \
   not re.search(r'adc1_init\s*\(\s*freqs\.pclk2_hz\s*\)', main_c) or \
   not re.search(r'tim3_trgo_init_1khz\s*\(\s*freqs\.timclk1_hz\s*\)', main_c):
    print("ERROR: main.c must pass dynamic frequencies to peripheral drivers!", file=sys.stderr)
    sys.exit(1)

# adc1_init check and non-returning deterministic failure trap
adc_init_match = re.search(r'if\s*\(\s*adc1_init\s*\([^)]*\)\s*!=\s*ADC_INIT_OK\s*\)\s*\{', main_c)
if not adc_init_match:
    print("ERROR: main.c must check adc1_init() return code against ADC_INIT_OK!", file=sys.stderr)
    sys.exit(1)
adc_fail_body, _ = extract_brace_block(main_c, adc_init_match.start())
if not adc_fail_body or not re.search(r'for\s*\(\s*;\s*;\s*\)|while\s*\(\s*(1|true)\s*\)|system_fail\s*\(', adc_fail_body):
    print("ERROR: adc1_init() failure branch must contain a non-returning deterministic trap (for(;;) or while(1))!", file=sys.stderr)
    sys.exit(1)

# IWDG config and check
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

# Health task gating: must gate iwdg_refresh on all three audits: progress_ok && stack_ok && heap_ok
health_task = re.search(r'void\s+prvTaskHealth\s*\(\s*void\s*\*pvParameters\s*\)\s*\{(.*?)\n\}', node_c, re.S)
health_body = health_task.group(1) if health_task else ""
iwdg_pos = health_body.find("iwdg_refresh();")
if iwdg_pos == -1:
    print("ERROR: Health task missing iwdg_refresh() call!", file=sys.stderr)
    sys.exit(1)
if_matches = list(re.finditer(r'if\s*\(([^()]+)\)\s*\{', health_body[:iwdg_pos]))
if not if_matches:
    print("ERROR: Health task does not guard iwdg_refresh inside an if condition!", file=sys.stderr)
    sys.exit(1)
gate_cond = if_matches[-1].group(1)
if not (re.search(r'\bprogress_ok\b', gate_cond) and re.search(r'\bstack_ok\b', gate_cond) and re.search(r'\bheap_ok\b', gate_cond)):
    print("ERROR: Health task must gate iwdg_refresh on all three audits: progress_ok && stack_ok && heap_ok!", file=sys.stderr)
    sys.exit(1)

# Diagnostic ordering and DWT provenance
diag_func = re.search(r'void\s+(prvRunDiagnosticComparison|node_app_run_diagnostic)\s*\(\s*void\s*\)\s*\{(.*?)\n\}', node_c, re.S)
diag_body = diag_func.group(2) if diag_func else ""
high_pos = diag_body.find("xTaskNotifyGive(g_task_process_handle)")
med_pos = diag_body.find("xTaskNotifyGive(g_task_compute_handle)")
if high_pos == -1 or med_pos == -1 or high_pos > med_pos:
    print("ERROR: Diagnostic High notification/block opportunity must precede Medium release!", file=sys.stderr)
    sys.exit(1)

if not re.search(r'xTaskAbortDelay\s*\(\s*g_task_process_handle\s*\)', diag_body):
    print("ERROR: Diagnostic comparison must call xTaskAbortDelay(g_task_process_handle)!", file=sys.stderr)
    sys.exit(1)

low_workload = re.search(r'void\s+(?:__attribute__\(\(.*?\)\)\s+)?inversion_execute_low_workload\s*\(\s*void\s*\)\s*\{(.*?)\n\}', node_c, re.S)
if low_workload and re.search(r'\bvTaskDelay\b', low_workload.group(1)):
    print("ERROR: inversion_execute_low_workload illegally contains vTaskDelay!", file=sys.stderr)
    sys.exit(1)

# Source Pin Section Binding in SOURCE_LEDGER.md
ledger_path = os.path.join(work_dir, "SOURCE_LEDGER.md")
if not os.path.exists(ledger_path):
    ledger_path = os.path.join(os.path.dirname(work_dir), "SOURCE_LEDGER.md")
if os.path.exists(ledger_path):
    ledger_txt = open(ledger_path, "r", encoding="utf-8", errors="ignore").read()
    
    # Extract FreeRTOS section
    freertos_sec = re.search(r'###\s+5\.\s+FreeRTOS-Kernel(.*?)(?=###\s+6\.|\Z)', ledger_txt, re.S)
    if not freertos_sec or not re.search(r'9b777ae5c5b8e9e456065a00294d1e5f5f9facf5', freertos_sec.group(1)):
        print("ERROR: SOURCE_LEDGER.md: FreeRTOS-Kernel section missing exact pin commit 9b777ae5c5b8e9e456065a00294d1e5f5f9facf5!", file=sys.stderr)
        sys.exit(1)
    if re.search(r'2b7495b8535bdcb306dac29b9ded4cfb679d7e5c|8a76309ed1250d817e9c888c4417171d2ba3ba63', freertos_sec.group(1)):
        print("ERROR: SOURCE_LEDGER.md: FreeRTOS-Kernel section contains swapped CMSIS pin commit!", file=sys.stderr)
        sys.exit(1)

    # Extract CMSIS_5 section
    cmsis5_sec = re.search(r'###\s+6\.\s+CMSIS_5(.*?)(?=###\s+7\.|\Z)', ledger_txt, re.S)
    if not cmsis5_sec or not re.search(r'2b7495b8535bdcb306dac29b9ded4cfb679d7e5c', cmsis5_sec.group(1)):
        print("ERROR: SOURCE_LEDGER.md: CMSIS_5 section missing exact pin commit 2b7495b8535bdcb306dac29b9ded4cfb679d7e5c!", file=sys.stderr)
        sys.exit(1)
    if re.search(r'9b777ae5c5b8e9e456065a00294d1e5f5f9facf5|8a76309ed1250d817e9c888c4417171d2ba3ba63', cmsis5_sec.group(1)):
        print("ERROR: SOURCE_LEDGER.md: CMSIS_5 section contains swapped FreeRTOS or device pin commit!", file=sys.stderr)
        sys.exit(1)

    # Extract cmsis-device-f1 section
    device_sec = re.search(r'###\s+7\.\s+cmsis-device-f1(.*?)(?=##|\Z)', ledger_txt, re.S)
    if not device_sec or not re.search(r'8a76309ed1250d817e9c888c4417171d2ba3ba63', device_sec.group(1)):
        print("ERROR: SOURCE_LEDGER.md: cmsis-device-f1 section missing exact pin commit 8a76309ed1250d817e9c888c4417171d2ba3ba63!", file=sys.stderr)
        sys.exit(1)
    if re.search(r'9b777ae5c5b8e9e456065a00294d1e5f5f9facf5|2b7495b8535bdcb306dac29b9ded4cfb679d7e5c', device_sec.group(1)):
        print("ERROR: SOURCE_LEDGER.md: cmsis-device-f1 section contains swapped pin commit!", file=sys.stderr)
        sys.exit(1)

PYEOF

echo "[PASS] Python source, AST, priority, register bindings, and synchronization contracts verified"

# 7. Disassembly verification of peripheral base addresses
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
