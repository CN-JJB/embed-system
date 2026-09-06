# Fault Investigation: Fixture `f5`

## Scenario-Reported Symptom (Scenario-provided symptom, not author-captured evidence)
The firmware executes without crashing or throwing assertions, and timer interrupts fire regularly. However, the consumer task reports massive sequence continuity errors (`g_consumer_sequence_errors` rapidly increments), and the received sequence numbers appear truncated to 8-bit values or scrambled.

## Objective
Diagnose the memory mismatch between the queue storage item size and the producer payload, and correct the queue allocation contract.

## Build
```bash
make -C fundamentals/rtos/02-freertos-queue-isr-boundary/faults/f5 clean all
```
