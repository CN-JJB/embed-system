# Lab 1.4 — Static Target ELF: Absence of `PT_INTERP` and Dynamic Sections

## Objective
1. Compile `static_app.c` with `-static`.
2. Inspect the binary with `readelf -h` and observe that `Type: EXEC` and `Machine: ARM` are identical to dynamic binaries.
3. Inspect program headers with `readelf -l` and prove the complete absence of `INTERP`.
4. Inspect dynamic tags with `readelf -d` and confirm there is no dynamic section.
5. Contrast file sizes: static binary embeds library routines (~400KB to ~700KB with glibc, ~20KB with musl) compared to ~10KB for dynamic binary.

## Commands to Run
```bash
make all
make inspect
```

## Critical Proof Rule
`readelf -h` does NOT prove static linkage!
You must verify with:
- `readelf -l <binary> | grep INTERP` -> returns empty / no match
- `readelf -d <binary>` -> prints "There is no dynamic section in this file."

### Portability Boundary
Static linking eliminates the requirement for `/lib/ld-linux-armhf.so.3` and userspace shared libraries. It does NOT guarantee execution on arbitrary ARM systems: instruction set (ARMv7-A), hardware floating-point ABI (hard-float VFP), and kernel syscall interface compatibility are still mandatory.
