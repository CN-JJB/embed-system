# P3-M01 Reviewer Guide & Assessment Anchors

> **Reviewer Only** — Keep isolated from learner-facing directories.

## Assessment Matrix (fresh variant)

| Candidate | Machine Identity | Program Headers | Dynamic Section | Correct Verdict |
|---|---|---|---|---|
| `candidate_alpha` | `ARM` (ELF32) | Has `INTERP`: `/lib/ld-linux-armhf.so.3` | Has `(NEEDED) [libc.so.6]` | **Dynamic ARM target binary** (Fails if loader missing) |
| `candidate_beta` | `ARM` (ELF32) | No `INTERP` segment | No dynamic section | **Static ARM target binary** (Ready for minimal rootfs) |
| `candidate_gamma` | Host machine (e.g. X86-64) | Varies (Host format) | Host libs | **Wrong Architecture** (Fails on target with `Exec format error`) |

## Scoring Anchors
1. **Machine Binding (30 pts)**: Must provide `readelf -h` showing `Machine: ARM` vs host machine. Points lost if learner claims architecture from `file` without checking ELF machine field.
2. **Dynamic Loader Contract (35 pts)**: Must provide `readelf -l` showing `[Requesting program interpreter: /lib/ld-linux-armhf.so.3]`. Must explain that `-ENOENT` is triggered by the kernel failing to open the loader path, not the application path.
3. **Static Linkage Proof (35 pts)**: Must prove absence of `INTERP` via `readelf -l` and absence of dynamic section via `readelf -d`. Automatic fail on this part if learner claims `readelf -h` alone proves static linkage!

## Assessment Oracle & Regression
- Grading oracle: `reviewer/oracle_m01.sh` (single source of truth for the mapping).
- Oracle reference + mutation regression: `reviewer/test_m01_oracle_mutations.sh`.
- Fixture generators: `reviewer/scripts/generate_m01_challenge_fixtures.sh`, `reviewer/scripts/generate_m01_gate_fixtures.sh`.
  Materialized opaque fixtures are committed under `challenge/fixtures/` and `gate/fixtures/` for learner consumption.

## Component Negative Control Mutations
The reviewer maintains four adversarial mutations in `test_m01_mutations.sh` to ensure component validators do not false-pass (host binary vs F01 oracle, missing loader vs F02 oracle, non-ELF artifact, decoy interpreter string in static binary).
