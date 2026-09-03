# Reviewer Answer Key — Part C (ELF / Link / Binary Evidence)

This answer key defines the expected semantic conclusions for the five canonical evidence tasks. Minor variations in numeric hex offsets across GCC versions are normal and acceptable; grading evaluates correct technical reasoning and evidence interpretation.

---

## Task 1: Symbol Linkage & Binding
* **`internal_clamp`:**
  * Binding: `LOCAL` (or `t` in `nm`).
  * Section: Defined in `.text` (executable code).
  * C Cause: Declared with the `static` storage class specifier, giving it internal linkage restricted to the `calc.c` translation unit.
* **`compute_scaled_metric`:**
  * Binding: `GLOBAL` (or `T` in `nm`).
  * Section: Defined in `.text`.
  * C Cause: Defined as a non-static function, giving it external linkage accessible to other translation units.
* **`get_hardware_calibration_offset`:**
  * Binding: `GLOBAL` (or `U` in `nm`).
  * Section: `UND` (undefined).
  * C Cause: Declared in `calc.h` and called in `calc.c`, but not defined within this translation unit. It awaits symbol resolution at link time.

---

## Task 2: Relocation Entry Inspection
* **Observation:** `readelf -r src/calc.o` displays an entry referencing `get_hardware_calibration_offset` with type `R_X86_64_PLT32` (or `PC32` / architecture equivalent).
* **Explanation:**
  * The target offset points to the call instruction operand inside `.text`.
  * The compiler could not know the absolute address of `get_hardware_calibration_offset` during compilation of `calc.c`.
  * The static linker patches this offset with the relative displacement between the call site and the actual function definition (in `state.o`) during final executable generation.

---

## Task 3: Section Placement (.text / .rodata / .data / .bss)
* **`g_firmware_tag`:** Placed in `.rodata` (read-only data).
  * *Reason:* Declared as `const char[]`. It is immutable initialized data placed in a read-only page segment.
* **`g_initialized_config`:** Placed in `.data` (initialized read-write data).
  * *Reason:* Global variable initialized to a non-zero value (`42`).
* **`g_runtime_error_counter`:** Placed in `.bss` (or `COMMON`).
  * *Reason:* Uninitialized (or zero-initialized) global variable with static storage duration, allocated in BSS and zeroed at program startup.
* **`get_hardware_calibration_offset`:** Placed in `.text` (executable code).
  * *Reason:* Function definition containing machine instructions.

---

## Task 4: Compiler-vs-Linker Diagnostic Distinction
* **Diagnostic Message:**
  ```text
  /usr/bin/ld: src/calc.o: in function `compute_scaled_metric`:
  calc.c:(.text+0x...): undefined reference to `get_hardware_calibration_offset`
  collect2: error: ld returned 1 exit status
  ```
* **Explanation:**
  * The error occurs during the **linking** stage (`ld` / `collect2`), not during preprocessing or compilation (`cc1`).
  * Evidence: Object files `src/main.o` and `src/calc.o` were successfully generated. The error is emitted by the linker (`/usr/bin/ld`) because `state.o` was omitted from the command line, leaving unresolved symbol references.
  * Resolution: `make fixed-link` passes `src/state.o` to the linker, satisfying all symbols.

---

## Task 5: Short Disassembly-to-C Lowering Observation
* **Disassembly Excerpt (`objdump -d src/calc.o`):**
  ```text
  <internal_clamp>:
    cmp    edi, esi          ; compare val (edi) with min_v (esi)
    jge    .L_check_max      ; if val >= min_v, jump to max check
    mov    eax, esi          ; return min_v
    ret
  .L_check_max:
    cmp    edi, edx          ; compare val (edi) with max_v (edx)
    jle    .L_return_val     ; if val <= max_v, jump to return val
    mov    eax, edx          ; return max_v
    ret
  .L_return_val:
    mov    eax, edi          ; return val
    ret
  ```
* **Mapping:**
  * First `cmp`/conditional jump: corresponds to `if (val < min_v) return min_v;`.
  * Second `cmp`/conditional jump: corresponds to `if (val > max_v) return max_v;`.
  * Final return path: corresponds to `return val;`.
