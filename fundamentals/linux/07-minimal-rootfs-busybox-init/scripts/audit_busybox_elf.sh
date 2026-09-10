#!/bin/bash
set -euo pipefail

# Audit ELF binary for static ARM target constraints (M03)
# 1. Target Machine = ARM (EM_ARM)
# 2. No PT_INTERP (no dynamic linker specified)
# 3. No dynamic section / DT_NEEDED dependencies

TARGET_ELF="${1:-}"
if [ -z "$TARGET_ELF" ] || [ ! -f "$TARGET_ELF" ]; then
    echo "ERROR: Target ELF file not provided or does not exist: '$TARGET_ELF'" >&2
    exit 1
fi

READELF="readelf"
if ! command -v "$READELF" >/dev/null 2>&1; then
    echo "ERROR: readelf not found in PATH" >&2
    exit 1
fi

# 1. Check machine architecture
MACHINE=$("$READELF" -h "$TARGET_ELF" | awk -F: '/Machine:/ {print $2}' | xargs)
if [[ "$MACHINE" != *"ARM"* ]]; then
    echo "REJECT: ELF machine '$MACHINE' is not ARM (expected ARM target)." >&2
    exit 2
fi

# 2. Check ELF type
ELF_TYPE=$("$READELF" -h "$TARGET_ELF" | awk -F: '/Type:/ {print $2}' | xargs)
if [[ "$ELF_TYPE" != *"EXEC"* ]] && [[ "$ELF_TYPE" != *"DYN"* ]]; then
    echo "REJECT: ELF type '$ELF_TYPE' is neither EXEC nor DYN executable." >&2
    exit 2
fi

# 3. Check for dynamic program interpreter (PT_INTERP)
INTERP=$("$READELF" -l "$TARGET_ELF" | grep "INTERP" || true)
if [ -n "$INTERP" ]; then
    echo "REJECT: ELF contains dynamic program interpreter (PT_INTERP): $INTERP" >&2
    echo "        A minimal standalone rootfs requires a statically linked BusyBox binary." >&2
    exit 2
fi

# 4. Check for dynamic section (DT_NEEDED)
DYNAMIC_SEC=$("$READELF" -d "$TARGET_ELF" 2>&1 || true)
if [[ "$DYNAMIC_SEC" == *"NEEDED"* ]]; then
    echo "REJECT: ELF contains dynamic library dependencies (DT_NEEDED):" >&2
    echo "$DYNAMIC_SEC" | grep "NEEDED" >&2
    exit 2
fi

echo "[PASS] ELF static ARM identity verified: $TARGET_ELF (Machine: $MACHINE, Static: YES, No PT_INTERP, No DT_NEEDED)"
