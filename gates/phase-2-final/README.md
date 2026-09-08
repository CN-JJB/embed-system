# Phase 2 Final Gate Assessment: STM32 Bare-Metal Foundations & FreeRTOS Kernel Mechanisms

> **Target Audience:** Learners completing Phase 2 of `embed-system` (P2-M01 through P2-M07)  
> **Scored Mode:** **AI-Free**, official documentation and pinned upstream specifications allowed  
> **Canonical Time Budget:** **3.5 hours** (210 minutes, single timed session)  
> **Total Score:** **100 points** across four Parts (25 / 25 / 25 / 25)  
> **Passing Threshold:** Total $\ge \mathbf{75 / 100}$, Part A $\ge 15.0$ (60%), Part B $\ge 15.0$ (60%), Part C $\ge 15.0$ (60%), Part D $\ge 17.5$ (70%)  
> **Calibration Status:** UNVERIFIED — pending first learner attempt  

---

## 1. Purpose

The Phase 2 Final Gate is an independent, evidence-backed transfer assessment covering bare-metal MCU initialization, peripheral data movement, FreeRTOS kernel mechanics, and real-time concurrency debugging.

This assessment does not test LeetCode algorithms or syntax recall. Every part tests concrete engineering evidence captured from linker scripts, ELF headers, memory-mapped peripheral registers, context switch stack frames, and real-time task behavior:

$$\mathbf{Technical\ Correctness} > \mathbf{Observable\ Evidence} > \mathbf{Mental\ Model} > \mathbf{Debugging\ Transfer} > \mathbf{Source\ Quality}$$

---

## 2. Assessment Structure

| Part | Title | Weight | Time Budget | Key Deliverable / Evidence |
|---|---|---:|---:|---|
| **Part A** | Bare-Metal Startup & Linker Reasoning | 25 pts | 45 min | Startup path reconstruction; Binutils ELF/section audit; minimal linker fix; regression proof. |
| **Part B** | Peripheral Register & DMA Data-Path Diagnosis | 25 pts | 50 min | Clock & trigger rate calculation; GDB register & DMA buffer audit; circular path repair; regression proof. |
| **Part C** | FreeRTOS Scheduling & Context Switch Mechanics | 25 pts | 50 min | Cortex-M3 exception frame analysis; PSP/MSP calculation; TCB list audit; NVIC priority & BASEPRI safety audit. |
| **Part D** | Concurrency & HW/SW Debugging | 25 pts | 65 min | 8-step diagnostic report; 2 independent evidence channels; concurrency hazard resolution & regression proof. |
| **Total** | | **100 pts** | **210 min** | Minimum passing score: **75 / 100** |

---

## 3. Passing Rules

A submission passes if and only if **all eight** conditions are satisfied:

1. **Overall Score:** Total score $\ge \mathbf{75 / 100}$.
2. **Individual Part Floors:**
   * Part A $\ge 15.0 / 25$ (60%)
   * Part B $\ge 15.0 / 25$ (60%)
   * Part C $\ge 15.0 / 25$ (60%)
   * Part D $\ge 17.5 / 25$ (70%)
3. **Zero Unexplained Memory Corruption:** No stack overflows, buffer overruns, or unmapped memory dereferences.
4. **Evidence Chain:** Every bug diagnosis and repair must provide verifiable register, map, disassembly, or trace evidence.
5. **Two Evidence Channels for Part D:** Part D requires at least two distinct, corroborating evidence channels (e.g. GDB task state + timing/watchdog reset flag).
6. **No Arbitrary Timing Hacks:** Adding `vTaskDelay()` or busy loops to hide race conditions or mask deadline violations is strictly rejected.
7. **Reviewer Material Isolation:** Reviewer materials under `reviewer/` must remain uninspected until scoring is completed.
8. **Signed Attestation:** A signed AI-Free Attestation must accompany the submission in `SUBMISSION_TEMPLATE.md`.

---

## 4. Execution Workflow

1. **Verify Environment:** Check and record host toolchain details and equipment in `ENVIRONMENT.md`.
2. **Start Timer:** Note your start time in `SUBMISSION_TEMPLATE.md`. The target budget is 210 minutes.
3. **Part A (Startup & Linker):** Enter `part-a/`, investigate the seeded boot fault, collect ELF/symbol evidence, apply the minimal fix, and verify regression.
4. **Part B (Peripheral & DMA):** Enter `part-b/`, inspect the clock/trigger configuration and DMA buffer evidence, identify the register defect, apply the fix, and verify.
5. **Part C (Scheduler & Context Switch):** Enter `part-c/`, audit the exception stack frame, compute PSP/MSP and TCB pointers, and audit the NVIC priority configuration.
6. **Part D (Concurrency & Debugging):** Enter `part-d/`, execute the 8-step diagnostic chain, collect multi-channel evidence, resolve the concurrency fault, and verify regression.
7. **Stop Timer:** Record total elapsed time in `SUBMISSION_TEMPLATE.md`.
8. **Package Submission:** Deliver your completed `SUBMISSION_TEMPLATE.md` to the reviewer. Do not inspect `reviewer/` until scoring is complete.

---

## 5. Scope & Assessment Governance Note

> [!IMPORTANT]
> Merging this Gate package into the repository does **not** indicate that the learner has passed P2-GATE. Phase 2 reaches 100% completion only after an actual, genuine, AI-Free learner attempt is independently scored and achieves a PASS result.
