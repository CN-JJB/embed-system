# Lab 06: Evidence-Driven DMA Fault Investigation and Systematic Root-Cause Analysis

## Objective
Apply the structured hypothesis-driven debugging methodology (`Symptom -> Own Description -> Hypotheses -> Evidence -> Narrow Scope -> Root Cause -> Fix -> Regression`) to diagnose a non-streaming or corrupt DMA acquisition path.

## Prerequisites
- Labs 01 through 05.
- Structured debugging methodology from Phase 1.

## Environment
- Target: STM32F103C8T6.
- Toolchain: Arm GNU Toolchain 13.3.rel1 / Ubuntu GCC 13.2.1.
- Debugger: GDB via OpenOCD / ST-Link.

## Estimated Time
- 60 minutes (MUST load).

## AI Mode
- **AI-Hint**: Learner must independently form 3–5 hypotheses and inspect registers before asking Socratic questions.

## Build
```bash
make -C fundamentals/mcu/03-adc-dma-acquisition clean all
```

## The Diagnostic Framework
When an acquisition path fails (e.g. no data in buffer, markers silent, or values corrupt):

```text
Symptom: PA3/PA4 markers produce no pulses; g_adc_buffer contains only initial zeroes.
  ├── Hypothesis 1: TIM3 is not generating TRGO update pulses (counter stopped or MMS != 010).
  ├── Hypothesis 2: ADC1 external trigger is disabled or misrouted (EXTSEL != 100 or EXTTRIG == 0).
  ├── Hypothesis 3: ADC1 DMA request generation is disabled (ADC_CR2_DMA == 0).
  ├── Hypothesis 4: DMA1 Channel 1 is not enabled or clock is un-gated (DMA_CCR_EN == 0 or AHBENR == 0).
  └── Hypothesis 5: DMA1 Channel 1 NVIC interrupt is not enabled (NVIC_ISER == 0).
```

## Diagnostic Procedure
1. Step 1 — Check DMA Counter (`CNDTR`):
   ```gdb
   (gdb) p/d DMA1_Channel1->CNDTR
   ```
   - **Case A**: `CNDTR` is stuck at 128.
     - Scope narrowed to **Trigger & Request Generation** (DMA is ready, but no requests arrive).
     - Check: `ADC1->CR2[DMA]`, `ADC1->CR2[EXTTRIG]`, `ADC1->CR2[EXTSEL]`, `TIM3->CR1[CEN]`, `TIM3->CR2[MMS]`.
   - **Case B**: `CNDTR` is actively decrementing, but no interrupts fire.
     - Scope narrowed to **Interrupt & NVIC Path**.
     - Check: `DMA1_Channel1->CCR[HTIE/TCIE]`, `NVIC->ISER[0]`, priority masking.
   - **Case C**: `CNDTR` decrements, interrupts fire, but buffer data is constant or garbage.
     - Scope narrowed to **Analog & Clock Configuration**.
     - Check: `RCC->CFGR[ADCPRE]`, PA0 analog mode in `GPIOA->CRL`, ADC calibration flags.
2. Step 2 — Check ADC Status & Trigger Configuration:
   ```gdb
   (gdb) p/x ADC1->CR2
   # Verify EXTSEL (bits 19:17 == 0b100), EXTTRIG (bit 20 == 1), DMA (bit 8 == 1), ADON (bit 0 == 1)
   (gdb) p/x TIM3->CR2
   # Verify MMS (bits 6:4 == 0b010)
   ```
3. Step 3 — Formulate Minimal Fix:
   - Identify the single defective bit or register.
   - Apply fix, rebuild, and execute regression test.

## Actual Verification Status
- **Methodology & Static Register Checks**: **VERIFIED** on host.
- **Interactive Live Fault Debugging**: **UNVERIFIED** (Requires target hardware).

## Questions
1. If `CNDTR` remains at 128 and `ADC1->SR & ADC_SR_EOC` is set, what does this tell you about the ADC vs DMA configuration?
2. If `DMA1->ISR & DMA_ISR_TEIF1` is asserted, what physical bus or memory fault has occurred?

## Failure Modes
- Jumping to code rewrites without reading `CNDTR` or `DMA1->ISR`.
- Assuming hardware failure when a single software bit (`ADC_CR2_DMA`) was omitted.

## Debug Strategy
- Always read `CNDTR` first. It immediately bisects the problem space into (1) trigger/request generation vs (2) transfer/interrupt servicing.

## Sources
- ST RM0008 Rev 21, Section 11 & Section 13.
