#!/bin/bash
set -euo pipefail

# Semantic Boot-Log Milestone Auditor (M04) — STATIC TEACHING FIXTURE ONLY.
# Verifies the presence and strict chronological ordering of key boot
# milestones in a KNOWN-CAPTURED log for log-analysis practice.
# THIS SCRIPT DOES NOT CERTIFY RUNTIME: a forged/concatenated text file
# containing the milestone strings in order WILL pass it. Runtime Gate
# certification must use scripts/verify_runtime_boot.sh, which binds the
# log to an actual execution (command line, kernel, console handoff, init,
# and real BusyBox userspace response).

LOG_FILE="${1:-}"
if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
    echo "ERROR: Valid boot log file required: '$LOG_FILE'" >&2
    exit 1
fi

echo "=== Auditing Boot-Log Milestones: $LOG_FILE ==="

# Key Milestone Definitions (Regex patterns)
MILESTONES=(
    "Linux version 6.18.50"
    "CPU: ARMv7 Processor"
    "Kernel command line:"
    "printk: console \\[ttyAMA0\\] enabled"
    "Trying to unpack rootfs image as initramfs"
    "Run /init as init process"
    "REAL-BUSYBOX-INIT-READY"
)

PREV_LINE=0
MILESTONE_IDX=1

for pattern in "${MILESTONES[@]}"; do
    LINE_NUM=$(grep -En "$pattern" "$LOG_FILE" | head -n 1 | cut -d: -f1 || true)
    if [ -z "$LINE_NUM" ]; then
        echo "REJECT: Missing expected boot milestone pattern: '$pattern'" >&2
        exit 2
    fi

    if [ "$LINE_NUM" -lt "$PREV_LINE" ]; then
        echo "REJECT: Chronological ordering violation! Milestone '$pattern' at line $LINE_NUM appeared before preceding milestone at line $PREV_LINE." >&2
        exit 2
    fi

    MATCH_TEXT=$(sed -n "${LINE_NUM}p" "$LOG_FILE" | tr -s ' ' | head -c 80)
    echo "[PASS] Milestone $MILESTONE_IDX (Line $LINE_NUM): $MATCH_TEXT..."
    PREV_LINE="$LINE_NUM"
    MILESTONE_IDX=$((MILESTONE_IDX + 1))
done

echo "[PASS] All $((${#MILESTONES[@]})) boot milestones verified in strict chronological order."
