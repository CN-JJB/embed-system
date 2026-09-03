# Reviewer Remediation Map: Phase 1 Final Gate

When a learner fails to achieve $\ge 60\%$ on a specific Part (or $\ge 70\%$ on Part B), reviewers must direct them to targeted milestone remediation rather than restarting all of Phase 1.

---

## 1. Milestone Remediation Mapping

| Deficient Area | Observed Failure Mode | Target Milestones to Review | Key Exercises |
|---|---|---|---|
| **Part A: Ownership** | Memory leak under ASan, dangling pointer | **P1-M01** (Objects & Lifetime) | Re-implement resource allocator; practice valgrind/ASan clean checks. |
| **Part A: FD Boundaries** | Leaked owned FD, closed borrowed FD | **P1-M02** (Files & FD Lifecycle) | Re-implement owned-vs-borrowed table; audit with `/proc/<pid>/fd`. |
| **Part A: Architecture** | Single monolithic file, missing callback | **P1-M05** (Ownership & Callback) | Refactor CLI tool into header/source modules with context pointer. |
| **Part B: Variant B1** | Heap-use-after-free, scope escape | **P1-M01** (Lifetime & Extent) | Audit buffer lifecycles; practice deep copy vs borrow contracts. |
| **Part B: Variant B2** | File descriptor retention on rotation | **P1-M02** (Files & Error Paths) | Write rotation harness; verify descriptor stability across loops. |
| **Part B: Variant B3** | Invariant violation, data race | **P1-M09** (Concurrency & Mutex) | Audit critical section boundaries; enforce atomic multi-field updates. |
| **Part C: Symbols & Link** | Confused compile-time vs link-time | **P1-M03** (ELF / Linker Mechanics) | Inspect `.o` symbol tables (`nm`, `readelf`); resolve link errors. |
| **Part D: Process / FD** | Inherited descriptor hang, pipe EOF stall | **P1-M04** / **P1-M06** (Process, Fork, IPC) | Audit descriptor tables across `fork()`; verify pipe closure rules. |
| **Part D: Concurrency** | Thread join/destroy ordering error | **P1-M09** / **P1-M10** (Pthreads & Shutdown) | Implement graceful shutdown drain; verify join-before-destroy ordering. |

---

## 2. Retake Protocol

1. **Partial Retake:** A learner who fails 1 or 2 parts retakes **only those deficient parts**.
2. **Part B Variant Rotation:** Any retake of Part B **must assign a different variant from a different family** (e.g. if the learner failed Variant B1 [B-MEM], the retake must be Variant B2 [B-FD] or B3 [B-CONC]).
3. **Comprehensive Review Bar:** A learner scoring $< 60\%$ on 3 or more parts requires an end-to-end curriculum review before re-attempting the full Final Gate.
