# Part A: Bare-Metal Startup & Linker Reasoning

> **Time Budget:** 45 minutes  
> **Weight:** 25 points (Floor: 60% / $\ge 15.0$ points)  
> **Mode:** AI-Free (Strict)  

---

## 1. System Context & Observed Symptom

You are provided with a bare-metal firmware image for the STM32F103C8T6 (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM) in this directory.

The build system compiles and links cleanly with strict flags:
`-mcpu=cortex-m3 -mthumb -O2 -g3 -Wall -Wextra -Werror -nostartfiles -Wl,--gc-sections`

However, upon executing the firmware, the processor fails the startup health contract:
* Target execution never reaches the operational loop in `main()`.
* Instead, execution traps in an infinite loop inside `main()` due to an unfulfilled hardware pre-initialization invariant.
* Specifically, a mandatory constructor registered via the standard GNU C runtime constructor mechanism (`__attribute__((constructor))`) failed to execute prior to `main()`.

---

## 2. Deliverables & Investigation Tasks

1. **Annotated Startup Path:**
   Trace and document the 7 discrete phases of the startup sequence from hardware reset vector fetch to `main()`.
2. **Binary / Section Header Evidence:**
   Use GNU Binutils (`arm-none-eabi-readelf -S`, `readelf -s`, and the linker map `build/firmware.map`) to examine the ELF binary. Capture verbatim evidence showing why the constructor was not invoked.
3. **Formulate Hypotheses:**
   Write 3–5 competing hypotheses explaining why the constructor function was omitted or failed to execute despite compiling without error.
4. **Identify Root Cause:**
   Determine the precise root cause in the linker script section definition and linker garbage collection interactions.
5. **Apply Minimal Principled Correction:**
   Apply the minimal correction to the linker script.
6. **Verify Regression Resolution:**
   Rebuild the binary and prove that `make check` passes, confirming that the constructor section is properly preserved and executed.

---

## 3. Investigation Protocol

1. Build the seeded fixture:
   ```bash
   make clean && make
   ```
2. Run the automated check to observe the failure:
   ```bash
   make check
   ```
3. Inspect the ELF binary section headers and map file:
   ```bash
   arm-none-eabi-readelf -S build/firmware.elf
   grep -A 10 "init_array" build/firmware.map
   ```
4. Record your findings in Section 4 of `../SUBMISSION_TEMPLATE.md`.
5. Apply the fix and run `make check` to confirm resolution.
