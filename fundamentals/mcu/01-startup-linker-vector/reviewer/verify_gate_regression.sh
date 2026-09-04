#!/usr/bin/env bash
# ==============================================================================
# verify_gate_regression.sh: Reviewer Verification for M01 Gate Fault Fixture
# Proves that the seeded Gate fixture exhibits the authentic vector displacement fault.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M01_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
GATE_DIR="${M01_DIR}/gate/gate_fault_firmware"

echo "=== Verifying P2-M01 Gate Fault Fixture Seeded Properties ==="

# 1. Build Gate fixture
make -C "${GATE_DIR}" clean all >/dev/null

ELF="${GATE_DIR}/build/firmware.elf"
if [ ! -f "${ELF}" ]; then
    echo "ERROR: Gate firmware ELF build failed!" >&2
    exit 1
fi

# 2. Check section header addresses
SECTIONS=$(arm-none-eabi-readelf -SW "${ELF}")

BOOT_META_ADDR=$(echo "${SECTIONS}" | awk '$0 ~ /\.boot_meta/ {for(i=1;i<=NF;i++) if($i==".boot_meta") print $(i+2)}')
ISR_VECTOR_ADDR=$(echo "${SECTIONS}" | awk '$0 ~ /\.isr_vector/ {for(i=1;i<=NF;i++) if($i==".isr_vector") print $(i+2)}')

echo "Observed .boot_meta address: 0x${BOOT_META_ADDR}"
echo "Observed .isr_vector address: 0x${ISR_VECTOR_ADDR}"

if [ "${BOOT_META_ADDR}" != "08000000" ]; then
    echo "ERROR: Seeded fault missing! .boot_meta must be placed at Flash base 0x08000000!" >&2
    exit 1
fi

if [ "${ISR_VECTOR_ADDR}" != "08000020" ]; then
    echo "ERROR: Seeded fault missing! .isr_vector must be displaced to 0x08000020!" >&2
    exit 1
fi
echo "[PASS] Binary section headers prove .isr_vector is displaced by .boot_meta"

# 3. Check memory contents at Flash base
HEX_DUMP=$(arm-none-eabi-readelf -x .boot_meta "${ELF}" | awk '/0x08000000/ {print $2, $3}')
echo "Hex dump at 0x08000000: ${HEX_DUMP}"

# Word 0 is 'STM3' (0x53544D33 -> 334d5453 in little endian bytes)
# Word 1 is format revision 0x00010000 -> 00000100 in little endian bytes
if ! echo "${HEX_DUMP}" | grep -qi "334d5453"; then
    echo "ERROR: Memory at 0x08000000 does not contain boot_meta signature!" >&2
    exit 1
fi
echo "[PASS] Flash base 0x08000000 contains metadata signature instead of valid MSP"

echo "=== M01 GATE FAULT FIXTURE PROVEN CORRECT (STATIC/BINARY REGRESSION PASSED) ==="
