#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PART_C_DIR="$SCRIPT_DIR/../../part-c"

echo "=== Verifying Part C (ELF / Link / Binary Evidence) ==="

cd "$PART_C_DIR"
make clean >/dev/null
make objects >/dev/null

echo "--- 1. Testing Symbol Inspection (readelf -s & nm) ---"
readelf -s src/calc.o | grep "internal_clamp" >/dev/null
nm src/calc.o | grep "compute_scaled_metric" >/dev/null
echo "PASS: Symbol inspection verified."

echo "--- 2. Testing Relocation Inspection (readelf -r) ---"
readelf -W -r src/calc.o | grep "get_hardware_calibration_offset" >/dev/null
echo "PASS: Relocation inspection verified."

echo "--- 3. Testing Section Placement (readelf -S) ---"
readelf -S src/state.o | grep "\.rodata" >/dev/null
readelf -S src/state.o | grep "\.data" >/dev/null
readelf -S src/state.o | grep "\.bss" >/dev/null
echo "PASS: Section placement verified."

echo "--- 4. Testing Linker Failure & Resolution ---"
set +e
make failing-link >/dev/null 2>&1
FAIL_STATUS=$?
set -e
if [ "$FAIL_STATUS" -eq 0 ]; then
    echo "FAIL: Expected failing-link to fail, but it exited 0."
    exit 1
fi
echo "PASS: Failing link failed as expected (exit code $FAIL_STATUS)."

make fixed-link >/dev/null
./part_c_app | grep "FINAL_GATE_RELEASE" >/dev/null
echo "PASS: Fixed link succeeded and executed cleanly."

echo "--- 5. Testing Disassembly (objdump -d) ---"
objdump -d src/calc.o | grep "<internal_clamp>:" >/dev/null
echo "PASS: Disassembly verified."

make clean >/dev/null
echo ">>> ALL PART C VERIFICATION CHECKS PASSED <<<"
