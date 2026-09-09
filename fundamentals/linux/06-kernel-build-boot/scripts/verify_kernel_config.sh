#!/bin/bash
set -euo pipefail

# Semantic auditor for final effective Linux kernel configuration

CONFIG_FILE="${1:-fixtures/configs/effective_kernel.config}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file $CONFIG_FILE does not exist." >&2
    exit 1
fi

echo "=== Auditing Kernel Configuration: $CONFIG_FILE ==="

FAILURES=0

assert_opt_enabled() {
    local opt="$1"
    # Strict regex check for ^CONFIG_OPT=y
    if grep -E -q "^${opt}=y" "$CONFIG_FILE"; then
        echo "  [PASS] ${opt}=y"
    else
        echo "  [FAIL] Expected ${opt}=y not found!" >&2
        FAILURES=$((FAILURES + 1))
    fi
}

assert_opt_disabled() {
    local opt="$1"
    # Must be either explicitly '=n' or '# CONFIG_OPT is not set'
    if grep -E -q "^# ${opt} is not set" "$CONFIG_FILE" || grep -E -q "^${opt}=n" "$CONFIG_FILE"; then
        echo "  [PASS] ${opt} is disabled"
    else
        echo "  [FAIL] ${opt} is NOT disabled (found enabled or missing)!" >&2
        FAILURES=$((FAILURES + 1))
    fi
}

assert_opt_value() {
    local opt="$1"
    local val="$2"
    if grep -E -q "^${opt}=${val}" "$CONFIG_FILE"; then
        echo "  [PASS] ${opt}=${val}"
    else
        echo "  [FAIL] Expected ${opt}=${val} not found!" >&2
        FAILURES=$((FAILURES + 1))
    fi
}

echo "1. Platform Target:"
assert_opt_enabled "CONFIG_ARCH_VIRT"
# Vexpress must not be enabled as primary platform
if grep -E -q "^CONFIG_ARCH_VEXPRESS=y" "$CONFIG_FILE"; then
    echo "  [FAIL] CONFIG_ARCH_VEXPRESS=y is active! Vexpress is rejected in Phase 3." >&2
    FAILURES=$((FAILURES + 1))
else
    echo "  [PASS] Legacy vexpress platform disabled"
fi

echo "2. Translation Architecture:"
assert_opt_disabled "CONFIG_ARM_LPAE"
assert_opt_enabled "CONFIG_VMSPLIT_3G"
assert_opt_value "CONFIG_PAGE_OFFSET" "0xC0000000"

echo "3. Console & Logging:"
assert_opt_enabled "CONFIG_SERIAL_EARLYCON"
assert_opt_enabled "CONFIG_SERIAL_AMBA_PL011"
assert_opt_enabled "CONFIG_SERIAL_AMBA_PL011_CONSOLE"
assert_opt_enabled "CONFIG_PRINTK"

echo "4. Virtual I/O & Filesystem:"
assert_opt_enabled "CONFIG_DEVTMPFS"
assert_opt_enabled "CONFIG_DEVTMPFS_MOUNT"
assert_opt_enabled "CONFIG_VIRTIO_MMIO"
assert_opt_enabled "CONFIG_VIRTIO_BLK"
assert_opt_enabled "CONFIG_EXT4_FS"

if [ "$FAILURES" -eq 0 ]; then
    echo "=== Effective Kernel Configuration Validated Successfully ==="
    exit 0
else
    echo "=== Config Validation Failed with $FAILURES errors ===" >&2
    exit 1
fi
