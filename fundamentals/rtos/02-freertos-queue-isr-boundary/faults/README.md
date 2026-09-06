# P2-M05 Controlled Diagnostic Fault Catalog

> **MANDATORY LEARNER INSTRUCTION**:  
> In accordance with course standards, learner-facing fault fixtures present **symptoms and objectives only**.  
> The underlying root causes, hypotheses, and minimal fixes are located exclusively under reviewer-isolated directories (`reviewer/fault_analysis.md`).

---

## Catalog of Diagnostic Fixtures

| Fixture ID | Scenario-Provided Symptom (Not author-captured evidence) | Diagnostic Focus | Build Command |
| :--- | :--- | :--- | :--- |
| **`f1`** | System halts inside `vAssertCalled()` as soon as the first timer interrupt occurs | NVIC interrupt priority vs `configMAX_SYSCALL` threshold | `make -C faults/f1 clean all` |
| **`f2`** | Kernel traps in assertion during scheduler startup or first ISR invocation | Cortex-M3 priority grouping configuration (`SCB->AIRCR`) | `make -C faults/f2 clean all` |
| **`f3`** | Core traps inside `vPortEnterCritical()` assertion upon timer interrupt execution | Context execution rules: Task APIs vs `FromISR` APIs | `make -C faults/f3 clean all` |
| **`f4`** | Consumer task exhibits severe execution latency and high jitter (~1 ms delays) | Deferred context switch triggering (`portYIELD_FROM_ISR`) | `make -C faults/f4 clean all` |
| **`f5`** | Telemetry logs report missing packets and corrupted sequence numbers | Queue-full return handling and queue item size contracts | `make -C faults/f5 clean all` |
