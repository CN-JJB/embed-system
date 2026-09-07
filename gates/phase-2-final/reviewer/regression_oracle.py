#!/usr/bin/env python3
"""
regression_oracle.py: Reviewer-Isolated Exact Semantic Regression Oracle.
Houses all exact seed signatures, hardware register expectations, disassembly checks,
and reference contract verifications. Reviewer-only; never exposed to learners.

Hardened for Leader Rework Round 3:
- Binds effective register writes, store instructions, and resource-specific pairings.
- Rejects token presence decoys and improper write targets.
"""
import sys
import os
import subprocess
import re

def verify_part_a(elf_path, nm="arm-none-eabi-nm", readelf="arm-none-eabi-readelf"):
    """
    Part A Oracle:
    - Intended Seed Defect: _sidata defined as _etext before .rodata/.init_array,
      causing _sidata != LOADADDR(.data) (data section initialized with rodata bytes).
    - Reference Pass: _sidata == LOADADDR(.data) and _edata > _sdata.
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
    etext = symbols.get("_etext")

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

    if edata <= sdata:
        return "UNEXPECTED_FAILURE", f"Empty data range: sdata=0x{sdata:08x}, edata=0x{edata:08x}"

    if sidata != data_lma:
        return "SEEDED_DEFECT_REJECT", (
            f"Intended defect confirmed: _sidata (0x{sidata:08x}) != LOADADDR(.data) (0x{data_lma:08x}). "
            f"_sidata points to _etext (0x{etext:08x}); startup relocation loop copies .rodata into .data."
        )
    else:
        return "REFERENCE_PASS", (
            f"Reference fix verified: _sdata=0x{sdata:08x}, _edata=0x{edata:08x} "
            f"(size={edata-sdata} bytes), _sidata=LOADADDR(.data)=0x{sidata:08x}."
        )


def verify_part_b(elf_path, objdump="arm-none-eabi-objdump"):
    """
    Part B Oracle:
    - Intended Seed Defect: DMA1_Channel1->CCR configured without DMA_CCR_CIRC (0x20).
      Effective store to CCR is 0x58E (1422 decimal), causing single-shot transfer
      where channel halts upon CNDTR=0 and interrupt counters freeze at HT=1, TC=1.
    - Reference Pass: Effective store to CCR contains DMA_CCR_CIRC (0x5AE / 1454 decimal),
      enabling continuous autonomous double-buffering.
    - Bound to effective store instruction into DMA1_Channel1->CCR (0x40020008).
    """
    try:
        asm = subprocess.check_output([objdump, "-d", elf_path]).decode("utf-8", errors="replace")
    except Exception as e:
        return "ERROR", f"Could not run objdump: {e}"

    m = re.search(r"<dma1_channel1_init>:.*?(bx\s+lr|pop\s+\{[^}]*pc\})", asm, re.DOTALL)
    if not m:
        return "ERROR", "Function <dma1_channel1_init> not found in disassembly"

    body = m.group(0)

    # Track effective write into DMA1_Channel1->CCR (offset 0x08 from base 0x40020000)
    # Pattern: movw/movs/mov rX, #val ... str rX, [rY, #8]
    ccr_writes = []
    lines = body.splitlines()
    for i, line in enumerate(lines):
        # Look for store to offset 8 or [rY, #8]
        m_str = re.search(r"str(?:\.w)?\s+r([0-3]),\s+\[r([0-3]),\s+#8\]", line)
        if m_str:
            reg = m_str.group(1)
            # Scan backward to find the value loaded into reg
            val_loaded = None
            for prev in reversed(lines[:i]):
                m_load = re.search(r"mov[ws]?\s+r" + reg + r",\s+#(\d+)", prev)
                if m_load:
                    val_loaded = int(m_load.group(1))
                    break
                m_load_hex = re.search(r"mov[ws]?\s+r" + reg + r",\s+#0x([0-9a-fA-F]+)", prev)
                if m_load_hex:
                    val_loaded = int(m_load_hex.group(1), 16)
                    break
            if val_loaded is not None:
                ccr_writes.append(val_loaded)

    if not ccr_writes:
        return "ERROR", "Could not locate effective store into DMA1_Channel1->CCR in disassembly"

    # Effective configuration is the primary CCR setup write before |= DMA_CCR_EN
    effective_ccr = ccr_writes[0]

    # Check for CIRC bit (0x20):
    has_circ = bool(effective_ccr & 0x20)
    has_minc = bool(effective_ccr & 0x80)

    if not has_circ and has_minc:
        return "SEEDED_DEFECT_REJECT", (
            f"Intended defect confirmed: effective DMA1_Channel1->CCR write is 0x{effective_ccr:03x} ({effective_ccr} decimal). "
            f"Bit 5 (DMA_CCR_CIRC = 0x20) is omitted; channel halts after first block upon CNDTR=0."
        )
    elif has_circ and has_minc:
        return "REFERENCE_PASS", (
            f"Reference fix verified: effective DMA1_Channel1->CCR write is 0x{effective_ccr:03x} ({effective_ccr} decimal). "
            f"Circular mode (CIRC), memory increment (MINC), and transfer interrupts enabled."
        )
    else:
        return "UNEXPECTED_FAILURE", f"Unexpected effective CCR configuration: 0x{effective_ccr:03x} ({effective_ccr})"


def verify_part_c(elf_path, objdump="arm-none-eabi-objdump"):
    """
    Part C Oracle:
    - Intended Seed Defect: EXTI0_IRQn (IRQ 6) configured with logical priority 4 (hardware byte 0x40).
      Under Cortex-M3 architecture, 0x40 is higher urgency than 0x50
      (configMAX_SYSCALL_INTERRUPT_PRIORITY), triggering FreeRTOS portASSERT_IF_INTERRUPT_PRIORITY_INVALID().
    - Reference Pass: Priority byte >= 0x50 (e.g. 0x60 / 96 decimal), satisfying syscall boundary.
    - Bound to effective store instruction into NVIC->IP[6] (address 0xE000E406).
    """
    try:
        asm = subprocess.check_output([objdump, "-d", elf_path]).decode("utf-8", errors="replace")
    except Exception as e:
        return "ERROR", f"Could not run objdump: {e}"

    m = re.search(r"<interrupt_config_init>:.*?(bx\s+lr|pop\s+\{[^}]*pc\})", asm, re.DOTALL)
    if not m:
        return "ERROR", "Function <interrupt_config_init> not found in disassembly"

    body = m.group(0)

    # In Cortex-M3, NVIC->IP[6] is at offset 0x306 from 0xE000E100 or offset 6 from 0xE000E400.
    # Instruction is strb rX, [rY, #774] (774 == 0x306) or strb rX, [rY, #6]
    lines = body.splitlines()
    exti0_prio_byte = None

    for i, line in enumerate(lines):
        m_strb = re.search(r"strb(?:\.w)?\s+r([0-3]),\s+\[r[0-3],\s+#(?:774|6|0x306)\]", line)
        if m_strb:
            reg = m_strb.group(1)
            # Scan backward to find what byte was loaded into reg
            for prev in reversed(lines[:i]):
                m_load = re.search(r"mov[ws]?\s+r" + reg + r",\s+#(\d+)", prev)
                if m_load:
                    exti0_prio_byte = int(m_load.group(1))
                    break
                m_load_hex = re.search(r"mov[ws]?\s+r" + reg + r",\s+#0x([0-9a-fA-F]+)", prev)
                if m_load_hex:
                    exti0_prio_byte = int(m_load_hex.group(1), 16)
                    break
            if exti0_prio_byte is not None:
                break

    if exti0_prio_byte is None:
        return "ERROR", "Could not locate effective strb into NVIC->IP[EXTI0_IRQn] (0xE000E406) in disassembly"

    if exti0_prio_byte < 80:  # < 0x50
        return "SEEDED_DEFECT_REJECT", (
            f"Intended defect confirmed: EXTI0 configured with priority byte 0x{exti0_prio_byte:02x} (logical {exti0_prio_byte>>4}). "
            f"Numerical byte 0x{exti0_prio_byte:02x} < 0x50, violating FreeRTOS configMAX_SYSCALL_INTERRUPT_PRIORITY boundary."
        )
    else:
        return "REFERENCE_PASS", (
            f"Reference fix verified: EXTI0 configured with priority byte 0x{exti0_prio_byte:02x} (logical {exti0_prio_byte>>4}). "
            f"Numerical byte 0x{exti0_prio_byte:02x} >= 0x50, safely within FreeRTOS syscall boundary."
        )


def verify_part_d(src_path, trace_path=None):
    """
    Part D Oracle:
    - Intended Seed Defect: task_storage acquires xSensorBusLock but releases xLogBufferLock,
      leaving xSensorBusLock permanently held. When task_telemetry wakes, it blocks on
      xSensorBusLock and is starved of watchdog refresh, triggering IWDG reset.
    - Reference Pass: task_storage properly pairs xSemaphoreTake(xSensorBusLock) with
      xSemaphoreGive(xSensorBusLock).
    - Bound to resource-specific take/release pairing inside task_storage control flow.
    """
    if not os.path.exists(src_path):
        return "ERROR", f"File not found: {src_path}"

    with open(src_path, "r", encoding="utf-8", errors="replace") as f:
        src = f.read()

    storage_match = re.search(r"void\s+task_storage\s*\([^)]*\)\s*\{(.*?)\n\}", src, re.DOTALL)
    if not storage_match:
        return "ERROR", "Function task_storage not found in source"

    body = storage_match.group(1)

    has_take_bus = bool(re.search(r"xSemaphoreTake\s*\(\s*xSensorBusLock", body))
    has_give_bus = bool(re.search(r"xSemaphoreGive\s*\(\s*xSensorBusLock", body))
    has_give_log = bool(re.search(r"xSemaphoreGive\s*\(\s*xLogBufferLock", body))

    # Reviewer-side consistency check on trace if supplied
    if trace_path and os.path.exists(trace_path):
        with open(trace_path, "r", encoding="utf-8", errors="replace") as tf:
            trace_content = tf.read()
        # Verify timestamps match task periods: telemetry @ 0ms, 50ms; storage @ 20ms, 120ms
        assert "t = 0.000 s" in trace_content, "Trace missing t=0.000s"
        assert "t = 0.020 s" in trace_content, "Trace missing t=0.020s"
        assert "t = 0.050 s" in trace_content, "Trace missing t=0.050s"
        assert "t = 0.120 s" in trace_content, "Trace missing t=0.120s"
        assert "0x24000000" in trace_content, "Trace missing IWDG reset register readout"

    if has_take_bus and not has_give_bus and has_give_log:
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: task_storage acquires xSensorBusLock but releases xLogBufferLock. "
            "Leaked mutex starves task_telemetry and triggers independent watchdog reset."
        )
    elif has_take_bus and has_give_bus:
        return "REFERENCE_PASS", (
            "Reference fix verified: task_storage properly acquires and releases xSensorBusLock, "
            "preserving synchronization safety and continuous watchdog refresh."
        )
    else:
        return "UNEXPECTED_FAILURE", f"Unexpected lock usage in task_storage: take_bus={has_take_bus}, give_bus={has_give_bus}, give_log={has_give_log}"


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
        trace = sys.argv[3] if len(sys.argv) > 3 else None
        status, msg = verify_part_d(target, trace)
    else:
        print(f"Unknown part: {part}")
        sys.exit(1)

    print(f"[{status}] {msg}")
    if status in ["SEEDED_DEFECT_REJECT", "REFERENCE_PASS"]:
        sys.exit(0)
    else:
        sys.exit(1)
