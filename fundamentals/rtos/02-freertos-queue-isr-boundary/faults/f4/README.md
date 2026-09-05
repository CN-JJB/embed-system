# Fault Investigation: Fixture `f4`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
The firmware runs without assertions or crashes, but timing measurements show that the consumer task starts executing with unpredictable, significant latency (up to 1 ms delay) after the timer interrupt has fired, instead of starting within microseconds of interrupt completion.

## Objective
Diagnose why task preemption is deferred to the next SysTick interrupt and restore immediate task switching via the FreeRTOS interrupt yield macro.

## Build
```bash
make -C fundamentals/rtos/02-freertos-queue-isr-boundary/faults/f4 clean all
```
