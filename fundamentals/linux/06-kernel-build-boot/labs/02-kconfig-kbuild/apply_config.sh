#!/bin/bash
set -euo pipefail

# Apply Phase 3 config fragment over baseline defconfig and audit effective configuration

BASE_CONFIG="../../fixtures/configs/multi_v7_defconfig"
DELTA_CONFIG="../../fixtures/configs/phase3_delta.config"
EFFECTIVE_CONFIG="../../fixtures/configs/effective_kernel.config"

echo "=== Auditing Effective Kernel Configuration ==="

# Validation oracle: checks effective final .config
check_config_opt() {
    local opt="$1"
    local expected="$2"
    
    if [ "$expected" = "y" ]; then
        if grep -q "^${opt}=y" "$EFFECTIVE_CONFIG"; then
            echo "[PASS] ${opt}=y"
        else
            echo "[FAIL] Expected ${opt}=y, but not found in effective config!" >&2
            return 1
        fi
    elif [ "$expected" = "n" ]; then
        if grep -q "^# ${opt} is not set" "$EFFECTIVE_CONFIG" || grep -q "^${opt}=n" "$EFFECTIVE_CONFIG"; then
            echo "[PASS] ${opt}=n (disabled)"
        else
            echo "[FAIL] Expected ${opt}=n, but found enabled or missing!" >&2
            return 1
        fi
    fi
}

echo "1. Checking QEMU virt platform support:"
check_config_opt "CONFIG_ARCH_VIRT" "y"

echo "2. Checking short-descriptor MMU translation model (non-LPAE):"
check_config_opt "CONFIG_ARM_LPAE" "n"

echo "3. Checking virtual address split (3G User / 1G Kernel):"
check_config_opt "CONFIG_VMSPLIT_3G" "y"

echo "4. Checking early and serial console support (PL011):"
check_config_opt "CONFIG_SERIAL_EARLYCON" "y"
check_config_opt "CONFIG_SERIAL_AMBA_PL011" "y"
check_config_opt "CONFIG_SERIAL_AMBA_PL011_CONSOLE" "y"

echo "5. Checking storage and devtmpfs:"
check_config_opt "CONFIG_DEVTMPFS" "y"
check_config_opt "CONFIG_DEVTMPFS_MOUNT" "y"
check_config_opt "CONFIG_VIRTIO_MMIO" "y"
check_config_opt "CONFIG_VIRTIO_BLK" "y"
check_config_opt "CONFIG_EXT4_FS" "y"
check_config_opt "CONFIG_PRINTK" "y"

echo "=== All Effective Kernel Configuration Contracts Verified ==="
