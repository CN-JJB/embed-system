#!/usr/bin/env python3
"""
check_artifact.py: Generic Build & Firmware Artifact Integrity Check.
Verifies that the compiled ELF binary exists, adheres to the Cortex-M3 architecture,
fits within physical silicon memory limits (64 KB Flash, 20 KB SRAM), and exports
fundamental startup symbols.
Generic and non-answer-bearing: does NOT grade root-cause fix correctness.
"""
import sys
import os
import subprocess

if len(sys.argv) < 2:
    print("Usage: check_artifact.py <elf-file> [readelf] [nm]")
    sys.exit(1)

elf_path = sys.argv[1]
readelf = sys.argv[2] if len(sys.argv) > 2 else "arm-none-eabi-readelf"
nm = sys.argv[3] if len(sys.argv) > 3 else "arm-none-eabi-nm"

if not os.path.isfile(elf_path):
    print(f"[FAIL] Artifact missing: {elf_path}")
    sys.exit(1)

# 1. Verify ELF Header architecture
try:
    header_out = subprocess.check_output([readelf, "-h", elf_path]).decode("utf-8", errors="replace")
except Exception as e:
    print(f"[FAIL] Could not read ELF header: {e}")
    sys.exit(1)

if "ARM" not in header_out:
    print("[FAIL] Target architecture is not ARM")
    sys.exit(1)

# 2. Verify Program Headers and Silicon Memory Bounds (STM32F103C8: 64KB Flash, 20KB RAM)
try:
    segments_out = subprocess.check_output([readelf, "-l", elf_path]).decode("utf-8", errors="replace")
except Exception as e:
    print(f"[FAIL] Could not read program headers: {e}")
    sys.exit(1)

flash_used = 0
ram_used = 0

for line in segments_out.splitlines():
    parts = line.split()
    if len(parts) >= 6 and parts[0] == "LOAD":
        paddr = int(parts[3], 16)
        memsz = int(parts[5], 16)
        if 0x08000000 <= paddr < 0x08010000:
            flash_used = max(flash_used, (paddr - 0x08000000) + memsz)
        vaddr = int(parts[2], 16)
        if 0x20000000 <= vaddr < 0x20005000:
            ram_used = max(ram_used, (vaddr - 0x20000000) + memsz)

if flash_used > 64 * 1024:
    print(f"[FAIL] Flash footprint ({flash_used} bytes) exceeds STM32F103C8 limit (65536 bytes)")
    sys.exit(1)

if ram_used > 20 * 1024:
    print(f"[FAIL] RAM footprint ({ram_used} bytes) exceeds STM32F103C8 limit (20480 bytes)")
    sys.exit(1)

# 3. Verify Fundamental Hardware Symbols
try:
    nm_out = subprocess.check_output([nm, elf_path]).decode("utf-8", errors="replace")
except Exception as e:
    print(f"[FAIL] Could not read symbol table: {e}")
    sys.exit(1)

required_symbols = ["Reset_Handler", "_estack"]
missing_syms = []
for sym in required_symbols:
    if not any(sym == line.split()[-1] for line in nm_out.splitlines() if len(line.split()) >= 3):
        missing_syms.append(sym)

if missing_syms:
    print(f"[FAIL] Required hardware symbol(s) missing: {missing_syms}")
    sys.exit(1)

print(f"[PASS] Part A generic firmware artifact verified (Flash: {flash_used} B, RAM: {ram_used} B).")
sys.exit(0)
