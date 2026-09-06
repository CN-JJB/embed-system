# P2-M06 Reproducible Fault Scenarios

This directory contains five reproducible fault fixtures demonstrating common concurrency, stack memory, and watchdog failure modes in FreeRTOS applications on STM32F103:

- **`f1`**: Binary semaphore used for mutual exclusion, leading to priority inversion and latency spikes under medium-priority interference.
- **`f2`**: Medium task infinite loop / unconstrained execution, starving lower-priority tasks and triggering IWDG watchdog reset.
- **`f3`**: Using `vTaskDelay()` inside a critical section, voluntarily yielding the CPU while holding a shared mutex and defeating priority inheritance.
- **`f4`**: Task stack overflow caused by undersized stack buffer and deep nested allocation, triggering `vApplicationStackOverflowHook()`.
- **`f5`**: Watchdog refreshed from an unmonitored task / timer, masking complete system deadlock.

Each fixture contains:
- `README.md`: Symptom-first description of observed behavior.
- `Makefile`: Self-contained build recipe producing a diagnostic ELF binary.
- Defective source variant reproducing the exact failure mode.
