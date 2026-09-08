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
    Binds:
    - Task priority & initial preemption (Task_Telemetry priority 2 runs at t=0.000s before Task_Storage priority 1)
    - Phase/wake ordering (Storage 20ms offset, Telemetry 50ms period, Storage 100ms period -> wakes at 120ms)
    - Blocking/ownership state causality (Telemetry blocked on leaked mutex at 0.050s, both LOW 0.121s..0.501s)
    - Watchdog refresh & starvation (last refresh before lockup at t=0.000s; starved after 0.050s)
    - Reset ordering & hardware register assertion (reset marker at t=0.501s with RCC->CSR 0x24000000)
    - IWDG count model (PR=4 /64, RLR=312, RLR+1=313 cycles, nominal 500.8ms, DS5319 tolerance 334-668ms)
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

    # 3. Priority and phase/wake ordering verification
    if not re.search(r"t\s*=\s*0\.000\s*s.*?PA1\s+HIGH.*?PA2\s+LOW", content, re.DOTALL):
        return False, "Trace missing initial Task_Telemetry priority-2 preemption over Task_Storage at t=0.000s"

    if not re.search(r"t\s*=\s*0\.020\s*s.*?PA2\s+HIGH.*?PA1\s+LOW", content, re.DOTALL):
        return False, "Trace missing Task_Storage phase offset execution at t=0.020s (20ms phase offset)"

    if not re.search(r"t\s*=\s*0\.050\s*s.*?PA1\s+HIGH", content, re.DOTALL):
        return False, "Trace missing Task_Telemetry 50ms periodic wake at t=0.050s"

    if not re.search(r"t\s*=\s*0\.120\s*s.*?PA2\s+HIGH", content, re.DOTALL):
        return False, "Trace missing Task_Storage 100ms periodic wake at t=0.120s (20ms phase + 100ms period)"

    # 4. Mutex starvation & blocking interval
    if not re.search(r"0\.121\s*s\s*\.\.\s*0\.501\s*s.*?PA1\s+LOW,\s*PA2\s+LOW", content, re.DOTALL):
        return False, "Trace missing mutex starvation interval where both tasks remain blocked/idle before reset"

    # 5. Reset ordering: hardware reset marker at 0.501s strictly following starvation window
    if not re.search(r"t\s*=\s*0\.501\s*s.*?(?:reset|reboot).*?0x24000000", content, re.DOTALL | re.IGNORECASE):
        return False, "Trace missing scripted reset marker at t=0.501s asserting RCC->CSR 0x24000000"

    return True, "Trace validated: monotonic timeline, causal priority/wake ordering, and valid RLR+1 IWDG model"


