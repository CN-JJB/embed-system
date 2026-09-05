# Fault Investigation: Fixture `f1`

## Observed Symptom
When the firmware is flashed to the microcontroller, the target appears completely dead. The heartbeat LED never illuminates or toggles, and attaching a debugger reveals that the core is trapped in an infinite loop inside `Default_Handler` immediately after calling `vTaskStartScheduler()`.

## Objective
Analyze the vector table bindings and FreeRTOS exception handler mappings to diagnose why task scheduling fails to initiate.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/faults/f1 clean all
```
