# P2-M03 Controlled Fault Study Fixtures

This directory contains controlled, reproducible hardware-software fault fixtures representing recurring failure modes in microcontroller peripheral acquisition, ADC contracts, and DMA data paths.

Learner fault directories use **neutral identifiers** (`f1` through `f5`) to preserve diagnostic challenge and eliminate confirmation bias.

## Fault Directory Index

| Fixture ID | Observed Symptom | Execution Context | Relevant Peripherals |
|---|---|---|---|
| **`f1`** | ADC conversions exhibit severe non-linearity, high noise, and occasional missing codes | Bare-metal 72 MHz system run | RCC, ADC1 clock prescaler |
| **`f2`** | `g_adc_buffer` remains completely empty (all zeroes); PA3/PA4 markers are silent | TIM3 running, ADC1 initialized | TIM3, ADC1 trigger multiplexer |
| **`f3`** | Buffer data contains interleaved zeroes and corrupt high-byte readings; buffer fills twice as fast | TIM3 and DMA active | DMA1 Channel 1 CCR data sizing |
| **`f4`** | Initial conversions appear valid, but buffer values become unpredictably corrupted after subsequent function calls | Post-initialization runtime | SRAM stack bounds, DMA CMAR |
| **`f5`** | TIM3 counter is running and ADC indicates conversion ready, but DMA never transfers data | TIM3 running, ADC1 active | ADC1 control register, DMA request |

---

## Diagnostic Protocol

For each fault:
1. Formulate **3–5 competing hypotheses** based solely on the observed symptom.
2. Identify the specific MMIO registers or memory addresses that can prove or disprove each hypothesis.
3. Inspect the binary artifact or live target state using GDB / `readelf` / `objdump`.
4. Narrow down the root cause and implement the minimal correct change.
5. Re-run automated static regression to prove resolution.

*(Detailed root cause analysis, register proofs, and minimal diffs are maintained in `reviewer/fault_analysis.md`)*.
