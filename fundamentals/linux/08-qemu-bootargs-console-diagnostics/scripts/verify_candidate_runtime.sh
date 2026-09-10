#!/bin/bash
set -euo pipefail

# P3-M04 Candidate Runtime Binding Verifier (RUNTIME EVIDENCE ONLY)
#
# Binds a fresh QEMU console capture to the EXACT candidate launch
# configuration that produced it. Two independent halves must agree:
#
#   1. HOST PROVENANCE (scripts/run_candidate_manifest.sh output): the
#      normalized argv actually executed, including machine, highmem,
#      gic-version, CPU, RAM, SMP, nographic, kernel, initrd and bootargs.
#      It is re-derived from the candidate manifest here, so a provenance
#      file cannot claim a configuration the manifest does not declare.
#
#   2. GUEST EVIDENCE (kernel console log): the kernel command line, kernel
#      version, console handoff, initramfs unpack, PID-1 launch, and the
#      guest-visible CPU count / available RAM / real BusyBox userspace
#      responses that must match the executed configuration.
#
# A forged or stock log cannot satisfy half 1, and a declaration that was
# never executed cannot satisfy half 2.
#
# Usage: verify_candidate_runtime.sh <provenance> <console-log> <manifest>
#
# Exit codes: 0 = VERIFIED, 2 = REJECT (semantic), 1 = usage/internal error.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

PROVENANCE="${1:-}"
LOG_FILE="${2:-}"
MANIFEST="${3:-}"

for arg in PROVENANCE LOG_FILE MANIFEST; do
    val="${!arg}"
    if [ -z "$val" ] || [ ! -f "$val" ]; then
        echo "ERROR: required input '$arg' missing or not a file: '${val:-<empty>}'" >&2
        exit 1
    fi
done

echo "=== Verifying CANDIDATE-BOUND runtime evidence ==="
echo "    provenance: $PROVENANCE"
echo "    console log: $LOG_FILE"
echo "    manifest:   $MANIFEST"

# --- Half 1: host provenance <-> candidate declarations -------------------
prov_val() { grep -E "^$1=" "$PROVENANCE" | head -n 1 | cut -d= -f2-; }

P_MACHINE=$(prov_val MACHINE)
P_CPU=$(prov_val CPU)
P_MEM=$(prov_val MEM)
P_SMP=$(prov_val SMP)
P_NOGRAPHIC=$(prov_val NOGRAPHIC)
P_BOOTARGS=$(prov_val BOOTARGS)
P_KERNEL=$(prov_val KERNEL)
P_INITRD=$(prov_val INITRD)
P_FINGERPRINT=$(prov_val ARGV_FINGERPRINT)
P_TIMEOUT=$(prov_val TIMEOUT_SEC)

# Re-derive the declarations straight from the candidate manifest.
REDERIVED=$(mktemp /tmp/m04_rederive_XXXXXX.txt)
trap 'rm -f "$REDERIVED"' EXIT
set +e
python3 "$SCRIPT_DIR/parse_candidate_manifest.py" \
    --manifest "$MANIFEST" --kernel "$P_KERNEL" --initrd "$P_INITRD" \
    > "$REDERIVED" 2>&1
REDERIVE_RC=$?
set -e
if [ "$REDERIVE_RC" -ne 0 ]; then
    echo "REJECT: candidate manifest is not canonical / not parseable:" >&2
    sed 's/^/  /' "$REDERIVED" | tail -n 12 >&2
    exit 2
fi
red_val() { grep -E "^$1=" "$REDERIVED" | head -n 1 | cut -d= -f2-; }

REJECT_COUNT=0
reject() { echo "REJECT: $1" >&2; REJECT_COUNT=$((REJECT_COUNT + 1)); }
pass() { echo "[PASS] $1"; }

bind_dimension() {
    local name="$1" declared="$2" executed="$3"
    if [ "$declared" != "$executed" ]; then
        reject "$name mismatch: manifest declares '$declared' but the executed \
argv carries '$executed' (declaration not actually executed)"
    else
        pass "$name bound to the executed candidate argv: $executed"
    fi
}

for dim in MACHINE CPU MEM SMP BOOTARGS; do
    bind_dimension "$dim" "$(red_val "$dim")" "$(prov_val "$dim")"
done
if [ "$P_NOGRAPHIC" != "true" ]; then
    reject "NOGRAPHIC: executed argv is not headless-serial ('$P_NOGRAPHIC')"
