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
* Instead, execution traps in an infinite fault loop inside `main()` (`g_boot_status == 0xDEADBEEFU`).
* System self-checks reveal that initialized global configuration variables residing in `.data` (such as `g_boot_config_token`) fail validation against their compile-time initializers.

---

## 2. Deliverables & Investigation Tasks

1. **Annotated Startup Path:**
   Trace and document the discrete phases of the startup sequence from hardware reset vector fetch to `main()`.
2. **Binary / Section Header Evidence:**
   Use GNU Binutils (`arm-none-eabi-readelf -S`, `readelf -l`, `nm`, and the linker map `build/firmware.map`) to examine the ELF binary. Capture verbatim evidence demonstrating the relationship between Flash load memory addresses (LMA) and SRAM virtual memory addresses (VMA).
3. **Formulate Hypotheses:**
   Write 3–5 competing hypotheses explaining why initialized data in SRAM fails to match its compile-time initializers despite compiling without error.
4. **Root-Cause Investigation:**
   Determine the precise root cause in the linker script memory allocation, section definitions, and startup symbol exports.
5. **Apply Minimal Principled Correction:**
   Apply the minimal correction to the linker script.
6. **Verify Artifact & Regression Resolution:**
   Rebuild the binary and run `make check` to confirm that the firmware artifact compiles, links, and complies with silicon memory limits. (Note: `make check` validates generic artifact integrity; technical evaluation of the relocation contract is performed by reviewer-isolated testing).

---

## 3. Investigation Protocol

1. Build the seeded fixture:
   ```bash
   make clean && make
   ```
2. Run `make check` to confirm valid firmware build and artifact generation:
   ```bash
   make check
   ```
3. Inspect the ELF binary section and segment headers and map file:
   ```bash
   arm-none-eabi-readelf -l build/firmware.elf
   arm-none-eabi-nm build/firmware.elf | grep -E '_si|_sd|_ed|_et'
   ```
4. Record your findings and reasoning in Section 4 of `../SUBMISSION_TEMPLATE.md`.
5. Apply the minimal principled correction to `linker/stm32f103c8tx_flash.ld` and verify build integrity with `make check`.
