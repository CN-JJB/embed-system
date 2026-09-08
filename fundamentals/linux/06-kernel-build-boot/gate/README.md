# P3-M02 Module Gate — AI-Free Kernel Build & Artifact Exam

> **AI Policy:** Strict AI-Free. Official Linux Documentation and ARM manuals allowed.

## Instructions
1. Run `make all` inside `gate/` to verify the provisioned evaluation artifacts are in place:
   - `fixtures/gate_effective.config`
   - `fixtures/gate_vmlinux`
   - `fixtures/gate_zImage`
   - `fixtures/gate_System.map`
2. Audit the effective configuration against Phase 3 canonical platform rules and report every deviation.
3. Extract symbol addresses from `gate_vmlinux` and verify synchronization with `gate_System.map`.
4. State the canonical QEMU launch command line and articulate the technical justification for each flag.
5. Fill out your findings in `gate_manifest.template`.
6. Submit to reviewer for grading.
