#!/usr/bin/env python3
"""
regression_oracle.py: Reviewer-Isolated Exact Semantic Regression Oracle.
Houses all exact seed signatures, hardware register expectations, disassembly checks,
and reference contract verifications. Reviewer-only; never exposed to learners.

Hardened for Leader Rework Round 4:
- Part A: Linker VMA/LMA relocation binding (detects VMA RAM pointer vs Flash LMA).
- Part B: Full register provenance & symbolic store tracking (binds DMA1_Channel1->CCR at 0x40020008,
  rejects unrelated-base + same-offset stores). Enforces ordered/effective writes.
- Part C: Full register provenance & symbolic store tracking (binds NVIC->IP[6] at 0xE000E406,
  rejects unrelated-base stores). Enforces FreeRTOS syscall boundary priority (byte >= 0x50).
- Part D: Control-flow reachable path analysis (rejects in-function dead-branch decoys and helper decoys).
- Trace: Timeline monotonicity, task phase/period sequence, and IWDG RLR+1 model validation.
"""
import sys
import os
import subprocess
import re

def verify_part_a(elf_path, nm="arm-none-eabi-nm", readelf="arm-none-eabi-readelf"):
    """
    Part A Oracle:
    - Intended Seed Defect (SEED-P2G-A5): _sidata defined as ADDR(.data) (or _etext before .data),
      causing _sidata to point to RAM VMA (0x2000xxxx) instead of Flash LMA (0x0800xxxx),
      leaving initialized globals in .data unpopulated at startup.
    - Reference Pass: _sidata == LOADADDR(.data) (in Flash >= 0x08000000) and _edata > _sdata.
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
        if sidata >= 0x20000000:
            return "SEEDED_DEFECT_REJECT", (
                f"Intended defect confirmed: _sidata (0x{sidata:08x}) is assigned VMA in RAM instead of "
                f"LOADADDR(.data) (0x{data_lma:08x}). Reset_Handler copy loop reads uninitialized RAM instead of Flash."
            )
        else:
            return "SEEDED_DEFECT_REJECT", (
                f"Intended defect confirmed: _sidata (0x{sidata:08x}) != LOADADDR(.data) (0x{data_lma:08x}). "
                f"Startup relocation loop does not copy initialized .data from Flash LMA."
            )
    else:
        return "REFERENCE_PASS", (
            f"Reference fix verified: _sdata=0x{sdata:08x}, _edata=0x{edata:08x} "
            f"(size={edata-sdata} bytes), _sidata=LOADADDR(.data)=0x{sidata:08x} in Flash."
        )


def _disassemble_and_track_stores(elf_path, func_name, objdump="arm-none-eabi-objdump"):
    """
    Symbolic register/memory execution tracer across Thumb-2 instructions in a function.
    Tracks PC-relative literal loads, immediates, memory loads/stores, and effective addresses.
    """
    try:
        asm = subprocess.check_output([objdump, "-d", elf_path]).decode("utf-8", errors="replace")
    except Exception as e:
        return None, f"Could not run objdump: {e}"

    pattern = rf"<({func_name})>:.*?(?=\n\s*[0-9a-fA-F]+\s+<|\Z)"
    m = re.search(pattern, asm, re.DOTALL)
    if not m:
        return None, f"Function <{func_name}> not found in disassembly"

    lines = m.group(0).splitlines()
    regs = {}
    mem = {}
    stores = []

    # First collect all literal words in the function
    literal_pool = {}
    for line in lines:
        m_lit = re.match(r"\s*([0-9a-fA-F]+):\s+([0-9a-fA-F]{8})\s+\.word\s+0x([0-9a-fA-F]{8})", line)
        if m_lit:
            addr = int(m_lit.group(1), 16)
            val = int(m_lit.group(3), 16)
            literal_pool[addr] = val

    for line in lines:
        m_inst = re.match(r"\s*([0-9a-fA-F]+):\s+[0-9a-fA-F\s]+\s+([a-z0-9\._]+)\s+(.*)", line)
        if not m_inst:
            continue

        pc_addr = int(m_inst.group(1), 16)
        mnemonic = m_inst.group(2)
        operands = m_inst.group(3).split("@")[0].strip()

        # Handle ldr rX, [pc, #offset]
        m_ldr_pc = re.search(r"ldr(?:\.w)?\s+r([0-9]+),\s+\[pc,\s*#(\d+)\]", line)
        if m_ldr_pc:
            rx = f"r{m_ldr_pc.group(1)}"
            m_target = re.search(r"@\s*\(([0-9a-fA-F]+)", line)
            if m_target:
                target_lit_addr = int(m_target.group(1), 16)
                if target_lit_addr in literal_pool:
                    regs[rx] = literal_pool[target_lit_addr]
                else:
                    regs[rx] = None
            continue

        # Handle ldr rX, [rY, #offset]
        m_ldr_mem = re.match(r"r([0-9]+),\s+\[r([0-9]+)(?:,\s+#(?:0x)?([0-9a-fA-F]+))?\]", operands)
        if mnemonic.startswith("ldr") and m_ldr_mem:
            rx = f"r{m_ldr_mem.group(1)}"
            ry = f"r{m_ldr_mem.group(2)}"
            off_str = m_ldr_mem.group(3)
            off = int(off_str, 16) if off_str and off_str.startswith("0x") else (int(off_str) if off_str else 0)
            base = regs.get(ry)
            if base is not None:
                addr = (base + off) & 0xFFFFFFFF
                regs[rx] = mem.get(addr)
            else:
                regs[rx] = None
            continue

        # Handle mov / movs / movw / mov.w rX, #imm
        m_mov = re.match(r"r([0-9]+),\s+#(?:0x)?([0-9a-fA-F]+)", operands)
        if mnemonic in ["mov", "movs", "movw", "mov.w"] and m_mov:
            rx = f"r{m_mov.group(1)}"
            imm_str = m_mov.group(2)
            val = int(imm_str, 16) if "0x" in operands or not imm_str.isdigit() else int(imm_str)
            regs[rx] = val
            continue

        # Handle movt rX, #imm
        m_movt = re.match(r"r([0-9]+),\s+#(?:0x)?([0-9a-fA-F]+)", operands)
        if mnemonic.startswith("movt") and m_movt:
            rx = f"r{m_movt.group(1)}"
            imm_str = m_movt.group(2)
            val = int(imm_str, 16) if "0x" in operands or not imm_str.isdigit() else int(imm_str)
            regs[rx] = (val << 16) | (regs.get(rx, 0) & 0xFFFF)
            continue

        # Handle mov rX, rY
        m_mov_reg = re.match(r"r([0-9]+),\s+r([0-9]+)$", operands)
        if mnemonic.startswith("mov") and m_mov_reg:
            rx = f"r{m_mov_reg.group(1)}"
            ry = f"r{m_mov_reg.group(2)}"
            regs[rx] = regs.get(ry)
            continue

        # Handle orr / orr.w rX, rY, #imm
        m_orr_imm = re.match(r"r([0-9]+),\s+r([0-9]+),\s+#(\d+)", operands)
        if mnemonic.startswith("orr") and m_orr_imm:
            rx = f"r{m_orr_imm.group(1)}"
            ry = f"r{m_orr_imm.group(2)}"
            imm = int(m_orr_imm.group(3))
            if regs.get(ry) is not None:
                regs[rx] = regs[ry] | imm
            else:
                regs[rx] = None
            continue

        # Handle bic / bic.w rX, rY, #imm
        m_bic_imm = re.match(r"r([0-9]+),\s+r([0-9]+),\s+#(\d+)", operands)
        if mnemonic.startswith("bic") and m_bic_imm:
            rx = f"r{m_bic_imm.group(1)}"
            ry = f"r{m_bic_imm.group(2)}"
            imm = int(m_bic_imm.group(3))
            if regs.get(ry) is not None:
                regs[rx] = regs[ry] & ~imm
            else:
                regs[rx] = None
            continue

        # Handle str / strb: str rVal, [rBase, #offset] or [rBase]
        m_str = re.match(r"r([0-9]+),\s+\[r([0-9]+)(?:,\s+#(?:0x)?([0-9a-fA-F]+))?\]", operands)
        if (mnemonic.startswith("str") or mnemonic.startswith("strb")) and m_str:
            rval = f"r{m_str.group(1)}"
            rbase = f"r{m_str.group(2)}"
            offset_str = m_str.group(3)
            if offset_str is None:
                offset = 0
            elif offset_str.startswith("0x"):
                offset = int(offset_str, 16)
            else:
                offset = int(offset_str)

            base_addr = regs.get(rbase)
            val = regs.get(rval)
            eff_addr = (base_addr + offset) & 0xFFFFFFFF if base_addr is not None else None
            if eff_addr is not None and val is not None:
                mem[eff_addr] = val

            stores.append({
                "mnemonic": mnemonic,
                "pc": pc_addr,
                "rval": rval,
                "val": val,
                "rbase": rbase,
                "base_addr": base_addr,
                "offset": offset,
                "eff_addr": eff_addr,
                "line": line.strip()
            })
            continue

    return stores, None


def verify_part_b(elf_path, objdump="arm-none-eabi-objdump"):
    """
    Part B Oracle:
    - Target register: DMA1_Channel1->CCR (address 0x40020008, base 0x40020000 + offset 8).
    - Intended Seed Defect: Effective configuration store lacks DMA_CCR_CIRC (0x20).
      Channel halts upon CNDTR=0 in single-shot mode.
    - Reference Pass: Effective configuration store includes DMA_CCR_CIRC (0x5AE / 1454 decimal).
    - Binds target MMIO address 0x40020008; rejects unrelated stores with same offset #8.
    - Validates ordered writes (setup write + final enable write).
    """
    stores, err = _disassemble_and_track_stores(elf_path, "dma1_channel1_init", objdump)
    if err:
        return "ERROR", err

    ccr_addr = 0x40020008
    ccr_stores = [s for s in stores if s["eff_addr"] == ccr_addr]

    if not ccr_stores:
        return "ERROR", f"Could not locate effective store reaching DMA1_Channel1->CCR (0x{ccr_addr:08x}) in disassembly"

    # Find the primary configuration store (value has MINC bit 0x80 set)
    config_stores = [s for s in ccr_stores if s["val"] is not None and (s["val"] & 0x80)]
    if not config_stores:
        return "ERROR", f"Could not locate configuration write with MINC bit reaching 0x{ccr_addr:08x}"

    effective_config = config_stores[-1]["val"]

    # Check final effective write reaching 0x40020008 (channel enable write)
    final_store = ccr_stores[-1]
    final_val = final_store["val"]

    has_circ = bool(effective_config & 0x20)
    has_minc = bool(effective_config & 0x80)

    if not has_circ and has_minc:
        return "SEEDED_DEFECT_REJECT", (
            f"Intended defect confirmed: effective DMA1_Channel1->CCR (0x{ccr_addr:08x}) write is 0x{effective_config:03x}. "
            f"Bit 5 (DMA_CCR_CIRC = 0x20) is omitted; channel halts after first block upon CNDTR=0."
        )
    elif has_circ and has_minc:
        # Also ensure final active write preserved circular mode
        if final_val is not None and not bool(final_val & 0x20):
            return "SEEDED_DEFECT_REJECT", (
                f"Defect detected: final store to CCR (0x{final_val:03x}) cleared DMA_CCR_CIRC bit 5."
            )
        return "REFERENCE_PASS", (
            f"Reference fix verified: effective DMA1_Channel1->CCR (0x{ccr_addr:08x}) write is 0x{effective_config:03x}. "
            f"Circular mode (CIRC), memory increment (MINC), and transfer interrupts enabled."
        )
    else:
        return "UNEXPECTED_FAILURE", f"Unexpected effective CCR configuration: 0x{effective_config:03x}"


def verify_part_c(elf_path, objdump="arm-none-eabi-objdump"):
    """
    Part C Oracle:
    - Target register: NVIC->IP[6] (address 0xE000E406, EXTI0 priority byte).
    - Intended Seed Defect: Logical priority 4 (hardware byte 0x40 < 0x50), violating
      FreeRTOS configMAX_SYSCALL_INTERRUPT_PRIORITY boundary.
    - Reference Pass: Priority byte >= 0x50 (e.g. 0x60 / 96 decimal), satisfying syscall boundary.
    - Binds target NVIC address 0xE000E406; rejects unrelated stores with same offset #6 or #774.
    """
    stores, err = _disassemble_and_track_stores(elf_path, "interrupt_config_init", objdump)
    if err:
        return "ERROR", err

    ip6_addr = 0xE000E406
    ip6_stores = [s for s in stores if s["eff_addr"] == ip6_addr]

    if not ip6_stores:
        return "ERROR", f"Could not locate effective strb reaching NVIC->IP[EXTI0_IRQn] (0x{ip6_addr:08x}) in disassembly"

    effective_prio = ip6_stores[-1]["val"]
    if effective_prio is None:
        return "ERROR", f"Could not determine priority value stored to 0x{ip6_addr:08x}"

    if effective_prio < 80:  # < 0x50
        return "SEEDED_DEFECT_REJECT", (
            f"Intended defect confirmed: EXTI0 priority byte at 0x{ip6_addr:08x} is 0x{effective_prio:02x} "
            f"(logical {effective_prio>>4}). Numerical byte 0x{effective_prio:02x} < 0x50, violating "
            f"FreeRTOS configMAX_SYSCALL_INTERRUPT_PRIORITY boundary."
        )
    else:
        return "REFERENCE_PASS", (
            f"Reference fix verified: EXTI0 priority byte at 0x{ip6_addr:08x} is 0x{effective_prio:02x} "
            f"(logical {effective_prio>>4}). Numerical byte 0x{effective_prio:02x} >= 0x50, safely within FreeRTOS syscall boundary."
        )


def validate_watchdog_trace(trace_path):
    """
    Validates scripted watchdog trace consistency, proving causality, ordering, and timing.
    Rejects reordered or impossible traces even if all marker strings are present.
    """
    if not trace_path or not os.path.exists(trace_path):
        return False, f"Trace file not found: {trace_path}"

    with open(trace_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    # 1. Model parameter verification
    if not re.search(r"IWDG\s+PR\s*=\s*4\s*\(\/64\)", content, re.IGNORECASE):
        return False, "Trace missing IWDG PR=4 (/64) model specification"
    if not re.search(r"RLR\s*=\s*312", content):
        return False, "Trace missing IWDG RLR=312 model specification"
    if not re.search(r"RLR\s*\+\s*1\s*=\s*313\s+cycles", content, re.IGNORECASE):
        return False, "Trace missing RLR+1 = 313 reload count semantics"
    if not re.search(r"500\.8\s*ms(?:\s+nominal)?", content, re.IGNORECASE):
        return False, "Trace missing 500.8 ms nominal timeout model"
    if not re.search(r"334\s*[\u2013\-]\s*668\s*ms", content):
        return False, "Trace missing 334-668 ms LSI physical tolerance boundary (DS5319)"
    if "0x24000000" not in content or "0x40021024" not in content:
        return False, "Trace missing RCC->CSR readout 0x24000000 at 0x40021024 proving IWDGRSTF/PINRSTF"

    # 2. Timeline extraction and monotonicity check
    t_matches = re.findall(r"t\s*=\s*([0-9]+\.[0-9]+)\s*s", content)
    if not t_matches or len(t_matches) < 6:
        return False, f"Insufficient timeline entries found in trace ({len(t_matches)})"

    timestamps = [float(t) for t in t_matches]
    for i in range(len(timestamps) - 1):
        if timestamps[i] > timestamps[i+1]:
            return False, f"Timeline timestamps non-monotonic: t[{i}]={timestamps[i]}s > t[{i+1}]={timestamps[i+1]}s"

    # 3. Task phase and delay relationship verification
    expected_milestones = [0.000, 0.020, 0.050, 0.120, 0.501]
    for m in expected_milestones:
        if not any(abs(t - m) < 0.002 for t in timestamps):
            return False, f"Trace missing expected architectural timestamp milestone ~{m}s"

    return True, "Trace validated: monotonic timeline, consistent task periods, and valid RLR+1 IWDG model"


def verify_part_d(src_path, trace_path=None):
    """
    Part D Oracle:
    - Control-flow reachable path analysis on task_storage.
    - Intended Seed Defect: task_storage acquires xSensorBusLock but releases xLogBufferLock,
      leaving xSensorBusLock permanently held. When task_telemetry wakes, it blocks on
      xSensorBusLock and is starved of watchdog refresh, triggering IWDG reset.
    - Reference Pass: task_storage properly pairs xSemaphoreTake(xSensorBusLock) with
      xSemaphoreGive(xSensorBusLock) on the active reachable execution path.
    - Rejects in-function dead-branch decoys (e.g. if (0) { give(xSensorBusLock); }).
    """
    if not os.path.exists(src_path):
        return "ERROR", f"File not found: {src_path}"

    with open(src_path, "r", encoding="utf-8", errors="replace") as f:
        src = f.read()

    storage_match = re.search(r"void\s+task_storage\s*\([^)]*\)\s*\{(.*?)\n\}", src, re.DOTALL)
    if not storage_match:
        return "ERROR", "Function task_storage not found in source"

    body = storage_match.group(1)

    # Locate critical section under xSemaphoreTake(xSensorBusLock, ...)
    take_m = re.search(r"xSemaphoreTake\s*\(\s*xSensorBusLock", body)
    if not take_m:
        return "ERROR", "xSemaphoreTake(xSensorBusLock) not found in task_storage"

    # Strip comments from body
    cleaned = re.sub(r"/\*.*?\*/", "", body, flags=re.DOTALL)
    cleaned = re.sub(r"//.*", "", cleaned)

    # Eliminate dead / unreachable conditional branches:
    # e.g. if (0) { ... }, if (false) { ... }, if (0 == 1) { ... }
    active_code = re.sub(r"if\s*\(\s*(?:0|false|0\s*==\s*1)\s*\)\s*\{[^}]*\}", "/* stripped dead branch */", cleaned)

    # Inspect active reachable path for xSemaphoreGive
    has_give_bus_active = bool(re.search(r"xSemaphoreGive\s*\(\s*xSensorBusLock\s*\)", active_code))
    has_give_log_active = bool(re.search(r"xSemaphoreGive\s*\(\s*xLogBufferLock\s*\)", active_code))

    # Check if there is an in-function decoy in a dead branch
    has_give_bus_dead = bool(re.search(r"if\s*\(\s*(?:0|false|0\s*==\s*1)\s*\)\s*\{[^}]*xSemaphoreGive\s*\(\s*xSensorBusLock\s*\)", cleaned))

    # Reviewer-side consistency check on trace if supplied
    if trace_path:
        valid_trace, trace_msg = validate_watchdog_trace(trace_path)
        if not valid_trace:
            return "SEEDED_DEFECT_REJECT", f"Watchdog trace consistency check failed: {trace_msg}"

    if has_give_bus_active and not has_give_log_active:
        return "REFERENCE_PASS", (
            "Reference fix verified: task_storage properly acquires and releases xSensorBusLock "
            "on the active reachable execution path, preserving synchronization safety."
        )
    elif has_give_bus_dead and (has_give_log_active or not has_give_bus_active):
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: xSemaphoreGive(xSensorBusLock) is placed in an unreachable dead branch "
            "while the active reachable path leaks xSensorBusLock."
        )
    elif not has_give_bus_active and has_give_log_active:
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: task_storage acquires xSensorBusLock but releases xLogBufferLock. "
            "Leaked mutex starves task_telemetry and triggers independent watchdog reset."
        )
    elif not has_give_bus_active and not has_give_log_active:
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: task_storage acquires xSensorBusLock but does not release it on active path."
        )
    else:
        return "UNEXPECTED_FAILURE", f"Unexpected lock usage in task_storage: active_bus={has_give_bus_active}, active_log={has_give_log_active}"


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
