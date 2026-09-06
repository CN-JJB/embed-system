# Reviewer Reference: Fault Campaign Solutions and Root-Cause Analysis

> **RESTRICTED REVIEWER / INSTRUCTOR MATERIAL**
>
> This document contains canonical root causes, candidate hypotheses, discriminative tests, and reference resolutions for the P2-M07 Integrated Fault Campaign.
> Learner-facing documentation must remain symptom-first without leaking these explanations.

---

## Fault Scenario 1: Missing Telemetry Sequence Numbers (`f1_missing_telemetry_sequence`)

### 1. Observable Symptom
Under heavy telemetry logging load or slow serial transmission, external monitors observe non-monotonic sequence jumps in received frames:
```text
[TELEM] seq=142 min=2040 max=2055 avg=2048 rms=2048 drops=0
[TELEM] seq=146 min=2041 max=2054 avg=2048 rms=2048 drops=0
```
Frames 143, 144, and 145 never arrived, yet `drops=0` is reported.

### 2. Candidate Hypotheses & Discriminative Evidence
- **Hypothesis 1 (USART TXE Overwrite)**: USART DR is overwritten before TXE is set, clobbering characters.
  - *Refutation*: Frame format is intact and well-formed; full lines are missing rather than individual garbled bytes.
- **Hypothesis 2 (DMA Double-Buffer Index Drift)**: DMA wraps incorrectly and overwrites active buffer without generating HT/TC flags.
  - *Refutation*: Hardware CNDTR and ISR flags increment normally; `g_dma_ht_count` and `g_dma_tc_count` continue advancing.
- **Hypothesis 3 (Queue Saturation with Unchecked Return Code)**: `xAcqQueue` is full because `Task_Process` has not finished prior batch. `xQueueSendFromISR()` returns `errQUEUE_FULL`, but the ISR ignores the return value and fails to increment `g_acq_drops`.
  - *Verification*: GDB breakpoint on `DMA1_Channel1_IRQHandler` reveals `xResult == errQUEUE_FULL` while `g_acq_drops` remains 0.

### 3. Root Cause
In `src/dma.c`, `xQueueSendFromISR` was called without evaluating whether `xResult == pdPASS`. The global sequence number was incremented unconditionally before submission, but when the queue was saturated, the message was silently dropped without incrementing `g_acq_drops`.

### 4. Canonical Fix
```c
BaseType_t xResult = xQueueSendFromISR(xAcqQueue, &msg, &xHigherPriorityTaskWoken);
if (xResult == pdPASS) {
    g_dma_ht_count++;
    g_acq_transfers++;
} else {
    g_acq_drops++;
}
```

---

## Fault Scenario 2: Frozen Sensor Input Produces Silent Stall (`f2_frozen_sensor_no_reboot`)

### 1. Observable Symptom
A hardware fault stalls the ADC trigger (TIM3 stops generating TRGO pulses). Telemetry stream ceases on USART1, and PA1 stops pulsing. However, the MCU never triggers a hardware watchdog reset and remains hung indefinitely in a deadlocked state.

### 2. Candidate Hypotheses & Discriminative Evidence
- **Hypothesis 1 (IWDG Peripheral Inactive)**: Watchdog was never initialized or LSI clock failed.
  - *Refutation*: Reading `IWDG->SR` and `RCC->CSR` confirms LSI is running and IWDG key was activated.
- **Hypothesis 2 (Task Starvation)**: `Task_Health` is starved by higher-priority runaway tasks.
  - *Refutation*: If `Task_Health` were starved, it would NOT refresh the watchdog, and the MCU WOULD reboot. The symptom is that the MCU DOES NOT reboot.
- **Hypothesis 3 (Unconditional Watchdog Refresh Policy)**: `Task_Health` calls `iwdg_refresh()` periodically without asserting that data acquisition is progressing.
  - *Verification*: Code inspection of `prvTaskHealth()` shows `iwdg_refresh()` is called unconditionally at the bottom of the loop, completely decoupled from `progress_ok`.

### 3. Root Cause
In `src/node_app.c`, `prvTaskHealth()` refreshed the Independent Watchdog regardless of whether any acquisition milestones occurred. The watchdog was turned into a simple "RTOS scheduler alive" heartbeat rather than an end-to-end system health supervisor.

### 4. Canonical Fix
```c
/* Audit 1: Acquisition progress check */
bool progress_ok = (g_acq_transfers > s_prev_transfers);
s_prev_transfers = g_acq_transfers;

/* Audit 2: Stack watermark audit (>= 32 words / 128 bytes) */
bool stack_ok = (wm_process >= 128 && wm_comm >= 128 &&
                 wm_compute >= 128 && wm_health >= 128);

/* Audit 3: Steady-state heap health check */
bool heap_ok = (free_heap == g_steady_free_heap && min_ever_heap >= g_steady_min_ever_heap);

/* Health-gated IWDG refresh policy: only refresh if all audits succeed */
if (progress_ok && stack_ok && heap_ok) {
    iwdg_refresh();
}
```

---

## Fault Scenario 3: Sporadic Processing Latency Jitter (`f3_sporadic_latency_jitter`)

### 1. Observable Symptom
Logic analyzer captures on PA1 (DMA / Process marker) show sporadic, severe timing jitter: instead of processing within ~15 microseconds of DMA completion, `Task_Process` is delayed by 20 to 50 milliseconds. Telemetry drops accumulate rapidly.

### 2. Candidate Hypotheses & Discriminative Evidence
- **Hypothesis 1 (ISR Latency / Masking)**: Interrupts are masked for 20-50 ms via `taskENTER_CRITICAL()`.
  - *Refutation*: SysTick and DMA interrupts continue firing at 1 kHz; PA1 shows DMA milestones continuing regularly.
- **Hypothesis 2 (Floating-point / Compute Overload)**: `isqrt_u32` or variance calculation in `Task_Process` is computationally too expensive.
  - *Refutation*: In normal cycles, execution time is <15 us. Severe jitter occurs only intermittently.
- **Hypothesis 3 (Mutual Exclusion Contention on Fast Path)**: `Task_Process` takes a shared mutex (e.g. `g_diag_resource`) inside its normal per-batch processing loop. When lower-priority tasks hold that mutex during an extended workload, `Task_Process` is blocked.
  - *Verification*: Tracing `prvTaskProcess` shows an `xSemaphoreTake(g_diag_resource, portMAX_DELAY)` call inside the main `xQueueReceive` loop.

### 3. Root Cause
An application mutual exclusion lock was inserted directly into the time-critical acquisition fast path. Real-time acquisition pipelines must remain completely lock-free and asynchronous, relying solely on message passing queues with copy semantics.

### 4. Canonical Fix
Ensure the sample-processing loop in `prvTaskProcess()` contains zero mutex or semaphore calls. The diagnostic synchronization object `g_diag_resource` is strictly reserved for the isolated diagnostic branch triggered prior to starting acquisition.
