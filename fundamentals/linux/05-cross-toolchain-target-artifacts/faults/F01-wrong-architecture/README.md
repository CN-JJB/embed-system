# Fault F01 — Binary Architecture Mismatch (`Exec format error`)

## Symptom
A binary compiled on the host is placed into the target rootfs or executed in an ARM target container/QEMU environment.
Attempting execution yields:
```text
cannot execute binary file: Exec format error
```

## Diagnostic Sequence
1. **Own Description**: The target operating system refused to load the executable.
2. **3–5 Hypotheses**:
   - Binary was compiled for x86-64 host instead of ARM target.
   - Binary is 64-bit ARM (AArch64) executed on a 32-bit ARM kernel.
   - Binary ELF header is corrupted or has invalid magic bytes.
   - Binary is a text script lacking a valid `#!` shebang interpreter.
3. **Experiment**: Run `readelf -h app_faulty` to inspect the ELF header fields `Machine:` and `Class:`.
4. **Evidence**:
   ```text
   Class:                             ELF64
   Machine:                           Advanced Micro Devices X86-64
   ```
   The target kernel expects `Machine: ARM` (decimal 40).
5. **Narrow Scope**: The binary file is a valid, uncorrupted executable, but its machine type belongs to the host workstation.
6. **Root Cause**: The Makefile was executed using host `gcc` instead of cross-compiler `$(CROSS_COMPILE)gcc`.
7. **Fix**: In the Makefile, bind `CC := $(CROSS_COMPILE)gcc` and rebuild.
8. **Regression**:
   Run `make build-fixed` and verify with `./diagnose_f01.sh app_fixed`:
   ```text
   ELF Class:   ELF32
   ELF Machine: ARM
   [PASS] Binary architecture matches ARM target (Machine: ARM)
   ```
