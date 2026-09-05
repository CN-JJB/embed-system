# P2-M03 Controlled Fault Study Fixtures

This directory contains controlled, reproducible hardware-software fault fixtures representing recurring failure modes in microcontroller peripheral acquisition, ADC contracts, and DMA data paths.

Learner fault directories use **neutral identifiers** (`f1` through `f5`) to preserve diagnostic challenge and eliminate confirmation bias.

## Fault Directory Index

| Fixture ID | Scenario-Reported Symptom | System Context | Investigation Domain |
|---|---|---|---|
| **`f1`** | Sampled ADC conversion values appear noisy and unstable under 72 MHz clock | Bare-metal 72 MHz system run | Analog subsystem clocking |
| **`f2`** | Destination buffer remains unpopulated (all zeroes); no transfer interrupts fire | TIM3 running, ADC1 initialized | Trigger routing & sequencing |
| **`f3`** | Destination buffer values appear byte-corrupted and misaligned when read as 16-bit items | TIM3 and DMA active | Transfer configuration & memory layout |
| **`f4`** | Initial acquisition starts, but memory corruption or crashes occur after init function exits | Post-initialization runtime | Memory lifetime & storage duration |
| **`f5`** | Timer triggers run and ADC indicates conversions, but DMA transfer count does not decrement | TIM3 running, ADC1 active | Peripheral handshake & DMA signaling |

---

## Diagnostic Protocol

For each fault:
1. Formulate **3–5 competing hypotheses** based solely on the observed symptom.
2. Identify the specific MMIO registers or memory addresses that can prove or disprove each hypothesis.
3. Inspect the binary artifact or live target state using GDB / `readelf` / `objdump`.
4. Narrow down the root cause and implement the minimal correct change.
5. Re-run automated static regression to prove resolution.

*(Detailed root cause analysis, register proofs, and minimal diffs are maintained in `reviewer/fault_analysis.md`)*.
