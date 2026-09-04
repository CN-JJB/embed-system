# Lab 04 — NVIC Priority Encoding and Processor Modes

## Objective
Explore Cortex-M3 processor execution states (Privileged Thread mode vs Handler mode) and verify the 4-bit NVIC priority encoding model.

## Prerequisites
- Lab 03 completed.
- P2-M02 README Section 2.4 (NVIC Priority Architecture).

## Environment
- Host: Linux / WSL2 with GDB.
- Target: STM32F103C8T6 via OpenOCD.

## Estimated Time
35 minutes.

## AI Mode
**AI-Free**.

## Build
```bash
make clean && make
```

## Procedure
1. In GDB, break at `main` and inspect core registers:
   ```gdb
   b main
   continue
   info registers ipsr control
   ```
   Notice that `IPSR == 0` (Thread Mode).
2. Set a breakpoint inside `TIM2_IRQHandler`:
   ```gdb
   b TIM2_IRQHandler
   continue
   info registers ipsr control
   ```
   Notice that `IPSR == 44` (Exception number for TIM2: IRQ 28 + 16 = 44). The processor is now in **Handler Mode**!
3. Inspect `EXC_RETURN` loaded into `LR`:
   ```gdb
   print /x $lr
   ```
   Expected return value: `0xFFFFFFF9` or `0xFFFFFFFD`.
4. Inspect physical priority byte written to NVIC:
   ```gdb
   # TIM2 IRQ number is 28. Physical register is NVIC->IP[28]
   x/1bx 0xE000E41C
   ```
   Notice that logical priority 6 encodes as `0x60` (96 decimal)!

## Expected Observation
- In Thread mode, `IPSR` is 0. In ISR, `IPSR` indicates active exception number.
- `NVIC->IP[28]` contains `0x60` ($6 \ll 4$).

## Actual Verification Status
**PARTIALLY VERIFIED**. Disassembly and symbol audit are **VERIFIED** on host toolchain. Target runtime GDB sessions (`IPSR`, `EXC_RETURN`, and live hardware priority register reads) are **EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED**.

## Questions
1. Why does STM32F103 put the 4 priority bits in the upper nibble (`[7:4]`) rather than the lower nibble (`[3:0]`)?
2. What happens if software writes logical priority 6 directly into `NVIC->IP` without shifting? What priority does hardware perceive?

## Failure Modes
- Inverting priority numbers: assuming priority 15 is higher urgency than priority 0. (In Cortex-M, 0 is highest urgency!).

## Debug Strategy
Use CMSIS `NVIC_GetPriority(IRQn)` to read logical priority, or read memory at `0xE000E400 + IRQn` for raw encoded hardware byte.

## Challenge
Configure two separate IRQs (e.g. TIM2 and TIM3) with different preemption priorities. In GDB, observe that the higher-priority ISR preempts the lower-priority ISR when both are pending.

## Cleanup
```bash
make clean
```

## Sources
- ST PM0056 Section 4.3 (NVIC).
- Armv7-M Architecture Reference Manual Section B3.4.