else
    pass "NOGRAPHIC bound to the executed candidate argv: true"
fi
if [ "$(red_val ARGV_FINGERPRINT)" != "$P_FINGERPRINT" ]; then
    reject "normalized argv fingerprint mismatch between manifest and provenance"
else
    pass "normalized argv fingerprint committed to provenance: $P_FINGERPRINT"
fi

# Machine sub-dimensions must be separately visible in the executed argv.
for sub in "highmem=off" "gic-version=2"; do
    if [[ "$P_MACHINE" != *"$sub"* ]]; then
        reject "executed machine definition lacks '$sub'"
    else
        pass "executed machine definition carries '$sub'"
    fi
done
if [[ "$P_MACHINE" != *"virt"* ]]; then
    reject "executed machine definition is not the 'virt' platform"
fi

# Kernel / initrd must be the pinned real runtime inputs, and the argv must
# be the argv that QEMU was actually handed.
if [ ! -f "$P_KERNEL" ] || [ ! -f "$P_INITRD" ]; then
    reject "provenance references kernel/initrd that do not exist"
fi
case "$P_INITRD" in
    *synthetic*) reject "provenance references the synthetic teaching fixture" ;;
esac
if ! grep -qE "^-kernel$" <(sed -n '/^ARGV_BEGIN$/,/^ARGV_END$/p' "$PROVENANCE"); then
    reject "provenance argv block does not contain a '-kernel' option"
fi
P_KERNEL_SHA=$(prov_val KERNEL_SHA256)
P_INITRD_SHA=$(prov_val INITRD_SHA256)
if [ -f "$P_KERNEL" ] && [ -n "$P_KERNEL_SHA" ]; then
    ACTUAL=$(sha256sum "$P_KERNEL" | awk '{print $1}')
    [ "$ACTUAL" = "$P_KERNEL_SHA" ] \
        && pass "executed kernel sha256 matches provenance" \
        || reject "executed kernel sha256 differs from provenance"
fi
if [ -f "$P_INITRD" ] && [ -n "$P_INITRD_SHA" ]; then
    ACTUAL=$(sha256sum "$P_INITRD" | awk '{print $1}')
    [ "$ACTUAL" = "$P_INITRD_SHA" ] \
        && pass "executed initrd sha256 matches provenance" \
        || reject "executed initrd sha256 differs from provenance"
fi
if [ -z "$P_TIMEOUT" ]; then
    reject "provenance lacks the capture budget metadata"
fi

# --- Half 2: guest evidence from the fresh console capture ----------------
TOTAL_LINES=$(wc -l < "$LOG_FILE")
if [ "$TOTAL_LINES" -lt 60 ]; then
    reject "console log is only $TOTAL_LINES lines: not a real kernel boot capture"
fi

CURSOR=0
expect_after() {
    local desc="$1" pattern="$2" rel
    rel=$(tail -n +"$((CURSOR + 1))" "$LOG_FILE" | grep -nE -m1 "$pattern" | cut -d: -f1 || true)
    if [ -z "$rel" ]; then
        reject "runtime evidence missing '$desc' (/$pattern/) after line $CURSOR"
        return 1
    fi
    CURSOR=$((CURSOR + rel))
    pass "runtime checkpoint @line $CURSOR: $desc"
}

expect_after "kernel decompressor start" "Booting Linux on physical CPU" || true
expect_after "real kernel version" "Linux version 6\.18\.50" || true
expect_after "early console registration" "bootconsole .*enabled" || true
expect_after "kernel command line" "Kernel command line:" || true

CMDLINE=$(grep -E "Kernel command line:" "$LOG_FILE" | head -n 1 || true)
if [ -z "$CMDLINE" ]; then
    reject "console log has no 'Kernel command line:' line"
else
    for tok in $P_BOOTARGS; do
        if ! echo "$CMDLINE" | grep -qF "$tok"; then
            reject "logged kernel command line lacks executed bootargs token '$tok'"
        fi
    done
    NCONS=$(echo "$CMDLINE" | grep -oE 'console=[^[:space:]]+' | wc -l | tr -d ' ')
    if [ "$NCONS" -ne 1 ]; then
        reject "logged command line carries $NCONS console= tokens (canonical requires exactly one)"
    else
        pass "logged kernel command line bound to the executed bootargs (1 console token)"
    fi
fi

