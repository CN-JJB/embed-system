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


def _parse_c_statements(code_str):
    clean = re.sub(r'/\*.*?\*/', '', code_str, flags=re.DOTALL)
    clean = re.sub(r'//.*', '', clean)
    clean = re.sub(r'".*?"', '""', clean)
    clean = re.sub(r"'.*?'", "''", clean)

    nodes = []
    i = 0
    n = len(clean)

    while i < n:
        while i < n and clean[i].isspace():
            i += 1
        if i >= n:
            break

        if clean[i:i+2] == 'if' and (i+2 == n or not (clean[i+2].isalnum() or clean[i+2] == '_')):
            i += 2
            while i < n and clean[i].isspace():
                i += 1
            if i < n and clean[i] == '(':
                paren_depth = 1
                cond_start = i + 1
                i += 1
                while i < n and paren_depth > 0:
                    if clean[i] == '(':
                        paren_depth += 1
                    elif clean[i] == ')':
                        paren_depth -= 1
                    i += 1
                cond_str = clean[cond_start : i - 1].strip()

                while i < n and clean[i].isspace():
                    i += 1
                then_stmts = []
                if i < n and clean[i] == '{':
                    brace_depth = 1
                    block_start = i + 1
                    i += 1
                    while i < n and brace_depth > 0:
                        if clean[i] == '{':
                            brace_depth += 1
                        elif clean[i] == '}':
                            brace_depth -= 1
                        i += 1
                    then_code = clean[block_start : i - 1]
                    then_stmts = _parse_c_statements(then_code)
                else:
                    stmt_start = i
                    while i < n and clean[i] != ';':
                        i += 1
                    if i < n:
                        i += 1
                    then_stmts = [('SIMPLE', clean[stmt_start:i].strip())]

                save_i = i
                while i < n and clean[i].isspace():
                    i += 1
                else_stmts = []
                if clean[i:i+4] == 'else' and (i+4 == n or not (clean[i+4].isalnum() or clean[i+4] == '_')):
                    i += 4
                    while i < n and clean[i].isspace():
                        i += 1
                    if i < n and clean[i] == '{':
                        brace_depth = 1
                        block_start = i + 1
                        i += 1
                        while i < n and brace_depth > 0:
                            if clean[i] == '{':
                                brace_depth += 1
                            elif clean[i] == '}':
                                brace_depth -= 1
                            i += 1
                        else_code = clean[block_start : i - 1]
                        else_stmts = _parse_c_statements(else_code)
                else:
                    i = save_i

                nodes.append(('IF', cond_str, then_stmts, else_stmts))
                continue

        stmt_start = i
        brace_depth = 0
        while i < n:
            if clean[i] == '{':
                brace_depth += 1
            elif clean[i] == '}':
                brace_depth -= 1
            elif clean[i] == ';' and brace_depth == 0:
                i += 1
                break
            i += 1
        stmt_str = clean[stmt_start:i].strip()
        if stmt_str:
            nodes.append(('SIMPLE', stmt_str))

    return nodes


