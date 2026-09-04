# Lab 02 — Step-by-Step Reset-to-Main Boot Verification

## Objective

Trace the execution path of the Cortex-M3 processor from power-on reset through `SystemInit()`, the `.data` copy loop, the `.bss` zero loop, and `__libc_init_array()` into `main()`. Verify register values and processor states at every boundary.

## Prerequisites

- Lab 01 completed.
- Understanding of the canonical reset execution sequence.

## Environment

- Host: Linux / WSL2 with GNU Toolchain (`arm-none-eabi-gcc`, `gdb-multiarch` / `arm-none-eabi-gdb`).
- Hardware (Optional): STM32F103C8T6 + ST-Link V2 + OpenOCD.
- Offline/Emulation: Disassembly trace analysis (`firmware.asm`) and GDB script verification.

## Estimated Time

40 minutes.

## AI Mode

**AI-Hint** permitted only for GDB command syntax.

## Build

```bash
make clean && make
```

## Procedure

1. **Disassemble the Boot Sequence:**
   Open `build/firmware.asm` and inspect the disassembled instructions of:
   - `Reset_Handler`
   - `SystemInit`
   - `.L_copy_data_loop` and `.L_check_data_loop`
   - `.L_zero_bss_loop` and `.L_check_zero_bss_loop`
   - `__libc_init_array`

2. **Trace the Assembly Operations:**
   - Note the instruction `bl SystemInit`. Notice that before this call, `R0-R3` are not guaranteed to hold any specific C values.
   - Note the `.data` copy loop:
     ```arm
     ldr r0, =_sdata     ; Destination pointer in RAM
     ldr r1, =_edata     ; End pointer in RAM
     ldr r2, =_sidata    ; Source pointer in Flash
     ```
     Identify how many 32-bit words are copied in your build.
   - Note the `.bss` zero loop:
     ```arm
     ldr r0, =_sbss      ; Destination pointer in RAM
     ldr r1, =_ebss      ; End pointer in RAM
     movs r2, #0         ; Zero value
     ```

3. **GDB Session (Target or Simulator):**
   ```bash
   gdb-multiarch build/firmware.elf
   ```
   In GDB:
   ```gdb
   target extended-remote :3333
   monitor reset halt
   info registers sp pc
   b Reset_Handler
   b SystemInit
   b __libc_init_array
   b main
   continue
   ```
   Inspect the Program Counter (`pc`) and Stack Pointer (`sp`) at each breakpoint.

## Expected Observation

- At `Reset_Handler` entry, `sp` is exactly `0x20005000` without any software `mov sp, ...` having run.
- Stepping past `__libc_init_array()` executes the constructor function `early_constructor_hook()`.
- Upon entering `main()`, global variables in `.data` (`g_boot_magic`) match `0xA5C3E107U`, and uninitialized `.bss` (`g_zero_bss_check`) is `0`.

## Actual Verification Status

- **Host Disassembly & Link Structure:** **VERIFIED** via `arm-none-eabi-objdump -d -S`.
- **Target Hardware Execution:** **UNVERIFIED** (no physical target flash/run was performed; host disassembly/register mapping evidence is reported separately above).

## Questions

1. Why does the processor hardware load `sp` from vector 0 rather than having the startup code configure `sp` in assembly?
2. What occurs if `main()` reaches its closing brace without an infinite loop? What instruction catches it?
3. If an interrupt fires during the `.data` copy loop, will the ISR execute properly? Why or why not?

## Failure Modes

- `Reset_Handler` infinite loop at `b .L_loop_forever`: Indicates that `main()` returned unexpectedly.
- `HardFault_Handler`: Attempted to write to a peripheral register whose clock was not enabled, or executed an unaligned memory access.

## Debug Strategy

Set hardware breakpoints at the beginning of each phase:
`break Reset_Handler` -> `break SystemInit` -> `break main`. Step instruction by instruction (`stepi`) across the copy loops to verify pointer arithmetic.

## Challenge

Modify `startup_stm32f103c8.s` to fill the stack region with a canary pattern (e.g. `0xA5A5A5A5`) during startup, then verify in `main()` how many stack words were consumed by startup function calls.

## Cleanup

```bash
make clean
```

## Sources

- ST PM0056 Section 2.1.
- Armv7-M Architecture Reference Manual Section B1.5.3.
