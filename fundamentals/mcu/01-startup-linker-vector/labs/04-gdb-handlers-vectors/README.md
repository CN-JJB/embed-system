# Lab 04 — Vector Table and Handler Inspection in GDB

## Objective

Connect GDB to the microcontroller (or an emulation stub) to inspect live core registers (`MSP`, `PSP`, `CONTROL`, `xPSR`), examine the vector table at physical address `0x08000000`, and trace weak alias resolution for interrupt handlers.

## Prerequisites

- Labs 01 through 03 completed.
- GDB installed (`gdb-multiarch` or `arm-none-eabi-gdb`).

## Environment

- Host: Linux / WSL2 with GDB.
- Target: STM32F103C8T6 via ST-Link V2 and OpenOCD (or QEMU/stub).

## Estimated Time

35 minutes.

## AI Mode

**AI-Free**.

## Build

```bash
make clean && make
```

## Procedure

1. **Start OpenOCD (in terminal 1, if hardware target is available):**
   ```bash
   openocd -f interface/stlink.cfg -f target/stm32f1x.cfg
   ```

2. **Launch GDB (in terminal 2):**
   ```bash
   gdb-multiarch build/firmware.elf
   ```
   Execute the following inspection script:
   ```gdb
   # Connect and halt target
   target extended-remote :3333
   monitor reset halt

   # 1. Inspect Vector Table in Flash
   echo === Vector Table First 4 Entries ===\n
   x/4a 0x08000000

   # 2. Inspect Processor Core Registers
   echo === Core Registers at Reset ===\n
   info registers sp pc xpsr

   # 3. Verify Default_Handler Weak Aliasing
   echo === Address of Default_Handler ===\n
   print Default_Handler
   echo === Address of TIM2_IRQHandler ===\n
   print TIM2_IRQHandler

   # 4. Step past SystemInit
   break main
   continue
   echo === Registers at main() ===\n
   info registers
   ```

3. **Analyze Output:**
   - Verify whether `TIM2_IRQHandler` points to `Default_Handler` (since it is weakly aliased and not yet overridden).
   - Verify that `xPSR` has bit 24 set (the Thumb state bit `T`).
   - Check `CONTROL` register value: verify whether processor is executing in Privileged Thread mode using MSP.

## Expected Observation

- Word 0 at `0x08000000` is `0x20005000` (`_estack`).
- Word 1 at `0x08000004` is the Thumb address of `Reset_Handler`.
- Unimplemented handlers (such as `TIM2_IRQHandler`, `SysTick_Handler`) resolve to the exact address of `Default_Handler`.
- `xPSR` register contains `0x01000000` (EPSR bit 24 = 1).
- `CONTROL` register is `0x00000000` (Privileged mode, active stack is MSP).

## Actual Verification Status

- **GDB Script and Symbol Resolution:** **VERIFIED** on host ELF image via `gdb-multiarch` batch mode.
- **Physical Hardware Observation:** **UNVERIFIED** (GDB commands/symbol resolution were checked against the ELF, but no live target register/exception trace was captured).

## Questions

1. In GDB, why does `print Reset_Handler` print an even address, but `x/4a 0x08000000` prints an odd address for the reset vector?
2. If `CONTROL` bit 1 (`SPSEL`) is 0, which stack pointer is active?
3. What occurs if an unhandled interrupt fires while weakly aliased to `Default_Handler`? Where does the CPU halt?

## Failure Modes

- Target halts in `HardFault_Handler`: Attempted to access an unmapped physical address or execute an invalid instruction.
- Target hangs in `Default_Handler`: An interrupt was enabled and triggered, but no dedicated handler was implemented to service and clear the interrupt flag.

## Debug Strategy

When execution halts unexpectedly, issue in GDB:
```gdb
info registers
bt
x/8xw $sp
```
Inspect `LR` to determine whether an exception return occurred, and read the stacked exception frame (`{r0-r3, r12, lr, pc, xpsr}`).

## Challenge

Override `SysTick_Handler` in `main.c` with a strong implementation. In GDB, print the address of `SysTick_Handler` and prove that it no longer points to `Default_Handler`.

## Cleanup

```bash
make clean
```

## Sources

- ST PM0056 Section 2.1 (Processor modes and stacks).
- Armv7-M Architecture Reference Manual Section B1.5.1 (Exception model).
