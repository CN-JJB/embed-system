# Lab 02 — Clock Tree Profiles and Flash Wait States

## Objective
Configure and verify the STM32F103 clock tree:
1. 72 MHz Primary Profile via 8 MHz HSE crystal.
2. 64 MHz Fallback Profile via internal 8 MHz HSI RC oscillator.
Verify Flash memory latency wait states and APB prescalers.

## Prerequisites
- Lab 01 completed.
- P2-M02 README Section 2.3 (Clock Tree & Timer Doubling Rule).

## Environment
- Host: Linux / WSL2 with GCC toolchain.
- Target (Optional): STM32F103C8T6 + ST-Link V2.

## Estimated Time
40 minutes.

## AI Mode
**AI-Free**.

## Build
```bash
make clean && make
```

## Procedure
1. Inspect `src/clock.c`:
   - Identify where `FLASH->ACR` is written. Why must latency be set to 2 wait states before switching SYSCLK?
   - Identify the APB1 prescaler setting (`RCC_CFGR_PPRE1_DIV2`). Why is `/2` mandatory for 72 MHz?
2. Run GDB to verify register values:
   ```gdb
   # Connect to target or simulator
   print /x RCC->CFGR
   print /x FLASH->ACR
   ```
3. Test Fallback Profile:
   In `src/main.c`, change `clock_init(CLOCK_PROFILE_72MHZ_HSE)` to `clock_init(CLOCK_PROFILE_64MHZ_HSI)`.
   Rebuild and verify in GDB that `RCC->CFGR` reflects `SWS_PLL` with HSI/2 source.

## Expected Observation
- In 72 MHz profile: `FLASH->ACR` contains `0x32` (Prefetch enable + 2 latency wait states).
- `RCC->CFGR` bits [10:8] (`PPRE1`) equal `0b100` (divide by 2).
- Timer clock doubling rule ensures APB1 timer clock is 72 MHz, NOT 36 MHz.

## Actual Verification Status
**PARTIALLY VERIFIED**. Toolchain build and clock arithmetic are **VERIFIED** on host by `verify_m02.sh`. Live target register readout via GDB is **EXPECTED / ILLUSTRATIVE — TARGET RUN UNVERIFIED**.

## Questions
1. What occurs if `FLASH->ACR` latency is left at 0 wait states and SYSCLK is switched to 72 MHz? (Hint: CPU attempts to fetch instructions faster than Flash access time).
2. Why is the APB1 maximum frequency 36 MHz while APB2 can run at 72 MHz?

## Failure Modes
- Target lockup on clock switch: Failed to enable Flash wait states before PLL switch.
- Timer running at half expected speed: Software assumed timer clock was PCLK1 (36 MHz) instead of 72 MHz.

## Debug Strategy
Read `RCC->CR` to verify oscillator ready flags (`HSERDY`, `PLLRDY`) and `RCC->CFGR` bits [3:2] (`SWS`) to confirm active system clock source.

## Challenge
Modify the clock configuration to use HSI directly without PLL (8 MHz SYSCLK). Recalculate APB prescalers, Flash wait states (0 WS), and timer prescalers to maintain a 1 kHz update rate.

## Cleanup
```bash
make clean
```

## Sources
- ST RM0008 Section 3.3.3 (Flash memory read interface) and Section 6.2 (Clocks).
