# Lab 03 — TIM2 1 kHz Periodic Interrupt and ISR Acknowledgment

## Objective
Implement and verify a direct-register 1.0 ms (1 kHz) periodic update interrupt on General Purpose Timer 2 (TIM2). Acknowledge interrupt flags in hardware and drive a physical GPIO timing marker on PA1.

## Prerequisites
- Lab 02 completed.
- P2-M02 README Section 2.5 (Interrupt Acknowledgment).

## Environment
- Host: Linux / WSL2 with GCC toolchain.
- Target: STM32F103C8T6, ST-Link V2, oscilloscope or logic analyzer on PA1.

## Estimated Time
45 minutes.

## AI Mode
**AI-Hint** (only for oscilloscope trigger setup).

## Build
```bash
make clean && make
```

## Procedure
1. Inspect `src/timer.c`:
   - Prescaler math: $f_{\text{timclk}} = 72\text{ MHz} \implies \text{PSC} = 71, \text{ARR} = 999$.
   - Flag clearing: `TIM2->SR = ~TIM_SR_UIF;`
   - Memory barrier: `__DSB();`
2. Flash target firmware using OpenOCD:
   ```bash
   openocd -f interface/stlink.cfg -f target/stm32f1x.cfg -c "program build/firmware.elf verify reset exit"
   ```
3. Connect oscilloscope channel 1 to pin **PA1**.
4. Measure pulse width and toggle period.

## Expected Observation
- PA1 toggles every 1.0 ms, generating a 500 Hz square wave.
- Main thread spends majority of execution sleeping in `__WFI()`.
- If flag clearing is commented out, PA1 stops toggling and the system locks in the ISR.

## Actual Verification Status
- **Target Compile/Link**: **VERIFIED** via GNU Binutils.
- **Evidence Statement (EXPECTED / TARGET RUN UNVERIFIED)**:
  ```text
  Expected Observation: PA1 periodic toggle at 1.0 ms period (500 Hz square wave) on hardware.
  Interpretation: Verifies PSC=71, ARR=999 divides 72 MHz clock to 1 kHz.
  Non-Proof: Static build does not measure physical crystal precision or temperature drift.
  ```

## Questions
1. Why must `TIM2->SR` be written with `~TIM_SR_UIF` rather than `0`?
2. What is the role of `__DSB()` immediately following the flag clear?

## Failure Modes
- **Interrupt Storm**: Omitting `TIM2->SR = ~TIM_SR_UIF` causes the core to endlessly re-enter `TIM2_IRQHandler`, starving `main()`.

## Debug Strategy
In GDB:
```gdb
print /x TIM2->SR
print /x TIM2->DIER
print /x NVIC->ISER[0]
```

## Challenge
Configure TIM2 to generate interrupts at 5 kHz (200 us period). Recalculate ARR and verify on an oscilloscope or logic analyzer that PA1 toggles at 2.5 kHz.

## Cleanup
```bash
make clean
```

## Sources
- ST RM0008 Section 14 (TIM2/3/4).
