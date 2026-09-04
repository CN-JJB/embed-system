# Lab 01 — Dissecting ELF Headers and the Vector Table

## Objective

Analyze the compiled `firmware.elf` binary using GNU Binutils binary inspection tools (`readelf`, `nm`, `objdump`). Verify the exact vector table structure, initial MSP address, entry point symbol, and Thumb state encoding before flashing to hardware.

## Prerequisites

- Read P2-M01 README Section 2.1 (Silicon Boot Sequence) and Section 2.2 (Thumb Bit Rule).
- Familiarity with GNU Binutils commands from Phase 1.

## Environment

- Linux / WSL2 host with `arm-none-eabi-gcc`, `arm-none-eabi-readelf`, `arm-none-eabi-nm`, `arm-none-eabi-objdump`.
- No target board required for this lab.

## Estimated Time

30 minutes.

## AI Mode

**AI-Free**. Use official GNU Binutils and Armv7-M Architecture Reference Manual documentation.

## Build

Compile the module firmware:

```bash
make clean && make
```

## Procedure

1. **Inspect ELF File Header:**
   ```bash
   arm-none-eabi-readelf -h build/firmware.elf
   ```
   Note the `Entry point address` value.

2. **Locate `Reset_Handler` in Symbol Table:**
   ```bash
   arm-none-eabi-nm -n build/firmware.elf | grep " Reset_Handler"
   ```
   Compare the symbol value of `Reset_Handler` with the ELF entry point address.

3. **Dump the Vector Table Section (`.isr_vector`):**
   ```bash
   arm-none-eabi-objdump -s -j .isr_vector build/firmware.elf
   ```
   Examine the first 8 bytes (two 32-bit little-endian words).
   - Byte offset 0x00 to 0x03: What is the initial MSP value?
   - Byte offset 0x04 to 0x07: What is the Reset Vector value?

4. **Verify Memory Section Headers:**
   ```bash
   arm-none-eabi-readelf -S build/firmware.elf
   ```
   Verify that `.isr_vector` has address `0x08000000` and flag `A` (Alloc).

## Expected Observation

- The ELF entry point address is odd (e.g. `0x08000221`), while `Reset_Handler` symbol address is even (`0x08000220`).
- Vector 0 contains little-endian `0x20005000` (printed as `00 50 00 20`), which matches `_estack` (top of 20 KB SRAM).
- Vector 1 contains little-endian `0x08000221` (printed as `21 02 00 08`), which is `Reset_Handler` with the Thumb mode bit (bit 0) set.

## Actual Verification Status

**VERIFIED** (host toolchain). Executed with Arm GNU Toolchain 13.2.1 / binutils 2.42 on Linux x86_64 / WSL2. Entry point, vector 0, and vector 1 values confirmed.

## Questions

1. Why does `readelf -h` report `0x08000221` instead of `0x08000220`? What happens if you manually patch byte 0x04 of `.isr_vector` to `0x20` instead of `0x21`?
2. Why is vector 0 loaded into SP by hardware rather than being an instruction like `LDR SP, =_estack` in `Reset_Handler`?
3. Where does `_estack` point in the memory map, and why is `0x20005000` safe for a 20 KB device?

## Failure Modes

- **Entry point is even (`0x08000220`):** Missing `.type Reset_Handler, %function` directive in assembly, causing the assembler to treat the symbol as data and omitting the Thumb bit.
- **Vector table misplaced:** Linker script omitted `KEEP(*(.isr_vector))` or placed another section at Flash origin `0x08000000`.

## Debug Strategy

Always run `readelf -h` and `readelf -x .isr_vector` before flashing any new MCU firmware. Never guess whether code reached `main()`; check whether the vector table was properly formed.

## Challenge

Write a bash one-liner that automatically extracts word 0 and word 1 from `firmware.bin` using `xxd` or `hexdump` and asserts that word 0 equals `0x20005000`.

## Cleanup

```bash
make clean
```

## Sources

- ST PM0056 Section 2.1 (Processor modes and stacks).
- Armv7-M Architecture Reference Manual Section B1.5.3 (Reset behavior).
