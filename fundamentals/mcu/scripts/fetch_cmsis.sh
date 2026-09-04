#!/usr/bin/env bash
# ==============================================================================
# fetch_cmsis.sh: Deterministic verification and fetch script for CMSIS headers
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCU_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VENDOR_DIR="${MCU_DIR}/vendor/cmsis"
INC_DIR="${VENDOR_DIR}/include"

CMSIS5_TAG="5.9.0"
CMSIS5_COMMIT="2b7495b8535bdcb306dac29b9ded4cfb679d7e5c"
DEVICE_TAG="v4.3.5"
DEVICE_COMMIT="8a76309ed1250d817e9c888c4417171d2ba3ba63"

echo "=== Verifying / Fetching CMSIS Dependencies ==="
echo "Target Vendor Directory: ${VENDOR_DIR}"

mkdir -p "${INC_DIR}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# 1. Fetch CMSIS_5
echo "[1/2] Checking CMSIS_5 (tag: ${CMSIS5_TAG}, commit: ${CMSIS5_COMMIT})..."
git clone --depth 1 --branch "${CMSIS5_TAG}" https://github.com/ARM-software/CMSIS_5.git "${TMP_DIR}/CMSIS_5"
ACTUAL_CMSIS5_COMMIT="$(git -C "${TMP_DIR}/CMSIS_5" rev-parse HEAD)"
if [ "${ACTUAL_CMSIS5_COMMIT}" != "${CMSIS5_COMMIT}" ]; then
    echo "ERROR: CMSIS_5 commit mismatch! Expected ${CMSIS5_COMMIT}, got ${ACTUAL_CMSIS5_COMMIT}" >&2
    exit 1
fi
echo "CMSIS_5 commit verified: ${ACTUAL_CMSIS5_COMMIT}"

cp "${TMP_DIR}/CMSIS_5/CMSIS/Core/Include/core_cm3.h" "${INC_DIR}/"
cp "${TMP_DIR}/CMSIS_5/CMSIS/Core/Include/cmsis_version.h" "${INC_DIR}/"
cp "${TMP_DIR}/CMSIS_5/CMSIS/Core/Include/cmsis_compiler.h" "${INC_DIR}/"
cp "${TMP_DIR}/CMSIS_5/CMSIS/Core/Include/cmsis_gcc.h" "${INC_DIR}/"
cp "${TMP_DIR}/CMSIS_5/CMSIS/Core/Include/mpu_armv7.h" "${INC_DIR}/"
cp "${TMP_DIR}/CMSIS_5/LICENSE.txt" "${VENDOR_DIR}/LICENSE.CMSIS_5"

# 2. Fetch cmsis-device-f1
echo "[2/2] Checking cmsis-device-f1 (tag: ${DEVICE_TAG}, commit: ${DEVICE_COMMIT})..."
git clone --depth 1 --branch "${DEVICE_TAG}" https://github.com/STMicroelectronics/cmsis-device-f1.git "${TMP_DIR}/cmsis-device-f1"
ACTUAL_DEVICE_COMMIT="$(git -C "${TMP_DIR}/cmsis-device-f1" rev-parse HEAD)"
if [ "${ACTUAL_DEVICE_COMMIT}" != "${DEVICE_COMMIT}" ]; then
    echo "ERROR: cmsis-device-f1 commit mismatch! Expected ${DEVICE_COMMIT}, got ${ACTUAL_DEVICE_COMMIT}" >&2
    exit 1
fi
echo "cmsis-device-f1 commit verified: ${ACTUAL_DEVICE_COMMIT}"

cp "${TMP_DIR}/cmsis-device-f1/Include/stm32f1xx.h" "${INC_DIR}/"
cp "${TMP_DIR}/cmsis-device-f1/Include/stm32f103xb.h" "${INC_DIR}/"
cp "${TMP_DIR}/cmsis-device-f1/Include/system_stm32f1xx.h" "${INC_DIR}/"
cp "${TMP_DIR}/cmsis-device-f1/License.md" "${VENDOR_DIR}/LICENSE.cmsis-device-f1"

echo "=== CMSIS dependencies successfully verified and installed ==="