def _evaluate_all_paths(nodes, state):
    current_paths = [state]

    for node in nodes:
        next_paths = []
        for p in current_paths:
            if p.get("exited"):
                next_paths.append(p)
                continue

            node_type = node[0]
            if node_type == 'SIMPLE':
                stmt = node[1]
                new_p = dict(p)
                new_p["path_desc"] = list(p["path_desc"]) + [stmt]

                if re.search(r"xSemaphoreGive\s*\(\s*xSensorBusLock\s*\)", stmt):
                    new_p["released"] = True
                    new_p["locked"] = False
                elif re.search(r"xSemaphoreGive\s*\(\s*xLogBufferLock\s*\)", stmt):
                    new_p["wrong_release"] = "xLogBufferLock"

                if re.search(r"\b(return|break|goto)\b", stmt):
                    new_p["exited"] = True
                    new_p["exit_type"] = re.search(r"\b(return|break|goto)\b", stmt).group(1)

                next_paths.append(new_p)

            elif node_type == 'IF':
                cond_str, then_stmts, else_stmts = node[1], node[2], node[3]
                is_dead_cond = bool(re.match(r"^(?:0|false|0\s*==\s*1)$", cond_str.strip()))

                if is_dead_cond:
                    dead_eval = _evaluate_all_paths(then_stmts, dict(p))
                    if any(dp.get("released") for dp in dead_eval):
                        p["dead_release"] = True
                    if else_stmts:
                        else_res = _evaluate_all_paths(else_stmts, dict(p))
                        next_paths.extend(else_res)
                    else:
                        next_paths.append(p)
                else:
                    p_then = dict(p)
                    p_then["path_desc"] = list(p["path_desc"]) + [f"if ({cond_str})"]
                    then_res = _evaluate_all_paths(then_stmts, p_then)

                    p_else = dict(p)
                    p_else["path_desc"] = list(p["path_desc"]) + [f"else [from if ({cond_str})]"]
                    if else_stmts:
                        else_res = _evaluate_all_paths(else_stmts, p_else)
                    else:
                        else_res = [p_else]

                    next_paths.extend(then_res)
                    next_paths.extend(else_res)

        current_paths = next_paths

    return current_paths


def validate_evidence_cross_consistency(trace_path, state_dump_path):
    """
    Cross-validates scripted timing evidence with task/synchronization state evidence.
    Ensures:
    - Task priority & priority inheritance match (Telemetry priority 2, Storage base 1 promoted to 2)
    - Thread blocking states match trace starvation (both Task_Telemetry & Task_Storage in Blocked state)
    - Mutex holder causality (xSensorBusLock held by Task_Storage, waiters waiting on it)
    - Released lock status (xLogBufferLock unheld and available)
    """
    if not trace_path or not os.path.exists(trace_path):
        return False, f"Trace file not found: {trace_path}"
    if not state_dump_path or not os.path.exists(state_dump_path):
        return False, f"Task state dump file not found: {state_dump_path}"

    valid_trace, trace_msg = validate_watchdog_trace(trace_path)
    if not valid_trace:
        return False, f"Watchdog trace consistency check failed: {trace_msg}"

    with open(state_dump_path, "r", encoding="utf-8", errors="replace") as f:
        dump_content = f.read()

    # 1. Cross-validate thread blocking states
    if not re.search(r"Thread\s+[0-9]+\s*\(\s*Task_Telemetry\s*:\s*Blocked\s*\)", dump_content):
        return False, "Task_Telemetry thread state is not Blocked in task dump; contradicts timing trace starvation causality"

    if not re.search(r"Thread\s+[0-9]+\s*\(\s*Task_Storage\s*:\s*Blocked\s*\)", dump_content):
        return False, "Task_Storage thread state is not Blocked in task dump; contradicts periodic timing state"

    # 2. Cross-validate task priority and priority inheritance
    telemetry_match = re.search(r'xTaskGetHandle\("Task_Telemetry"\).*?uxPriority\s*=\s*([0-9]+).*?uxBasePriority\s*=\s*([0-9]+)', dump_content, re.DOTALL)
    if not telemetry_match:
        return False, "Task_Telemetry task attributes not found in dump"
    telemetry_prio = int(telemetry_match.group(1))
    telemetry_base = int(telemetry_match.group(2))
    if telemetry_prio != 2 or telemetry_base != 2:
        return False, f"Task_Telemetry priority mismatch in dump: prio={telemetry_prio}, base={telemetry_base} (expected 2/2)"

    storage_match = re.search(r'xTaskGetHandle\("Task_Storage"\).*?pvOwner\s*=\s*(0x[0-9a-fA-F]+).*?uxPriority\s*=\s*([0-9]+).*?uxBasePriority\s*=\s*([0-9]+)', dump_content, re.DOTALL)
    if not storage_match:
        return False, "Task_Storage task attributes not found in dump"
    storage_tcb = storage_match.group(1).lower()
    storage_prio = int(storage_match.group(2))
    storage_base = int(storage_match.group(3))

    if storage_base != 1:
        return False, f"Task_Storage uxBasePriority={storage_base} (expected 1)"
    if storage_prio != 2:
        return False, f"Task_Storage uxPriority={storage_prio} does not reflect priority inheritance from Task_Telemetry (expected uxPriority=2 inherited from priority-2 waiter)"

    # 3. Cross-validate mutex holder and waiter causality
    sensor_lock_match = re.search(r'xSensorBusLock.*?xMutexHolder\s*=\s*(0x[0-9a-fA-F]+).*?uxNumberOfItems\s*=\s*([0-9]+)', dump_content, re.DOTALL)
    if not sensor_lock_match:
        return False, "xSensorBusLock attributes not found in dump"
    sensor_holder = sensor_lock_match.group(1).lower()
    sensor_waiters = int(sensor_lock_match.group(2))

    if sensor_holder == "0x0" or sensor_holder == "0x00000000":
        return False, "xSensorBusLock xMutexHolder is 0x0 (unheld); contradicts timing trace where Task_Storage leaks the lock"

    if sensor_holder != storage_tcb:
        return False, f"xSensorBusLock xMutexHolder ({sensor_holder}) does not match Task_Storage TCB ({storage_tcb})"

    if sensor_waiters < 1:
        return False, f"xSensorBusLock uxNumberOfItems={sensor_waiters}; contradicts timing trace where Task_Telemetry waits on lock"

    # xLogBufferLock must NOT be held (holder == 0x0, messages waiting == 1)
    log_lock_match = re.search(r'xLogBufferLock.*?xMutexHolder\s*=\s*(0x[0-9a-fA-F]+).*?uxMessagesWaiting\s*=\s*([0-9]+)', dump_content, re.DOTALL)
    if not log_lock_match:
        return False, "xLogBufferLock attributes not found in dump"
    log_holder = log_lock_match.group(1).lower()
    log_avail = int(log_lock_match.group(2))

    if log_holder != "0x0" and log_holder != "0x00000000":
        return False, f"xLogBufferLock xMutexHolder is {log_holder} (expected unheld 0x0); contradicts symptom where Task_Storage gave xLogBufferLock"

    if log_avail != 1:
        return False, f"xLogBufferLock uxMessagesWaiting={log_avail} (expected 1 available)"

    return True, "Evidence cross-consistency confirmed: timing trace starvation matches task dump ownership, priority inheritance, and blocked waiter state."


