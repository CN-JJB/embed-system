# Fault Fixture F4: Unexpected Priority Readback

## Symptom
Software attempts to configure the priority of `TIM2_IRQn` to a non-zero logical priority, but reading back the hardware priority register `NVIC->IP[TIM2_IRQn]` unexpectedly yields `0x00`.

## Task
1. Reproduce the mismatch between the requested priority and the observed priority-register value.
2. Formulate 3–5 hypotheses before editing source.
3. Use PM0056/CMSIS plus source/disassembly evidence to explain the discrepancy.
4. Apply the minimal fix and show the intended encoded priority value in static/binary evidence; live readback remains target-dependent.

## Build
```bash
make clean && make
```
