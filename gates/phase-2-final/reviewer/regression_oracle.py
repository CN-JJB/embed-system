#!/usr/bin/env python3
"""
regression_oracle.py: Reviewer-Isolated Exact Semantic Regression Oracle.
Houses all exact seed signatures, hardware register expectations, disassembly checks,
and reference contract verifications. Reviewer-only; never exposed to learners.
"""
import sys
import os
import subprocess
import re

def verify_part_a(elf_path, nm="arm-none-eabi-nm", readelf="arm-none-eabi-readelf"):
    """
    Part A Oracle:
    - Intended Seed Defect: _edata defined before input sections in linker script,
      causing _edata == _sdata (empty copy range, 0 bytes copied from Flash to SRAM).
    - Reference Pass: _edata > _sdata and _sidata == LOADADDR(.data).
    """
    try:
        nm_out = subprocess.check_output([nm, elf_path]).decode("utf-8", errors="replace")
    except Exception as e:
        return "ERROR", f"Could not run nm: {e}"

    symbols = {}
    for line in nm_out.splitlines():
        parts = line.split()
        if len(parts) >= 3:
            symbols[parts[2]] = int(parts[0], 16)

    sdata = symbols.get("_sdata")
    edata = symbols.get("_edata")
    sidata = symbols.get("_sidata")

    if sdata is None or edata is None or sidata is None:
        return "ERROR", f"Missing boundary symbols: sdata={sdata}, edata={edata}, sidata={sidata}"

    try:
        readelf_out = subprocess.check_output([readelf, "-l", elf_path]).decode("utf-8", errors="replace")
    except Exception as e:
        return "ERROR", f"Could not run readelf: {e}"

    data_lma = None
    for line in readelf_out.splitlines():
        parts = line.split()
        if len(parts) >= 6 and parts[0] == "LOAD" and parts[2].startswith("0x20000000"):
            data_lma = int(parts[3], 16)
            break

    if data_lma is None:
        return "ERROR", "Could not locate .data segment LOADADDR in readelf -l"

    if edata == sdata:
        return "SEEDED_DEFECT_REJECT", (
            f"Intended defect confirmed: _edata (0x{edata:08x}) == _sdata (0x{sdata:08x}). "
            f"Copy range length is 0 bytes; startup copy loop skips initialized data relocation."
        )
    elif edata > sdata and sidata == data_lma:
        return "REFERENCE_PASS", (
            f"Reference fix verified: _sdata=0x{sdata:08x}, _edata=0x{edata:08x} "
            f"(size={edata-sdata} bytes), _sidata=LOADADDR(.data)=0x{sidata:08x}."
        )
    else:
        return "UNEXPECTED_FAILURE", f"Unexpected state: sdata=0x{sdata:x}, edata=0x{edata:x}, sidata=0x{sidata:x}, lma=0x{data_lma:x}"


def verify_part_b(elf_path, objdump="arm-none-eabi-objdump"):
    """
    Part B Oracle:
    - Intended Seed Defect: DMA1_Channel1->CCR configured without DMA_CCR_MINC (0x80).
      Disassembly reveals CCR load with 0x52e (1326 decimal), causing continuous
      transfers to overwrite buffer index 0 repeatedly without incrementing.
    - Reference Pass: CCR load contains 0x5ae (1454 decimal), enabling CIRC, MINC,
      16-bit word size, and interrupts.
    """
    try:
        asm = subprocess.check_output([objdump, "-d", elf_path]).decode("utf-8", errors="replace")
    except Exception as e:
        return "ERROR", f"Could not run objdump: {e}"

    m = re.search(r"<dma1_channel1_init>:.*?(bx\s+lr|pop\s+\{[^}]*pc\})", asm, re.DOTALL)
    if not m:
        return "ERROR", "Function <dma1_channel1_init> not found in disassembly"

    body = m.group(0)

    # Check for 0x52e (1326) vs 0x5ae (1454)
    if re.search(r"#1326|0x52e", body):
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: DMA1_Channel1->CCR configured with 0x52e (1326 decimal). "
            "Bit 7 (DMA_CCR_MINC = 0x80) is omitted; memory pointer does not increment."
        )
    elif re.search(r"#1454|0x5ae", body):
        return "REFERENCE_PASS", (
            "Reference fix verified: DMA1_Channel1->CCR configured with 0x5ae (1454 decimal). "
            "Circular mode (CIRC), memory increment (MINC), and transfer interrupts enabled."
        )
    else:
        return "UNEXPECTED_FAILURE", "CCR configuration does not match expected seeded (0x52e) or reference (0x5ae) pattern"


