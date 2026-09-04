# Fault Fixture F1: Early Reset Halt

## Symptom
Firmware compiles cleanly with zero warnings, but upon execution on target hardware or in simulation, the processor never reaches `main()`. Instead, it halts immediately in an architectural fault handler.

## Task
1. Inspect the binary artifact using `arm-none-eabi-readelf` and `arm-none-eabi-objdump`.
2. Formulate 3–5 hypotheses before modifying any source code.
3. Collect binary and ELF header evidence to isolate the fault.
4. Document the architectural root cause and verify the minimal fix.

## Build
```bash
make clean && make
```
