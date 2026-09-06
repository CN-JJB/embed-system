#!/usr/bin/env bash
# ==============================================================================
# test_acceptance.sh: End-to-End Acceptance Test for P2-M07 Acquisition Node
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "================================================================================"
echo " Starting P2-M07 STM32 FreeRTOS Acquisition Node Acceptance Test Suite"
echo "================================================================================"

# 1. Clean build
echo "[1/4] Clean build and artifact generation..."
make -C "${PROJECT_DIR}" clean build
echo "PASS: Clean build succeeded."

# 2. Run project-level static and architectural validation
echo ""
echo "[2/4] Executing project validator (verify_project.sh)..."
bash "${PROJECT_DIR}/scripts/verify_project.sh"
echo "PASS: Project validator passed."

# 3. Run positive reference and 38 negative mutations suite
echo ""
echo "[3/4] Executing reviewer mutation verification suite (verify_mutations.sh)..."
bash "${PROJECT_DIR}/reviewer/verify_mutations.sh"
echo "PASS: Reviewer mutation suite passed."

# 4. Memory footprint audit
echo ""
echo "[4/4] Auditing memory limits..."
ELF="${PROJECT_DIR}/build/firmware.elf"
FLASH_USAGE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $1 + $2}')
RAM_USAGE=$(arm-none-eabi-size -B "${ELF}" | awk 'NR==2 {print $2 + $3}')

echo "Flash: ${FLASH_USAGE} / 65536 bytes ($((FLASH_USAGE * 100 / 65536))% capacity)"
echo "SRAM:  ${RAM_USAGE} / 20480 bytes ($((RAM_USAGE * 100 / 20480))% capacity)"

if [ "${FLASH_USAGE}" -gt 65536 ] || [ "${RAM_USAGE}" -gt 20480 ]; then
    echo "ERROR: Memory audit failed!" >&2
    exit 1
fi
echo "PASS: Memory usage strictly within 64 KB Flash / 20 KB SRAM."

echo ""
echo "================================================================================"
echo " ALL P2-M07 ACCEPTANCE TESTS PASSED SUCCESSFULLY!"
echo "================================================================================"
