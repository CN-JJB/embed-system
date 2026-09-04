# Fault Fixture 4: NVIC Priority Encoding Error

## Symptom
Interrupt priorities are inverted or fail to preempt as intended. A low-urgency background ISR blocks a high-urgency timing-critical ISR.

## Task
1. Inspect the raw bytes written to `NVIC->IP[x]`.
2. Trace the bit shift required for STM32F103's 4 implemented priority bits.
3. Correct the priority assignment.

## Build
```bash
make clean && make
```
