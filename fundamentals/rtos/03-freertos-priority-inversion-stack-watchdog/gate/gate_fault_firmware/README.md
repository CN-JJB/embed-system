# P2-M06 Module Gate Assessment: Unfamiliar Defect Firmware

## Context
You have been handed a pre-production firmware build for an environmental sensor node on STM32F103. The node runs three tasks:
- `Task_Sensor` (Priority 3): Real-time acquisition task.
- `Task_Filter` (Priority 2): Digital filtering pipeline.
- `Task_Telemetry` (Priority 1): Telemetry formatting, stack health monitoring, and watchdog refreshing.

## Symptoms Reported from Qualification Testing
1. Under heavy filtering load, `Task_Sensor` suffers unpredictable latency spikes exceeding 25 ms before acquiring the shared communication buffer.
2. The telemetry task reports stack headroom of 48 bytes, but manual stack analysis indicates the task should have over 190 bytes remaining.
3. If an LSI clock synchronization stall occurs during boot, the device hangs permanently inside `iwdg_init()`.
4. Power-on reset telemetry frequently misdiagnoses normal boots as prior watchdog resets.

## Gate Exam Tasks
1. Identify the root cause of priority inversion on the shared buffer and restore priority inheritance.
2. Correct the stack watermark calculation in `Task_Telemetry`.
3. Harden `iwdg_init()` with bounded status register polling.
4. Ensure hardware reset flags are cleared upon boot.
