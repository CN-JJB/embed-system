# Fault Fixture F4: Interrupt Priority Register Encoding

## Symptom
Software attempts to configure the priority of `TIM2_IRQn` to a non-zero logical priority, but reading back the hardware priority register `NVIC->IP[TIM2_IRQn]` unexpectedly yields `0x00`.

## Task
1. Inspect the priority assignment mechanism and the hardware byte format in `NVIC->IP`.
2. Formulate 3 hypotheses regarding how the processor silicon implements priority levels.
3. Determine why direct assignment of the logical priority integer failed to set the expected priority bits.
4. Correct the priority assignment using the standard architectural mechanism.

## Build
```bash
make clean && make
```
