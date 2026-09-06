# Fault Investigation: Fixture `f2`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
After boot and peripheral bringup, the microcontroller runs for approximately 1.0 second and then spontaneously reboots. This reboot loop repeats endlessly every ~1.0 second. Examining the reset flag register `RCC->CSR` reveals that `IWDGRSTF` (Independent Watchdog Reset Flag) is persistently asserted upon every reset.

## Objective
Diagnose why the independent watchdog is not being refreshed in time, identify the task starvation defect causing the timeout, and restore predictable multi-task execution.

## Build
```bash
make -C fundamentals/rtos/03-freertos-priority-inversion-stack-watchdog/faults/f2 clean all
```
