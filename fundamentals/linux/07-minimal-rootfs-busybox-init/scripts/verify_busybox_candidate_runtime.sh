#!/bin/bash
set -euo pipefail

# P3-M03 candidate-bound Real-BusyBox runtime verifier.
#
# Proves that the LEARNER'S OWN PACKAGED ARCHIVE actually booted real BusyBox
# 1.36.1 as PID 1 through BusyBox init, that the SUBMITTED /etc/inittab
# produced the activated console, that the SUBMITTED /etc/init.d/rcS ran and
# mounted the pseudo-filesystems, and that a real interactive BusyBox shell
# was reached. Evidence is read out of a single fresh console capture that is
# bound (archive digest) to the submitted archive.
#
# Usage: verify_busybox_candidate_runtime.sh <console-log> <provenance> <archive>
#
# Exit codes: 0 = VERIFIED, 2 = REJECT (semantic), 1 = usage/internal error.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

CONSOLE_LOG="${1:-}"
PROVENANCE="${2:-}"
ARCHIVE="${3:-}"

for pair in "console-log:$CONSOLE_LOG" "provenance:$PROVENANCE" "archive:$ARCHIVE"; do
    name="${pair%%:*}"; path="${pair#*:}"
    if [ -z "$path" ] || [ ! -f "$path" ]; then
        echo "ERROR: required input '$name' missing or not a file: '${path:-<empty>}'" >&2
        exit 1
    fi
done

echo "=== Verifying candidate-bound REAL BusyBox runtime evidence ==="
echo "    console:    $CONSOLE_LOG"
echo "    provenance: $PROVENANCE"
echo "    archive:    $ARCHIVE"

FAILURES=0
reject() { echo "REJECT: $1" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "[PASS] $1"; }

prov_val() { grep -E "^$1=" "$PROVENANCE" | head -n 1 | cut -d= -f2-; }

# --- 1. Evidence provenance binding ---------------------------------------
P_SHA=$(prov_val ARCHIVE_SHA256)
ACTUAL_SHA=$(sha256sum "$ARCHIVE" | awk '{print $1}')
P_ARCHIVE=$(prov_val ARCHIVE)
if [ "$ACTUAL_SHA" != "$P_SHA" ]; then
    reject "console evidence was captured for a different archive (provenance $P_SHA != submitted $ACTUAL_SHA)"
else
    pass "console evidence is bound to the submitted archive (sha256 ${ACTUAL_SHA:0:16}...)"
fi
if [ "$(readlink -f "$P_ARCHIVE")" != "$(readlink -f "$ARCHIVE")" ]; then
    reject "provenance names a different archive path than the submitted candidate"
fi
case "$ARCHIVE" in
    *synthetic*) reject "submitted archive is the synthetic teaching fixture" ;;
esac

P_KERNEL=$(prov_val KERNEL)
P_KERNEL_SHA=$(prov_val KERNEL_SHA256)
if [ ! -f "$P_KERNEL" ]; then
    reject "provenance kernel does not exist: $P_KERNEL"
elif [ "$(sha256sum "$P_KERNEL" | awk '{print $1}')" != "$P_KERNEL_SHA" ]; then
    reject "provenance kernel digest does not match the pinned kernel on disk"
else
    pass "provenance is bound to the pinned real kernel ($(basename "$P_KERNEL"))"
fi

P_MACHINE=$(prov_val MACHINE)
P_BOOTARGS=$(prov_val BOOTARGS)
for sub in "virt" "highmem=off" "gic-version=2"; do
    [[ "$P_MACHINE" == *"$sub"* ]] || reject "pinned machine definition lacks '$sub'"
done
[[ "$P_BOOTARGS" == *"rdinit=/sbin/init"* ]] \
    && pass "pinned boot selector invokes the real BusyBox init (rdinit=/sbin/init)" \
    || reject "pinned bootargs do not select /sbin/init"

# --- 2. Ordered kernel -> init -> userspace chain -------------------------
CURSOR=0
expect_after() {
    local desc="$1" pattern="$2" rel
    rel=$(tail -n +"$((CURSOR + 1))" "$CONSOLE_LOG" | grep -nE -m1 "$pattern" | cut -d: -f1 || true)
    if [ -z "$rel" ]; then
        reject "runtime evidence missing '$desc' (/$pattern/) after line $CURSOR"
        return 1
    fi
    CURSOR=$((CURSOR + rel))
    pass "runtime checkpoint @line $CURSOR: $desc"
}

TOTAL_LINES=$(wc -l < "$CONSOLE_LOG")
if [ "$TOTAL_LINES" -lt 60 ]; then
    reject "console capture is only $TOTAL_LINES lines: not a real kernel boot"
fi

expect_after "kernel decompressor start" "Booting Linux on physical CPU" || true
expect_after "real kernel version" "Linux version 6\.18\.50" || true
expect_after "kernel command line" "Kernel command line:" || true
CMDLINE=$(grep -E "Kernel command line:" "$CONSOLE_LOG" | head -n 1 || true)
if [ -n "$CMDLINE" ]; then
    if echo "$CMDLINE" | grep -qF "rdinit=/sbin/init"; then
        pass "logged command line selected the real BusyBox init"
    else
        reject "logged command line does not contain 'rdinit=/sbin/init'"
    fi
