# Part B — Unknown Bug Investigation (25%)

## 1. Objective
Demonstrate independent diagnostic ability on an unfamiliar, un-rehearsed defect using disciplined hypothesis formulation, targeted experimentation, and concrete runtime evidence.

---

## 2. Assessment Rules & Protocol

### 2.1 Variant Assignment
You will be assigned one variant from the variant pool (located in `variants/b1/`, `variants/b2/`, or `variants/b3/`). Each variant tests an independent systems engineering domain:
* `B-MEM`: Memory lifetime, allocation extent, and pointer ownership boundaries.
* `B-FD`: File descriptor lifecycle, owned vs borrowed FDs, and cleanup boundaries.
* `B-CONC`: Concurrency synchronization, multi-field invariants under contention, and thread lifecycle.

### 2.2 Bounded Reproduction Harness
Every variant includes a bounded reproduction harness:
```bash
cd variants/<assigned-variant>/
make repro
./repro
```
The harness includes a safety watchdog timer (terminating within 3 seconds) to prevent infinite loops or system stalls while safely reproducing the failure symptom.

### 2.3 Diagnostic Record Requirement
You must document your investigation in `SUBMISSION_TEMPLATE.md` using the canonical 8-step protocol:
1. **Symptom:** Exact observed failure from `./repro`.
2. **Own Description:** Technical explanation of the failure in your own words.
3. **3–5 Hypotheses:** Competing physical/logical hypotheses formulated **before** running tools.
4. **Targeted Experiment:** A specific test designed to falsify competing hypotheses.
5. **Evidence:** Verbatim output (debugger state, sanitizer report, `/proc` audit, or syscall log) with explicit *Observation*, *Interpretation*, and *Non-Proof* limits.
6. **Narrow Scope:** Localization to the exact contract or boundary.
7. **Root Cause:** Naming the broken contract or invariant.
8. **Fix & Regression:** Minimal principled fix and automated proof of repeated clean runs.

---

## 3. Hard Pass Criteria for Part B
* Score $\ge 17.5 / 25$ (**70% passing bar**).
* **Zero points for patch guessing:** A patch submitted without supporting diagnostic evidence receives zero points for the diagnosis and root-cause scoring dimensions.
