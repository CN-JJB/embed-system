#!/bin/bash
set -euo pipefail

# Runtime Boot Evidence Verifier (M04) — RUNTIME GATE ONLY.
# Binds a boot log to an ACTUAL execution. Unlike the static teaching
# auditor (audit_boot_milestones.sh), this script REJECTS forged or
# concatenated milestone text: the log must carry the full semantic chain
# of a real Linux 6.18.50 + real BusyBox boot, in kernel order, with the
# exact command line under test and live userspace command responses.
#
# Usage: verify_runtime_boot.sh <log> [expected-bootargs]
#   expected-bootargs defaults to the canonical contract:
#     earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init
#   The log's 'Kernel command line:' must contain every expected token and
#   exactly one console= token.

LOG_FILE="${1:-}"
EXPECTED_BOOTARGS="${2:-earlycon=pl011,0x09000000 console=ttyAMA0,115200 rdinit=/init}"

if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
    echo "ERROR: Valid boot log file required: '$LOG_FILE'" >&2
    exit 1
fi

echo "=== Verifying RUNTIME boot evidence: $LOG_FILE ==="

# Sequential ordered search: each checkpoint must appear AFTER the previous
# one (forged concatenation of subsets fails on missing/wrong-order lines).
CURSOR=0
expect_after() {
    local desc="$1" pattern="$2"
    local rel
    rel=$(tail -n +"$((CURSOR + 1))" "$LOG_FILE" | grep -nE -m1 "$pattern" | cut -d: -f1 || true)
    if [ -z "$rel" ]; then
        echo "REJECT: Runtime evidence missing '$desc' (/$pattern/) after line $CURSOR." >&2
        exit 2
    fi
    CURSOR=$((CURSOR + rel))
    echo "[PASS] Runtime checkpoint @line $CURSOR: $desc"
}

TOTAL_LINES=$(wc -l < "$LOG_FILE")
if [ "$TOTAL_LINES" -lt 60 ]; then
    echo "REJECT: Boot log too short ($TOTAL_LINES lines) for a real kernel boot; forged fragment suspected." >&2
    exit 2
fi

expect_after "decompressor/kernel start" "Booting Linux on physical CPU"
expect_after "real kernel version" "Linux version 6\.18\.50"
expect_after "early console registration" "printk: legacy bootconsole \[pl11\] enabled"
expect_after "kernel command line" "Kernel command line:"

# Bind the command line to the configuration under test.
CMDLINE=$(grep -E "Kernel command line:" "$LOG_FILE" | head -n 1)
for tok in $EXPECTED_BOOTARGS; do
    if ! echo "$CMDLINE" | grep -qF "$tok"; then
        echo "REJECT: Logged kernel command line lacks expected token '$tok'." >&2
        echo "        Got: $CMDLINE" >&2
        exit 2
    fi
done
NCONS=$(echo "$CMDLINE" | grep -oE 'console=[^[:space:]]+' | wc -l | tr -d ' ')
if [ "$NCONS" -ne 1 ]; then
    echo "REJECT: Logged command line carries $NCONS console= tokens; canonical runtime requires exactly one." >&2
    exit 2
fi
echo "[PASS] Logged command line bound to expected bootargs ($NCONS console token)."
# Exact binding: no extra tokens beyond the expected canonical set
# (order-insensitive). Closes the harmless-extra-arg false-pass at runtime.
# Note: QEMU serial captures carry trailing CR characters; strip them before
# the set comparison (the subset check above is CR-insensitive via grep -F).
LOGGED_ARGS=$(echo "$CMDLINE" | tr -d '\r' | sed -n 's/.*Kernel command line:[[:space:]]*//p' | tr -s ' ' | sed 's/^ *//;s/ *$//')
if [ -n "$LOGGED_ARGS" ]; then
    EXPECT_SORTED=$(echo "$EXPECTED_BOOTARGS" | tr -d '\r' | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ *$//')
    LOGGED_SORTED=$(echo "$LOGGED_ARGS" | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ' | sed 's/ *$//')
    if [ "$EXPECT_SORTED" != "$LOGGED_SORTED" ]; then
        echo "REJECT: Logged kernel command line carries extra/mismatched tokens (expected '$EXPECTED_BOOTARGS', logged '$LOGGED_ARGS')." >&2
        exit 2
    fi
    echo "[PASS] Logged command line exactly matches the expected bootargs token set."
fi

expect_after "memory detection" "Memory: .* available"
expect_after "console driver handoff (ttyAMA0 enabled)" "printk: console \[ttyAMA0\] enabled"
expect_after "early console retirement (handoff complete)" "printk: legacy bootconsole \[pl11\] disabled"
expect_after "initramfs unpack" "Trying to unpack rootfs image as initramfs"
expect_after "initmem free (pre-userspace)" "Freeing unused kernel image \(initmem\) memory"
expect_after "PID 1 launch" "Run /init as init process"
expect_after "real BusyBox init ready" "REAL-BUSYBOX-INIT-READY"

# Post-userspace command responses may arrive in any order (the guest shell
# executes whatever the run script sends first), so they are verified as
# present-anywhere-after-READY rather than in a fixed sequence.
TAIL_AFTER_READY=$(tail -n +"$((CURSOR + 1))" "$LOG_FILE")
check_post_ready() {
    local desc="$1" pat="$2"
    if ! grep -Eq "$pat" <<<"$TAIL_AFTER_READY"; then
        echo "REJECT: Runtime evidence missing '$desc' (/$pat/) after userspace ready." >&2
        exit 2
    fi
    echo "[PASS] Runtime checkpoint (post-ready): $desc"
}
check_post_ready "real BusyBox identity" "BusyBox v1\.36\.1"
check_post_ready "real BusyBox ps response" "PID +USER +TIME +COMMAND"
check_post_ready "active proc mount state" "/proc.*proc"

echo "[PASS] Runtime boot evidence VERIFIED (bound to actual execution)."