fi
expect_after "console handoff (ttyAMA0 enabled)" "printk: console \[ttyAMA0\] enabled" || true
# The early-console registration line precedes the command line in the kernel
# banner, so it is searched over the whole capture (phase presence, not order).
if grep -qE "bootconsole .*enabled" "$CONSOLE_LOG"; then
    pass "early console (bootconsole) registration observed"
else
    reject "runtime evidence missing the early-console registration banner"
fi
expect_after "early console retirement" "bootconsole .*disabled" || true
expect_after "initramfs unpack of the submitted archive" "Trying to unpack rootfs image as initramfs" || true
expect_after "initmem free (pre-userspace)" "Freeing unused kernel image \(initmem\)" || true
expect_after "PID 1 launch of /sbin/init" "Run /sbin/init as init process" || true
# rcS output proves the SUBMITTED inittab ::sysinit line executed the
# SUBMITTED rcS inside real BusyBox init.
expect_after "submitted rcS executed by BusyBox init (::sysinit)" "Embedded Linux System Initialized" || true
# askfirst handoff proves the SUBMITTED inittab askfirst line was consumed.
expect_after "submitted inittab askfirst console handoff" "Please press Enter to activate this console" || true

# --- 3. Userspace command responses from the submitted archive ------------
TAIL=$(tail -n +"$((CURSOR + 1))" "$CONSOLE_LOG")

framed_block() {
    local begin="$1" end="$2"
    awk -v b="$begin" -v e="$end" \
        'index($0,b){f=1;next} index($0,e){f=0} f' "$CONSOLE_LOG" 2>/dev/null || true
}

# 3a. Real BusyBox multi-call identity, framed between the probe markers.
IDENT_BLOCK=$(framed_block "BUSYBOX-IDENTITY-BEGIN" "BUSYBOX-IDENTITY-END")
if ! grep -qE "BusyBox v1\.36\.1" <<<"$IDENT_BLOCK"; then
    reject "guest did not answer 'busybox' with the real BusyBox v1.36.1 identity"
else
    pass "guest answered 'busybox' with the real BusyBox v1.36.1 identity"
fi

# 3b. Pseudo-filesystem mount state inside the framed mounts block.
MOUNTS_BLOCK=$(framed_block "MOUNTS-BEGIN" "MOUNTS-END")
for spec in "proc:/proc:proc" "sysfs:/sys:sysfs" "devtmpfs:/dev:devtmpfs"; do
    fstype="${spec%%:*}"; rest="${spec#*:}"; target="${rest%%:*}"
    if grep -qE "^[^[:space:]]+[[:space:]]+$target[[:space:]]+$fstype" <<<"$MOUNTS_BLOCK"; then
        pass "active $fstype mount on $target observed in the submitted rootfs"
    else
        reject "no active $fstype mount on $target observed at runtime"
    fi
done

# 3c. PID 1 is BusyBox init.
PID1_BLOCK=$(framed_block "PID1-BEGIN" "PID1-END")
PID1_COMM=$(echo "$PID1_BLOCK" | grep -vE "^~ #|^/ #|^# " | sed -n '1p' | tr -d '\r')
PID1_EXE=$(echo "$PID1_BLOCK" | grep -vE "^~ #|^/ #|^# " | sed -n '2p' | tr -d '\r')
if [ "$PID1_COMM" = "init" ]; then
    pass "PID 1 comm is 'init'"
else
    reject "PID 1 comm is not 'init' (got: '$PID1_COMM')"
fi
if [ "$PID1_EXE" = "/bin/busybox" ]; then
    pass "PID 1 exe resolves to the real /bin/busybox multi-call binary"
else
    reject "PID 1 exe does not resolve to /bin/busybox (got: '$PID1_EXE')"
fi

# 3d. Real BusyBox process-table evidence, including the askfirst shell.
PS_BLOCK=$(framed_block "PS-BEGIN" "PS-END")
if ! grep -qE "PID +USER +TIME +COMMAND" <<<"$PS_BLOCK"; then
    reject "real BusyBox 'ps' response (PID USER TIME COMMAND) missing"
else
    pass "real BusyBox process table captured"
fi
if ! grep -qE "^ *1 +[^ ]+ +[^ ]+ +init" <<<"$PS_BLOCK"; then
    reject "'ps' does not list init as PID 1"
else
    pass "'ps' lists init as PID 1"
fi
if ! grep -qE "bin/sh" <<<"$PS_BLOCK"; then
    reject "'ps' does not show the interactive /bin/sh spawned by the submitted inittab"
else
    pass "'ps' shows the interactive /bin/sh from the submitted inittab askfirst line"
fi

# 3e. Interactive shell liveness.
if ! grep -q "SHELL-PROBE-OK" <<<"$TAIL"; then
    reject "interactive shell probe did not complete (no live userspace shell)"
else
    pass "interactive BusyBox shell responded to the probe"
fi

# 3f. Synthetic masquerade guard.
if grep -q "SYNTHETIC" "$CONSOLE_LOG"; then
    reject "synthetic pedagogical fixture strings present in the runtime capture"
fi

echo "------------------------------------------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "[PASS] Submitted archive booted REAL BusyBox init as PID 1 with the"
    echo "       submitted inittab/rcS semantics and an interactive shell."
    exit 0
fi
echo "REJECT: $FAILURES candidate runtime mismatch(es) for $ARCHIVE" >&2
exit 2
