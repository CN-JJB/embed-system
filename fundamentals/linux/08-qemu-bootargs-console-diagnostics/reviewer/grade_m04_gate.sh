#!/bin/bash
set -euo pipefail

# Reviewer Grading Oracle for P3-M04 Gate (REVIEWER-ONLY entry point).
#
# Grades the learner's candidate submission:
#   gate/build/candidate_boot_manifest.conf   (data-only launch manifest)
#   gate/build/candidate_boot.argv            (executed-argv provenance)
#   gate/build/candidate_boot.log             (fresh console capture)
#
# The reviewer RE-EXECUTES the candidate's manifest through the trusted
# runner, so the fresh capture is produced from the candidate's OWN
# machine/CPU/RAM/SMP/nographic/bootargs argv. A stock reference log, a
# declaration that was never executed, or a canonical substitution by the
# runner can therefore never satisfy the runtime portion.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
LINUX_DIR=$(cd "${M04_ROOT}/.." && pwd)

MANIFEST="${1:-$M04_ROOT/gate/build/candidate_boot_manifest.conf}"
SUBMITTED_LOG="${2:-$M04_ROOT/gate/build/candidate_boot.log}"
SUBMITTED_ARGV="${3:-$M04_ROOT/gate/build/candidate_boot.argv}"

if [ ! -f "$MANIFEST" ]; then
    echo "REJECT: Gate candidate manifest '$MANIFEST' does not exist." >&2
    echo "        Provision and author first: make -C gate provision" >&2
    exit 2
fi

LINUX_SRC="${LINUX_SRC:-/tmp/linux-6.18.50}"
REAL_ZIMAGE="${LINUX_SRC}/arch/arm/boot/zImage"
REAL_INITRD="${M04_ROOT}/../07-minimal-rootfs-busybox-init/fixtures/build/real_rootfs.cpio.gz"
if [ ! -f "$REAL_ZIMAGE" ] || [ ! -f "$REAL_INITRD" ]; then
    echo "REJECT: Re-execution requires the pinned real kernel ($REAL_ZIMAGE)" >&2
    echo "        and the real BusyBox initramfs ($REAL_INITRD)." >&2
    exit 2
fi
if ! command -v qemu-system-arm >/dev/null 2>&1; then
    echo "QEMU runtime status: UNVERIFIED (qemu-system-arm not found in PATH)" >&2
    exit 2
fi

echo "=== Grading P3-M04 Gate Submission ==="

# 1. Grade the submitted artifacts: declarations + submitted argv provenance
#    + submitted console log, all bound to the same manifest.
if [ -f "$SUBMITTED_ARGV" ] && [ -f "$SUBMITTED_LOG" ]; then
    bash "$M04_ROOT/reviewer/oracle_m04.sh" "$MANIFEST" "$SUBMITTED_ARGV" "$SUBMITTED_LOG"
elif [ -f "$SUBMITTED_LOG" ]; then
    echo "[GRADE] Submitted log present without executed-argv provenance; a log"
    echo "        alone cannot prove which argv produced it: REJECT."
    bash "$M04_ROOT/reviewer/oracle_m04.sh" "$MANIFEST" "$SUBMITTED_ARGV" "$SUBMITTED_LOG"
else
    echo "[GRADE] No submitted runtime evidence at $SUBMITTED_LOG; grading the manifest contract only, then capturing fresh reviewer-owned evidence."
    bash "$M04_ROOT/reviewer/oracle_m04.sh" "$MANIFEST"
fi

# 2. Reviewer re-execution: run the CANDIDATE's own manifest through the
#    trusted runner and verify the fresh provenance + console evidence.
GRADE_DIR=$(mktemp -d /tmp/m04_gate_grade_XXXXXX)
trap 'rm -rf "$GRADE_DIR"' EXIT
FRESH_LOG="$GRADE_DIR/fresh_boot.log"
FRESH_ARGV="$GRADE_DIR/fresh_boot.argv"

echo "[GRADE] Re-executing the candidate manifest (fresh reviewer capture)..."
TIMEOUT_SEC="${TIMEOUT_SEC:-60}" \
    bash "$M04_ROOT/scripts/run_candidate_manifest.sh" \
    "$MANIFEST" "$FRESH_LOG" "$FRESH_ARGV" > "$GRADE_DIR/runner.out" 2>&1 || true
sed 's/^/    /' "$GRADE_DIR/runner.out"

if [ ! -f "$FRESH_ARGV" ] || [ ! -f "$FRESH_LOG" ]; then
    echo "[FAIL] ASSESSMENT MISMATCH: fresh candidate-bound runtime capture was not produced." >&2
    exit 1
fi
if ! bash "$M04_ROOT/scripts/verify_candidate_runtime.sh" \
        "$FRESH_ARGV" "$FRESH_LOG" "$MANIFEST"; then
    echo "[FAIL] ASSESSMENT MISMATCH: fresh reviewer runtime evidence for the submitted candidate is not bound to its executed argv." >&2
    exit 1
fi

echo "[PASS] P3-M04 Gate Submission: VERIFIED (100/100)"
