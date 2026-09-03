#!/usr/bin/env bash
set -euo pipefail

# FD Audit Helper Script
# Usage: ./scripts/fd_audit.sh [pid]

PID="${1:-self}"

if [ ! -d "/proc/$PID/fd" ]; then
    echo "Error: /proc/$PID/fd does not exist or insufficient permissions."
    exit 1
fi

echo "=== File Descriptor Audit for PID $PID ==="
echo "Active descriptors in /proc/$PID/fd:"
ls -l "/proc/$PID/fd" | tail -n +2 | while read -r line; do
    echo "  $line"
done

FD_COUNT=$(ls -1 "/proc/$PID/fd" | wc -l)
echo "Total active descriptors: $FD_COUNT"
