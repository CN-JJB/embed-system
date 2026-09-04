# P2-M01 Fault Analysis & Diagnostic Chains

This document details the complete hypothesis-driven diagnostic chains for all deliberate fault fixtures in Module P2-M01.

---

## Fault 1: Misaligned / Even Reset Vector (`faults/fault1_misaligned_vector/`)

- **Symptom**:
  The MCU halts immediately at boot. In GDB, the CPU traps in `UsageFault` or `HardFault` before entering `Reset_Handler` or `main()`.
- **Hypotheses**:
  1. Boot pins (BOOT0 / BOOT1) are improperly strapped, booting from System Memory or SRAM instead of Flash.
  2. The reset vector in the vector table has an even address (bit 0 = 0), violating the Cortex-M Thumb execution contract.
  3. Memory at address `0x08000000` is corrupted or blank (unprogrammed Flash).
  4. Stack pointer is pointing to an invalid memory region.
- **Evidence**:
  ```bash
  arm-none-eabi-readelf -x .isr_vector build/firmware.elf
  ```
  Output shows word 1 (bytes 0x04..0x07) contains an even address ending in `0x08000220` (bit 0 = 0).
  In GDB:
  ```gdb
  x/2wx 0x08000000
  ```
  Confirms the hardware attempts to load PC with an even address, triggering `UsageFault` (CFSR `INVSTATE` bit set).
- **Root Cause**:
  In `startup_faulty.s`, `.type Reset_Handler, %function` was omitted. The GNU assembler and linker therefore treat `Reset_Handler` as raw data rather than a Thumb function, omitting the required `+1` Thumb execution bit in the vector table entry.
- **Minimal Fix**:
  Add `.type Reset_Handler, %function` in assembly:
  ```assembly
  .type Reset_Handler, %function
  ```
- **Regression**:
  Rebuild and run `arm-none-eabi-readelf -h build/firmware.elf`. Confirm entry point address is odd (e.g. `0x08000221`).

---

## Fault 2: LMA-VMA Symbol Mismatch (`faults/fault2_data_lma_mismatch/`)

- **Symptom**:
  Firmware boots and executes cleanly into `main()`, but all initialized global and static C variables evaluate to `0` or random uninitialized values instead of their compile-time initializers.
- **Hypotheses**:
  1. The `.data` copy loop in `Reset_Handler` was skipped or branched over.
  2. The loop counter or pointer increment in the copy loop is inverted or miscalculated.
  3. `_sidata` (Flash LMA load address) was assigned the VMA RAM address instead of `LOADADDR(.data)`.
  4. The compiler placed initialized variables into `.bss` instead of `.data`.
- **Evidence**:
  Inspect the generated map file:
  ```bash
  grep -A 10 "\.data" build/firmware.map
  ```
  Reveals:
  ```text
  _sidata = 0x20000000
  _sdata  = 0x20000000
  _edata  = 0x20000008
  ```
  `_sidata` resides at `0x20000000` (in RAM!), but the actual load memory address of initialized data is in Flash (`0x08000270`).
- **Root Cause**:
  In `linker_faulty.ld`, `_sidata` was defined using `ADDR(.data)` instead of `LOADADDR(.data)`. `ADDR(.data)` returns the execution virtual memory address (VMA) in SRAM. The copy loop copied uninitialized SRAM onto SRAM.
- **Minimal Fix**:
  Update `linker_faulty.ld`:
  ```diff
  -    _sidata = ADDR(.data);
  +    _sidata = LOADADDR(.data);
  ```
- **Regression**:
  Recompile and verify in `build/firmware.map` that `_sidata` starts in the Flash address range (`0x0800xxxx`), while `_sdata` is in the SRAM range (`0x2000xxxx`).

---

## Fault 3: SRAM Overflow Assertion (`faults/fault3_memory_overflow/`)

- **Symptom**:
  The linker aborts the build process with an error message, refusing to generate `firmware.elf`.
- **Hypotheses**:
  1. Syntax error in the linker script.
  2. Missing source file or undefined external reference.
  3. Linker memory region `RAM` has overflowed because statically allocated arrays exceed 20 KB capacity.
  4. User `ASSERT` directive in the linker script was triggered by memory exhaustion.
- **Evidence**:
  ```bash
  make clean && make
  ```
  Output:
  ```text
  arm-none-eabi/bin/ld: build/firmware.elf section `.bss' will not fit in region `RAM'
  arm-none-eabi/bin/ld: Linker Error: SRAM exhausted! BSS and stack exceed 20 KB capacity.
  arm-none-eabi/bin/ld: region `RAM' overflowed by 6144 bytes
  collect2: error: ld returned 1 exit status
  ```
- **Root Cause**:
  In `main_overflow.c`, a static buffer array of 24 KB was declared (`static uint8_t g_large_buffer[24576];`). Physical STM32F103C8 SRAM is only 20 KB (`0x5000` bytes). The original linker script's `ASSERT(_ebss + _min_stack_size <= ORIGIN(RAM) + LENGTH(RAM))` caught the overflow and safely terminated the build.
- **Minimal Fix**:
  Reduce the statically allocated buffer size to fit within available SRAM, leaving at least 1 KB (`0x400` bytes) for the hardware stack:
  ```diff
  -static uint8_t g_large_buffer[24576];
  +static uint8_t g_large_buffer[4096];
  ```
- **Regression**:
  Rebuild `make clean && make`. Verify with `arm-none-eabi-size build/firmware.elf` that `data + bss + 1024 <= 20480`.
