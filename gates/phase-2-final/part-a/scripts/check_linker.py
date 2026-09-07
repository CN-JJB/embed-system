#!/usr/bin/env python3
import sys
import subprocess

if len(sys.argv) < 2:
    print("Usage: check_linker.py <elf-file> [nm] [readelf]")
    sys.exit(1)

elf = sys.argv[1]
nm = sys.argv[2] if len(sys.argv) > 2 else "arm-none-eabi-nm"
readelf = sys.argv[3] if len(sys.argv) > 3 else "arm-none-eabi-readelf"

try:
    nm_out = subprocess.check_output([nm, elf]).decode("utf-8", errors="replace")
except Exception as e:
    print(f"[FAIL] Could not run {nm} on {elf}: {e}")
    sys.exit(1)

sidata = None
for line in nm_out.splitlines():
    parts = line.split()
    if len(parts) >= 3 and parts[2] == "_sidata":
        sidata = int(parts[0], 16)
        break

try:
    readelf_out = subprocess.check_output([readelf, "-l", elf]).decode("utf-8", errors="replace")
except Exception as e:
    print(f"[FAIL] Could not run {readelf} on {elf}: {e}")
    sys.exit(1)

data_lma = None
for line in readelf_out.splitlines():
    parts = line.split()
    if len(parts) >= 6 and parts[0] == "LOAD" and parts[2].startswith("0x20000000"):
        data_lma = int(parts[3], 16)
        break

if sidata is None:
    print("[FAIL] Symbol '_sidata' not found in ELF symbol table")
    sys.exit(1)

if data_lma is None:
    print("[FAIL] Could not determine LMA for .data segment from program headers")
    sys.exit(1)

if sidata != data_lma:
    print(f"[FAIL] Part A LMA mismatch: _sidata (0x{sidata:08x}) != LOADADDR(.data) (0x{data_lma:08x})!")
    print("       Startup data copy loop will copy wrong Flash bytes into SRAM .data section.")
    sys.exit(1)
else:
    print(f"[PASS] Part A Linker LMA contract verified: _sidata == LOADADDR(.data) == 0x{sidata:08x}.")
    sys.exit(0)
