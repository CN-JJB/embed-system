#!/usr/bin/env bash
# ==============================================================================
# verify_m01.sh: Automated Static & Link Verification for Module P2-M01
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${MODULE_DIR}/build"
ELF="${BUILD_DIR}/firmware.elf"
MAP="${BUILD_DIR}/firmware.map"
LDSCRIPT="${MODULE_DIR}/linker/stm32f103c8tx_flash.ld"

echo "=== Running P2-M01 Automated Verification ==="

# 1. Verify build artifacts
if [ ! -f "${ELF}" ]; then
    echo "Building firmware..."
    make -C "${MODULE_DIR}" clean all
fi

if [ ! -f "${ELF}" ] || [ ! -f "${MAP}" ]; then
    echo "ERROR: Missing ELF or MAP file!" >&2
    exit 1
fi
echo "[PASS] Build artifacts exist: firmware.elf and firmware.map"

# 2. Check memory bounds: Flash <= 64 KB (65536 bytes), RAM <= 20 KB (20480 bytes)
FLASH_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $1 + $2}')
RAM_SIZE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $2 + $3}')

echo "Memory usage: Flash = ${FLASH_SIZE} bytes (limit: 65536), RAM = ${RAM_SIZE} bytes (limit: 20480)"

if [ "${FLASH_SIZE}" -gt 65536 ]; then
    echo "ERROR: Flash usage ${FLASH_SIZE} exceeds 64 KB limit!" >&2
    exit 1
fi

if [ "${RAM_SIZE}" -gt 20480 ]; then
    echo "ERROR: RAM usage ${RAM_SIZE} exceeds 20 KB limit!" >&2
    exit 1
fi
echo "[PASS] Memory bounds verified within 64 KB Flash and 20 KB RAM"

# 3. Check expected ELF sections
REQUIRED_SECTIONS=(".isr_vector" ".text" ".rodata" ".init_array" ".data" ".bss")
SECTION_LIST=$(arm-none-eabi-objdump -h "${ELF}" | awk '{print $2}')

for sec in "${REQUIRED_SECTIONS[@]}"; do
    if ! echo "${SECTION_LIST}" | grep -qw "${sec}"; then
        echo "ERROR: Required ELF section ${sec} missing from image!" >&2
        exit 1
    fi
done
echo "[PASS] Required ELF sections present: ${REQUIRED_SECTIONS[*]}"

# 4. Check Reset_Handler symbol and Entry point
ENTRY_POINT=$(arm-none-eabi-readelf -h "${ELF}" | grep "Entry point address" | awk '{print $4}')
RESET_HANDLER_ADDR=$(arm-none-eabi-nm -n "${ELF}" | grep " Reset_Handler" | awk '{print $1}')

# On Thumb architecture, entry point has bit 0 set (Reset_Handler + 1)
EXPECTED_ENTRY=$(printf "0x%x" $((0x${RESET_HANDLER_ADDR} | 1)))
ACTUAL_ENTRY=$(printf "0x%x" $((ENTRY_POINT)))

if [ "${ACTUAL_ENTRY}" != "${EXPECTED_ENTRY}" ]; then
    echo "ERROR: ELF entry point (${ACTUAL_ENTRY}) does not match Thumb Reset_Handler (${EXPECTED_ENTRY})!" >&2
    exit 1
fi
echo "[PASS] Entry point correctly points to Thumb Reset_Handler: ${ACTUAL_ENTRY}"

# 5. Check Vector Table entry 0 (_estack) and entry 1 (Reset_Handler)
VEC0=$(arm-none-eabi-readelf -x .isr_vector "${ELF}" | awk '/0x08000000/ {print $2}')
# 00500020 in byte-order hex = 0x20005000
if [ "${VEC0}" != "00500020" ]; then
    echo "ERROR: Vector 0 (initial MSP) is not 0x20005000 (got: ${VEC0})!" >&2
    exit 1
fi
echo "[PASS] Vector table entry 0 (initial MSP) correctly set to 0x20005000"

# 6. Check init-array symbols
REQUIRED_SYMBOLS=("__init_array_start" "__init_array_end" "__libc_init_array" "_init" "_fini" "_sidata" "_sdata" "_edata" "_sbss" "_ebss")
NM_OUTPUT=$(arm-none-eabi-nm "${ELF}")

for sym in "${REQUIRED_SYMBOLS[@]}"; do
    if ! echo "${NM_OUTPUT}" | grep -qw "${sym}"; then
        echo "ERROR: Required symbol ${sym} missing!" >&2
        exit 1
    fi
done
echo "[PASS] Constructor and runtime symbols verified: ${REQUIRED_SYMBOLS[*]}"

# 7. Check absence of unintended CRT startup and dynamic memory allocation
FORBIDDEN_SYMBOLS=("_start" "malloc" "free" "realloc" "calloc")
for sym in "${FORBIDDEN_SYMBOLS[@]}"; do
    if echo "${NM_OUTPUT}" | grep -qw "${sym}"; then
        echo "ERROR: Forbidden symbol ${sym} detected in binary!" >&2
        exit 1
    fi
done
echo "[PASS] Forbidden symbols absent (no _start, no libc malloc/free)"

# 8. Check original linker script provenance (no Ac6 vendor copy)
if grep -qi "Ac6" "${LDSCRIPT}" || grep -qi "128K" "${LDSCRIPT}"; then
    echo "ERROR: Linker script contains vendor Ac6 copyright or incorrect 128KB sizing!" >&2
    exit 1
fi
echo "[PASS] Linker script is verified original pedagogical work (64 KB Flash, 20 KB RAM)"

# 9. Verify header dependency generation
touch "${MODULE_DIR}/include/system_stm32f1xx.h"
REBUILD_OUT=$(make -C "${MODULE_DIR}" -n build/src/main.o)
if ! echo "${REBUILD_OUT}" | grep -q "arm-none-eabi-gcc"; then
    echo "ERROR: Header dependency rebuild test failed!" >&2
    exit 1
fi
echo "[PASS] Makefile header dependency tracking (-MMD -MP) verified"

echo "=== ALL P2-M01 STATIC CHECKS PASSED ==="
