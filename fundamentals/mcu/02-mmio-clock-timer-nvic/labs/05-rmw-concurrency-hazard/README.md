# Lab 05 — Read-Modify-Write Concurrency Hazards on Shared Registers

## Objective
Demonstrate the read-modify-write (RMW) race hazard that occurs when Thread mode and an interrupt handler concurrently access the same peripheral register (`GPIOA->ODR`). Prove that dedicated set/reset registers (`BSRR`/`BRR`) resolve the hazard atomically.

## Prerequisites
- Labs 01 through 04 completed.
- P2-M02 README Section 2.2 (RMW Race Conditions).

## Environment
- Host: Linux / WSL2 with GCC toolchain.
- Target: STM32F103C8T6, logic analyzer or oscilloscope probing PA1 and PA2.

## Estimated Time
40 minutes.

## AI Mode
**AI-Free**.

## Build
```bash
make clean && make
```

## Procedure
1. Inspect `src/gpio.c`:
   - `gpio_toggle_pa2_non_atomic_rmw()` executes `GPIOA->ODR ^= (1U << 2);`.
   - `gpio_toggle_pa1_atomic()` executes atomic writes to `GPIOA->BSRR` and `GPIOA->BRR`.
2. Trace the disassembly of `gpio_toggle_pa2_non_atomic_rmw()` in `build/firmware.asm`:
   ```arm
   ldr  r1, [r0, #12]   ; Read ODR
   eor  r1, r1, #4      ; Modify bit 2
   str  r1, [r0, #12]   ; Write back ODR
   ```
3. In `main.c`, execute a tight loop calling `gpio_toggle_pa2_non_atomic_rmw()` while TIM2 interrupts fire at 10 kHz:
   Observe on a logic analyzer: occasionally PA1 toggle modifies ODR while PA2 RMW is in flight, resulting in lost edges and glitching.
4. Replace `gpio_toggle_pa2_non_atomic_rmw()` with `gpio_toggle_pa2_atomic()`:
   On target, record whether the previously observed lost-edge symptom disappears. This physical regression remains **UNVERIFIED** until measured.

## Expected Observation
- Non-atomic RMW on shared registers suffers race hazards when preempted by an ISR.
- Atomic `BSRR`/`BRR` writes avoid the shared-ODR read/modify/write lost-update mechanism for independent bit set/reset operations. They do not make arbitrary software toggle-state logic race-free across contexts.

## Actual Verification Status
**PARTIALLY VERIFIED**. Disassembly verifies the multi-instruction ODR RMW hazard and single-store BSRR/BRR mechanism. Actual lost-edge reproduction and physical regression remain **UNVERIFIED** without target waveform capture.

## Questions
1. Why does `volatile` fail to prevent the RMW race condition?
2. If a peripheral lacks a BSRR register (e.g. `TIM2->CR1`), how must software protect shared bit modifications?

## Failure Modes
- Using non-atomic bitwise operations (`|=`, `&=`) on GPIO `ODR` inside both an ISR and main thread.

## Debug Strategy
Whenever erratic pin toggling or missing pulses occur, search the codebase for direct assignments to `ODR`. Replace with `BSRR` or `BRR`.

## Challenge
Measure the cycle count of a 3-instruction RMW sequence (`LDR/ORR/STR`) versus a single atomic `STR` to `BSRR` using the Cortex-M3 DWT cycle counter (`DWT->CYCCNT`).

## Cleanup
```bash
make clean
```

## Sources
- ST RM0008 Section 9.1 (GPIO registers).
