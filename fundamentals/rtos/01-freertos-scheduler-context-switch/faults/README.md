# P2-M04 Controlled Fault Study Fixtures

This directory contains controlled, reproducible hardware-software fault fixtures representing recurring failure modes in Cortex-M3 FreeRTOS kernel bring-up, task context switching, exception vectors, and heap configuration.

Learner fault directories use **neutral identifiers** (`f1` through `f5`) to preserve diagnostic challenge and eliminate confirmation bias.

## Fault Directory Index

| Fixture ID | Scenario-Reported Symptom | System Context |
|---|---|---|
| **`f1`** | Target core hangs in `Default_Handler` immediately upon calling `vTaskStartScheduler()` | Scheduler initialization |
| **`f2`** | Periodic delays and timer intervals run approximately 12.5% slower than requested | Internal HSI clock fallback |
| **`f3`** | Target enters `HardFault_Handler` shortly after worker task begins executing local calculations | Multi-task runtime |
| **`f4`** | Target immediately traps into a Fault handler with `INVSTATE` upon first task launch | Scheduler dispatch |
| **`f5`** | Target traps into `vApplicationMallocFailedHook` during task creation before scheduler starts | System startup |

---

## Diagnostic Protocol

For each fault:
1. Formulate **3–5 competing hypotheses** based solely on the scenario-reported symptom.
2. Identify the specific registers, vector table slots, or memory structures that can prove or disprove each hypothesis.
3. Inspect the binary artifact or simulated/target state using GDB / `arm-none-eabi-readelf` / `arm-none-eabi-objdump`.
4. Narrow down the root cause and implement the minimal correct change.
5. Re-run automated static regression to prove resolution.

*(Detailed root cause analysis, register proofs, and minimal diffs are maintained in `reviewer/fault_analysis.md`)*.
