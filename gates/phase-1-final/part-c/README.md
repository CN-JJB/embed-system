# Part C — ELF / Link / Binary Evidence (20%)

## 1. Objective
Demonstrate toolchain and binary literacy by using standard GNU binary inspection tools (`readelf`, `nm`, `objdump`) to analyze host-generated relocatable object files (`.o`), symbols, relocations, and section mappings.

---

## 2. Generating Host Object Files
Before executing the tasks, build the relocatable object files on your host environment:
```bash
make objects
```
This compiles `src/calc.o`, `src/state.o`, and `src/main.o`.

---

## 3. The Five Canonical Evidence Tasks

You must complete all five tasks and record your verbatim terminal outputs and explanations in `SUBMISSION_TEMPLATE.md`:

### Task 1: Symbol Linkage & Binding (4 Points)
Inspect `src/calc.o` using `readelf -s` (or `nm`):
1. Locate `internal_clamp`. What is its binding (LOCAL or GLOBAL) and section index? Which C keyword caused this binding?
2. Locate `compute_scaled_metric`. What is its binding and section index? Which C construct produced it?
3. Locate `get_hardware_calibration_offset`. Why is its section index marked `UND` (undefined)?

### Task 2: Relocation Entry Inspection (4 Points)
Inspect `src/calc.o` using `readelf -r`:
1. Identify the relocation entry corresponding to the call to `get_hardware_calibration_offset`.
2. What offset within `.text` is targeted, and what does the static linker patch at this offset during the final link phase?

### Task 3: Section Placement (.text / .rodata / .data / .bss) (4 Points)
Inspect `src/state.o` using `readelf -S`, `readelf -s`, or `objdump -h`:
1. In which ELF section is `g_firmware_tag` located, and why?
2. In which ELF section is `g_initialized_config` located, and why?
3. In which ELF section is `g_runtime_error_counter` located, and why?
4. In which ELF section is `get_hardware_calibration_offset` located, and why?

### Task 4: Compiler-vs-Linker Diagnostic Distinction (4 Points)
Execute `make failing-link` and examine the terminal output:
1. Paste the diagnostic error message.
2. Does this error occur during compilation (`cc1`) or linking (`ld`)? Cite specific output evidence proving your answer.
3. What command resolves the error and satisfies the dependency?

### Task 5: Short Disassembly-to-C Lowering Observation (4 Points)
Disassemble `internal_clamp` in `src/calc.o` using `objdump -d`:
1. Paste the disassembled instructions for `internal_clamp`.
2. Identify the comparison and branch/move instructions, and map each back to the corresponding C statements in `src/calc.c`.

---

## 4. Hard Pass Criteria for Part C
* Score $\ge 12 / 20$ (60%).
* All five tasks must include actual terminal command excerpts and clear technical reasoning.
