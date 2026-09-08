#!/bin/bash
set -euo pipefail

# P3-M02 Assessment Reference Oracle (REVIEWER-ONLY)
# ---------------------------------------------------
# Grades the materialized Challenge and Gate fixtures against the internal
# expected assessment design (config deviation profile, artifact identity,
# symbol-map synchronization profile, zImage magic). This file is the single
# source of truth for the seeded assessment design and must never be
# referenced by or copied into learner-facing material.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M02_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
cd "$M02_ROOT"

CROSS_COMPILE="${CROSS_COMPILE:-arm-none-linux-gnueabihf-}"
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    echo "ERROR: Cross compiler '${CROSS_COMPILE}gcc' not found in PATH." >&2
    exit 1
fi

NM="${CROSS_COMPILE}nm"
command -v "$NM" >/dev/null 2>&1 || NM="nm"

# NOTE: fixtures are materialized by the caller (reviewer-check orchestrator or
# the oracle mutation harness) so that mutated fixtures are graded as-is.

echo "=================================================================="
echo "=== P3-M02 Assessment Reference Oracle                         ==="
echo "=================================================================="

FAILURES=0

fail() {
    echo "[FAIL] ASSESSMENT MISMATCH: $1"
    FAILURES=$((FAILURES + 1))
}

expect_config_line() {
    local cfg="$1" line="$2"
    grep -q -F "$line" "$cfg" || fail "$cfg: missing expected line '$line'"
}

reject_config_line() {
    local cfg="$1" line="$2"
    if grep -q -F "$line" "$cfg"; then
        fail "$cfg: forbidden line '$line' present"
    fi
}

norm_hex() {
    echo "$1" | sed 's/^0x//; s/^0*//' | tr '[:upper:]' '[:lower:]'
}

sym_addr_vmlinux() {
    local vmlinux="$1" sym="$2"
    "$NM" -n "$vmlinux" 2>/dev/null | awk -v s="$sym" '$3 == s {print $1; exit}'
}

sym_addr_map() {
    local map="$1" sym="$2"
    awk -v s="$sym" '$3 == s {print $1; exit}' "$map"
}

# Expect the exact set of drifted symbols in a System.map vs vmlinux
expect_drift_profile() {
    local vmlinux="$1" map="$2" shift
    shift 2
    local -a expected=("$@")
    local sym drifted=()
    for sym in stext start_kernel setup_arch console_init rest_init kernel_init; do
        local vaddr maddr
        vaddr=$(sym_addr_vmlinux "$vmlinux" "$sym")
        maddr=$(sym_addr_map "$map" "$sym")
        if [ -z "$maddr" ]; then
            fail "$map: symbol $sym missing"
            continue
        fi
        if [ "$(norm_hex "$vaddr")" != "$(norm_hex "$maddr")" ]; then
            drifted+=("$sym")
        fi
    done
    local observed="${drifted[*]}"
    local want="${expected[*]}"
    if [ "$observed" != "$want" ]; then
        fail "$map: drift profile mismatch (expected drift on: '${want:-none}', observed: '${observed:-none}')"
    fi
}

# ---- 1. Challenge: config deviation profile ----
echo "--- Challenge config deviation profile ---"
CH_CFG="challenge/fixtures/candidate_effective.config"
[ -f "$CH_CFG" ] || fail "$CH_CFG missing"
expect_config_line "$CH_CFG" "CONFIG_ARCH_VIRT=y"
reject_config_line "$CH_CFG" "CONFIG_ARCH_VEXPRESS=y"
expect_config_line "$CH_CFG" "CONFIG_ARM_LPAE=y"
expect_config_line "$CH_CFG" "CONFIG_VMSPLIT_3G=y"
expect_config_line "$CH_CFG" "CONFIG_PAGE_OFFSET=0xC0000000"
expect_config_line "$CH_CFG" "CONFIG_SERIAL_AMBA_PL011=y"
expect_config_line "$CH_CFG" "CONFIG_SERIAL_AMBA_PL011_CONSOLE=y"
expect_config_line "$CH_CFG" "CONFIG_SERIAL_EARLYCON=y"
expect_config_line "$CH_CFG" "CONFIG_DEVTMPFS=y"
expect_config_line "$CH_CFG" "CONFIG_DEVTMPFS_MOUNT=y"
expect_config_line "$CH_CFG" "CONFIG_VIRTIO_MMIO=y"
expect_config_line "$CH_CFG" "CONFIG_VIRTIO_BLK=y"
expect_config_line "$CH_CFG" "CONFIG_EXT4_FS=y"
expect_config_line "$CH_CFG" "# CONFIG_PRINTK is not set"

