# P2-M01 Challenge Solution: Blank-Directory Startup Reconstruction

> **Target Mastery**: L3 Linker/Startup reasoning, L4-local boot fault recovery  
> **Challenge Goal**: Reconstruct a complete, working bare-metal startup assembly file, minimal runtime glue, and linker script from scratch in an empty directory within 25 minutes.

---

## 1. Diagnostic Mapping for Reconstruction Failures

When learners reconstruct startup code from a blank directory, the most frequent failure path maps as follows:

```text
symptom
→ hypotheses
→ evidence
→ root cause
→ minimal fix
→ regression
```

### Case Study: Reconstructed Image Faults at First Branch
- **Symptom**: Firmware compiles cleanly, but GDB reports target halts immediately at `HardFault_Handler` or `UsageFault` (INVSTATE) upon reset.
- **Hypotheses**:
  1. The stack pointer symbol `_estack` points outside physical SRAM bounds.
  2. The reset vector in `.isr_vector` is missing the Thumb execution bit (bit 0 = 0).
  3. `Reset_Handler` calls `SystemInit()`, which tries to access uninitialized global variables.
  4. Vector table is placed at an offset instead of Flash origin `0x08000000`.
- **Evidence**:
  ```bash
  arm-none-eabi-readelf -h build/firmware.elf
  # Entry point address is 0x8000220 (even address!)
  arm-none-eabi-objdump -s -j .isr_vector build/firmware.elf
  # Word 1 displays 20 02 00 08 (bit 0 is 0)
  ```
- **Root Cause**: The learner declared `Reset_Handler:` as a raw assembly label without `.type Reset_Handler, %function`. GNU as treats untyped symbols as data references, emitting an even address into the vector table.
- **Minimal Fix**:
  Add `.type Reset_Handler, %function` in assembly before or after the label:
  ```assembly
  .section .text.Reset_Handler
  .weak Reset_Handler
  .type Reset_Handler, %function
  Reset_Handler:
  ```
- **Regression**:
  Re-run `arm-none-eabi-readelf -h build/firmware.elf` and confirm entry point bit 0 is `1` (`0x8000221`), then verify with `bash challenge/verify_challenge.sh`.

---

## 2. Reference Implementation Architecture

A fully compliant reconstruction requires three files:

### 2.1 Linker Script (`linker/stm32f103c8tx_flash.ld`)
```ld
ENTRY(Reset_Handler)

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 64K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 20K
}

_estack = ORIGIN(RAM) + LENGTH(RAM);
_min_stack_size = 0x400;

SECTIONS
{
    .isr_vector :
    {
        . = ALIGN(4);
        KEEP(*(.isr_vector))
        . = ALIGN(4);
    } > FLASH

    .text :
    {
        . = ALIGN(4);
        *(.text)
        *(.text*)
        . = ALIGN(4);
        _etext = .;
    } > FLASH

    .rodata :
    {
        . = ALIGN(4);
        *(.rodata)
        *(.rodata*)
        . = ALIGN(4);
    } > FLASH

    .init_array :
    {
        . = ALIGN(4);
        PROVIDE_HIDDEN (__init_array_start = .);
        KEEP (*(SORT(.init_array.*)))
        KEEP (*(.init_array*))
        PROVIDE_HIDDEN (__init_array_end = .);
        . = ALIGN(4);
    } > FLASH

    _sidata = LOADADDR(.data);

    .data :
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data)
        *(.data*)
        . = ALIGN(4);
        _edata = .;
    } > RAM AT > FLASH

    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    ASSERT(_ebss + _min_stack_size <= ORIGIN(RAM) + LENGTH(RAM),
           "Linker Error: SRAM exhausted! BSS and stack exceed 20 KB capacity.")
    ASSERT(LOADADDR(.data) + SIZEOF(.data) <= ORIGIN(FLASH) + LENGTH(FLASH),
           "Linker Error: Flash exhausted! Firmware image exceeds 64 KB capacity.")
}
```

### 2.2 Assembly Startup (`src/startup_stm32f103c8.s`)
```assembly
  .syntax unified
  .cpu cortex-m3
  .fpu softvfp
  .thumb

  .global g_pfnVectors
  .global Reset_Handler
  .global Default_Handler

  .section .text.Reset_Handler
  .weak Reset_Handler
  .type Reset_Handler, %function
Reset_Handler:
  bl  SystemInit

  ldr r0, =_sdata
  ldr r1, =_edata
  ldr r2, =_sidata
  movs r3, #0
  b .L_check_data_loop
.L_copy_data_loop:
  ldr r3, [r2], #4
  str r3, [r0], #4
.L_check_data_loop:
  cmp r0, r1
  bcc .L_copy_data_loop

  ldr r0, =_sbss
  ldr r1, =_ebss
  movs r3, #0
  b .L_check_bss_loop
.L_zero_bss_loop:
  str r3, [r0], #4
.L_check_bss_loop:
  cmp r0, r1
  bcc .L_zero_bss_loop

  bl  __libc_init_array
  bl  main

.L_hang:
  b .L_hang
  .size Reset_Handler, .-Reset_Handler
```

### 2.3 Minimal Runtime Glue (`src/runtime_glue.c`)
```c
void _init(void) {}
void _fini(void) {}
```

---

## 3. Automated Verification

Run from module root:
```bash
bash challenge/verify_challenge.sh
```
Verifies:
1. Build artifacts exist (`firmware.elf`, `firmware.map`).
2. Memory bounds are within 64 KB Flash and 20 KB SRAM.
3. Vector 0 is `0x20005000` (initial MSP) and Vector 1 has Thumb bit set.
4. `__libc_init_array`, `_init`, `_fini`, and section symbols are verified.
5. No CRT0 `_start` or libc dynamic heap allocators linked.
