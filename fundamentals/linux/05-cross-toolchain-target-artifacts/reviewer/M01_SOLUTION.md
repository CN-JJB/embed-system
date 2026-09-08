# P3-M01 Solution & Reference Evidence

> Reviewer Reference Only.

## 1. Challenge Solutions

### `fixtures/unknown_1`
- `readelf -h unknown_1` output:
  `Machine: Advanced Micro Devices X86-64` (or host arch)
- Root Cause: Compiled with host `gcc`.
- Error on Target: `cannot execute binary file: Exec format error`.

### `fixtures/unknown_2`
- `readelf -h unknown_2` output:
  `Machine: ARM`, `Flags: 0x5000400, Version5 EABI, hard-float ABI`
- `readelf -l unknown_2`:
  `INTERP ... [Requesting program interpreter: /lib/ld-linux-armhf.so.3]`
- `readelf -d unknown_2`:
  `(NEEDED) Shared library: [libc.so.6]`
- Root Cause: Dynamically linked ARM binary. Fails on minimal target rootfs if `/lib/ld-linux-armhf.so.3` or `libc.so.6` is missing with error `sh: ./unknown_2: not found`.

### `fixtures/unknown_3`
- `readelf -h unknown_3`:
  `Machine: ARM`, `Flags: 0x5000400, Version5 EABI, hard-float ABI`
- `readelf -l unknown_3`:
  No `INTERP` segment present.
- `readelf -d unknown_3`:
  "There is no dynamic section in this file."
- Root Cause: Statically linked ARM binary. Ready to run in any Linux ARM rootfs with zero shared libraries.

---

## 2. Gate Candidate Solutions

- `candidate_alpha`: Dynamic ARM target binary (`Machine: ARM`, `PT_INTERP: /lib/ld-linux-armhf.so.3`, `NEEDED: libc.so.6`).
- `candidate_beta`: Host binary (`Machine: Advanced Micro Devices X86-64`).
- `candidate_gamma`: Static ARM target binary (`Machine: ARM`, No `PT_INTERP`, No `PT_DYNAMIC`).
