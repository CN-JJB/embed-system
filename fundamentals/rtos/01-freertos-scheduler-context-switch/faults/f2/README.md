# Fault Investigation: Fixture `f2`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
When this firmware is deployed on boards operating under internal HSI oscillator fallback (due to absent or unpopulated 8 MHz HSE crystals), all task delays, periodic telemetry transmissions, and blink intervals are observed to run approximately 12.5% slower than specified (a requested 1000 ms delay takes ~1125 ms).

## Objective
Diagnose the source of the timing dilation under alternate clock configurations.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/faults/f2 clean all
```
