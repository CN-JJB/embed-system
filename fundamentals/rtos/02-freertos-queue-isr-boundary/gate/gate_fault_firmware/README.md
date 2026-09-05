# Module Gate: High-Speed Sensor Telemetry Handoff Failure

## Target Description
A mission-critical sensor telemetry processing node using FreeRTOS V11.3.0 on STM32F103 has been submitted for gate certification. The system uses a periodic timer interrupt to enqueue sensor packets into a FreeRTOS queue, which should unblock a high-priority telemetry dispatch task.

During acceptance testing, two severe operational failures are observed:
1. When kernel assertions are enabled, the microcontroller traps immediately into `vAssertCalled()` on the very first timer interrupt.
2. If assertions are disabled, the system suffers from severe CPU starvation, erratic packet delivery, and high dispatch jitter.

**Scenario-provided symptom (not author-captured evidence)**:
Under headless execution or target bring-up, the system traps inside `vPortValidateInterruptPriority()`. Inspecting the task scheduling reveals that the consumer task spins continuously rather than blocking on the queue.

## Candidate Mission
1. Analyze the NVIC interrupt priority assignment against the FreeRTOS syscall boundary.
2. Inspect the consumer task queue-receive interaction and blocking semantics.
3. Formulate hypotheses explaining why kernel validation assertions reject the interrupt and why CPU starvation occurs.
4. Apply a minimal, zero-regression patch to restore robust interrupt handoff and priority-preemptive scheduling.
5. Verify that the patched firmware passes `reviewer/verify_gate_regression.sh`.

## Build
```bash
make -C fundamentals/rtos/02-freertos-queue-isr-boundary/gate/gate_fault_firmware clean all
```
