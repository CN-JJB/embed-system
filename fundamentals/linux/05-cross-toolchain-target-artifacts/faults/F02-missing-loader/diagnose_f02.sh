#!/bin/bash
set -euo pipefail

ROOTFS_DIR="${1:-rootfs_fixture}"
APP_PATH="${ROOTFS_DIR}/bin/app_dynamic"
READELF="readelf"

echo "=== Diagnosing Missing Dynamic Loader (Fault F02) ==="

# Step 1: Prove binary exists
if [ ! -f "$APP_PATH" ]; then
    echo "ERROR: Target application $APP_PATH does not exist. Run 'make setup-fixture' first." >&2
    exit 1
fi
echo "[PROVEN] 1. Executable file exists at: $APP_PATH"
echo "         Permissions: $(ls -l "$APP_PATH" | awk '{print $1}')"

# Step 2: Prove executable itself is NOT the missing path
if [ -x "$APP_PATH" ]; then
    echo "[PROVEN] 2. Executable has execute permissions; shell pathname itself is valid."
fi

# Step 3: Extract PT_INTERP from ELF headers
INTERP=$("$READELF" -l "$APP_PATH" | grep "program interpreter" | awk -F: '{print $2}' | tr -d '[] ' || true)
if [ -z "$INTERP" ]; then
    echo "ERROR: $APP_PATH does not request an interpreter (static binary?)." >&2
    exit 1
fi
echo "[PROVEN] 3. ELF binary requests dynamic interpreter: $INTERP"

# Step 4: Prove rootfs lacks that exact interpreter
EXPECTED_ROOTFS_LOADER="${ROOTFS_DIR}${INTERP}"
if [ -f "$EXPECTED_ROOTFS_LOADER" ]; then
    echo "[PASS] Target rootfs contains required interpreter: $EXPECTED_ROOTFS_LOADER"
    exit 0
else
    echo "[FAIL] Rootfs lacks the requested interpreter: $EXPECTED_ROOTFS_LOADER"
    echo "       Existing files in ${ROOTFS_DIR}/lib:"
    ls -la "${ROOTFS_DIR}/lib" || true
    echo ""
    echo "       ROOT CAUSE EXPLANATION:"
    echo "       When target Linux kernel executes load_elf_binary(), it opens the interpreter"
    echo "       pathname ($INTERP). Because it does not exist in rootfs, kernel returns -ENOENT (-2)."
    echo "       The userspace shell renders this as: 'sh: ./bin/app_dynamic: No such file or directory'."
    echo "       The missing file is NOT the executable; it is the INTERPRETER ($INTERP)!"
    exit 1
fi
