# Fault Fixture 5: Read-Modify-Write Shared Register Hazard

## Symptom
Under heavy interrupt loading, GPIO output pulses on PA2 are intermittently missed or corrupted.

## Task
1. Inspect the disassembly of `GPIOA->ODR ^= ...;`.
2. Trace what occurs when an interrupt modifies `GPIOA` between `LDR` and `STR`.
3. Replace the non-atomic RMW sequence with atomic `BSRR`/`BRR`.

## Build
```bash
make clean && make
```
