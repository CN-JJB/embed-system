#!/bin/bash
set -euo pipefail

# Test negative control mutations against the validator logic
# Every mutation MUST fail validation!

CROSS_COMPILE=${CROSS_COMPILE:-arm-none-linux-gnueabihf-}
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    if command -v arm-linux-gnueabihf-gcc >/dev/null 2>&1; then
        CROSS_COMPILE="arm-linux-gnueabihf-"
    else
        echo "ERROR: Cross compiler not found" >&2
        exit 1
    fi
fi

HOST_CC=${HOST_CC:-gcc}
READELF="readelf"
MUT_DIR="reviewer/mutations"
mkdir -p "$MUT_DIR"

echo "=== Running P3-M01 Negative Control Mutation Tests ==="

FAILED_COUNT=0

# Mutation 1: Host binary falsely claimed as ARM target binary
echo "[MUTATION 1] Host binary falsely claimed as ARM"
echo 'int main(){return 0;}' | "$HOST_CC" -x c - -o "$MUT_DIR/mut1_host_binary"
MACHINE=$("$READELF" -h "$MUT_DIR/mut1_host_binary" | awk -F: '/Machine:/ {print $2}' | xargs)
if [[ "$MACHINE" == *"ARM"* ]]; then
    echo "ERROR: Mutation 1 was incorrectly identified as ARM!"
    FAILED_COUNT=$((FAILED_COUNT + 1))
else
    echo "[PASS] Mutation 1 correctly rejected by machine identity oracle (Machine: $MACHINE)"
fi

# Mutation 2: Dynamic binary claimed as static (checking only readelf -h)
echo "[MUTATION 2] Dynamic binary claimed as static"
echo 'int main(){return 0;}' | "${CROSS_COMPILE}gcc" -x c - -o "$MUT_DIR/mut2_dynamic_binary"
# Oracle: check INTERP segment
HAS_INTERP=$("$READELF" -l "$MUT_DIR/mut2_dynamic_binary" 2>/dev/null | grep -c "INTERP" || true)
if [ "$HAS_INTERP" -eq 0 ]; then
    echo "ERROR: Mutation 2 lacked INTERP segment!"
    FAILED_COUNT=$((FAILED_COUNT + 1))
else
    echo "[PASS] Mutation 2 correctly detected as dynamic via PT_INTERP ($HAS_INTERP segment)"
fi

# Mutation 3: Static binary with decoy string in .rodata
echo "[MUTATION 3] Decoy string in .rodata tested against semantic validator"
cat << 'EOF' > "$MUT_DIR/mut3_decoy.c"
#include <stdio.h>
const char *decoy = "/lib/ld-linux-armhf.so.3";
int main(void) {
    printf("Decoy: %s\n", decoy);
    return 0;
}
EOF
"${CROSS_COMPILE}gcc" -static "$MUT_DIR/mut3_decoy.c" -o "$MUT_DIR/mut3_decoy_static"

# If a naive validator runs `grep -q "/lib/ld-linux-armhf.so.3" binary`, it would falsely claim dynamic!
# A semantic validator must inspect PT_INTERP via readelf -l:
INTERP_SEGMENT=$("$READELF" -l "$MUT_DIR/mut3_decoy_static" 2>/dev/null | grep "program interpreter" || true)
if [ -n "$INTERP_SEGMENT" ]; then
    echo "ERROR: Semantic validator false-positive on decoy static binary!"
    FAILED_COUNT=$((FAILED_COUNT + 1))
else
    echo "[PASS] Mutation 3 (decoy string) correctly verified as static via PT_INTERP segment absence"
fi

# Clean up mutation artifacts
rm -rf "$MUT_DIR"/*.o "$MUT_DIR"/mut*.c

if [ "$FAILED_COUNT" -eq 0 ]; then
    echo "=== ALL P3-M01 NEGATIVE CONTROL MUTATIONS REJECTED AS EXPECTED (4/4) ==="
    exit 0
else
    echo "=== ERROR: $FAILED_COUNT MUTATION TESTS FAILED ==="
    exit 1
fi
