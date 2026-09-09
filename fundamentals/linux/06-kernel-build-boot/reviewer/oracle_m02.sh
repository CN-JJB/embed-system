#!/bin/bash
set -euo pipefail

# P3-M02 Assessment Reference Oracle (REVIEWER-ONLY)
# ---------------------------------------------------
# Grades the materialized Challenge and Gate fixtures against the internal
# expected assessment design. This file is the single source of truth for the
# seeded assessment design and must never be referenced by or copied into
# learner-facing material.
#
# Hardening contract (Round 3 + Round 4):
# - Kconfig symbols are graded by EXACT effective state, not substring
#   presence: exactly one state line per constrained symbol
#   (`CONFIG_X=<value>` OR `# CONFIG_X is not set`, exact full line);
#   contradictory/duplicate states and decoy/comment text are REJECTed.
# - Drift grading first PROVES each audited symbol exists exactly once in
#   vmlinux and exactly once in System.map; missing/duplicate/unparseable
#   symbols are REJECTed, never mistaken for drift.
# - Symbol existence failures MUST be recorded by fail() in the parent
#   shell. Helpers invoked via $(...) run in a subshell and cannot be
#   used to increment FAILURES.

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
    echo "[FAIL] ASSESSMENT MISMATCH: $1" >&2
    FAILURES=$((FAILURES + 1))
}

# --- Exact Kconfig effective-state grading ---
# state is either "CONFIG_X=<value>" or "# CONFIG_X is not set".
# Rules:
#   * a state line is an exact full line; assignment lines match ^CONFIG_X=
#     and the unset form matches the exact "# CONFIG_X is not set" line;
#   * comments/decoy text that merely contain the expected string are NOT
#     states and can never satisfy an expectation;
#   * exactly one effective state is required; contradictory/duplicate
#     states (multiple assignments, or assignment + unset together) are a
#     semantic REJECT;
#   * the single effective state must equal the expected state exactly.
expect_config_state() {
    local cfg="$1" sym="$2" state="$3"
    local set_count unset_count total
    set_count=$(grep -cE "^${sym}=" "$cfg" || true)
    unset_count=$(grep -cxF "# ${sym} is not set" "$cfg" || true)
    total=$((set_count + unset_count))

    if [ "$total" -eq 0 ]; then
        fail "$cfg: symbol $sym has NO effective state (decoy/comment text does not count)"
        return
    fi
    if [ "$total" -gt 1 ]; then
        fail "$cfg: symbol $sym has contradictory/duplicate effective states ($set_count assignment(s), $unset_count 'not set' line(s))"
        return
    fi

    if [ "$state" = "# ${sym} is not set" ]; then
        if [ "$unset_count" -ne 1 ]; then
            fail "$cfg: symbol $sym expected exact state '$state' but actual effective state differs"
        fi
    else
        if ! grep -qxF "$state" "$cfg"; then
            fail "$cfg: symbol $sym expected exact state '$state' but actual effective state differs"
        fi
    fi
}

norm_hex() {
    echo "$1" | sed 's/^0x//; s/^0*//' | tr '[:upper:]' '[:lower:]'
}

# Collect matching symbol addresses (one per line). Output-only: these
# helpers never call fail() and never mutate FAILURES. Command
# substitution is safe here because the parent grades the count.
collect_vmlinux_addrs() {
    local vmlinux="$1" sym="$2"
    "$NM" -n "$vmlinux" 2>/dev/null | awk -v s="$sym" '$3 == s {print $1}'
}

collect_map_addrs() {
    local map="$1" sym="$2"
    awk -v s="$sym" '$3 == s {print $1}' "$map"
}

# Expect the exact set of drifted symbols in a System.map vs vmlinux.
# Every audited symbol must first be proven to exist exactly once on BOTH
# sides in THIS parent-shell function (fail() is never invoked from a
# command-substitution subshell); only then are normalized addresses
# compared. Missing/duplicate symbols never reach MATCH/DRIFT.
expect_drift_profile() {
    local vmlinux="$1"
    local map="$2"
    shift 2
    local -a expected=("$@")
    local sym drifted=()
    for sym in stext start_kernel setup_arch console_init rest_init kernel_init; do
        local vaddrs maddrs vcount mcount vaddr maddr nv nmap
        vaddrs=$(collect_vmlinux_addrs "$vmlinux" "$sym")
        maddrs=$(collect_map_addrs "$map" "$sym")
        vcount=$(printf '%s\n' "$vaddrs" | grep -c . || true)
        mcount=$(printf '%s\n' "$maddrs" | grep -c . || true)

        if [ "$vcount" -eq 0 ]; then
            fail "$vmlinux: symbol $sym MISSING — cannot grade MATCH/DRIFT (missing is not drift)"
            continue
        fi
        if [ "$vcount" -gt 1 ]; then
            fail "$vmlinux: symbol $sym has $vcount entries — ambiguous, cannot grade MATCH/DRIFT"
            continue
        fi
        if [ "$mcount" -eq 0 ]; then
            fail "$map: symbol $sym MISSING — cannot grade MATCH/DRIFT (missing is not drift)"
            continue
        fi
        if [ "$mcount" -gt 1 ]; then
            fail "$map: symbol $sym has $mcount entries — ambiguous, cannot grade MATCH/DRIFT"
            continue
        fi

        vaddr=$vaddrs
        maddr=$maddrs
        nv=$(norm_hex "$vaddr")
        nmap=$(norm_hex "$maddr")
        if ! [[ "$nv" =~ ^[0-9a-f]+$ ]]; then
            fail "$vmlinux: symbol $sym address unparseable: '$vaddr'"
            continue
        fi
        if ! [[ "$nmap" =~ ^[0-9a-f]+$ ]]; then
            fail "$map: symbol $sym address unparseable: '$maddr'"
            continue
        fi
        if [ "$nv" != "$nmap" ]; then
            drifted+=("$sym")
        fi
    done
    local observed="${drifted[*]}"
    local want="${expected[*]}"
    if [ "$observed" != "$want" ]; then
        fail "$map: drift profile mismatch (expected drift on: '${want:-none}', observed: '${observed:-none}')"
    fi
}