# ---- 3. Challenge: vmlinux entry + drift profile ----
CH_VMLINUX="challenge/fixtures/candidate_vmlinux"
CH_MAP="challenge/fixtures/candidate_System.map"
[ -f "$CH_VMLINUX" ] || fail "$CH_VMLINUX missing"
[ -f "$CH_MAP" ] || fail "$CH_MAP missing"
CH_ENTRY=$(readelf -h "$CH_VMLINUX" | awk -F: '/Entry point/ {print $2}' | xargs)
if [ "$(norm_hex "$CH_ENTRY")" != "c0008000" ]; then
    fail "$CH_VMLINUX: entry point $CH_ENTRY does not match expected PAGE_OFFSET+0x8000"
fi
CH_MACHINE=$(readelf -h "$CH_VMLINUX" | awk -F: '/Machine:/ {print $2}' | xargs)
[[ "$CH_MACHINE" == *"ARM"* ]] || fail "$CH_VMLINUX: machine is not ARM"
expect_drift_profile "$CH_VMLINUX" "$CH_MAP" "console_init"

# ---- 4. Gate: config deviation profile ----
echo "--- Gate config deviation profile ---"
GT_CFG="gate/fixtures/gate_effective.config"
[ -f "$GT_CFG" ] || fail "$GT_CFG missing"
expect_config_line "$GT_CFG" "CONFIG_ARCH_VIRT=y"
reject_config_line "$GT_CFG" "CONFIG_ARCH_VEXPRESS=y"
expect_config_line "$GT_CFG" "# CONFIG_ARM_LPAE is not set"
expect_config_line "$GT_CFG" "CONFIG_VMSPLIT_3G=y"
expect_config_line "$GT_CFG" "CONFIG_PAGE_OFFSET=0xC0000000"
expect_config_line "$GT_CFG" "CONFIG_SERIAL_AMBA_PL011=y"
expect_config_line "$GT_CFG" "CONFIG_SERIAL_AMBA_PL011_CONSOLE=y"
expect_config_line "$GT_CFG" "CONFIG_SERIAL_EARLYCON=y"
expect_config_line "$GT_CFG" "CONFIG_DEVTMPFS=y"
expect_config_line "$GT_CFG" "CONFIG_DEVTMPFS_MOUNT=y"
expect_config_line "$GT_CFG" "CONFIG_VIRTIO_MMIO=y"
expect_config_line "$GT_CFG" "# CONFIG_VIRTIO_BLK is not set"
expect_config_line "$GT_CFG" "# CONFIG_EXT4_FS is not set"
expect_config_line "$GT_CFG" "CONFIG_PRINTK=y"

# ---- 5. Gate: vmlinux + zImage + drift profile ----
GT_VMLINUX="gate/fixtures/gate_vmlinux"
GT_ZIMAGE="gate/fixtures/gate_zImage"
GT_MAP="gate/fixtures/gate_System.map"
[ -f "$GT_VMLINUX" ] || fail "$GT_VMLINUX missing"
[ -f "$GT_ZIMAGE" ] || fail "$GT_ZIMAGE missing"
[ -f "$GT_MAP" ] || fail "$GT_MAP missing"

if ! bash scripts/audit_zimage_header.sh "$GT_ZIMAGE" >/dev/null 2>&1; then
    fail "$GT_ZIMAGE: production zImage header audit did not pass (expected valid magic)"
fi

GT_MACHINE=$(readelf -h "$GT_VMLINUX" | awk -F: '/Machine:/ {print $2}' | xargs)
[[ "$GT_MACHINE" == *"ARM"* ]] || fail "$GT_VMLINUX: machine is not ARM"
expect_drift_profile "$GT_VMLINUX" "$GT_MAP" "kernel_init"

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "=== ASSESSMENT REFERENCE PASS (M02 Challenge + Gate) ==="
    exit 0
else
    echo "=== ASSESSMENT REFERENCE REJECT: $FAILURES mismatch(es) ===" >&2
    exit 1
fi
