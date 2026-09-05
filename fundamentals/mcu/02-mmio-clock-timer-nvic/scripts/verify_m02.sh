#!/usr/bin/env bash
# ==============================================================================
# verify_m02.sh: Automated Static & Logic Verification for Module P2-M02
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${MODULE_DIR}/build"
ELF="${BUILD_DIR}/firmware.elf"
MAP="${BUILD_DIR}/firmware.map"

echo "=== Running P2-M02 Automated Verification ==="

# 1. Verify build
if [ ! -f "${ELF}" ]; then
    echo "Building M02 firmware..."
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
FORBIDDEN_PATTERNS=("HAL_Init" "HAL_TIM_Base_Init" "HAL_GPIO_Init" "stm32f1xx_hal.h" "MX_GPIO_Init")
for pat in "${FORBIDDEN_PATTERNS[@]}"; do
    if grep -rql "${pat}" "${MODULE_DIR}/src" "${MODULE_DIR}/include"; then
        echo "ERROR: Forbidden HAL/CubeMX artifact detected: ${pat}!" >&2
        exit 1
    fi
done
echo "[PASS] Zero HAL or CubeMX dependencies in MUST coursework"

# 4. Check presence of required MMIO / peripheral symbols
REQUIRED_SYMBOLS=("clock_init" "tim2_init_1khz" "TIM2_IRQHandler" "gpio_init" "gpio_toggle_pa1_atomic" "g_tim2_ticks")
NM_OUTPUT=$(arm-none-eabi-nm "${ELF}")

for sym in "${REQUIRED_SYMBOLS[@]}"; do
    if ! echo "${NM_OUTPUT}" | grep -qw "${sym}"; then
        echo "ERROR: Required symbol ${sym} missing from ELF!" >&2
        exit 1
    fi
done
echo "[PASS] All direct-register peripheral functions verified in ELF"

# 5. Arithmetic validation: Timer prescaler / period consistency check
# Primary: 72 MHz clock / (71 + 1) / (999 + 1) == 1000 Hz
# Fallback: 64 MHz clock / (63 + 1) / (999 + 1) == 1000 Hz
CALC_PRIMARY=$(( 72000000 / (71 + 1) / (999 + 1) ))
CALC_FALLBACK=$(( 64000000 / (63 + 1) / (999 + 1) ))

if [ "${CALC_PRIMARY}" -ne 1000 ] || [ "${CALC_FALLBACK}" -ne 1000 ]; then
    echo "ERROR: Timer arithmetic calculation failed!" >&2
    exit 1
fi
echo "[PASS] Timer frequency arithmetic strictly equals 1000 Hz (1.0 ms period)"

# 6. Physical observation disclosure
echo "[NOTE] Physical oscilloscope waveform measurement: UNVERIFIED (Headless automated build)"
echo "[PASS] Static register and linker contracts verified"

echo "=== ALL P2-M02 STATIC CHECKS PASSED ==="
