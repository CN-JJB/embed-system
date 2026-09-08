#!/bin/bash
set -euo pipefail

CROSS_COMPILE=${CROSS_COMPILE:-arm-none-linux-gnueabihf-}
if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
    if command -v arm-linux-gnueabihf-gcc >/dev/null 2>&1; then
        CROSS_COMPILE="arm-linux-gnueabihf-"
    else
        echo "ERROR: Cross compiler not found (${CROSS_COMPILE}gcc / arm-linux-gnueabihf-gcc)" >&2
        exit 1
    fi
fi

echo "=== Target Sysroot Inspection ==="
echo "Active Cross-Compiler: $(command -v "${CROSS_COMPILE}gcc")"

SYSROOT=$("${CROSS_COMPILE}gcc" -print-sysroot 2>/dev/null || true)
if [ -z "$SYSROOT" ] || [ "$SYSROOT" = "/" ]; then
    # Some multiarch distro compilers use a multiarch path
    MULTIARCH_DIR=$("${CROSS_COMPILE}gcc" -print-file-name=libc.so.6 2>/dev/null || true)
    echo "Distro multiarch path: ${MULTIARCH_DIR}"
    SYSROOT=$(dirname "$(dirname "${MULTIARCH_DIR}")")
fi

echo "Discovered Sysroot Path: ${SYSROOT}"

echo "Searching for C library headers..."
if [ -d "${SYSROOT}/usr/include" ]; then
    echo "Found /usr/include in sysroot: $(ls "${SYSROOT}/usr/include" | head -n 5)"
elif [ -d "/usr/arm-linux-gnueabihf/include" ]; then
    echo "Found /usr/arm-linux-gnueabihf/include: $(ls /usr/arm-linux-gnueabihf/include | head -n 5)"
fi

echo "Searching for dynamic loader..."
LOADER_PATH=$("${CROSS_COMPILE}gcc" -print-file-name=ld-linux-armhf.so.3 2>/dev/null || true)
echo "Dynamic loader: ${LOADER_PATH}"

echo "Searching for target C runtime..."
LIBC_PATH=$("${CROSS_COMPILE}gcc" -print-file-name=libc.so.6 2>/dev/null || true)
echo "Target libc: ${LIBC_PATH}"

echo "=== Sysroot Inspection Complete ==="
