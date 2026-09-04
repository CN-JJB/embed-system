# Fault Fixture 3: Physical Memory Region Overflow

## Symptom
Firmware fails to link. The linker emits an explicit memory exhaustion assertion error.

## Task
1. Inspect the linker output error message.
2. Determine which memory section breached physical silicon limits.
3. Verify how the pedagogical linker script ASSERT guards against memory corruption.

## Build
```bash
make clean && make
```
