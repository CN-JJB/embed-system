# Fault Investigation: Fixture `f5`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
During field testing, the device occasionally enters an unresponsive state where telemetry packets cease and sensor inputs are ignored. Hardware debugging reveals that application tasks are completely deadlocked waiting on mutual exclusion locks. However, the Independent Watchdog (IWDG) never triggers a recovery reset; the system remains permanently hung while the power consumption and heartbeat pin indicate the MCU is still powered and ticking.

## Objective
Diagnose why the hardware watchdog fails to reset the system during complete application deadlock, audit the watchdog feeding architecture, and eliminate unmonitored blind watchdog refreshes.

## Build
```bash
make -C fundamentals/rtos/03-freertos-priority-inversion-stack-watchdog/faults/f5 clean all
```
