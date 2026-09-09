#!/bin/bash
set -euo pipefail

# Reviewer Negative Control Mutation Suite for P3-M02
# Enforces: PREP/BUILD PASS / VALIDATOR EXECUTION PASS / INTENDED REJECT PASS
# Invokes actual production validators (verify_kernel_config.sh, diagnose_f03.sh, audit_zimage_header.sh).

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M02_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M02_ROOT"

MUT_DIR="reviewer/mutations"
mkdir -p "$MUT_DIR"

CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"
make -C fixtures/artifacts all CROSS_COMPILE="$CROSS_COMPILE" >/dev/null

echo "=================================================================="
echo "=== Running P3-M02 Production-Validator Negative Control Suite ==="
echo "=================================================================="

TOTAL_MUTATIONS=8
PASSED_MUTATIONS=0

run_mutation() {
    local mut_id="$1"
    local desc="$2"
    local prep_cmd="$3"
    local val_cmd="$4"
    local expect_reject_pattern="$5"
    local expect_exit_code="$6"

    echo "------------------------------------------------------------------"
    echo "Testing Mutation ${mut_id}: ${desc}"

    # 1. PREP / BUILD
    if ! eval "$prep_cmd" >/dev/null 2>&1; then
        echo "[MUTATION ${mut_id} FAIL] Build/Prep stage failed!"
        return 1
    fi
    local prep_status="PASS"

    # 2. VALIDATOR EXECUTION
    local val_output=""
    local val_exit=0
    set +e
    val_output=$(eval "$val_cmd" 2>&1)
    val_exit=$?
    set -e

    # Check validator did not crash
    if [ "$val_exit" -ge 128 ]; then
        echo "[MUTATION ${mut_id} FAIL] Validator crashed with signal $((val_exit - 128))!"
        echo "$val_output"
        return 1
    fi
    local val_status="PASS"

    # 3. INTENDED SEMANTIC REJECT
    if [ "$val_exit" -ne "$expect_exit_code" ]; then
        echo "[MUTATION ${mut_id} FAIL] Expected validator exit code ${expect_exit_code}, got ${val_exit}!"
        echo "Output was:"
        echo "$val_output"
        return 1
    fi

    if ! echo "$val_output" | grep -Eq "$expect_reject_pattern"; then
        echo "[MUTATION ${mut_id} FAIL] Validator output did not match expected reject pattern: ${expect_reject_pattern}"
        echo "Output was:"
        echo "$val_output"
        return 1
    fi
    local reject_status="PASS"

    echo "Status: MUTATION BUILD/PREP ${prep_status} / VALIDATOR EXECUTION ${val_status} / INTENDED REJECT ${reject_status}"
    echo "[PASS] Mutation ${mut_id} successfully rejected by production validator"
    PASSED_MUTATIONS=$((PASSED_MUTATIONS + 1))
    return 0
}

# Base valid config template
BASE_CONFIG="fixtures/configs/effective_kernel.config"

# Mutation 1: CONFIG_ARCH_VEXPRESS enabled in place of ARCH_VIRT
run_mutation \
    1 \
    "Legacy vexpress platform enabled in place of virt" \
    "sed 's/CONFIG_ARCH_VIRT=y/CONFIG_ARCH_VEXPRESS=y/' $BASE_CONFIG > $MUT_DIR/mut1.config" \
    "bash scripts/verify_kernel_config.sh $MUT_DIR/mut1.config" \
    "CONFIG_ARCH_VIRT=y missing|CONFIG_ARCH_VEXPRESS=y is active" \
    1

# Mutation 2: CONFIG_ARM_LPAE enabled against non-LPAE baseline
run_mutation \
    2 \
    "LPAE enabled when frozen baseline requires non-LPAE" \
    "sed -E 's/(# CONFIG_ARM_LPAE is not set|CONFIG_ARM_LPAE=n)/CONFIG_ARM_LPAE=y/' $BASE_CONFIG > $MUT_DIR/mut2.config" \
    "bash scripts/verify_kernel_config.sh $MUT_DIR/mut2.config" \
    "CONFIG_ARM_LPAE is NOT disabled" \
    1

