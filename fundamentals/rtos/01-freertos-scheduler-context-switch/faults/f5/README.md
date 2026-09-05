# Fault Investigation: Fixture `f5`

## Observed Symptom
When the firmware is flashed, the microcontroller halts execution inside `vApplicationMallocFailedHook` (or hits a software breakpoint) during boot before entering thread mode. The scheduler never starts, and debugging indicates that `pvPortMalloc` returned a `NULL` pointer during kernel initialization.

## Objective
Analyze heap allocation parameters, task stack memory requirements, and internal TCB footprints to determine the cause of memory allocation failure.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/faults/f5 clean all
```
