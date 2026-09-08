#!/bin/bash
set -euo pipefail

# Audit binary artifacts in a directory or file list
# Classifies each artifact into:
#   NOT_ELF
#   HOST_ELF (Machine != ARM)
#   TARGET_DYNAMIC (Machine == ARM, has PT_INTERP, lists loader & NEEDED)
#   TARGET_STATIC (Machine == ARM, no PT_INTERP, no dynamic section)

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path_to_binary_or_directory>" >&2
    exit 1
fi

TARGET_PATH="$1"
FILES=()

if [ -d "$TARGET_PATH" ]; then
    while IFS= read -r f; do
        [ -f "$f" ] && FILES+=("$f")
    done < <(find "$TARGET_PATH" -type f)
elif [ -f "$TARGET_PATH" ]; then
    FILES+=("$TARGET_PATH")
else
    echo "Error: Target path does not exist: $TARGET_PATH" >&2
    exit 1
fi

READELF="readelf"

echo "=== Target Binary Artifact Audit ==="
printf "%-25s | %-16s | %-16s | %-32s\n" "Filename" "Classification" "Machine" "Details / Interpreter"
echo "--------------------------+------------------+------------------+---------------------------------"

for file in "${FILES[@]}"; do
    fname=$(basename "$file")
    
    # Check if ELF
    if ! "$READELF" -h "$file" >/dev/null 2>&1; then
        printf "%-25s | %-16s | %-16s | %-32s\n" "$fname" "NOT_ELF" "-" "Non-ELF data or script"
        continue
    fi
    
    MACHINE=$("$READELF" -h "$file" | awk -F: '/Machine:/ {print $2}' | xargs)
    
    if [[ "$MACHINE" != *"ARM"* ]]; then
        printf "%-25s | %-16s | %-16s | %-32s\n" "$fname" "HOST_ELF" "$MACHINE" "Architecture mismatch for ARM target"
        continue
    fi
    
    # Check for INTERP segment
    INTERP=$("$READELF" -l "$file" 2>/dev/null | grep "program interpreter" | awk -F: '{print $2}' | tr -d '[] ' || true)
    
    if [ -n "$INTERP" ]; then
        NEEDED=$("$READELF" -d "$file" 2>/dev/null | awk -F'Shared library: \\[' '/NEEDED/ {print $2}' | tr -d ']' | tr '\n' ',' | sed 's/,$//' || true)
        printf "%-25s | %-16s | %-16s | %-32s\n" "$fname" "TARGET_DYNAMIC" "$MACHINE" "Interp: $INTERP (Libs: $NEEDED)"
    else
        # Check if dynamic section exists
        if "$READELF" -d "$file" 2>&1 | grep -q "There is no dynamic section"; then
            printf "%-25s | %-16s | %-16s | %-32s\n" "$fname" "TARGET_STATIC" "$MACHINE" "Self-contained (No INTERP/DYNAMIC)"
        else
            printf "%-25s | %-16s | %-16s | %-32s\n" "$fname" "TARGET_DYNAMIC_NODL" "$MACHINE" "Dynamic section without PT_INTERP"
        fi
    fi
done
echo "--------------------------+------------------+------------------+---------------------------------"
