#!/bin/bash
set -euo pipefail

# Inspect and contrast vmlinux, zImage, and System.map

ARTIFACTS_DIR="../../fixtures/artifacts"
VMLINUX="${ARTIFACTS_DIR}/vmlinux"
ZIMAGE="${ARTIFACTS_DIR}/arch/arm/boot/zImage"
SYSTEM_MAP="${ARTIFACTS_DIR}/System.map"

echo "=== Inspecting Kernel Image Artifacts ==="

echo "--- 1. vmlinux (Raw ELF32 Kernel Executable) ---"
readelf -h "$VMLINUX" | grep -E "Class:|Machine:|Entry point"
ls -lh "$VMLINUX"

echo ""
echo "--- 2. arch/arm/boot/zImage (Compressed Bootable Image) ---"
file "$ZIMAGE" || ls -l "$ZIMAGE"
ls -lh "$ZIMAGE"

echo ""
echo "--- 3. System.map (Kernel Symbol Lookup Table) ---"
head -n 5 "$SYSTEM_MAP"
echo "..."
grep -E "start_kernel|console_init|rest_init" "$SYSTEM_MAP"

echo ""
echo "--- 4. Cross-Referencing vmlinux Symbols with System.map ---"
VMLINUX_START=$(readelf -s "$VMLINUX" | awk '$8 == "start_kernel" {print $2}')
MAP_START=$(awk '$3 == "start_kernel" {print $1}' "$SYSTEM_MAP")

echo "vmlinux start_kernel address:    0x${VMLINUX_START}"
echo "System.map start_kernel address: 0x${MAP_START}"

if [ "0x${VMLINUX_START}" = "0x${MAP_START}" ]; then
    echo "[PASS] System.map is strictly synchronized with vmlinux!"
else
    echo "[FAIL] System.map symbol address mismatch!" >&2
    exit 1
fi
