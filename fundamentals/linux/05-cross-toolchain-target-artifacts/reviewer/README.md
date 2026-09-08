# P3-M01 Reviewer Guide & Assessment Anchors

> **Reviewer Only** — Keep isolated from learner-facing directories.

## Assessment Matrix

| Candidate | Machine Identity | Program Headers | Dynamic Section | Correct Verdict |
|---|---|---|---|---|
| `candidate_alpha` | `ARM` (ELF32) | Has `INTERP`: `/lib/ld-linux-armhf.so.3` | Has `(NEEDED) [libc.so.6]` | **Dynamic ARM target binary** (Fails if loader missing) |
| `candidate_beta` | `Advanced Micro Devices X86-64` | Varies (Host format) | Host libs | **Wrong Architecture** (Fails on target with `Exec format error`) |
| `candidate_gamma` | `ARM` (ELF32) | No `INTERP` segment | No dynamic section | **Static ARM target binary** (Ready for minimal rootfs) |

## Scoring Anchors
1. **Machine Binding (30 pts)**: Must provide `readelf -h` showing `Machine: ARM` vs `X86-64`. Points lost if learner claims architecture from `file` without checking ELF machine field.
2. **Dynamic Loader Contract (35 pts)**: Must provide `readelf -l` showing `[Requesting program interpreter: /lib/ld-linux-armhf.so.3]`. Must explain that `-ENOENT` is triggered by the kernel failing to open the loader path, not the application path.
3. **Static Linkage Proof (35 pts)**: Must prove absence of `INTERP` via `readelf -l` and absence of dynamic section via `readelf -d`. Automatic fail on this part if learner claims `readelf -h` alone proves static linkage!

## Negative Control Mutations
The reviewer maintains four adversarial mutations in `mutations/` to ensure the validator does not false-pass:
- `mut1_fake_arm`: Host binary renamed with `.arm` extension.
- `mut2_fake_static`: Dynamic binary where validator only inspects `readelf -h`.
- `mut3_wrong_loader`: Binary requesting an invalid loader `/lib/ld-musl-x86_64.so.1`.
- `mut4_decoy_string`: Binary containing string `ld-linux-armhf.so.3` in `.rodata` but lacking actual `PT_INTERP` segment.
