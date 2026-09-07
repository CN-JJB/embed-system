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

symbols = {}
for line in nm_out.splitlines():
    parts = line.split()
    if len(parts) >= 3:
        symbols[parts[2]] = int(parts[0], 16)

sidata = symbols.get("_sidata")
sdata = symbols.get("_sdata")
edata = symbols.get("_edata")

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

if sidata is None or sdata is None or edata is None or data_lma is None:
    print("[FAIL] Part A runtime data relocation contract not satisfied; collect required evidence and diagnose.")
    sys.exit(1)

if edata <= sdata or sidata != data_lma:
    print("[FAIL] Part A runtime data relocation contract not satisfied; collect required evidence and diagnose.")
    sys.exit(1)

print("[PASS] Part A runtime data relocation contract satisfied.")
sys.exit(0)