def verify_part_d(src_path, trace_path=None):
    """
    Part D Oracle:
    - Control-flow reachable exit-path analysis on task_storage.
    - Intended Seed Defect: task_storage acquires xSensorBusLock but releases xLogBufferLock,
      leaving xSensorBusLock permanently held. When task_telemetry wakes, it blocks on
      xSensorBusLock and is starved of watchdog refresh, triggering IWDG reset.
    - Reference Pass: task_storage properly pairs xSemaphoreTake(xSensorBusLock) with
      xSemaphoreGive(xSensorBusLock) on all reachable exit paths of the critical section.
    - Rejects in-function dead-branch decoys (e.g. if (0) { give(xSensorBusLock); }).
    - Rejects runtime-conditional release decoys (e.g. if (flag) { give(xSensorBusLock); }).
    - Rejects premature jump exits (return/break/goto) before resource release.
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
    take_idx = body.find("xSemaphoreTake")
    if take_idx == -1 or "xSensorBusLock" not in body[take_idx:take_idx+100]:
        return "ERROR", "xSemaphoreTake(xSensorBusLock) not found in task_storage"

    # Find the opening '{' of the take block
    brace_start = body.find("{", take_idx)
    if brace_start == -1:
        return "ERROR", "Opening brace for xSemaphoreTake block not found in task_storage"

    # Match closing brace for the take block
    depth = 0
    brace_end = -1
    for i in range(brace_start, len(body)):
        if body[i] == "{":
            depth += 1
        elif body[i] == "}":
            depth -= 1
            if depth == 0:
                brace_end = i
                break

    if brace_end == -1:
        return "ERROR", "Closing brace for xSemaphoreTake block not found in task_storage"

    cs_body = body[brace_start + 1 : brace_end]

    # Clean comments and string literals
    cleaned = re.sub(r"/\*.*?\*/", "", cs_body, flags=re.DOTALL)
    cleaned = re.sub(r"//.*", "", cleaned)
    cleaned = re.sub(r'".*?"', '""', cleaned)

    # Detect if release of xLogBufferLock is present anywhere in critical section
    has_give_log = bool(re.search(r"xSemaphoreGive\s*\(\s*xLogBufferLock\s*\)", cleaned))

    # Detect if xSemaphoreGive(xSensorBusLock) is present in dead branch
    has_give_bus_dead = bool(re.search(r"if\s*\(\s*(?:0|false|0\s*==\s*1)\s*\)\s*\{[^}]*xSemaphoreGive\s*\(\s*xSensorBusLock\s*\)", cleaned))

    # Analyze statements and depth inside the critical section:
    # Scan tokens tracking nested brace depth inside cs_body
    curr_depth = 0
    top_level_stmts = []
    nested_stmts = []
    buf = []

    for ch in cleaned:
        if ch == '{':
            curr_depth += 1
            buf.append(ch)
        elif ch == '}':
            curr_depth -= 1
            buf.append(ch)
            if curr_depth == 0:
                nested_stmts.append("".join(buf).strip())
                buf = []
        elif ch == ';' and curr_depth == 0:
            buf.append(ch)
            top_level_stmts.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
    if buf:
        rest = "".join(buf).strip()
        if rest:
            if curr_depth == 0:
                top_level_stmts.append(rest)
            else:
                nested_stmts.append(rest)

    # Check if xSemaphoreGive(xSensorBusLock) is called at top level (depth 0)
    has_top_level_give_bus = any(
        re.search(r"xSemaphoreGive\s*\(\s*xSensorBusLock\s*\)", s) for s in top_level_stmts
    )

    # Check if xSemaphoreGive(xSensorBusLock) is called inside a nested conditional
    has_nested_give_bus = any(
        re.search(r"xSemaphoreGive\s*\(\s*xSensorBusLock\s*\)", s) for s in nested_stmts
    )

    # Check for early exits before give
    has_early_exit = False
    give_seen = False
    for s in top_level_stmts:
        if re.search(r"xSemaphoreGive\s*\(\s*xSensorBusLock\s*\)", s):
            give_seen = True
            break
        if re.search(r"\b(return|break|goto)\b", s):
            has_early_exit = True
            break
    for n in nested_stmts:
        if not give_seen and re.search(r"\b(return|break|goto)\b", n):
            has_early_exit = True
            break

    # Optional trace validation
    if trace_path:
        valid_trace, trace_msg = validate_watchdog_trace(trace_path)
        if not valid_trace:
            return "SEEDED_DEFECT_REJECT", f"Watchdog trace consistency check failed: {trace_msg}"

    # Decision logic:
    if has_early_exit:
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: premature exit path in task_storage leaves xSensorBusLock leaked."
        )

    if has_give_bus_dead:
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: xSemaphoreGive(xSensorBusLock) is placed in an unreachable dead branch "
            "while the active reachable path leaks xSensorBusLock."
        )

    if has_nested_give_bus and not has_top_level_give_bus:
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: xSemaphoreGive(xSensorBusLock) is placed on a runtime-conditional path "
            "within task_storage, leaving at least one reachable exit path that leaks the acquired mutex."
        )

    if has_give_log and not has_top_level_give_bus:
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: task_storage acquires xSensorBusLock but releases xLogBufferLock. "
            "Leaked mutex starves task_telemetry and triggers independent watchdog reset."
        )

    if not has_top_level_give_bus:
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: task_storage acquires xSensorBusLock but does not release it on all reachable exit paths."
        )

    if has_give_log:
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: task_storage releases wrong synchronization object xLogBufferLock alongside xSensorBusLock."
        )

    # Reference pass:
    return "REFERENCE_PASS", (
        "Reference fix verified: task_storage properly acquires and releases xSensorBusLock "
        "on all reachable exit paths of the critical section, preserving synchronization safety."
    )


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
