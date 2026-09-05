# Fault Investigation: Fixture `f4`

## Observed Symptom
During boot, the firmware executes through system initialization and calls `vTaskStartScheduler()`. However, the microcontroller immediately traps into a Fault handler before executing a single instruction inside any task function. Reading the Cortex-M System Control Block Configurable Fault Status Register (`SCB->CFSR`) reveals bit 17 (`INVSTATE`) is set, indicating an Invalid State UsageFault.

## Objective
Analyze the initial stack frame structure created during task initialization to determine what causes the Cortex-M3 processor to fault on exception return.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/faults/f4 clean all
```
