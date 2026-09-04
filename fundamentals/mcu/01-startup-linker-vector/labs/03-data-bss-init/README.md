# Lab 03 — Observing .data Copy and .bss Zeroing

## Objective

Demonstrate the physical memory transition of global variables from their cold state in Flash memory to their runtime state in SRAM. Prove through memory dumps that uninitialized variables are zeroed and initialized variables match their initializers.

## Prerequisites

- Read P2-M01 README Section 2.3 (Memory Layout: VMA vs. LMA).
- Lab 02 completed.

## Environment

- Host: Linux / WSL2 with GNU Toolchain (`arm-none-eabi-gcc`, `arm-none-eabi-readelf`, `arm-none-eabi-nm`).
- GDB / OpenOCD.

## Estimated Time

30 minutes.

## AI Mode

**AI-Free**.

## Build

```bash
make clean && make
```

## Procedure

1. **Locate Symbols in ELF:**
   ```bash
   arm-none-eabi-nm -n build/firmware.elf | grep -E "g_boot_magic|g_zero_bss_check|g_constructor_ran|_sidata|_sdata|_edata|_sbss|_ebss"
   ```
   Record the VMA addresses of `g_boot_magic` and `g_zero_bss_check`.
   Record the LMA address `_sidata`.

2. **Inspect the Linker Map:**
   Open `build/firmware.map`.
   Find the `.data` and `.bss` output sections:
   - What is the load address (LMA) of `.data`?
   - What is the execution address (VMA) of `.data`?
   - What is the size of `.bss`?

3. **GDB Memory Inspection (Target / Simulator):**
   Attach GDB and set breakpoints before and after the data/bss copy loops:
   ```gdb
   b Reset_Handler
   continue
   # We are at Reset_Handler entry: inspect RAM before initialization
   x/4wx 0x20000000
   # Break right before main()
   b main
   continue
   # Inspect RAM after initialization
   x/4wx 0x20000000
   ```

4. **Compare Pre-Copy vs. Post-Copy State:**
   - Before the copy loop, what was located at `0x20000000`? (Uninitialized SRAM bytes / noise).
   - After the copy loop, what value is at `0x20000000`? (Should match `0xA5C3E107`).

## Expected Observation

- In `firmware.map`, `.data` has `LOADADDR` in Flash (e.g. `0x08000270`) and runtime address in RAM (`0x20000000`).
- The initial values stored in Flash at `_sidata` are copied word-by-word into RAM at `_sdata`.
- The `.bss` section in RAM (`_sbss` to `_ebss`) is completely cleared to zeroes.

## Actual Verification Status

**VERIFIED** (host toolchain & map inspection). Symbol locations and section mappings verified via GNU Binutils 2.42.

## Questions

1. Why cannot the compiler simply emit instructions to execute directly out of Flash for `.data` variables?
2. If `_sidata` is erroneously defined in the linker script as `ADDR(.data)` instead of `LOADADDR(.data)`, what symptom will appear in `main()`?
3. If an uninitialized static variable `static int count;` is placed in a function, which section does it occupy, and what guarantees its value is 0 on the first call?

## Failure Modes

- `g_boot_magic` in `main()` contains 0 or garbage: The `.data` copy loop bounds `_sdata` and `_edata` were inverted or the increment step was incorrect.
- `g_zero_bss_check` is non-zero: The `.bss` zero loop terminated prematurely or skipped alignment padding.

## Debug Strategy

Check the map file (`firmware.map`) for the exact symbol addresses:
Verify that `_edata - _sdata` matches the byte count copied from `_sidata`.

## Challenge

Add a global array `uint32_t table[16] = {1, 2, 3, ...};` and verify in GDB that all 16 words appear consecutively in SRAM after boot.

## Cleanup

```bash
make clean
```

## Sources

- GNU Binutils LD Manual Section 3.6 (Output Section LMA).
- ST RM0008 Section 3.3 (Embedded SRAM).
