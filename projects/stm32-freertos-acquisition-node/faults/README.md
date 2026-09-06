# Integrated Fault Campaign: STM32 FreeRTOS Acquisition Node

This directory contains three diagnostic-neutral fault scenarios designed to test systemic debugging and root-cause isolation in an integrated embedded RTOS environment.

## Fault Scenarios Overview

| Scenario | Subsystem | Manifested Symptom | Root Cause Category |
|---|---|---|---|
| [`f1_backpressure_drop`](./f1_backpressure_drop/) | DMA / ISR / Queue | Telemetry sequence gaps, lost acquisition batches | Queue saturation & unhandled backpressure drop |
| [`f2_watchdog_unconditional`](./f2_watchdog_unconditional/) | Health / IWDG | Node hangs indefinitely without watchdog recovery when sensor freezes | Unconditional watchdog refresh bypassing health audit gate |
| [`f3_diag_mutex_in_fastpath`](./f3_diag_mutex_in_fastpath/) | Pipeline / Concurrency | Severe acquisition jitter, high latency, missed DMA milestones | Mutex lock contention injected into time-critical fast path |

---

## Pedagogical Guidelines

1. **Observe before guessing**: Use the USART telemetry stream and GPIO instrumentation markers (PA1–PA4) to identify phase shifts and rate mismatches.
2. **Distinguish symptom from cause**: An overrun or watchdog failure is often caused by an architectural violation upstream (e.g. blocking inside a high-priority path or unconditional refresh).
3. **Verify under isolation**: Apply patches individually and verify using the project verification harness `scripts/verify_project.sh`.
