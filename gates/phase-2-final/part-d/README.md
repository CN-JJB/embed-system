# Part D: Concurrency & HW/SW Debugging

> **Time Budget:** 65 minutes  
> **Weight:** 25 points (Floor: 70% / $\ge 17.5$ points — Highest Mastery Bar)  
> **Mode:** AI-Free (Strict)  

---

## 1. System Context & Observed Symptom

You are assigned to investigate an intermittent system freeze and unexpected hardware reset in an STM32F103C8T6 multi-task sensor telemetry node running FreeRTOS V11.3.0:
* **Task_Telemetry (Priority 2):** Periodically samples sensor status, formats outbound telemetry packets every 50 ms, and maintains system watchdog refresh.
* **Task_Storage (Priority 1):** Periodically logs sensor status and diagnostic status to local memory every 100 ms.
* Both tasks interact with shared system resources protected by FreeRTOS synchronization primitives.

The firmware builds cleanly with zero compiler warnings (`-Wall -Wextra -Werror`).
However, during concurrent stress testing:
1. The sensor node intermittently freezes during execution, halting all telemetry transmission and logging.
2. Shortly following the freeze, the MCU abruptly reboots.
3. Post-reset register examination reveals an independent hardware watchdog fault flag asserted in the reset status register (`RCC->CSR & RCC_CSR_IWDGRSTF != 0`).

---

## 2. Deliverables & Investigation Tasks

1. **Independent 8-Step Diagnostic Chain:**
   In Section 7 of `../SUBMISSION_TEMPLATE.md`, execute the full diagnostic protocol:
   - Step 1: Symptom.
   - Step 2: Own Description.
   - Step 3: 3–5 Hypotheses (formulated before modifying code).
   - Step 4: Targeted Experiment.
   - Step 5: Multi-Channel Evidence.
   - Step 6: Narrow Scope.
   - Step 7: Root Cause.
   - Step 8: Fix & Regression.
2. **Two Independent Evidence Channels:**
   Collect and interpret evidence across at least two distinct channels:
   - **Channel 1 (RTOS Task State & Synchronization Inspection):** Inspect `fixtures/task_state_dump.txt` (labeled `SCRIPTED / SEEDED ASSESSMENT FIXTURE — NOT LIVE HARDWARE EVIDENCE`). Examine task scheduling states, queue wait lists, and resource ownership.
   - **Channel 2 (Hardware Reset Flag & Timing Markers):** Inspect `fixtures/watchdog_reset_trace.txt`. Trace task execution windows, timing relationships, and the `RCC_CSR_IWDGRSTF` reset trigger.
3. **Root Cause Analysis:**
   Identify the architectural interaction between task synchronization, scheduling, and watchdog refresh that causes the system freeze.
4. **Principled Minimal Correction:**
   Modify `src/node_app.c` to resolve the concurrency hazard and restore periodic watchdog refresh operation.
   *(Note: Inserting arbitrary `vTaskDelay()` calls, disabling the watchdog, or extending watchdog timeouts without architectural justification is rejected).*
5. **Verify Artifact & Build Integrity:**
   Rebuild the firmware and run `make check` to confirm valid compilation, symbol exports, and artifact generation. (Note: `make check` validates generic artifact integrity; technical evaluation of the concurrency safety contract is performed by reviewer-isolated testing).

---

## 3. Investigation Protocol

1. Build the seeded fixture:
   ```bash
   make clean && make
   ```
2. Run `make check` to verify initial build integrity:
   ```bash
   make check
   ```
3. Inspect `fixtures/task_state_dump.txt` and `fixtures/watchdog_reset_trace.txt`.
4. Document your 8-step diagnostic report in Section 7 of `../SUBMISSION_TEMPLATE.md`.
5. Apply the minimal fix in `src/node_app.c` and verify build integrity with `make check`.
