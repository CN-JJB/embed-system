# Module Gate: Real-Time Scheduler HardFault & Preemption Priority Defect

## Target Description
A mission-critical flight telemetry firmware module using FreeRTOS V11.3.0 on STM32F103 was submitted for release. In static testing without peripheral interrupts, the scheduler appears to run; however, as soon as any hardware interrupt fires or when analyzed with strict Cortex-M architectural verification rules, severe priority inversions and NVIC exceptions are reported.

## Candidate Mission
1. Analyze the FreeRTOS Cortex-M3 interrupt priority configuration and System Handler Priority registers.
2. Identify the root cause of the priority configuration defect.
3. Apply a minimal, zero-regression patch to restore proper exception priority tail-chaining.
4. Verify that the patched firmware passes `reviewer/verify_gate_regression.sh`.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/gate/gate_fault_firmware clean all
```
