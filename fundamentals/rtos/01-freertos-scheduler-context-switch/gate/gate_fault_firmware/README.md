# Module Gate: Real-Time Scheduler Lockup & Kernel Invariant Violation

## Target Description
A mission-critical flight controller firmware image using FreeRTOS V11.3.0 on STM32F103 was submitted for gate assessment.
During execution, whenever all active user tasks enter a delay or sleep period, the system abruptly ceases scheduling or halts in an assertion trap within `vTaskSwitchContext`, even though no hardware faults or memory leaks are flagged during compilation.

**Scenario-provided symptom (not author-captured evidence)**:
Under headless simulation or target startup, as soon as `vGateTask` transitions to the Blocked list via `vTaskDelay()`, the kernel assertion fires or the CPU halts in the scheduler context-switch path with zero ready tasks.

## Candidate Mission
1. Analyze FreeRTOS task state transitions, ready list invariants, and background hook execution.
2. Formulate a hypothesis explaining why the kernel invariant is violated when user tasks are blocked.
3. Collect static or binary evidence to identify the root cause.
4. Apply a minimal, zero-regression patch to restore proper scheduler operation.
5. Verify that the patched firmware passes `reviewer/verify_gate_regression.sh`.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/gate/gate_fault_firmware clean all
```
