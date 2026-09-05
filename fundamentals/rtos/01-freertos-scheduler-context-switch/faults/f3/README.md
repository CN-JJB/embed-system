# Fault Investigation: Fixture `f3`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
The firmware starts and executes `vTaskStartScheduler()`, but crashes into `HardFault_Handler` shortly after the first task begins local computations and nested calls. Scenario-provided debugger evidence shows the PSP moving unexpectedly close to neighboring task/heap data before the fault; the exact failure mechanism is for the learner to prove.

## Objective
Diagnose why the worker task triggers a fault shortly after beginning execution.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/faults/f3 clean all
```
