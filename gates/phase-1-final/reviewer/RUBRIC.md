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
- [ ] **Part D Runtime Root-Cause Proof:** Live evidence proving both faults are resolved and both single-fix variants fail as designed.
- [ ] **Part A Zero Leaks:** Zero ASan memory leaks and in-process descriptor audit confirming zero leaked owned file descriptors before termination.
- [ ] **Attestation:** Signed AI-Free attestation is present.

---

## 3. Evidence Mapping Standard: What It Proves vs What It Does Not Prove

Every evaluated claim must follow the canonical mapping:
```text
requirement → path/command → expected observation → what it proves → what it does not prove → pass/fail
```

### Example 1: Part A In-Process Application Descriptor Lifecycle Audit
* **Requirement:** All owned file descriptors opened by the application lifecycle are explicitly closed before return and on all failure paths.
* **Command:** In-process descriptor audit (`reviewer/part-a/test_lifecycle.c`) measuring `/proc/self/fd` active descriptor delta across the reusable application lifecycle helper (`app_lifecycle.c`), verifying success paths, output-open failure after input-open, processing errors, and borrowed descriptor preservation.
* **Expected Observation:** The active descriptor count in `/proc/self/fd` before opening owned files strictly matches the count after lifecycle completion on both success and failure paths.
* **What it proves:** Proves that the C application lifecycle logic explicitly invokes `close()` on every owned descriptor it allocated (including error unwinding when subsequent opens fail), and that borrowed descriptors (`stdin`, `stdout`) remain open.
* **What it does not prove:** An external parent-shell `/proc/self/fd` comparison does NOT prove child application cleanup (because kernel process tear-down forcibly closes descriptors on exit regardless of code quality). Evidence must be captured via in-process descriptor tracking of the application's actual lifecycle helper.
* **Pass/Fail:** Pass if in-process active descriptor count returns to baseline across all paths; Fail if descriptors are retained.

### Example 2: Part B Concurrency Synchronization & TSan
* **Requirement:** Multi-field invariant synchronization free of data races.
* **Command:** Execution under ThreadSanitizer (`setarch x86_64 -R make tsan`) and 100-cycle stress regression.
* **Expected Observation:** TSan reports zero data races on shared state and harness control flags (`exit=0`).
* **What it proves:** In the recorded instrumented execution, TSan reported no conflicting unsynchronized accesses on the exercised shared-state and harness-control paths.
* **What it does not prove:** Neither 100 clean stress runs nor one clean TSan execution proves absence of races under every possible schedule; they provide bounded evidence for the exercised paths.
* **Pass/Fail:** Pass if TSan reports zero races and invariant check succeeds.

### Example 3: Part D Interacting Root-Cause & Residual Failure Proof
* **Requirement:** Demonstration that two distinct defect boundaries interact, such that single-fix repairs leave residual failure while the integrated fix restores clean operation.
* **Command:** `reviewer/part-d/regression.sh` running broken fixture, `partial_fd_fixed`, `partial_conc_fixed`, and reference implementation, alongside `test_channels.c`.
* **Expected Observation:**
  1. Broken fixture hits watchdog timeout (exit code 2).
  2. Live inspection of the target child shows two descriptors referencing the exact expected communication `pipe:[inode]` in `/proc/<target_pid>/fd` after the parent writer is closed.
  3. Process/FD-only repair fails with residual concurrency drain error (exit code 1) and active unjoined threads.
  4. Concurrency-only repair stalls on stream EOF (exit code 2).
  5. Fully fixed reference passes 50/50 consecutive cycles (exit code 0).
* **What it proves:** Provides bounded runtime evidence that the exact communication pipe retains a writer reference and that the concurrency lifecycle remains incomplete when only one boundary is repaired; together with both partial-fix runs, this demonstrates the intended interaction on the exercised fixture.
* **What it does not prove:** A single fixed run alone does not prove interaction; both partial-fix failures must be demonstrated. Watchdog timeout proves bounded execution safety, not root-cause diagnosis.
* **Pass/Fail:** Pass if all four execution states match expected results and two live evidence channels are documented.
