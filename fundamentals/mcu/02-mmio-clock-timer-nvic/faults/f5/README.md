# Fault Fixture F5: Intermittent GPIO Edge Loss

## Symptom
When the firmware runs with concurrent execution between Thread mode and the periodic timer interrupt, output pulses on shared GPIO pins exhibit missing edges or sporadic glitches.

## Task
1. Inspect the generated machine instructions for the relevant GPIO updates in Thread mode and Handler mode.
2. Formulate 3–5 hypotheses regarding execution interleaving, register access, and hardware behavior.
3. Use disassembly and RM0008 evidence to isolate the lost-update mechanism.
4. Apply the minimal fix and explain what the replacement proves and what still requires target waveform evidence.

## Build
```bash
make clean && make
```