# Guest-visible RAM must match the executed -m value.
MEM_KB=$(echo "$P_MEM" | sed -nE 's/^([0-9]+)M$/\1/p')
if [ -n "$MEM_KB" ]; then
    EXPECT_MEM_BYTES=$((MEM_KB * 1024 * 1024))
    AVAIL_LINE=$(grep -E "Memory: .* available" "$LOG_FILE" | head -n 1 || true)
    if [ -z "$AVAIL_LINE" ]; then
        reject "runtime evidence missing kernel memory-detection line"
    else
        AVAIL_KB=$(echo "$AVAIL_LINE" | grep -oE '[0-9]+K/[0-9]+K available' | head -n 1 | sed -E 's#^[0-9]+K/([0-9]+)K available$#\1#')
        if [ -z "$AVAIL_KB" ]; then
            reject "could not parse available RAM from: $AVAIL_LINE"
        else
            ACTUAL_BYTES=$((AVAIL_KB * 1024))
            DELTA=$((ACTUAL_BYTES - EXPECT_MEM_BYTES))
            [ "$DELTA" -lt 0 ] && DELTA=$((-DELTA))
            # Guest "available" memory is the executed RAM minus reserved
            # kernel/serial/GIC reservations (a few MiB), never a different
            # -m size (a 256M or 1G launch differs by >= 250 MiB).
            if [ "$DELTA" -gt $((16 * 1024 * 1024)) ]; then
                reject "guest RAM (${ACTUAL_BYTES} bytes) does not match the executed -m ${P_MEM} (${EXPECT_MEM_BYTES} bytes)"
            else
                pass "guest-visible RAM matches the executed -m $P_MEM (reserved delta ${DELTA} bytes)"
            fi
        fi
    fi
else
    reject "executed MEM value '$P_MEM' is not a '<N>M' size"
fi

# Guest-visible online CPU count must match the executed -smp value.
if ! [[ "$P_SMP" =~ ^[0-9]+$ ]]; then
    reject "executed SMP value '$P_SMP' is not numeric"
else
    CPU_LINES=$(grep -cE "^\[[[:space:]]*[0-9.]+\] CPU[0-9]+:" "$LOG_FILE" || true)
    if [ "$CPU_LINES" -eq 0 ]; then
        CPU_LINES=$(grep -cE "CPU[0-9]+: " "$LOG_FILE" || true)
    fi
    if [ "$CPU_LINES" -ne "$P_SMP" ]; then
        reject "guest reported $CPU_LINES online CPU(s) but the executed argv used -smp $P_SMP"
    else
        pass "guest-visible CPU count matches the executed -smp $P_SMP"
    fi
fi

expect_after "console handoff (ttyAMA0 enabled)" "printk: console \[ttyAMA0\] enabled" || true
expect_after "early console retirement (handoff complete)" "bootconsole \[pl11\] disabled" || true
expect_after "initramfs unpack" "Trying to unpack rootfs image as initramfs" || true
expect_after "initmem free (pre-userspace)" "Freeing unused kernel image \(initmem\)" || true
expect_after "PID 1 launch" "Run /init as init process" || true
expect_after "real BusyBox init ready marker" "REAL-BUSYBOX-INIT-READY" || true

TAIL_AFTER_READY=$(tail -n +"$((CURSOR + 1))" "$LOG_FILE")
check_post_ready() {
    local desc="$1" pat="$2"
    if ! grep -Eq "$pat" <<<"$TAIL_AFTER_READY"; then
        reject "runtime evidence missing '$desc' (/$pat/) after userspace ready"
    else
        pass "runtime checkpoint (post-ready): $desc"
    fi
}
check_post_ready "real BusyBox identity" "BusyBox v1\.36\.1"
check_post_ready "real BusyBox ps response" "PID +USER +TIME +COMMAND"
check_post_ready "active proc mount state" "/proc.*proc"
check_post_ready "active sysfs mount state" "/sys.*sysfs"

echo "------------------------------------------------------------------"
if [ "$REJECT_COUNT" -eq 0 ]; then
    echo "[PASS] Candidate-bound runtime evidence VERIFIED: machine/CPU/RAM/SMP/"
    echo "       nographic/kernel/initrd/bootargs all bound to the executed argv."
    exit 0
fi
echo "REJECT: $REJECT_COUNT runtime-binding mismatch(es) for the submitted candidate" >&2
exit 2
