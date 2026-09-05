# Lab 03: Hardware Triggering: TIM3 Update Event to TRGO and ADC External Trigger Routing

## Objective
Configure General-Purpose Timer 3 (TIM3) to produce periodic update events at 10 kHz, output them via the internal Trigger Output (`TRGO`), and route TRGO to trigger ADC1 regular conversions without CPU intervention.

## Prerequisites
- Lab 01 (ADC Clock & Prescaler).
- Lab 02 (ADC Calibration & Regular Sequence).
- P2-M02 (Timer Prescalers & Auto-Reload arithmetic).

## Environment
- Target: STM32F103C8T6.
- Toolchain: Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1.

## Estimated Time
- 40 minutes (MUST load).

## AI Mode
- **AI-Hint**: Questions about RM0008 Table 65 trigger multiplexing allowed.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition clean all
```

## Procedure
1. Enable TIM3 clock in `RCC->APB1ENR[TIM3EN]`.
2. Compute TIM3 Prescaler (`PSC`) and Auto-Reload (`ARR`) for 10,000 updates/sec:
   - APB1 timer input clock:
     - 72 MHz profile: $f_{\text{TIMCLK}} = 36\text{ MHz} \times 2 = 72\text{ MHz}$.
     - 64 MHz profile: $f_{\text{TIMCLK}} = 32\text{ MHz} \times 2 = 64\text{ MHz}$.
   - We target a 1 MHz counter tick rate:
     $$f_{\text{CNT}} = \frac{f_{\text{TIMCLK}}}{\text{PSC} + 1} = 1\text{ MHz} \implies \text{PSC} = \frac{f_{\text{TIMCLK}}}{10^6} - 1$$
     - At 72 MHz: $\text{PSC} = 72 - 1 = 71$.
     - At 64 MHz: $\text{PSC} = 64 - 1 = 63$.
   - We target an update period of $100\ \mu\text{s}$ (10 kHz):
     $$\text{ARR} = \frac{1\text{ MHz}}{10\text{ kHz}} - 1 = 100 - 1 = 99$$
3. Configure TIM3 Master Mode Selection (`MMS`) in `TIM3->CR2`:
   - Set `MMS[2:0] = 0b010` (Update: The update event is selected as trigger output TRGO).
4. Configure ADC1 External Trigger Multiplexing (RM0008 Section 11 Table 65):
   - Table 65 specifies:
     - `000`: TIM1_CC1
     - `001`: TIM1_CC2
     - `010`: TIM1_CC3
     - `011`: TIM2_CC2
     - `100`: **TIM3_TRGO**
     - `101`: TIM4_CC4
     - `110`: EXTI11
     - `111`: SWSTART
   - In `ADC1->CR2`:
     - Set `EXTSEL[2:0] = 0b100` (`ADC_CR2_EXTSEL_2`).
     - Set `EXTTRIG = 1` (`ADC_CR2_EXTTRIG` enables regular conversion on external trigger).
5. Pre-load shadow registers via `TIM3->EGR = TIM_EGR_UG` and clear `TIM3->SR = 0`.
6. Enable TIM3 counter: `TIM3->CR1 |= TIM_CR1_CEN`.

## Expected Observation
- At each TIM3 update event (every $100\ \mu\text{s}$), a hardware pulse is emitted on internal net `TIM3_TRGO`.
- ADC1 detects the trigger edge, transitions from Idle to Converting, samples PA0 for 55.5 cycles, and converts for 12.5 cycles.
- When conversion finishes ($T_{\text{conv}} \approx 5.67\ \mu\text{s}$), ADC1 asserts `EOC` (End Of Conversion) and generates a DMA request.

## Actual Verification Status
- **Static & Disassembly Verification**: **VERIFIED** on host cross-compiler.
- **Hardware Trigger Net**: **UNVERIFIED** (Internal chip interconnect; requires logic analyzer / DMA milestone verification).

## Questions
1. Why does Table 65 prohibit using TIM2 TRGO for ADC1 regular conversions?
2. What happens if `EXTTRIG` bit in `ADC1->CR2` is left at 0 even if `EXTSEL` is configured to `0b100`?

## Failure Modes
- Setting `EXTSEL` to `0b011` (TIM2_CC2) expecting TIM2 TRGO, which does not trigger regular conversions.
- Forgetting to enable `EXTTRIG` in `ADC1->CR2`, leaving ADC in software trigger mode (`SWSTART`).

## Debug Strategy
- Check `TIM3->CR2` bits [6:4] in GDB to confirm `MMS == 0b010`.
- Check `ADC1->CR2` bits [19:17] to confirm `EXTSEL == 0b100` and bit 20 to confirm `EXTTRIG == 1`.

## Challenge
Modify TIM3 to generate triggers at 1 kHz instead of 10 kHz by recalculating ARR. What is the new ARR value?

## Cleanup
Counter remains active to feed the DMA controller in Lab 04.

## Sources
- ST RM0008 Rev 21, Section 11.3.7 (External trigger for regular channels) & Table 65.
- ST RM0008 Rev 21, Section 14.4.2 (TIMx control register 2 MMS).
