# Fault Fixture 3: Timer Clock Doubler Miscalculation

## Symptom
Timer interrupts trigger at exactly twice the expected frequency (2000 Hz / 500 us interval instead of 1000 Hz / 1.0 ms).

## Task
1. Inspect the APB1 prescaler division factor in `RCC->CFGR`.
2. Apply the timer clock doubling rule from RM0008 Section 6.2.
3. Fix the prescaler math in `timer.c`.

## Build
```bash
make clean && make
```
