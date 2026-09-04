# Fault Fixture F5: Shared Peripheral Register Race

## Symptom
When the firmware runs with concurrent execution between Thread mode and the periodic timer interrupt, output pulses on shared GPIO pins exhibit missing edges or sporadic glitches.

## Task
1. Inspect the generated machine instructions for pin toggling in Thread mode and Handler mode.
2. Formulate 3 hypotheses regarding execution interleaving and register update semantics.
3. Identify why standard C bitwise manipulation on peripheral output registers is susceptible to preemption.
4. Replace the vulnerable sequence with an atomic architectural alternative.

## Build
```bash
make clean && make
```
