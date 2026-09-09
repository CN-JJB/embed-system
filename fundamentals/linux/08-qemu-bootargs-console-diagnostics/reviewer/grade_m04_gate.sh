#!/bin/bash
set -euo pipefail

# Reviewer Grading Oracle for P3-M04 Gate (REVIEWER-ONLY entry point).
# Grades the learner's candidate submission:
#   gate/build/candidate_boot_config.sh (+ gate/build/candidate_boot.log)
# and then RE-EXECUTES the candidate launch itself against the pinned real
# kernel + real BusyBox initramfs, capturing a fresh log that must also
# verify. A stock repository reference log can NEVER satisfy the runtime
# portion: both the submitted log and the fresh capture are bound to the
# candidate's own BOOTARGS.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
M04_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
LINUX_DIR=$(cd "${M04_ROOT}/.." && pwd)

CONFIG_FILE="${1:-$M04_ROOT/gate/build/candidate_boot_config.sh}"
LOG_FILE="${2:-$M04_ROOT/gate/build/candidate_boot.log}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "REJECT: Gate candidate configuration '$CONFIG_FILE' does not exist." >&2
    echo "        Provision and author first: make -C gate provision" >&2
    exit 2
fi

echo "=== Grading P3-M04 Gate Submission ==="

# 1. Grade the submitted artifacts (config + submitted-log binding).
if [ -f "$LOG_FILE" ]; then
    bash "$M04_ROOT/reviewer/oracle_m04.sh" "$CONFIG_FILE" "$LOG_FILE"
else
    echo "[GRADE] No submitted log at $LOG_FILE; grading config only, then capturing fresh runtime evidence."
    bash "$M04_ROOT/reviewer/oracle_m04.sh" "$CONFIG_FILE"
fi

# 2. Preferred path: re-execute the candidate launch and verify fresh evidence.
LINUX_SRC="${LINUX_SRC:-/tmp/linux-6.18.50}"
REAL_ZIMAGE="$LINUX_SRC/arch/arm/boot/zImage"
REAL_INITRD="$LINUX_DIR/07-minimal-rootfs-busybox-init/fixtures/build/real_rootfs.cpio.gz"
if [ ! -f "$REAL_ZIMAGE" ] || [ ! -f "$REAL_INITRD" ]; then
    echo "REJECT: Re-execution requires the pinned real kernel ($REAL_ZIMAGE) and real initramfs ($REAL_INITRD)." >&2
    exit 2
fi
if ! command -v qemu-system-arm >/dev/null 2>&1; then
    echo "QEMU runtime status: UNVERIFIED (qemu-system-arm not found in PATH)" >&2
    exit 2
fi

STRIPPED=$(grep -v '^[[:space:]]*#' "$CONFIG_FILE" || true)
CAND_BOOTARGS=""
if echo "$STRIPPED" | grep -Eq 'BOOTARGS='; then
    CAND_BOOTARGS=$(echo "$STRIPPED" | grep -E 'BOOTARGS=' | tail -n 1 | sed -E 's/^[[:space:]]*BOOTARGS=["'"'"']?([^"'"'"']+)["'"'"']?.*$/\1/')
fi
[ -n "$CAND_BOOTARGS" ] || { echo "REJECT: Cannot extract candidate BOOTARGS for re-execution." >&2; exit 2; }

FRESH_LOG=$(mktemp /tmp/m04_gate_fresh_XXXXXX.log)
trap 'rm -f "$FRESH_LOG"' EXIT
echo "[GRADE] Re-executing candidate launch (fresh capture)..."
TIMEOUT_SEC=40 BOOTARGS="$CAND_BOOTARGS" OUTPUT_LOG="$FRESH_LOG" \
    bash "$M04_ROOT/scripts/run_qemu_diagnostic.sh" "$CAND_BOOTARGS" "$FRESH_LOG" >/dev/null 2>&1 || true
bash "$M04_ROOT/scripts/verify_runtime_boot.sh" "$FRESH_LOG" "$CAND_BOOTARGS"

echo "[PASS] P3-M04 Gate Submission: VERIFIED (100/100)"
