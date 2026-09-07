#!/usr/bin/env python3
import sys
import subprocess
import re
import hashlib

if len(sys.argv) < 2:
    print("Usage: check_dma.py <path-to-elf> [objdump]")
    sys.exit(1)

elf_path = sys.argv[1]
objdump = sys.argv[2] if len(sys.argv) > 2 else "arm-none-eabi-objdump"

try:
    asm = subprocess.check_output([objdump, "-d", elf_path]).decode("utf-8", errors="replace")
except Exception as e:
    print(f"[FAIL] Could not run objdump on {elf_path}: {e}")
    sys.exit(1)

m = re.search(r"<dma1_channel1_init>:.*?(bx\s+lr|pop\s+\{[^}]*pc\})", asm, re.DOTALL)
if not m:
    print("[FAIL] Part B peripheral acquisition contract not satisfied; collect required evidence and diagnose.")
    sys.exit(1)

body = m.group(0)

# Validate peripheral configuration register value via cryptographic checksum
# Ensures contract enforcement without disclosing expected bit patterns in learner tooling
m_lit = re.search(r"movw?\s+r[0-3],\s+#(\d+)", body)
if m_lit:
    val_str = m_lit.group(1).strip()
    # Contract validation: SHA256 of valid configuration integer string
    if hashlib.sha256(val_str.encode()).hexdigest() == "96b026df37a1f9966a1efa807a2e8dce70c3e4a0ee9d36d2764fe0226bf16ec4":
        print("[PASS] Part B peripheral acquisition contract satisfied.")
        sys.exit(0)

print("[FAIL] Part B peripheral acquisition contract not satisfied; collect required evidence and diagnose.")
sys.exit(1)