# ---- 1. Challenge: config effective-state profile ----
echo "--- Challenge config effective-state profile ---"
CH_CFG="challenge/fixtures/candidate_effective.config"
[ -f "$CH_CFG" ] || fail "$CH_CFG missing"
expect_config_state "$CH_CFG" "CONFIG_ARCH_VIRT" "CONFIG_ARCH_VIRT=y"
expect_config_state "$CH_CFG" "CONFIG_ARCH_VEXPRESS" "# CONFIG_ARCH_VEXPRESS is not set"
expect_config_state "$CH_CFG" "CONFIG_ARM_LPAE" "CONFIG_ARM_LPAE=y"
expect_config_state "$CH_CFG" "CONFIG_VMSPLIT_3G" "CONFIG_VMSPLIT_3G=y"
expect_config_state "$CH_CFG" "CONFIG_PAGE_OFFSET" "CONFIG_PAGE_OFFSET=0xC0000000"
expect_config_state "$CH_CFG" "CONFIG_SERIAL_AMBA_PL011" "CONFIG_SERIAL_AMBA_PL011=y"
expect_config_state "$CH_CFG" "CONFIG_SERIAL_AMBA_PL011_CONSOLE" "CONFIG_SERIAL_AMBA_PL011_CONSOLE=y"
expect_config_state "$CH_CFG" "CONFIG_SERIAL_EARLYCON" "CONFIG_SERIAL_EARLYCON=y"
expect_config_state "$CH_CFG" "CONFIG_DEVTMPFS" "CONFIG_DEVTMPFS=y"
expect_config_state "$CH_CFG" "CONFIG_DEVTMPFS_MOUNT" "CONFIG_DEVTMPFS_MOUNT=y"
expect_config_state "$CH_CFG" "CONFIG_VIRTIO_MMIO" "CONFIG_VIRTIO_MMIO=y"
expect_config_state "$CH_CFG" "CONFIG_VIRTIO_BLK" "CONFIG_VIRTIO_BLK=y"
expect_config_state "$CH_CFG" "CONFIG_EXT4_FS" "CONFIG_EXT4_FS=y"
expect_config_state "$CH_CFG" "CONFIG_PRINTK" "# CONFIG_PRINTK is not set"

# ---- 2. Challenge: vmlinux entry + drift profile ----
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

# ---- 3. Gate: config effective-state profile ----
echo "--- Gate config effective-state profile ---"
GT_CFG="gate/fixtures/gate_effective.config"
[ -f "$GT_CFG" ] || fail "$GT_CFG missing"
expect_config_state "$GT_CFG" "CONFIG_ARCH_VIRT" "CONFIG_ARCH_VIRT=y"
expect_config_state "$GT_CFG" "CONFIG_ARCH_VEXPRESS" "# CONFIG_ARCH_VEXPRESS is not set"
expect_config_state "$GT_CFG" "CONFIG_ARM_LPAE" "# CONFIG_ARM_LPAE is not set"
expect_config_state "$GT_CFG" "CONFIG_VMSPLIT_3G" "CONFIG_VMSPLIT_3G=y"
expect_config_state "$GT_CFG" "CONFIG_PAGE_OFFSET" "CONFIG_PAGE_OFFSET=0xC0000000"
expect_config_state "$GT_CFG" "CONFIG_SERIAL_AMBA_PL011" "CONFIG_SERIAL_AMBA_PL011=y"
expect_config_state "$GT_CFG" "CONFIG_SERIAL_AMBA_PL011_CONSOLE" "CONFIG_SERIAL_AMBA_PL011_CONSOLE=y"
expect_config_state "$GT_CFG" "CONFIG_SERIAL_EARLYCON" "CONFIG_SERIAL_EARLYCON=y"
expect_config_state "$GT_CFG" "CONFIG_DEVTMPFS" "CONFIG_DEVTMPFS=y"
expect_config_state "$GT_CFG" "CONFIG_DEVTMPFS_MOUNT" "CONFIG_DEVTMPFS_MOUNT=y"
expect_config_state "$GT_CFG" "CONFIG_VIRTIO_MMIO" "CONFIG_VIRTIO_MMIO=y"
expect_config_state "$GT_CFG" "CONFIG_VIRTIO_BLK" "# CONFIG_VIRTIO_BLK is not set"
expect_config_state "$GT_CFG" "CONFIG_EXT4_FS" "# CONFIG_EXT4_FS is not set"
expect_config_state "$GT_CFG" "CONFIG_PRINTK" "CONFIG_PRINTK=y"

# ---- 4. Gate: vmlinux + zImage + drift profile ----
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
