# Fault Fixture 1: Unclocked Peripheral Access

## Symptom
Firmware configures TIM2 registers and enables NVIC interrupt. However, the timer never generates interrupts, `g_tim2_ticks` remains 0, and PA1 never toggles.

## Task
1. Inspect peripheral clock enable registers in RCC.
2. Verify why reading or writing TIM2 registers has no physical effect.
3. Formulate hypotheses and collect register evidence in GDB.

## Build
```bash
make clean && make
```
