# P2-M04 Challenge Solution: Real-Time Dual-Task Scheduler & Telemetry Monitor

## Design Overview
The P2-M04 challenge requires implementing a dual-task real-time monitoring system on FreeRTOS V11.3.0 with strict temporal and memory bounds:
1. **Telemetry Task**: Higher priority (Priority 2), executing every 50 ms (`TELEMETRY_PERIOD_MS`). Tracks high-water mark of both tasks via `uxTaskGetStackHighWaterMark()`.
2. **Worker Task**: Lower priority (Priority 1), executing every 100 ms (`WORKER_PERIOD_MS`). Simulates background processing.
3. **Thread Safety**: Shared telemetry state (`g_telemetry`) is accessed across task boundaries and thread mode via `taskENTER_CRITICAL()` and `taskEXIT_CRITICAL()`.
4. **Absolute Periodic Timing**: Must use `vTaskDelayUntil(&xLastWakeTime, xFrequency)` rather than relative `vTaskDelay(xFrequency)` to eliminate cumulative phase drift caused by scheduling latency and task execution time.

## Architectural Deep Dive

### 1. Eliminating Phase Drift via `vTaskDelayUntil()`
With relative `vTaskDelay(T)`:
$$\text{Next Wake Time} = \text{Current Tick} + T$$
If the task takes $\Delta t$ to execute, or if it is delayed by $\delta$ due to a higher-priority task preempting it, the period becomes $T + \Delta t + \delta$. Over many iterations, this error accumulates monotonically, corrupting deterministic sampling rates.

With `vTaskDelayUntil(&xLastWakeTime, T)`:
$$\text{Next Wake Time} = \text{xLastWakeTime} + T$$
FreeRTOS calculates the wake tick relative to the *scheduled* wake tick of the previous cycle. Any execution latency or temporary preemption is absorbed without long-term drift.

### 2. High-Water Mark Stack Headroom
`uxTaskGetStackHighWaterMark(TaskHandle_t xTask)` checks the task stack memory for the watermark fill pattern (`0xa5` in FreeRTOS). It returns the minimum number of words (`uint32_t`) that have remained untouched since the task was created:
$$\text{Unused Stack Bytes} = \text{uxTaskGetStackHighWaterMark} \times 4$$
If this value approaches zero, stack overflow is imminent and stack size must be increased.

### 3. Critical Section Protection
`taskENTER_CRITICAL()` masks interrupts up to `configMAX_SYSCALL_INTERRUPT_PRIORITY` by setting `BASEPRI = 0x50` on STM32F103. This ensures that while `g_telemetry` is being copied or updated, no context switch or interrupt can interleave, preventing torn 32-bit word reads or inconsistent struct snapshots.

## Verification & Mutation Regression
The reference solution in `reviewer/challenge-reference/app_tasks.c` passes all static and compilation tests.
The validator rejects all 8 negative mutations in `reviewer/mutations/`:
- `m1` (relative `vTaskDelay`)
- `m2` (priority inversion)
- `m3` (undersized stack)
- `m4` (unprotected telemetry read/write)
- `m5` (prohibited libc `malloc`)
- `m6` (unchecked `xTaskCreate` return codes)
- `m7` (incorrect telemetry period)
- `m8` (missing stack watermark tracking)
