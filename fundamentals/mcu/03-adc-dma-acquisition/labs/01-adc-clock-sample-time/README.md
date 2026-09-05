# Lab 01: ADC Clock Prescaler, Sample Timing, and Source Impedance Math

## Objective
Compute, configure, and verify the STM32F103 ADC clock prescaler (`ADCPRE`), calculate channel 0 (PA0) sample time and total conversion time, and evaluate source impedance ($R_{\text{AIN}}$) compatibility according to ST RM0008 and DS5319.

## Prerequisites
- P2-M02 Clock tree configuration and APB bus understanding.
- Understanding of voltage dividers and Thevenin equivalent resistance.

## Environment
- Target: STM32F103C8T6 (Arm Cortex-M3, 64 KB Flash, 20 KB SRAM).
- Toolchain: Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1 cross-compiler.
- Signal source: 10 kΩ potentiometer wired between 3.3V and GND with wiper connected to PA0.

## Estimated Time
- 40 minutes (MUST load).

## AI Mode
- **AI-Hint**: Socratic guidance permitted on register bitfields and formula derivation. Direct code generation prohibited.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition clean all
```

## Procedure
1. Inspect `RCC->CFGR` bits [15:14] (`ADCPRE`).
   - The reset default is `0b00` (PCLK2 divided by 2).
   - Under the canonical 72 MHz system profile ($f_{\text{PCLK2}} = 72\text{ MHz}$), divide-by-2 produces $36\text{ MHz}$, which severely violates the datasheet maximum rating $f_{\text{ADC}} \le 14\text{ MHz}$!
   - Configure `ADCPRE = 0b10` (Divide by 6):
     $$f_{\text{ADCCLK}} = \frac{72\text{ MHz}}{6} = 12\text{ MHz} \le 14\text{ MHz}$$
   - Under the 64 MHz HSI fallback profile ($f_{\text{PCLK2}} = 64\text{ MHz}$), divide-by-6 yields:
     $$f_{\text{ADCCLK}} = \frac{64\text{ MHz}}{6} \approx 10.67\text{ MHz} \le 14\text{ MHz}$$
2. Configure PA0 (`ADC1_IN0`) sample time in `ADC1->SMPR2[SMP0[2:0]]`:
   - Set `SMP0 = 0b101` (55.5 ADC clock cycles).
3. Compute total conversion time $T_{\text{conv}}$:
   $$T_{\text{conv}} = T_{\text{sample}} + 12.5\text{ cycles} = 55.5 + 12.5 = 68.0\text{ ADC clock cycles}$$
   At $f_{\text{ADCCLK}} = 12\text{ MHz}$ ($1\text{ cycle} \approx 83.33\text{ ns}$):
   $$T_{\text{conv}} = 68 \times 83.333\text{ ns} \approx 5.667\ \mu\text{s}$$
   This conversion duration easily fits within the 10 kHz sample period ($T_{\text{sample\_period}} = 100\ \mu\text{s}$).
4. Calculate maximum allowable source impedance $R_{\text{AIN}}$:
   - A 10 kΩ potentiometer has maximum Thevenin output impedance at midscale:
     $$R_{\text{th}} = \frac{5\text{ k}\Omega \times 5\text{ k}\Omega}{5\text{ k}\Omega + 5\text{ k}\Omega} = 2.5\text{ k}\Omega \ll 10\text{ k}\Omega$$
   - According to DS5319 Table 49, at $f_{\text{ADC}} = 14\text{ MHz}$, 55.5 cycles allows $R_{\text{AIN}}$ up to $31.4\text{ k}\Omega$ (and up to $\approx 50\text{ k}\Omega$ at 12 MHz), easily accommodating both midscale and unbuffered high-impedance sensors.

## Expected Observation
- Statically verified register encoding in `adc_init()`:
  - `RCC->CFGR[15:14] == 0b10` (`RCC_CFGR_ADCPRE_DIV6`).
  - `ADC1->SMPR2[2:0] == 0b101` (55.5 cycles).
- Live target inspection in GDB (if hardware present):
  ```gdb
  p/x (RCC->CFGR >> 14) & 0x3
  # Expected: 0x2
  p/x ADC1->SMPR2 & 0x7
  # Expected: 0x5
  ```

## Actual Verification Status
- **Static & Build Verification**: **VERIFIED** on host cross-compiler.
- **Live GDB & Hardware Measurement**: **UNVERIFIED** (Headless build environment; no physical probe attached).

## Questions
1. Why does setting `ADCPRE = /2` on a 72 MHz STM32F103 cause ADC conversion errors or hardware damage?
2. If a sensor has a Thevenin output impedance of 40 kΩ, can you use `SMP0 = 0b000` (1.5 cycles)? What would happen to the sampled voltage?

## Failure Modes
- Setting `ADCPRE` to `/4` at 72 MHz yields 18 MHz, violating the 14 MHz electrical specification.
- Confusing a potentiometer's end-to-end resistance (10 kΩ) with its worst-case Thevenin resistance (2.5 kΩ).

## Debug Strategy
- Read `RCC->CFGR` and verify bits [15:14].
- Calculate $f_{\text{ADCCLK}} = f_{\text{PCLK2}} / \text{prescaler}$ explicitly before initializing the peripheral.

## Challenge
Write a small C helper function that takes `SystemCoreClock` and automatically chooses the smallest valid `ADCPRE` division factor such that $f_{\text{ADCCLK}} \le 14\text{ MHz}$.

## Cleanup
Leave `ADCPRE` set to `0b10` (/6) for subsequent labs.

## Sources
- ST RM0008 Rev 21, Section 11.3.11 (Sample time and $R_{\text{AIN}}$).
- ST DS5319 Rev 20, Section 5.3.18 (ADC characteristics and Table 49).
