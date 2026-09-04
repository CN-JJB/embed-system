# Fault Fixture F1: Peripheral Inactivity

## Symptom
Firmware compiles without warnings, but the timer counter register never advances, the tick counter remains stationary, and the periodic timing marker pin never transitions.

## Task
1. Inspect the peripheral initialization sequence and register states.
2. Formulate 3–5 hypotheses regarding why hardware peripheral registers fail to update.
3. Identify the missing hardware state prerequisite before peripheral registers can function.
4. Apply the minimal fix and verify counter operation.

## Build
```bash
make clean && make
```
