# Fault Fixture F3: Linker Memory Boundary Diagnostic

## Symptom
The toolchain terminates the build process during the linking phase with an error diagnostic, refusing to generate the final firmware executable.

## Task
1. Inspect the linker output diagnostic messages.
2. Formulate 3 hypotheses regarding memory layout constraints and section allocation.
3. Determine how the linker script enforces physical memory boundaries.
4. Apply the appropriate structural fix and verify that the build succeeds within silicon limits.

## Build
```bash
make clean && make
```
