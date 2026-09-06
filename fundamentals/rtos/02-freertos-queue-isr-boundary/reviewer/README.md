# P2-M05 Reviewer Isolated Guidance & Solution Suite

> **CONFIDENTIALITY & PEDAGOGICAL ISOLATION**:  
> All files in this directory (`reviewer/`) are strictly isolated from learner-facing materials.  
> They provide golden solutions, hypothesis trees, negative mutation harnesses, and automated gate regression verification.

---

## Reviewer Directory Contents

| Path | Purpose |
| :--- | :--- |
| `challenge-reference/` | Golden reference implementation of `queue_app.c`, `queue_app.h`, `FreeRTOSConfig.h` passing all contracts |
| `mutations/` | 12 negative mutation bundles testing every boundary constraint of `challenge/validate.sh` |
| `test_m05_validator_mutations.sh` | Automated test suite running positive control and negative mutations against `validate.sh` |
| `verify_gate_regression.sh` | Automated harness compiling unpatched Gate firmware, proving defects, applying patch, verifying fix, and restoring clean state |
| `challenge_solution.md` | Architectural breakdown and line-by-line solution notes for the M05 challenge |
| `fault_analysis.md` | Systematic hypothesis trees (`Symptom -> Hypotheses -> Evidence -> Root Cause -> Fix -> Regression`) for faults `f1` to `f5` |
| `gate_solution.md` | Complete root-cause analysis, GDB verification, and source patch for the M05 Module Gate |
| `hints.md` | Tiered Socratic hints for guiding learners through labs, faults, and challenge without leaking code |
