# Fault Investigation: Fixture `f1`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
When the firmware is flashed to the microcontroller, the target appears completely dead. The heartbeat LED never illuminates or toggles, and attaching a debugger reveals that the core is trapped in an infinite loop inside `Default_Handler` immediately after calling `vTaskStartScheduler()`.

## Objective
Diagnose why task scheduling fails to initiate and why the core enters `Default_Handler`.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/faults/f1 clean all
```
