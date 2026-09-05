# Fault Investigation: Fixture `f3`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
The firmware starts up and executes `vTaskStartScheduler()`, but crashes into `HardFault_Handler` almost instantaneously when the first task begins executing local computations and nested subroutine calls. A debugger backtrace shows that the Process Stack Pointer (PSP) has exceeded its allocated boundary and overwritten adjacent memory structures.

## Objective
Diagnose why the worker task triggers a fault shortly after beginning execution.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/faults/f3 clean all
```