def verify_part_d(src_path, trace_path=None, state_dump_path=None):
    """
    Part D Oracle:
    - Control-flow reachable all-path lifecycle analysis on task_storage.
    - Preserves exact lexical/control-flow order across statements and branches.
    - Intended Seed Defect: task_storage acquires xSensorBusLock but releases xLogBufferLock,
      leaving xSensorBusLock permanently held. When task_telemetry wakes, it blocks on
      xSensorBusLock and is starved of watchdog refresh, triggering IWDG reset.
    - Reference Pass: task_storage properly pairs xSemaphoreTake(xSensorBusLock) with
      xSemaphoreGive(xSensorBusLock) on all reachable exit paths of the critical section.
    - Rejects reachable early exits before later cleanup (return/break/goto).
    - Rejects runtime-conditional release decoys (e.g. if (flag) { give; }).
    - Rejects in-function dead-branch release decoys (e.g. if (0) { give; }).
    - Cross-validates timing trace with task/synchronization state dump.
    """
    if not os.path.exists(src_path):
        return "ERROR", f"File not found: {src_path}"

    with open(src_path, "r", encoding="utf-8", errors="replace") as f:
        src = f.read()

    storage_match = re.search(r"void\s+task_storage\s*\([^)]*\)\s*\{(.*?)\n\}", src, re.DOTALL)
    if not storage_match:
        return "ERROR", "Function task_storage not found in source"

    body = storage_match.group(1)

    take_idx = body.find("xSemaphoreTake")
    if take_idx == -1 or "xSensorBusLock" not in body[take_idx:take_idx+100]:
        return "ERROR", "xSemaphoreTake(xSensorBusLock) not found in task_storage"

    brace_start = body.find("{", take_idx)
    if brace_start == -1:
        return "ERROR", "Opening brace for xSemaphoreTake block not found in task_storage"

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

    # Parse statements in exact lexical order into an AST
    ast_nodes = _parse_c_statements(cs_body)

    # Evaluate all control-flow paths through the critical section
    init_state = {
        "locked": True,
        "released": False,
        "wrong_release": None,
        "dead_release": False,
        "path_desc": ["entry"]
    }
    paths = _evaluate_all_paths(ast_nodes, init_state)

    has_dead_release = any(p.get("dead_release") for p in paths)
    wrong_releases = [p.get("wrong_release") for p in paths if p.get("wrong_release")]
    early_exits = [p for p in paths if p.get("exited") and p.get("locked")]
    unreleased_fallthrough = [p for p in paths if not p.get("exited") and p.get("locked")]
    clean_paths = [p for p in paths if p.get("released") and not p.get("locked")]

    # Decision logic based on control-flow all-path verification:
    if early_exits:
        return "SEEDED_DEFECT_REJECT", (
            f"Intended defect confirmed: reachable early exit path (via {early_exits[0].get('exit_type')}) "
            f"in task_storage exits before xSemaphoreGive(xSensorBusLock), leaking the acquired mutex."
        )

    if has_dead_release:
        return "SEEDED_DEFECT_REJECT", (
            "Intended defect confirmed: xSemaphoreGive(xSensorBusLock) is placed in an unreachable dead branch "
            "while the active reachable path leaks xSensorBusLock."
        )

    if unreleased_fallthrough:
        if clean_paths:
            return "SEEDED_DEFECT_REJECT", (
                "Intended defect confirmed: xSemaphoreGive(xSensorBusLock) is placed on a runtime-conditional path "
                "within task_storage, leaving at least one reachable exit path that leaks the acquired mutex."
            )
        elif wrong_releases:
            return "SEEDED_DEFECT_REJECT", (
                f"Intended defect confirmed: task_storage acquires xSensorBusLock but releases {wrong_releases[0]}. "
                f"Leaked mutex starves task_telemetry and triggers independent watchdog reset."
            )
        else:
            return "SEEDED_DEFECT_REJECT", (
                "Intended defect confirmed: task_storage acquires xSensorBusLock but does not release it on all reachable exit paths."
            )

    if wrong_releases:
        return "SEEDED_DEFECT_REJECT", (
            f"Intended defect confirmed: task_storage releases wrong synchronization object {wrong_releases[0]} alongside xSensorBusLock."
        )

    # Cross-bind evidence: timing trace and task/synchronization state dump
    if trace_path:
        dump_target = state_dump_path
        if not dump_target:
            candidate = os.path.join(os.path.dirname(trace_path), "task_state_dump.txt")
            if os.path.exists(candidate):
                dump_target = candidate

        if dump_target and os.path.exists(dump_target):
            valid_cross, cross_msg = validate_evidence_cross_consistency(trace_path, dump_target)
            if not valid_cross:
                if "Watchdog trace consistency check failed:" in cross_msg:
                    return "SEEDED_DEFECT_REJECT", cross_msg
                return "SEEDED_DEFECT_REJECT", f"Evidence cross-consistency check failed: {cross_msg}"
        else:
            valid_trace, trace_msg = validate_watchdog_trace(trace_path)
            if not valid_trace:
                return "SEEDED_DEFECT_REJECT", f"Watchdog trace consistency check failed: {trace_msg}"
    elif state_dump_path:
        pass

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
        state_dump = sys.argv[4] if len(sys.argv) > 4 else None
        status, msg = verify_part_d(target, trace, state_dump)
    else:
        print(f"Unknown part: {part}")
        sys.exit(1)

    print(f"[{status}] {msg}")
    if status in ["SEEDED_DEFECT_REJECT", "REFERENCE_PASS"]:
        sys.exit(0)
    else:
        sys.exit(1)
