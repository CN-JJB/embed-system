# Fault Fixture F2: Unexpected Initial Variable State

## Symptom
Firmware boots and executes cleanly into `main()`, but initialized C variables evaluate to unexpected, invalid, or zero values rather than their expected compile-time initializers.

## Task
1. Inspect the generated linker map (`build/firmware.map`) and ELF segment headers (`readelf -l build/firmware.elf`).
2. Formulate 3–5 hypotheses regarding the data transfer path between non-volatile and volatile memory.
3. Compare the startup copy loop boundaries against linker section addresses.
4. Apply the minimal fix and verify correct variable values at runtime.

## Build
```bash
make clean && make
```
