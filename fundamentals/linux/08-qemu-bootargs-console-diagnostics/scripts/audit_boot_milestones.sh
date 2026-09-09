#!/bin/bash
set -euo pipefail

# Semantic Boot-Log Milestone Auditor (M04)
# Verifies the presence and strict chronological ordering of key boot milestones.

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
    "Starting PID 1 Minimal Init Process"
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