def verify_part_c(elf_path, objdump="arm-none-eabi-objdump"):
    """
    Part C Oracle:
    - Intended Seed Defect: EXTI0_IRQn configured with logical priority 3 (hardware byte 0x30).
      Under Cortex-M3 architecture, 0x30 is higher urgency than 0x50
      (configMAX_SYSCALL_INTERRUPT_PRIORITY), triggering FreeRTOS portASSERT_IF_INTERRUPT_PRIORITY_INVALID().
    - Reference Pass: Priority byte >= 0x50 (e.g. 0x60 / 96 decimal), satisfying syscall boundary.
    """
    try:
        asm = subprocess.check_output([objdump, "-d", elf_path]).decode("utf-8", errors="replace")
    except Exception as e:
        return "ERROR", f"Could not run objdump: {e}"

    m = re.search(r"<interrupt_config_init>:.*?(strb[^\n]*)", asm, re.DOTALL)
    if not m:
        return "ERROR", "Function <interrupt_config_init> not found in disassembly"

    block = m.group(0)
    prio_match = re.search(r"movs\s+r[0-3],\s+#(\d+)", block)
    if not prio_match:
        return "ERROR", "Could not extract priority literal from <interrupt_config_init>"

    val = int(prio_match.group(1))

    if val == 48:  # 0x30
        return "SEEDED_DEFECT_REJECT", (
            f"Intended defect confirmed: EXTI0 configured with priority byte 0x{val:02x} (logical 3). "
            f"Numerical byte 0x{val:02x} < 0x50, violating FreeRTOS configMAX_SYSCALL_INTERRUPT_PRIORITY boundary."
        )
    elif val >= 80:  # >= 0x50
        return "REFERENCE_PASS", (
            f"Reference fix verified: EXTI0 configured with priority byte 0x{val:02x} (logical {val>>4}). "
            f"Numerical byte 0x{val:02x} >= 0x50, safely within FreeRTOS syscall boundary."
        )
    else:
        return "UNEXPECTED_FAILURE", f"Unexpected priority byte value: 0x{val:02x} ({val})"


def verify_part_d(src_path):
    """
    Part D Oracle:
    - Intended Seed Defect: task_storage acquires xSensorBusLock with xSemaphoreTake
      but omits xSemaphoreGive, leaking the lock. When task_telemetry wakes up to refresh
      IWDG, it blocks on xSensorBusLock indefinitely, causing watchdog hardware reset.
    - Reference Pass: task_storage releases xSensorBusLock via xSemaphoreGive(xSensorBusLock).
    """
    if not os.path.exists(src_path):
        return "ERROR", f"File not found: {src_path}"

    with open(src_path, "r", encoding="utf-8", errors="replace") as f:
        src = f.read()

    storage_match = re.search(r"void\s+task_storage\s*\([^)]*\)\s*\{(.*?)\n\}", src, re.DOTALL)
    if not storage_match:
        return "ERROR", "Function task_storage not found in source"

    body = storage_match.group(1)

    has_take = "xSemaphoreTake" in body and "xSensorBusLock" in body
    has_give = "xSemaphoreGive" in body and "xSensorBusLock" in body

    if has_take and not has_give:
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: task_storage acquires xSensorBusLock without calling xSemaphoreGive. "
            "Unreleased mutex causes mutual blocking and starves task_telemetry watchdog refresh."
        )
    elif has_take and has_give:
        return "REFERENCE_PASS", (
            "Reference fix verified: task_storage acquires and releases xSensorBusLock via xSemaphoreGive, "
            "preserving concurrency safety and continuous watchdog refresh."
        )
    else:
        return "UNEXPECTED_FAILURE", f"Unexpected lock usage in task_storage: take={has_take}, give={has_give}"


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: regression_oracle.py <part-a|part-b|part-c|part-d> <target-file-or-elf> [tool...]")
        sys.exit(1)

    part = sys.argv[1]
    target = sys.argv[2]

    if part == "part-a":
        status, msg = verify_part_a(target, *sys.argv[3:])
    elif part == "part-b":
        status, msg = verify_part_b(target, *sys.argv[3:])
    elif part == "part-c":
        status, msg = verify_part_c(target, *sys.argv[3:])
    elif part == "part-d":
        status, msg = verify_part_d(target)
    else:
        print(f"Unknown part: {part}")
        sys.exit(1)

    print(f"[{status}] {msg}")
    if status in ["SEEDED_DEFECT_REJECT", "REFERENCE_PASS"]:
        sys.exit(0)
    else:
        sys.exit(1)
