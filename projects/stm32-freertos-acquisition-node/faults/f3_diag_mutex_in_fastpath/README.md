# Fault Case F3: Diagnostic Mutex Contention in Acquisition Fast Path

## Symptom
Logic analyzer captures on PA1 (DMA / Process marker) show sporadic, severe timing jitter: instead of processing within ~15 microseconds of DMA completion, `Task_Process` is delayed by 20 to 50 milliseconds. Telemetry drops accumulate rapidly.

## Diagnostic Steps
1. Trace the execution dependencies of `Task_Process`:
   - Does `Task_Process` attempt to acquire an application mutex (e.g. `xSemaphoreTake(g_diag_resource)`) during normal sample processing?
2. Analyze the priority inversion / blocking hazard:
   - If a lower-priority task (`Task_Health` or `Task_Compute`) holds that mutex during an extended workload, `Task_Process` blocks.
   - The normal acquisition fast path must remain completely queue-driven and decoupled from mutual exclusion locks.

## Resolution Contract
Remove all application mutex acquisitions from the normal DMA $\to$ `Task_Process` $\to$ `Task_Comm` pipeline. Use FreeRTOS message copying via queues for cross-task data handoff.
