# Phase 1 Final Gate: Assessment Rules

## 1. Scored Mode: AI-Free

The scored assessment measures your independent mental model, diagnostic intuition, and systems reasoning.

### 1.1 Permitted Resources
* Linux manual pages (`man 2`, `man 3`, `man 7`).
* GNU GCC, GDB, Make, and Binutils official manuals.
* C17 Standard (ISO/IEC 9899:2018) and POSIX.1-2017 specifications.
* Canonical repository notes and source ledgers from P1-M01 through P1-M10.
* Standard local inspection tools (`GDB`, `readelf`, `nm`, `objdump`, `strace`, `/proc`).

### 1.2 Prohibited Resources
* Generative AI tools (ChatGPT, Claude, Gemini, GitHub Copilot, Cursor, or local LLMs) for hypothesis creation, code repair, error diagnosis, or postmortem authoring.
* Copying solutions from peers, previous cohorts, or external online blogs.
* Inspecting hidden reference directories or solution files before the assessment is scored.

$$\mathbf{AI\text{-}Free} \neq \mathbf{Documentation\text{-}Free}$$

Looking up function signatures, system call behavior, ABI details, or compiler warning options in official documentation is standard engineering practice and is explicitly encouraged.

---

## 2. Timing Policy

* **Target Budget:** 5–6 hours (300–360 minutes).
* **Stop the Clock:** You may pause the timer for meals, sleep, and physical external interruptions.
* **Do NOT Stop the Clock:** Reading man-pages, researching specifications, running builds, or analyzing debugger logs is part of the scored time.
* Record actual start, end, and elapsed times in `SUBMISSION_TEMPLATE.md`.

---

## 3. Evidence, Interpretation & Non-Proof Policy

Every diagnostic report (Parts B and D) and binary analysis (Part C) must distinguish three elements:

1. **Evidence:** The verbatim, unedited output captured from the tool (sanitizer report line, `/proc/self/fd` listing, GDB thread state, `readelf` output).
2. **Interpretation:** What the observation specifically proves or disproves regarding your hypothesis.
3. **Non-Proof:** An explicit statement of what the evidence does **not** prove (e.g., *"One clean TSan run does not prove all thread schedules are race-free"*, or *"ASan-clean exit does not prove byte order correctness"*).

### Evidence Integrity
Do **not** fabricate terminal output, sanitizer logs, debugger frames, or execution timings. If a tool is unavailable in your environment (e.g. `strace` or `TSan`), document it honestly as `UNVERIFIED` or `PARTIALLY VERIFIED` and use an approved equivalent evidence channel.

---

## 4. Diagnostic Record Format

For all debugging tasks, you must complete the full 8-step chain:

```text
1. Symptom
2. Own Description
3. 3–5 Hypotheses
4. Experiment
5. Evidence
6. Narrow Scope
7. Root Cause
8. Fix & Regression
```

A patch submitted without supporting diagnostic evidence receives zero points for the diagnosis and root-cause scoring dimensions. Inserting arbitrary `sleep()` or `usleep()` delays to hide race conditions is rejected as an invalid workaround.
