# P2-M06 Module Gate Assessment: Unfamiliar Defect Firmware

## Context
You have been handed a pre-production firmware build for an environmental sensor node on STM32F103. The node runs three tasks:
- `Task_Sensor` (Priority 3): Real-time acquisition task.
- `Task_Filter` (Priority 2): Digital filtering pipeline.
- `Task_Telemetry` (Priority 1): Telemetry formatting, stack health monitoring, and watchdog refreshing.

## Symptoms Reported from Qualification Testing
1. Scenario-provided report (**DESIGN TARGET / UNVERIFIED**): under heavy filtering load, `Task_Sensor` suffers latency spikes exceeding ~25 ms before acquiring the shared communication buffer.
2. The telemetry task reports stack headroom of 48 bytes, but manual stack analysis indicates the task should have over 190 bytes remaining.
3. If an LSI clock synchronization stall occurs during boot, the device hangs permanently inside `iwdg_init()`.
4. Power-on reset telemetry frequently misdiagnoses normal boots as prior watchdog resets.

## Gate Exam Tasks
1. Analyze the acquisition latency spikes reported for `Task_Sensor` under concurrent CPU load and correct the underlying bounded inversion mechanism.
2. Reconcile the discrepancy between measured stack usage and reported telemetry headroom in `Task_Telemetry`.
3. Audit peripheral register access in `iwdg.c` to prevent indefinite hardware hangs during clock domain synchronization.
4. Verify reset cause determination logic across consecutive system boot cycles.
5. Confirm that the patched firmware passes all checks in `reviewer/verify_gate_regression.sh`.
