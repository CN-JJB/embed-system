# Fault Investigation: Fixture `f4`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
The system crashes within milliseconds after starting the scheduler. All diagnostic GPIO pins are suddenly driven high, and the core ceases execution. Connecting with an SWD debug probe shows the core trapped inside `vApplicationStackOverflowHook()`, with the stack pointer pointing well beyond the allocated stack buffer for task `"Low"`.

## Objective
Diagnose why `vApplicationStackOverflowHook()` is triggered, inspect task stack sizing vs runtime stack allocation, and resize the task stack or refactor the oversized local buffer.

## Build
```bash
make -C fundamentals/rtos/03-freertos-priority-inversion-stack-watchdog/faults/f4 clean all
```
