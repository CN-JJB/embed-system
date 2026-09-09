# Lab 1.1 — Host vs Target ELF Inspection

## Objective
1. Compile `hello_target.c` using the cross-compiler `${CROSS_COMPILE}gcc`.
2. Compile `hello_target.c` using the host compiler `${HOST_CC}`.
3. Compare the resulting ELF headers using `readelf -h` and identify architectural fields.
4. Execute both on host and observe why the target binary fails with `Exec format error`.

## Commands to Run
```bash
make all
readelf -h hello_host
readelf -h hello_target
./hello_host
./hello_target || true
```

## Key Inspection Checklist
- `hello_host`: Machine is `Advanced Micro Devices X86-64` (or host arch).
- `hello_target`:
  - `Class: ELF32`
  - `Data: 2's complement, little endian`
  - `Machine: ARM`
  - `Flags: 0x5000400, Version5 EABI, hard-float ABI`
- Host shell execution of `hello_target`:
  `./hello_target: cannot execute binary file: Exec format error`
