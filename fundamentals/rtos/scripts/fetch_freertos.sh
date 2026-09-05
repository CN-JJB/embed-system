#!/usr/bin/env bash
# ==============================================================================
# fetch_freertos.sh: Deterministic verification and fetch script for FreeRTOS Kernel
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENDOR_DIR="${RTOS_DIR}/vendor/freertos"

FREERTOS_TAG="V11.3.0"
FREERTOS_COMMIT="9b777ae5c5b8e9e456065a00294d1e5f5f9facf5"

echo "=== Verifying / Fetching FreeRTOS Kernel Dependencies ==="
echo "Target Vendor Directory: ${VENDOR_DIR}"

mkdir -p "${VENDOR_DIR}/include"
mkdir -p "${VENDOR_DIR}/portable/GCC/ARM_CM3"
mkdir -p "${VENDOR_DIR}/portable/MemMang"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Cloning FreeRTOS-Kernel (tag: ${FREERTOS_TAG}, commit: ${FREERTOS_COMMIT})..."
git clone --depth 1 --branch "${FREERTOS_TAG}" https://github.com/FreeRTOS/FreeRTOS-Kernel.git "${TMP_DIR}/FreeRTOS-Kernel"

ACTUAL_COMMIT="$(git -C "${TMP_DIR}/FreeRTOS-Kernel" rev-parse HEAD)"
if [ "${ACTUAL_COMMIT}" != "${FREERTOS_COMMIT}" ]; then
    echo "ERROR: FreeRTOS-Kernel commit mismatch! Expected ${FREERTOS_COMMIT}, got ${ACTUAL_COMMIT}" >&2
    exit 1
fi
echo "FreeRTOS-Kernel commit verified: ${ACTUAL_COMMIT}"

# Copy required kernel core files
cp -r "${TMP_DIR}/FreeRTOS-Kernel/include/"* "${VENDOR_DIR}/include/"
cp "${TMP_DIR}/FreeRTOS-Kernel/tasks.c" "${VENDOR_DIR}/"
cp "${TMP_DIR}/FreeRTOS-Kernel/list.c" "${VENDOR_DIR}/"
cp "${TMP_DIR}/FreeRTOS-Kernel/queue.c" "${VENDOR_DIR}/"

# Copy ARM_CM3 port and heap_4
cp "${TMP_DIR}/FreeRTOS-Kernel/portable/GCC/ARM_CM3/port.c" "${VENDOR_DIR}/portable/GCC/ARM_CM3/"
cp "${TMP_DIR}/FreeRTOS-Kernel/portable/GCC/ARM_CM3/portmacro.h" "${VENDOR_DIR}/portable/GCC/ARM_CM3/"
cp "${TMP_DIR}/FreeRTOS-Kernel/portable/MemMang/heap_4.c" "${VENDOR_DIR}/portable/MemMang/"

# Copy licenses and notices
cp "${TMP_DIR}/FreeRTOS-Kernel/LICENSE.md" "${VENDOR_DIR}/"
cp "${TMP_DIR}/FreeRTOS-Kernel/README.md" "${VENDOR_DIR}/"

echo "=== FreeRTOS Kernel V11.3.0 dependencies successfully verified and installed ==="
