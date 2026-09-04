# Fault Fixture 1: Misaligned / Even Reset Vector

## Symptom
Firmware compiles cleanly with zero warnings, but upon being flashed to hardware, the target never reaches `main()`. Instead, it halts immediately in `UsageFault_Handler` or `HardFault_Handler`.

## Task
1. Inspect the binary artifact using `arm-none-eabi-readelf`.
2. Formulate 3 hypotheses.
3. Identify the physical root cause and explain why the Cortex-M3 processor rejects this binary.

## Build
```bash
make clean && make
```
