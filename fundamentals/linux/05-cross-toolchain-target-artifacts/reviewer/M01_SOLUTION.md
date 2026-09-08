# P3-M01 Solution & Reference Evidence

> Reviewer Reference Only. Keep strictly isolated from learner files.

## 1. Challenge Reference (`challenge/fixtures`)

### `unknown_1`
- `readelf -h unknown_1`: non-ARM machine identity (host architecture).
- Classification: `HOST_OR_NON_ARM`
- Root Cause: Compiled with the host compiler.
- Error on Target: `cannot execute binary file: Exec format error` (`-ENOEXEC`).

### `unknown_2`
- `readelf -h unknown_2`: `Machine: ARM`, `Flags: 0x5000400, Version5 EABI, hard-float ABI`.
- `readelf -l unknown_2`: `INTERP ... [Requesting program interpreter: /lib/ld-linux-armhf.so.3]`.
- `readelf -d unknown_2`: `(NEEDED) Shared library: [libc.so.6]`.
- Classification: `TARGET_DYNAMIC`
- Behavior on target: Fails with `sh: ./unknown_2: not found` (`-ENOENT`) if `/lib/ld-linux-armhf.so.3` is absent.

### `unknown_3`
- `readelf -h unknown_3`: `Machine: ARM`, `Flags: 0x5000400, Version5 EABI, hard-float ABI`.
- `readelf -l unknown_3`: No `INTERP` segment present.
- `readelf -d unknown_3`: "There is no dynamic section in this file."
- Classification: `TARGET_STATIC`
- Behavior on target: Self-contained binary without dynamic loader requirements; executes on compatible ARMv7-A Linux even with empty `/lib`.

---

## 2. Gate Reference (`gate/fixtures`)

- `candidate_alpha`: Dynamic ARM target binary (`Machine: ARM`, `PT_INTERP: /lib/ld-linux-armhf.so.3`, `NEEDED: libc.so.6`).
- `candidate_beta`: Static ARM target binary (`Machine: ARM`, No `PT_INTERP`, No `PT_DYNAMIC`, safe for minimal rootfs).
- `candidate_gamma`: Host binary (non-ARM machine identity, `-ENOEXEC` on target).

---

## 3. Reference Audit Tool Verification

Reviewer builds and executes `reviewer/reference/audit_tool_reference.c` to verify that all candidates match the expected classification:
```bash
gcc reviewer/reference/audit_tool_reference.c -o reviewer/reference/audit_tool_reference
./reviewer/reference/audit_tool_reference challenge/fixtures/unknown_1
./reviewer/reference/audit_tool_reference challenge/fixtures/unknown_2
./reviewer/reference/audit_tool_reference challenge/fixtures/unknown_3
```
The authoritative grading oracle is `reviewer/oracle_m01.sh`; run `reviewer/test_m01_oracle_mutations.sh` for oracle regression.
