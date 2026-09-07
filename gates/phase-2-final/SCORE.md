# Phase 2 Final Gate: Scoring Rubric & Evaluation Standard

## 1. Score Distribution Matrix (100 Points Total)

```
+====================================================================================================+
|                                    SCORE DISTRIBUTION MATRIX                                       |
+=========+====================================+========+============================================+
| Part    | Description                        | Points | Sub-Dimensions (Points)                    |
+=========+====================================+========+============================================+
| Part A  | Bare-Metal Startup & Linker        | 25     | Startup & Linker Mental Model (5)          |
|         | Reasoning                          |        | ELF / Symbol / Map Evidence (5)            |
|         |                                    |        | Root Cause Reasoning (5)                   |
|         |                                    |        | Minimal Principled Correction (5)          |
|         |                                    |        | Automated Regression Proof (5)             |
+---------+------------------------------------+--------+--------------------------------------------+
| Part B  | Peripheral Register & DMA          | 25     | Clock Tree & Trigger Rate Calculation (5)  |
|         | Data-Path Diagnosis                |        | Trigger / ADC / DMA Route Diagnosis (5)    |
|         |                                    |        | Buffer & Interrupt Lifecycle Reasoning (5) |
|         |                                    |        | Observable Evidence & Non-Proof (5)        |
|         |                                    |        | Minimal Fix & Regression Verification (5)  |
+---------+------------------------------------+--------+--------------------------------------------+
| Part C  | FreeRTOS Scheduling & Context      | 25     | Cortex-M3 Exception & Stack Frame Model (5)|
|         | Switch Mechanics                   |        | PendSV Assembly & TCB Pointer Reasoning (5)|
|         |                                    |        | NVIC Priority vs BASEPRI Safety Audit (5)  |
|         |                                    |        | Evidence Interpretation & Non-Proof (5)    |
|         |                                    |        | Priority Repair & Calculation Proof (5)    |
+---------+------------------------------------+--------+--------------------------------------------+
| Part D  | Concurrency, Priority Inversion    | 25     | Independent 3–5 Hypotheses Formulation (4) |
|         | & HW/SW Debugging                  |        | Two Independent Evidence Channels (6)      |
|         |                                    |        | Root Cause & Real-Time Interaction (5)     |
|         |                                    |        | Principled Fix (Mutex & Watchdog) (5)      |
|         |                                    |        | Multi-Cycle Clean Regression Proof (5)     |
+=========+====================================+========+============================================+
| Total   |                                    | 100    | Hard Pass Threshold: >= 75 / 100           |
+=========+====================================+========+============================================+
```

---

## 2. Hard Pass Floors & Minimum Requirements

A submission is awarded **PASS** if and only if **all eight** mandatory criteria are met:

| Criterion | Requirement | Threshold |
|---|---|---:|
| **Overall Total Score** | Cumulative score across all 4 parts | $\ge \mathbf{75.0 / 100}$ |
| **Part A Floor** | Bare-Metal Startup & Linker Reasoning | $\ge \mathbf{15.0 / 25}$ (60%) |
| **Part B Floor** | Peripheral Register & DMA Data-Path Diagnosis | $\ge \mathbf{15.0 / 25}$ (60%) |
| **Part C Floor** | FreeRTOS Scheduling & Context Switch Mechanics | $\ge \mathbf{15.0 / 25}$ (60%) |
| **Part D Floor (Mastery Bar)** | Concurrency, Priority Inversion & Debugging | $\ge \mathbf{17.5 / 25}$ (70%) |
| **Zero Memory Corruption** | No stack smash, pointer corruption, or wild writes | **Required (Zero Tolerance)** |
| **Evidence Quality** | Verifiable register/ELF/trace evidence for every fix | **Required** |
| **Integrity Attestation** | Signed AI-Free Attestation | **Required** |

Failure to achieve any individual floor results in an automatic overall **FAIL**, regardless of total points.

---

## 3. Evidence-First Scoring Rules

1. **Technical Correctness > Observable Evidence > Prose Polish**:
   A submission with excellent technical evidence and concise explanations outscores verbose explanations lacking verifiable terminal/register data.
2. **No Evidence, No Credit**:
   A patch submitted without supporting diagnostic logs, register dumps, or disassembly analysis receives zero points for the hypothesis, diagnostic, and root-cause dimensions.
3. **Penalization of Heuristic Workarounds**:
   Inserting `vTaskDelay()` or busy loops to hide race conditions, increasing arbitrary buffer sizes to mask memory leaks, or disabling watchdog timers results in **0 points** for the fix dimension.
4. **Distinction Between Configuration and Execution**:
   Credit for peripheral verification requires proving that the peripheral actually functioned (e.g. data in buffer, interrupt counter advancing), not merely that control register bits were written.
