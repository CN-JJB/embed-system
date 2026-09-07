# Part D: Concurrency, Priority Inversion & HW/SW Debugging

> **Time Budget:** 65 minutes  
> **Weight:** 25 points (Floor: 70% / $\ge 17.5$ points — Highest Mastery Bar)  
> **Mode:** AI-Free (Strict)  

---

## 1. System Context & Observed Symptom

You are assigned to investigate an intermittent system freeze and unexpected hardware reset in an STM32F103C8T6 multi-task sensor node:
* **Task_Telemetry (Priority 3, High):** Transmits high-priority sensor frames every 50 ms. Acquires a shared resource lock (`xSharedResourceLock`) to format outbound telemetry.
* **Task_Compute (Priority 2, Medium):** Periodically runs compute-intensive signal processing algorithms.
* **Task_Storage (Priority 1, Low):** Logs diagnostic status using `xSharedResourceLock`, audits task stack watermarks (`uxTaskGetStackHighWaterMark`), and refreshes the hardware independent watchdog (`IWDG`).

The firmware builds cleanly with zero compiler warnings (`-Wall -Wextra -Werror`).
However, during stress testing under concurrent workloads:
1. `Task_Telemetry` (Priority 3) experiences severe, unbounded latency jitter, frequently missing its 50 ms deadline.
2. Shortly after the latency spike, the MCU abruptly resets.
3. Upon reboot, the Reset and Clock Control status register indicates a watchdog fault (`RCC->CSR & RCC_CSR_IWDGRSTF != 0`).

---

## 2. Deliverables & Investigation Tasks

1. **Independent 8-Step Diagnostic Chain:**
   In Section 7 of `../SUBMISSION_TEMPLATE.md`, execute the full diagnostic protocol:
   - Step 1: Symptom.
   - Step 2: Own Description.
   - Step 3: 3–5 Hypotheses (formulated before making code edits).
   - Step 4: Targeted Experiment.
   - Step 5: Multi-Channel Evidence.
   - Step 6: Narrow Scope.
   - Step 7: Root Cause.
   - Step 8: Fix & Regression.
2. **Two Independent Evidence Channels:**
   Collect and interpret evidence across at least two distinct channels:
   - **Channel 1 (RTOS Task State / Priority Audit):** Inspect `fixtures/task_state_dump.txt` (labeled `SEEDED FIXTURE / ASSESSMENT INPUT`). Examine task scheduling states, queue wait lists, and priority inheritance status.
   - **Channel 2 (Hardware Reset Flag & Timing Markers):** Inspect `fixtures/watchdog_reset_trace.txt`. Trace the relationship between `Task_Compute` execution, `Task_Storage` starvation, and the `RCC_CSR_IWDGRSTF` reset trigger.
3. **Root Cause Analysis:**
   Identify how the choice of synchronization primitive interacted with task priorities to cause unbounded priority inversion and IWDG starvation.
4. **Principled Minimal Correction:**
   Modify `src/node_app.c` to enforce proper mutual exclusion with priority inheritance and ensure watchdog refresh reliability.
   *(Note: Inserting arbitrary `vTaskDelay()` calls, disabling the watchdog, or extending watchdog timeouts without architectural justification is rejected).*
5. **Regression Verification:**
   Run `make check` to prove that priority inheritance is active and the system satisfies all concurrency safety contracts.

---

## 3. Investigation Protocol

1. Build the seeded fixture:
   ```bash
   make clean && make
   ```
2. Run `make check` to observe the automated concurrency check failure:
   ```bash
   make check
   ```
3. Inspect `fixtures/task_state_dump.txt` and `fixtures/watchdog_reset_trace.txt`.
4. Document your 8-step diagnostic report in Section 7 of `../SUBMISSION_TEMPLATE.md`.
5. Apply the minimal fix in `src/node_app.c` and verify with `make check`.
