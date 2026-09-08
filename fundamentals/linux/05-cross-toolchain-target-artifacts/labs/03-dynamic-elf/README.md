# Lab 1.3 — Dynamic Target ELF: `PT_INTERP` and `DT_NEEDED`

## Objective
1. Cross-compile a C program that links dynamically to libc and libm.
2. Use `readelf -l` to find the program interpreter segment (`PT_INTERP`).
3. Use `readelf -d` to inspect shared library dependencies (`DT_NEEDED`).

## Commands to Run
```bash
make all
make inspect
```

## Expected Evidence
```text
=== Inspecting Program Headers (INTERP) ===
  INTERP         0x000154 0x00010154 0x00010154 0x000019 0x000019 R   0x1
      [Requesting program interpreter: /lib/ld-linux-armhf.so.3]
=== Inspecting Dynamic Section (NEEDED) ===
 0x00000001 (NEEDED)                     Shared library: [libm.so.6]
 0x00000001 (NEEDED)                     Shared library: [libc.so.6]
```

## Meaning
- When executed by target Linux, the kernel will NOT run `dynamic_app` code first.
- The kernel will attempt to load `/lib/ld-linux-armhf.so.3`.
- If `/lib/ld-linux-armhf.so.3` is absent on the target, execution fails immediately with `No such file or directory`.
