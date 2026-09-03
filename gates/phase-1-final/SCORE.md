# Phase 1 Final Gate: Scoring Rubric & Evaluation Standard

## 1. Score Distribution (100 Points Total)

```
+----------------------------------------------------------------------------------------------------+
|                                    SCORE DISTRIBUTION MATRIX                                       |
+---------+------------------------------------+--------+--------------------------------------------+
| Part    | Description                        | Points | Sub-Dimensions                             |
+---------+------------------------------------+--------+--------------------------------------------+
| Part A  | Blank-Directory Build              | 30     | Architecture & Structure (6)               |
|         |                                    |        | Resource Ownership & Lifetime (8)          |
|         |                                    |        | I/O & Error Boundaries (8)                 |
|         |                                    |        | Strict Build, Sanitizer & Tests (8)        |
+---------+------------------------------------+--------+--------------------------------------------+
| Part B  | Unknown Bug Investigation          | 25     | Symptom & 3-5 Hypotheses (6)               |
|         |                                    |        | Targeted Experiment & Evidence (7)         |
|         |                                    |        | Root Cause & Contract Analysis (4)         |
|         |                                    |        | Minimal Principled Fix (4)                 |
|         |                                    |        | Automated Regression Proof (4)             |
+---------+------------------------------------+--------+--------------------------------------------+
| Part C  | ELF / Link / Binary Evidence       | 20     | Symbol Linkage & Binding (4)               |
|         |                                    |        | Relocation Entry Analysis (4)              |
|         |                                    |        | Section Placement Analysis (4)             |
|         |                                    |        | Compiler vs Linker Distinction (4)         |
|         |                                    |        | Disassembly-to-C Lowering (4)              |
+---------+------------------------------------+--------+--------------------------------------------+
| Part D  | Process / FD / Concurrency Debug   | 25     | Interacting Failure Analysis (6)           |
|         |                                    |        | Two Independent Evidence Channels (8)      |
|         |                                    |        | Runtime Root-Cause Proof (6)               |
|         |                                    |        | Multi-Cycle Clean Regression (5)           |
+---------+------------------------------------+--------+--------------------------------------------+
| Total   |                                    | 100    |                                            |
+---------+------------------------------------+--------+--------------------------------------------+
```

---

## 2. Hard Pass Criteria

A submission passes if and only if **all six** conditions are met:

1. **Overall Score:** Total points $\ge \mathbf{75 / 100}$.
2. **Individual Part Floor:** Every part achieves $\ge \mathbf{60\%}$:
   - Part A $\ge 18 / 30$
   - Part B $\ge 15 / 25$
   - Part C $\ge 12 / 20$
   - Part D $\ge 15 / 25$
3. **Diagnostic Mastery Bar:** Part B achieves $\ge \mathbf{70\%}$ ($\ge 17.5 / 25$).
4. **Runtime Root-Cause Proof:** Part D proves the resolution of both interacting faults with live runtime trace evidence.
5. **Zero Resource Leaks:** Part A executes completely clean under AddressSanitizer/LeakSanitizer with zero memory leaks and independently demonstrates zero leaked owned file descriptors via `/proc/<pid>/fd` runtime audit.
6. **Integrity Attestation:** Signed AI-Free Attestation is completed.

---

## 3. Evidence-First Scoring Rule

* **A patch without an evidence chain cannot receive full credit:** If a bug fix is submitted without evidence of hypothesis falsification or root-cause identification, points for the diagnostic stages are withheld.
* **Workarounds are penalized:** Adding arbitrary `sleep()` or `usleep()` delays, widening buffers to avoid overflow without bounds checks, or using `static` to hide dangling pointers results in zero credit for the fix dimension.
