# Phase 1 Final Gate Assessment: Linux Systems & Concurrency Foundations

> **Target Audience:** Learners completing Phase 1 of `embed-system` (P1-M01 through P1-M10)  
> **Scored Mode:** **AI-Free**, official documentation allowed  
> **Canonical Time Budget:** **5–6 hours** (300–360 minutes, single day or 2 sessions)  
> **Total Score:** **100 points** across four Parts (30 / 25 / 20 / 25)  
> **Calibration Status:** UNVERIFIED — pending first learner attempt  

---

## 1. Purpose

This Final Gate evaluates whether you have developed independent systems engineering and debugging capability in Linux and System C. It tests how you reason about resource lifetimes, file descriptors, binary compilation and linkage, and multithreaded synchronization.

This is **not** an academic quiz. There are no LeetCode algorithms or syntax memory challenges. Every part tests concrete engineering evidence captured from execution, sanitizers, binary inspection, or system state.

$$\mathbf{Technical\ Correctness} > \mathbf{Observable\ Evidence} > \mathbf{Mental\ Model} > \mathbf{Debugging\ Transfer} > \mathbf{Source\ Quality}$$

---

## 2. Assessment Structure

| Part | Title | Weight | Time Budget | Key Deliverable / Evidence |
|---|---|---:|---:|---|
| **Part A** | Blank-Directory Build | 30 pts | 90–105 min | Build `sifter` utility from scratch; $\ge 4$ files; zero memory & FD leaks. |
| **Part B** | Unknown Bug Investigation | 25 pts | 75–90 min | 8-step diagnostic report; bounded reproduction; runtime evidence; regression. |
| **Part C** | ELF / Link / Binary Evidence | 20 pts | 60–75 min | 5 canonical evidence tasks: symbols, relocations, sections, compile vs link, disasm. |
| **Part D** | Process / FD / Concurrency Debug | 25 pts | 75–90 min | Interacting OS + concurrency fault; 2 evidence channels; root-cause proof. |
| **Total** | | **100 pts** | **300–360 min** | Minimum passing score: **75 / 100** |

---

## 3. Passing Rules

To pass the Phase 1 Final Gate, your submission must satisfy all of the following:

1. **Overall Score:** Total score $\ge \mathbf{75 / 100}$.
2. **Floor per Part:** Every individual Part must achieve at least **60%**:
   * Part A $\ge 18 / 30$
   * Part B $\ge 15 / 25$
   * Part C $\ge 12 / 20$
   * Part D $\ge 15 / 25$
3. **Diagnostic Mastery Bar:** Part B must achieve at least **70%** ($\ge 17.5 / 25$).
4. **Runtime Root-Cause Proof:** Part D must include actual runtime evidence demonstrating both interacting defects are resolved.
5. **Zero Resource Leaks:** Part A must execute completely clean under AddressSanitizer with zero memory leaks and zero leaked file descriptors in `/proc/<pid>/fd`.
6. **Signed Attestation:** A signed AI-Free Attestation must accompany the submission.

---

## 4. Execution Workflow

1. **Record Environment:** Fill in `ENVIRONMENT.md` with your host toolchain versions (`uname -a`, `gcc`, `make`, `gdb`, etc.).
2. **Part A:** Enter an empty directory and implement the `sifter` utility according to `part-a/README.md`.
3. **Part B:** Receive your assigned variant (`variants/b1`, `b2`, or `b3`) and execute the 8-step diagnostic loop in `SUBMISSION_TEMPLATE.md`.
4. **Part C:** Build host relocatable objects in `part-c/` and capture the five required binary evidence items.
5. **Part D:** Reproduce the interacting stall in `part-d/`, gather evidence across two channels, repair the code, and prove regression.
6. **Package Submission:** Compile your code, logs, and completed `SUBMISSION_TEMPLATE.md`.
