# Phase 2 Final Gate: Submission & Diagnostic Record

> **MANDATORY INSTRUCTION FOR EXECUTORS & TEST AUTHORS**:  
> This template must remain completely blank of answers. Do **NOT** pre-populate answers, diagnostic hypotheses, code diffs, or evidence interpretations.

---

## 1. Learner AI-Free Attestation

```markdown
### AI-Free Examination Attestation

I hereby attest on my engineering honor that:
1. All diagnostic hypotheses, root-cause analyses, calculations, code fixes, and regression proofs submitted in this document were conceived, written, and verified independently by me without the use of generative AI tools (such as ChatGPT, Claude, Gemini, Copilot, Cursor, or local LLMs).
2. All documentation consulted during this 210-minute assessment consisted exclusively of official primary silicon manuals (RM0008, PM0056, DS5319), Arm architecture manuals (DDI 0403E.e), upstream source repositories (FreeRTOS-Kernel, CMSIS), GNU manuals, and canonical repository notes.
3. No terminal outputs, GDB register dumps, stack traces, oscilloscope waveforms, or benchmark measurements were fabricated, simulated, or artificially altered.
4. I did not open, inspect, or copy any file under the `reviewer/` directory prior to submitting this work.

- Learner Name / GitHub Handle: __________________________________________________
- Date of Completion:           __________________________________________________
- Total Elapsed Scored Time:    ______ hours ______ minutes (Canonical Budget: 210 min)
- Target Board Profile Used:    __________________________________________________
- Signature / Confirmation:     __________________________________________________
```

---

## 2. Timing & Execution Summary

| Part | Start Time | End Time | Elapsed Minutes | Budget | Notes / Permitted Pauses |
|---|---|---|---|---|---|
| **Part A** (Startup & Linker) | | | | 45 min | |
| **Part B** (Peripheral & DMA) | | | | 50 min | |
| **Part C** (Scheduler & Context Switch) | | | | 50 min | |
| **Part D** (Concurrency & HW/SW Debug) | | | | 65 min | |
| **Total** | | | | **210 min** | |

---

## 3. Environment & Documentation Record

### 3.1 Host Toolchain & System Info
* Host OS / Architecture:
* `arm-none-eabi-gcc --version`:
* `arm-none-eabi-readelf --version`:
* `make --version`:
* Debug Probe (ST-Link / J-Link / CMSIS-DAP) & OpenOCD version:
* Measurement Instruments (Scope / Logic Analyzer model):

### 3.2 Official Sources Consulted
* List specific manual sections, register tables, or upstream headers consulted:

---

## 4. Part A — Bare-Metal Startup & Linker Reasoning (25 Points)

### 4.1 Annotated Startup Path
* Step 1 (Hardware Reset & MSP):
* Step 2 (Reset_Handler entry & Thumb bit):
* Step 3 (SystemInit pre-runtime invariant):
* Step 4 (.data initialization from Flash LMA to SRAM VMA):
* Step 5 (.bss zeroing loop):
* Step 6 (__libc_init_array constructor dispatch):
* Step 7 (Branch to main):

### 4.2 Linker & ELF Inspection Evidence
* Command executed (`readelf -S`, `readelf -s`, or `nm`):
* Verbatim Evidence Output:
* *Observation:*
* *Interpretation:*
* *Non-Proof Limits:*

### 4.3 Diagnostic Hypotheses & Root Cause
* Hypotheses Considered:
* Root Cause in Linker Script / Startup Flow:

### 4.4 Minimal Correction & Regression Proof
* Exact file modified:
* Minimal Diff / Fix applied:
* Regression verification command and output:

---

## 5. Part B — Peripheral Register & DMA Data-Path Diagnosis (25 Points)

### 5.1 Clock Tree & Rate Calculations
* System Clock ($f_{\text{SYSCLK}}$) & APB1/APB2 Prescalers:
* TIM3 Timer Prescaler (PSC), Auto-Reload (ARR), and TRGO Frequency:
* ADC Clock Prescaler (ADCPRE) & $f_{\text{ADCCLK}}$ calculation ($\le 14\text{ MHz}$ constraint):
* Sample Time ($t_{\text{SMP}}$) & Total Conversion Time ($t_{\text{CONV}}$):

### 5.2 Peripheral Register & Buffer Audit
* Verbatim Register Dump Output (`TIM3->CR2`, `ADC1->CR2`, `DMA1_Channel1->CCR`, `CNDTR`):
* Verbatim Buffer Memory Dump Output (`g_adc_buffer`):
* *Observation:*
* *Interpretation:*
* *Non-Proof Limits:*

