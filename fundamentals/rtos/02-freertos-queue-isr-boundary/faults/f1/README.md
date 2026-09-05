# Fault Investigation: Fixture `f1`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
When the firmware is flashed to the microcontroller, the target executes `main()`, initializes peripherals, and starts the scheduler. However, within 10 milliseconds (as soon as the first timer interrupt occurs), the CPU immediately hangs. Attaching a debugger shows the core trapped inside `vAssertCalled()`, with the call stack originating inside `vPortValidateInterruptPriority()`.

## Objective
Diagnose why `vPortValidateInterruptPriority()` triggers a kernel assertion upon the first timer interrupt and restore safe interrupt execution.

## Build
```bash
make -C fundamentals/rtos/02-freertos-queue-isr-boundary/faults/f1 clean all
```
