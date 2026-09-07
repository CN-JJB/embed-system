#!/usr/bin/env python3
import sys
import subprocess
import re

if len(sys.argv) < 2:
    print("Usage: check_priority.py <path-to-elf>")
    sys.exit(1)

elf_path = sys.argv[1]
objdump = sys.argv[2] if len(sys.argv) > 2 else "arm-none-eabi-objdump"

try:
    asm = subprocess.check_output([objdump, "-d", elf_path]).decode("utf-8", errors="replace")
except Exception as e:
    print(f"[FAIL] Could not run objdump on {elf_path}: {e}")
    sys.exit(1)

# Extract body of interrupt_config_init
m = re.search(r"<interrupt_config_init>:.*?(strb[^\n]*)", asm, re.DOTALL)
if not m:
    print("[FAIL] Function <interrupt_config_init> not found in disassembly")
    sys.exit(1)

block = m.group(0)

# In Cortex-M3, NVIC_SetPriority(IRQn, priority) encodes priority into (priority << 4)
# In disassembly, this appears as movs rX, #<byte> before the strb to NVIC->IPR
prio_match = re.search(r"movs\s+r[0-3],\s+#(\d+)", block)
if not prio_match:
    print("[FAIL] Could not locate priority value in <interrupt_config_init>")
    sys.exit(1)

val = int(prio_match.group(1))

# configMAX_SYSCALL_INTERRUPT_PRIORITY is 0x50 (80 decimal)
# Numerical values < 80 have higher hardware urgency and violate the FreeRTOS API boundary!
if val < 80:
    print(f"[FAIL] EXTI0_IRQn configured with priority byte 0x{val:02x} (< 0x50 / logical 5)!")
    print("       BASEPRI (0x50) fails to mask this ISR, violating FreeRTOS critical sections.")
    sys.exit(1)
else:
    print(f"[PASS] EXTI0_IRQn priority byte is 0x{val:02x} (>= 0x50, safe for FreeRTOS).")
    sys.exit(0)
