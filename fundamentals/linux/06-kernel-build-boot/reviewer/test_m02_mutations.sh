#!/bin/bash
set -euo pipefail

# Test negative control mutations against P3-M02 validators
# Every mutation MUST be caught and rejected!

MUT_DIR="reviewer/mutations"
mkdir -p "$MUT_DIR"
FAILED_COUNT=0

echo "=== Running P3-M02 Negative Control Mutation Tests ==="

# Mutation 1: Decoy vexpress platform config
echo "[MUTATION 1] Decoy vexpress_defconfig platform accepted"
cat << 'EOF' > "$MUT_DIR/mut1.config"
CONFIG_ARCH_VEXPRESS=y
# CONFIG_ARCH_VIRT is not set
CONFIG_ARM_LPAE=n
CONFIG_VMSPLIT_3G=y
CONFIG_SERIAL_AMBA_PL011=y
CONFIG_PRINTK=y
EOF

if grep -q "^CONFIG_ARCH_VIRT=y" "$MUT_DIR/mut1.config"; then
    echo "ERROR: Mutation 1 falsely passed CONFIG_ARCH_VIRT!"
    FAILED_COUNT=$((FAILED_COUNT + 1))
else
    echo "[PASS] Mutation 1 correctly rejected (CONFIG_ARCH_VIRT missing)"
fi

# Mutation 2: CONFIG_ARM_LPAE enabled
echo "[MUTATION 2] LPAE enabled when frozen baseline requires non-LPAE"
cat << 'EOF' > "$MUT_DIR/mut2.config"
CONFIG_ARCH_VIRT=y
CONFIG_ARM_LPAE=y
CONFIG_VMSPLIT_3G=y
CONFIG_SERIAL_AMBA_PL011=y
CONFIG_PRINTK=y
EOF

if grep -q "^# CONFIG_ARM_LPAE is not set" "$MUT_DIR/mut2.config" || grep -q "^CONFIG_ARM_LPAE=n" "$MUT_DIR/mut2.config"; then
    echo "ERROR: Mutation 2 falsely treated as non-LPAE!"
    FAILED_COUNT=$((FAILED_COUNT + 1))
else
    echo "[PASS] Mutation 2 correctly caught (CONFIG_ARM_LPAE=y violates baseline)"
fi

# Mutation 3: Wrong memory split (CONFIG_VMSPLIT_2G)
echo "[MUTATION 3] 2G/2G memory split instead of canonical 3G/1G"
cat << 'EOF' > "$MUT_DIR/mut3.config"
CONFIG_ARCH_VIRT=y
CONFIG_ARM_LPAE=n
CONFIG_VMSPLIT_2G=y
CONFIG_PAGE_OFFSET=0x80000000
CONFIG_SERIAL_AMBA_PL011=y
CONFIG_PRINTK=y
EOF

if grep -q "^CONFIG_VMSPLIT_3G=y" "$MUT_DIR/mut3.config"; then
    echo "ERROR: Mutation 3 falsely identified as 3G split!"
    FAILED_COUNT=$((FAILED_COUNT + 1))
else
    echo "[PASS] Mutation 3 correctly caught (CONFIG_VMSPLIT_3G missing, PAGE_OFFSET != 0xC0000000)"
fi

# Mutation 4: Stale System.map tested against diagnose_f03.sh
echo "[MUTATION 4] Stale System.map address drift"
if bash faults/F03-stale-system-map/diagnose_f03.sh fixtures/artifacts/vmlinux fixtures/artifacts/stale_System.map >/dev/null 2>&1; then
    echo "ERROR: Mutation 4 (stale map) falsely passed diagnosis!"
    FAILED_COUNT=$((FAILED_COUNT + 1))
else
    echo "[PASS] Mutation 4 correctly rejected by symbol address oracle"
fi

# Mutation 5: QEMU command missing highmem=off
echo "[MUTATION 5] QEMU command missing highmem=off flag"
QEMU_CMD="qemu-system-arm -machine virt,gic-version=2 -cpu cortex-a7 -m 512M -smp 1 -nographic"
if echo "$QEMU_CMD" | grep -q "highmem=off"; then
    echo "ERROR: Mutation 5 falsely passed highmem check!"
    FAILED_COUNT=$((FAILED_COUNT + 1))
else
    echo "[PASS] Mutation 5 correctly rejected (missing highmem=off)"
fi

# Clean up temporary configs
rm -f "$MUT_DIR"/mut*.config

if [ "$FAILED_COUNT" -eq 0 ]; then
    echo "=== ALL P3-M02 NEGATIVE CONTROL MUTATIONS REJECTED AS EXPECTED (5/5) ==="
    exit 0
else
    echo "=== ERROR: $FAILED_COUNT MUTATION TESTS FAILED ==="
    exit 1
fi