### 5.3 Root Cause Analysis & Data-Path Correction
* Root Cause in Register Bit Configuration:
* Minimal Code Change:
* Regression verification command and output:

---

## 6. Part C — FreeRTOS Scheduling & Context Switch Mechanics (25 Points)

### 6.1 Exception Stack Frame & Context Switch Derivation
* Exception entry mode & active stack pointer (MSP vs PSP):
* Values of hardware-saved frame registers (`r0-r3, r12, lr, pc, xpsr`):
* Software-saved frame registers (`r4-r11`) location and address range:
* `EXC_RETURN` value and architectural meaning:
* Calculation of `pxCurrentTCB->pxTopOfStack` before and after PendSV:

### 6.2 NVIC Priority & BASEPRI Safety Audit
* Interrupt IRQn inspected:
* Encoded NVIC Priority Byte from `NVIC->IP[...]`:
* CMSIS Logical Priority calculation:
* Comparison with `configMAX_SYSCALL_INTERRUPT_PRIORITY` (`0x50` / logical 5):
* Assessment of `BASEPRI` masking behavior and safety of calling `FromISR` API:

### 6.3 Minimal Correction & Verification Proof
* Recommended NVIC Priority Fix:
* Verification calculation or test output:

---

## 7. Part D — Concurrency, Priority Inversion & HW/SW Debugging (25 Points)

### 7.1 Symptom & Own Description
1. **Symptom:**
2. **Own Description:**

### 7.2 Diagnostic Hypotheses (3–5 Independent Hypotheses)
* Hypothesis 1:
* Hypothesis 2:
* Hypothesis 3:
* Hypothesis 4 (optional):

### 7.3 Multi-Channel Evidence Collection
* **Channel 1 (GDB / RTOS Task State / Priority):**
  - Command / Action:
  - Verbatim Output:
  - *Observation:*
  - *Interpretation:*
  - *Non-Proof Limits:*
* **Channel 2 (Timing Markers / Watchdog Reset Flag / GPIO):**
  - Command / Action:
  - Verbatim Output:
  - *Observation:*
  - *Interpretation:*
  - *Non-Proof Limits:*

### 7.4 Narrow Scope & Root Cause
* Scope Narrowing Reasoning:
* Root Cause (Interaction between synchronization primitive, priority inversion, and watchdog):

### 7.5 Minimal Principled Fix & Regression Proof
* Code Diffs Applied:
* Multi-cycle regression test output:

---

## 8. Explicit List of Unverified Items

List all items where live hardware or instrumentation could not be confirmed:
* Example: "Physical oscilloscope waveform capture: UNVERIFIED (Headless host environment)"
* Item 1:
* Item 2:

---

## 9. Reviewer Evaluation & Score Sheet (Reserved for Reviewer)

```markdown
+=============================================================================+
|                        OFFICIAL REVIEWER SCORE SHEET                        |
+=============================================================================+
| Part    | Section Name                       | Max Pts | Floor | Score | Result |
+---------+------------------------------------+---------+-------+-------+--------+
| Part A  | Bare-Metal Startup & Linker        | 25.0    | 15.0  |       |        |
| Part B  | Peripheral Register & DMA Diagnosis| 25.0    | 15.0  |       |        |
| Part C  | FreeRTOS Scheduling & Context      | 25.0    | 15.0  |       |        |
| Part D  | Concurrency & HW/SW Debugging      | 25.0    | 17.5  |       |        |
+---------+------------------------------------+---------+-------+-------+--------+
| Total   | Cumulative Score                   | 100.0   | 75.0  |       |        |
+=============================================================================+
| Hard Floor Checks:                                                          |
| [ ] Overall Score >= 75.0                                                   |
| [ ] Part A >= 15.0 (60%)                                                    |
| [ ] Part B >= 15.0 (60%)                                                    |
| [ ] Part C >= 15.0 (60%)                                                    |
| [ ] Part D >= 17.5 (70%)                                                    |
| [ ] Zero Memory Corruption Verified                                         |
| [ ] Evidence Quality & Non-Proof Confirmed                                  |
| [ ] Signed AI-Free Attestation Present                                      |
+-----------------------------------------------------------------------------+
| FINAL RESULT: [ PASS / FAIL ]                                               |
| Reviewer Signature: _______________________ Date: _________________________ |
+=============================================================================+
```
