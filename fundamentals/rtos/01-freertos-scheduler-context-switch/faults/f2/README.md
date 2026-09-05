# Fault Investigation: Fixture `f2`

## Observed Symptom
When this firmware is deployed on boards operating under internal HSI oscillator fallback (due to absent or unpopulated 8 MHz HSE crystals), all task delays, periodic telemetry transmissions, and blink intervals are observed to run approximately 12.5% slower than specified (a requested 1000 ms delay takes ~1125 ms).

## Objective
Analyze the relationship between the clock tree configuration and FreeRTOS timebase generation to identify the source of the timing dilation.

## Build
```bash
make -C fundamentals/rtos/01-freertos-scheduler-context-switch/faults/f2 clean all
```
