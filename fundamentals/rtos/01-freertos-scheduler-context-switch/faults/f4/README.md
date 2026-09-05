# Fault Investigation: Fixture `f4`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
During boot, the firmware executes through system initialization and calls `vTaskStartScheduler()`. However, the microcontroller immediately traps into a Fault handler before executing a single instruction inside any task function. Reading the Cortex-M System Control Block Configurable Fault Status Register (`SCB->CFSR`) reveals bit 17 (`INVSTATE`) is set, indicating an Invalid State UsageFault.

## Objective
Diagnose why the processor triggers an `INVSTATE` UsageFault upon exception return during scheduler launch.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/faults/f4 clean all
```
