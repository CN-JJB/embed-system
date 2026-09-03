# Reviewer Evaluation Rubric: Phase 1 Final Gate

## 1. Score Overview (100 Points Total)

```text
Part A — Blank-Directory Build (30 Points)
  - Architecture & Module Split (>= 4 files, clean separation):       6 pts
  - Resource Ownership & Lifetime (borrowed vs owned FDs, zero leak):  8 pts
  - I/O Robustness & Error Boundaries (EINTR, partial write, ranges): 8 pts
  - Strict Build, Sanitizer (ASan/UBSan) & Tests:                      8 pts

Part B — Unknown Bug Investigation (25 Points)
  - Symptom Formulation & 3–5 Competing Hypotheses:                   6 pts
  - Targeted Experimentation & Concrete Evidence:                     7 pts
  - Root-Cause Identification & Contract Violation Analysis:           4 pts
  - Minimal Principled Fix:                                           4 pts
  - Automated Regression Proof:                                       4 pts

Part C — ELF / Link / Binary Evidence (20 Points)
  - Task 1: Symbol Linkage & Binding:                                 4 pts
  - Task 2: Relocation Entry Inspection:                              4 pts
  - Task 3: Section Placement (.text/.rodata/.data/.bss):             4 pts
  - Task 4: Compiler vs Linker Diagnostic Distinction:                4 pts
  - Task 5: Short Disassembly-to-C Lowering Observation:             4 pts

Part D — Process / FD / Concurrency Debugging (25 Points)
  - Interacting Failure Analysis (both boundaries identified):        6 pts
  - Two Independent Evidence Channels:                                8 pts
  - Runtime Root-Cause Proof (live trace of clean termination):        6 pts
  - Multi-Cycle Clean Regression (zero deadlocks/leaks):              5 pts
```

---

## 2. Hard Pass Evaluation Checklist

Reviewers must verify that **all six** hard criteria are satisfied before granting a pass:

- [ ] **Total Score:** $\ge 75 / 100$.
- [ ] **Part Floors:** Each part achieves $\ge 60\%$ (Part A $\ge 18$, Part B $\ge 15$, Part C $\ge 12$, Part D $\ge 15$).
- [ ] **Diagnostic Mastery Bar:** Part B $\ge 70\%$ ($\ge 17.5 / 25$).
- [ ] **Part D Runtime Root-Cause Proof:** Live evidence proving both faults are resolved.
- [ ] **Part A Zero Leaks:** Zero ASan memory leaks and zero leaked owned file descriptors in `/proc/<pid>/fd`.
- [ ] **Attestation:** Signed AI-Free attestation is present.

---

## 3. Evidence Mapping Standard

Every evaluated claim must follow the canonical mapping:
```text
requirement → path/command → expected observation → what it proves → what it does not prove → pass/fail
```

### Example 1: Part A File Descriptor Audit
* **Requirement:** No leaked owned file descriptors.
* **Command:** `ls -l /proc/self/fd` (or baseline vs post-run comparison in `validate.sh`).
* **Expected Observation:** The set of open descriptors before invocation matches the set after invocation.
* **What it proves:** All file descriptors opened for input/output files were explicitly closed.
* **What it does not prove:** Does not prove that borrowed descriptors (`stdin`, `stdout`) were untouched (verified via source audit).
* **Pass/Fail:** Pass if descriptor count delta is zero; Fail if count grows.

### Example 2: Part D Interacting Root-Cause Proof
* **Requirement:** Live evidence proving child receives EOF and threads join before destroy.
* **Command:** `/proc/<child_pid>/fd` audit and ThreadSanitizer run on fixed binary.
* **Expected Observation:** Child process closes write pipe end, receives EOF, drains queue, and exits cleanly.
* **What it proves:** Both process/FD boundary and thread lifecycle were resolved.
* **What it does not prove:** One clean run does not prove all thread interleavings are impossible (hence 50-cycle regression).
* **Pass/Fail:** Pass if both evidence channels confirm root cause resolution and 50/50 regression passes.
