#!/bin/bash
set -euo pipefail

READELF="readelf"
TARGET_FILE="${1:-app_faulty}"

if [ ! -f "$TARGET_FILE" ]; then
    echo "Error: File $TARGET_FILE does not exist. Run 'make build-fault' first." >&2
    exit 1
fi

echo "=== Diagnosing Binary Architecture ==="
echo "Target file: $TARGET_FILE"

# Extract ELF machine field
MACHINE=$("$READELF" -h "$TARGET_FILE" 2>/dev/null | awk -F: '/Machine:/ {print $2}' | xargs || true)
CLASS=$("$READELF" -h "$TARGET_FILE" 2>/dev/null | awk -F: '/Class:/ {print $2}' | xargs || true)

echo "ELF Class:   $CLASS"
echo "ELF Machine: $MACHINE"

if [[ "$MACHINE" == *"ARM"* ]]; then
    echo "[PASS] Binary architecture matches ARM target (Machine: $MACHINE)"
    exit 0
else
    echo "[FAIL] Architecture mismatch! Expected ARM target, but detected: $MACHINE"
    echo "       Target Linux kernel will return -ENOEXEC ('cannot execute binary file: Exec format error')."
    echo "       Root cause: Compiled with host compiler instead of cross compiler."
    exit 1
fi
