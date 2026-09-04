# Fault Fixture 2: Data Section LMA-VMA Mismatch

## Symptom
Firmware compiles cleanly with zero warnings, but upon reaching `main()`, global variables in `.data` evaluate to garbage / uninitialized memory instead of their configured initializers.

## Task
1. Inspect `build/firmware.map`.
2. Compare symbol `_sidata` against `.data` section's actual load address (LMA).
3. Identify the linker script defect and explain why the startup copy loop copied noise.

## Build
```bash
make clean && make
```