# Mutation 3: Wrong memory split (CONFIG_VMSPLIT_2G)
run_mutation \
    3 \
    "2G/2G memory split instead of canonical 3G/1G" \
    "sed 's/CONFIG_VMSPLIT_3G=y/CONFIG_VMSPLIT_2G=y/' $BASE_CONFIG | sed 's/CONFIG_PAGE_OFFSET=0xC0000000/CONFIG_PAGE_OFFSET=0x80000000/' > $MUT_DIR/mut3.config" \
    "bash scripts/verify_kernel_config.sh $MUT_DIR/mut3.config" \
    "CONFIG_VMSPLIT_3G=y missing|CONFIG_PAGE_OFFSET" \
    1

# Mutation 4: Missing serial console configuration
run_mutation \
    4 \
    "PL011 console disabled (breaks early kernel printk)" \
    "sed 's/CONFIG_SERIAL_AMBA_PL011_CONSOLE=y/CONFIG_SERIAL_AMBA_PL011_CONSOLE=n/' $BASE_CONFIG > $MUT_DIR/mut4.config" \
    "bash scripts/verify_kernel_config.sh $MUT_DIR/mut4.config" \
    "CONFIG_SERIAL_AMBA_PL011_CONSOLE=y not found" \
    1

# Mutation 5: Stale System.map symbol address drift
run_mutation \
    5 \
    "Stale System.map address drift evaluated against F03 diagnostic oracle" \
    "awk '{if (\$3 == \"start_kernel\") print \"c0999000\", \$2, \$3; else print \$0}' fixtures/artifacts/System.map > $MUT_DIR/mut5_stale.map" \
    "bash faults/F03-stale-system-map/diagnose_f03.sh fixtures/artifacts/vmlinux $MUT_DIR/mut5_stale.map" \
    "Detected [0-9]+ symbol address mismatches / drift" \
    1

# Mutation 6: zImage with wrong magic bytes
run_mutation \
    6 \
    "zImage artifact with corrupted/invalid boot magic" \
    "python3 -c 'import struct; b = bytearray(64); struct.pack_into(\"<I\", b, 0x24, 0xdeadbeef); open(\"$MUT_DIR/mut6_bad_magic.bin\", \"wb\").write(b)'" \
    "bash scripts/audit_zimage_header.sh $MUT_DIR/mut6_bad_magic.bin" \
    "Invalid ARM zImage magic" \
    1

# Mutation 7: Truncated zImage (< 40 bytes)
run_mutation \
    7 \
    "Truncated zImage artifact too short for ARM header" \
    "head -c 20 /dev/zero > $MUT_DIR/mut7_short.bin" \
    "bash scripts/audit_zimage_header.sh $MUT_DIR/mut7_short.bin" \
    "too short" \
    1

# Mutation 8: Valid zImage magic placed as decoy at wrong offset (0x10 instead of 0x24)
run_mutation \
    8 \
    "Valid ARM magic (0x016f2818) placed at wrong offset (decoy offset 0x10)" \
    "python3 -c 'import struct; b = bytearray(64); struct.pack_into(\"<I\", b, 0x10, 0x016f2818); open(\"$MUT_DIR/mut8_decoy.bin\", \"wb\").write(b)'" \
    "bash scripts/audit_zimage_header.sh $MUT_DIR/mut8_decoy.bin" \
    "Invalid ARM zImage magic" \
    1

# Cleanup
rm -rf "$MUT_DIR"

echo "------------------------------------------------------------------"
if [ "$PASSED_MUTATIONS" -eq "$TOTAL_MUTATIONS" ]; then
    echo "=== ALL P3-M02 NEGATIVE CONTROL MUTATIONS REJECTED AS EXPECTED (${PASSED_MUTATIONS}/${TOTAL_MUTATIONS}) ==="
    exit 0
else
    echo "=== ERROR: Only ${PASSED_MUTATIONS}/${TOTAL_MUTATIONS} mutations passed! ==="
    exit 1
fi
