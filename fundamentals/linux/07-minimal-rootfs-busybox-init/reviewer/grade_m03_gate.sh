#!/bin/bash
set -euo pipefail

# Reviewer Grading Oracle for P3-M03 Gate (REVIEWER-ONLY entry point).
#
# Grades the learner's repaired candidate submission:
#   gate/build/candidate_rootfs   (repaired tree)
#   gate/build/candidate.cpio.gz  (packaged archive, if present)
#
# Grading has two halves and BOTH must pass:
#   1. STATIC: real-BusyBox artifact identity, structure, inittab/rcS
#      contract -- delegated to reviewer/oracle_m03.sh so the scored contract
#      lives in exactly one place.
#   2. RUNTIME: the learner's PACKAGED ARCHIVE is booted against the pinned
#      real Linux 6.18.50 zImage with rdinit=/sbin/init, and the fresh capture
#      must prove real BusyBox 1.36.1 as PID 1 through the SUBMITTED inittab
#      and rcS, plus an interactive shell. A canonical/stock rootfs is never
#      substituted: only the submitted archive is booted.
#
# Environment:
#   LINUX_SRC   : pinned Linux tree (default /tmp/linux-6.18.50)
#   BOOT_TIMEOUT: candidate boot budget in seconds (default 60)

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M03_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

CANDIDATE="${1:-$M03_ROOT/gate/build/candidate_rootfs}"
ARCHIVE="${2:-}"
if [ -z "$ARCHIVE" ] && [ -f "$M03_ROOT/gate/build/candidate.cpio.gz" ]; then
    ARCHIVE="$M03_ROOT/gate/build/candidate.cpio.gz"
fi

if [ ! -d "$CANDIDATE" ]; then
    echo "REJECT: Gate candidate '$CANDIDATE' does not exist." >&2
    echo "        Provision and repair first: make -C gate provision" >&2
    exit 2
fi

echo "=== [1/2] Static grading of the repaired candidate ==="
bash "$M03_ROOT/reviewer/oracle_m03.sh" "$CANDIDATE" ${ARCHIVE:+"$ARCHIVE"}

echo ""
echo "=== [2/2] Runtime grading of the learner's PACKAGED archive ==="
if [ -z "$ARCHIVE" ] || [ ! -f "$ARCHIVE" ]; then
    echo "REJECT: runtime grading requires the learner's packaged archive." >&2
    echo "        Package your repair first: make -C gate package" >&2
    exit 2
fi

RUNDIR=$(mktemp -d /tmp/m03_gate_runtime_XXXXXX)
trap 'rm -rf "$RUNDIR"' EXIT

BOOT_TIMEOUT="${BOOT_TIMEOUT:-60}" \
    bash "$M03_ROOT/scripts/run_real_busybox_candidate.sh" \
    "$ARCHIVE" "$RUNDIR/candidate_boot.log" "$RUNDIR/candidate_boot.argv"

echo "--- Observed candidate boot milestones ---"
grep -E "Linux version|Kernel command line|Run /sbin/init|Embedded Linux System Initialized|press Enter to activate|BusyBox v1\.36\.1|PID +USER +TIME" \
    "$RUNDIR/candidate_boot.log" | head -n 12 || true
echo "-----------------------------------------"

if ! bash "$M03_ROOT/scripts/verify_busybox_candidate_runtime.sh" \
        "$RUNDIR/candidate_boot.log" "$RUNDIR/candidate_boot.argv" "$ARCHIVE"; then
    echo "[FAIL] ASSESSMENT MISMATCH: the submitted packaged archive did not reach" >&2
    echo "       real BusyBox init as PID 1 with the submitted inittab/rcS semantics." >&2
    exit 1
fi

echo "[PASS] P3-M03 Gate Submission: VERIFIED (100/100)"
