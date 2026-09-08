#!/bin/bash
set -euo pipefail

# Semantic validator & diagnostic oracle for Fault F03 (Stale System.map)
# Binds actual symbol addresses from vmlinux against the candidate System.map

VMLINUX="${1:-fixtures/vmlinux}"
MAP_FILE="${2:-fixtures/System.map.stale}"

if [ ! -f "$VMLINUX" ] || [ ! -f "$MAP_FILE" ]; then
    echo "ERROR: Artifacts missing. Run 'make setup-fixtures' first." >&2
    exit 1
fi

echo "=== Diagnosing System.map Synchronization (Fault F03) ==="
echo "Kernel binary:   $VMLINUX"
echo "Candidate map:   $MAP_FILE"
echo ""

SYMBOLS=("stext" "start_kernel" "rest_init" "kernel_init")
MISMATCH_COUNT=0

printf "%-25s | %-16s | %-16s | %-10s\n" "Symbol Name" "vmlinux Addr" "System.map Addr" "Status"
echo "--------------------------+------------------+------------------+-----------"

for sym in "${SYMBOLS[@]}"; do
    # Extract address from vmlinux using readelf/nm
    VADDR=$(readelf -s "$VMLINUX" 2>/dev/null | awk -v s="$sym" '$8 == s {print $2}' || true)
    if [ -z "$VADDR" ]; then
        VADDR=$(nm -n "$VMLINUX" 2>/dev/null | awk -v s="$sym" '$3 == s {print $1}' || true)
    fi
    
    # Extract address from candidate System.map
    MADDR=$(awk -v s="$sym" '$3 == s {print $1}' "$MAP_FILE" || true)
    
    # Normalize hex strings (strip leading 0s or prefixes)
    NORM_V=$(echo "$VADDR" | sed 's/^0x//; s/^0*//' | tr '[:upper:]' '[:lower:]')
    NORM_M=$(echo "$MADDR" | sed 's/^0x//; s/^0*//' | tr '[:upper:]' '[:lower:]')
    
    if [ -z "$NORM_M" ]; then
        printf "%-25s | 0x%-14s | %-16s | %-10s\n" "$sym" "$VADDR" "MISSING" "FAIL"
        MISMATCH_COUNT=$((MISMATCH_COUNT + 1))
    elif [ "$NORM_V" != "$NORM_M" ]; then
        printf "%-25s | 0x%-14s | 0x%-14s | %-10s\n" "$sym" "$VADDR" "$MADDR" "DRIFT"
        MISMATCH_COUNT=$((MISMATCH_COUNT + 1))
    else
        printf "%-25s | 0x%-14s | 0x%-14s | %-10s\n" "$sym" "$VADDR" "$MADDR" "MATCH"
    fi
done
echo "--------------------------+------------------+------------------+-----------"

if [ "$MISMATCH_COUNT" -eq 0 ]; then
    echo "[PASS] System.map is strictly synchronized with current vmlinux binary!"
    exit 0
else
    echo "[FAIL] Detected $MISMATCH_COUNT symbol address mismatches / drift!"
    echo ""
    echo "       ROOT CAUSE EXPLANATION:"
    echo "       System.map was not regenerated when vmlinux was rebuilt."
    echo "       During kernel oops/panic decoding or dynamic tracing, stale addresses"
    echo "       will point to incorrect functions or unmapped memory."
    echo "       Fix: Run 'nm -n vmlinux > System.map' to synchronize."
    exit 1
fi
