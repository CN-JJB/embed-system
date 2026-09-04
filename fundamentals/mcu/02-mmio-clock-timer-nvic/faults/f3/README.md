# Fault Fixture F3: Unexpected Periodic Timing

## Symptom
The timer generates periodic interrupts, but timing measurements show that the event rate occurs at twice the expected frequency (2000 events/s instead of 1000 events/s).

## Task
1. Trace the clock distribution path from the primary oscillator to the timer peripheral.
2. Formulate 3–5 hypotheses regarding clock prescaling and bus domain multiplier rules.
3. Verify the actual timer input frequency against the mathematical prescaler formula.
4. Correct the configuration to achieve deterministic 1000 Hz update events.

## Build
```bash
make clean && make
```
