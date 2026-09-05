# Fault Investigation: Fixture `f3`

## Observed Symptom
The firmware starts up and executes `vTaskStartScheduler()`, but crashes into `HardFault_Handler` almost instantaneously when the first task begins executing local computations and nested subroutine calls. A debugger backtrace shows that the Process Stack Pointer (PSP) has exceeded its allocated boundary and overwritten adjacent memory structures.

## Objective
Investigate task creation parameters, stack frame sizing, and RAM allocation limits to identify why the task stack overflows.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/faults/f3 clean all
```
