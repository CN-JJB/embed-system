# Fault Investigation: Fixture `f5`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
When the firmware is flashed, the microcontroller halts execution inside `vApplicationMallocFailedHook` (or hits a software breakpoint) during boot before entering thread mode. The scheduler never starts, and debugging indicates that `pvPortMalloc` returned a `NULL` pointer during kernel initialization.

## Objective
Diagnose why dynamic memory allocation fails during task creation and kernel startup.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/faults/f5 clean all
```
