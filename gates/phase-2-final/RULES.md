# Phase 2 Final Gate: Assessment Rules

## 1. Scored Mode: AI-Free (Strict)

The scored assessment evaluates your independent engineering mental model, diagnostic reasoning, and ability to transfer embedded systems mechanisms to unfamiliar problems.

### 1.1 Prohibited Resources
* Generative AI tools (including ChatGPT, Claude, Gemini, GitHub Copilot, Cursor, code completion engines, or local LLMs) for:
  - formulating diagnostic hypotheses;
  - interpreting compiler, linker, or runtime errors;
  - generating or repairing code, linker scripts, or assembly;
  - writing diagnostic postmortems or submission text.
* Copying solutions or asking peers, mentors, or online forums during the timed exam.
* Opening, inspecting, or copying any file under `reviewer/` before scoring is completed.

### 1.2 Permitted Resources
* **Official Primary Specifications & Datasheets**:
  - STMicroelectronics RM0008 Reference Manual (DocID 13902 Rev 21);
  - STMicroelectronics PM0056 Cortex-M3 Programming Manual (DocID 15491 Rev 7);
  - STMicroelectronics DS5319 Datasheet (DocID 13587 Rev 20);
  - Armv7-M Architecture Reference Manual (Arm DDI 0403E.e).
* **Official Upstream Source Code**:
  - FreeRTOS-Kernel V11.3.0 upstream source code;
  - CMSIS_5 v5.9.0 and cmsis-device-f1 v4.3.5 pinned headers.
* **Toolchain & Tool Documentation**:
  - GNU Make, GCC, GDB, and Binutils official manuals;
  - OpenOCD user documentation.
* **Repository Curriculum & Canonical Notes**:
  - Canonical notes, source ledgers, and lab exercises from Phase 2 (P2-M01 through P2-M07).
* **Local Inspection & Hardware Tools**:
  - `arm-none-eabi-readelf`, `nm`, `objdump`, `size`;
  - Live SWD debugger (`GDB`, `OpenOCD`);
  - Oscilloscope and logic analyzer;
  - Local source code and build artifacts.

$$\mathbf{AI\text{-}Free} \neq \mathbf{Documentation\text{-}Free}$$

Consulting silicon reference manuals, register maps, architecture manuals, and API headers is standard professional engineering practice and is explicitly encouraged.

---

## 2. Timing Policy

* **Target Budget:** **210 minutes (3.5 hours)** continuous or single-session timed exam.
* **Recommended Breakdown**:
  - Part A: 45 min
  - Part B: 50 min
  - Part C: 50 min
  - Part D: 65 min
* **Stop the Clock:** You may pause the timer only for emergency external interruptions, meals, or brief physical breaks.
* **Do NOT Stop the Clock:** Reading manuals, disassembling binaries, stepping through GDB, calculating prescalers, running Make, or writing the diagnostic report is scored time.
* Record exact start, end, and elapsed times in `SUBMISSION_TEMPLATE.md`.

---

## 3. Evidence, Interpretation & Non-Proof Policy

Every diagnostic report and engineering claim must distinguish three elements:

1. **Observation / Evidence:** Verbatim, unedited terminal output, register readouts, linker map lines, or trace data captured from tools or target execution.
2. **Interpretation:** What the observed evidence specifically proves or disproves regarding your hypothesis.
3. **Non-Proof:** An explicit, disciplined statement of what the evidence does **not** prove (e.g. *"A static register bit check does not prove that hardware conversions or DMA requests actually occurred"*, or *"A clean single-run execution does not prove absence of priority inversion under different thread arrival schedules"*).

### Evidence Integrity Rule
Never fabricate:
- GDB register dumps or stack frames;
- terminal logs or test outputs;
- oscilloscope or logic analyzer waveforms;
- watchdog timeout or reset timings.

If physical hardware or probe instrumentation is unavailable, record the evidence honestly as `UNVERIFIED` and use static/ELF/disassembly channels to analyze the contract.

---

## 4. Diagnostic Record Format

For all debugging tasks, you must complete the disciplined 8-step chain:

```text
1. Symptom
2. Own Description
3. 3–5 Hypotheses
4. Experiment
5. Evidence (Observation / Interpretation / Non-Proof)
6. Narrow Scope
7. Root Cause
8. Fix & Regression
```

A patch submitted without an evidence chain cannot receive full diagnostic credit. Inserting arbitrary timing delays (`vTaskDelay()`, busy loops) to mask concurrency bugs or starvation is strictly rejected.

---

## 5. Reviewer Isolation Rule

All canonical solution keys, variant mappings, reference fixes, and regression oracles are placed exclusively under `reviewer/`.
Learners must **not** inspect `reviewer/` at any time before scoring is finalized.
