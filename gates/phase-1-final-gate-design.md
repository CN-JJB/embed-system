# Phase 1 Final Gate Specification: Linux Systems & Concurrency Foundations

> **Document Type:** Specification / Design Document  
> **Status:** Candidate Draft — Ready for Leader Review  
> **Canonical Target:** Phase 1 Part 11 Capstone Assessment  
> **Target Audience:** Curriculum authors, evaluators, and Phase 1 learners completing P1-M01 through P1-M10  
> **Evaluation Mode:** AI-Free core execution + Documentation Allowed  
> **Time Budget:** **5–6 hours** (300–360 minutes, single day or modular across 2 sessions)  
> **Score Weighting:** **Part A (30%) / Part B (25%) / Part C (20%) / Part D (25%)**  
> **Passing Standard:** Overall $\ge 75/100$; every Part $\ge 60\%$; Part B $\ge 70\%$; Part D runtime root-cause proof; Part A zero unexplained leaks; signed AI-Free attestation

---

## 1. Purpose & Phase-Exit Capability

The Phase 1 Final Gate is the summative capstone assessment for Phase 1 of `embed-system` (spanning **P1-M01 Objects/Lifetime** through **P1-M10 Linux Systems Telemetry Service**). Its objective is to evaluate whether the learner has developed independent systems engineering capability rather than rote memorization.

### 1.1 Verified Phase-Exit Capabilities

Passing the Phase 1 Final Gate verifies that the learner can independently:
1. **Construct Systems C Software from a Blank Directory:** Design, write, structure, and build a self-contained Linux userspace utility without starter code or templates, enforcing strict ISO C17 compliance, explicit memory management, and robust error boundaries.
2. **Track Deterministic Resource Ownership & Lifetimes:** Explicitly delineate owned versus borrowed resources (pointers, buffers, file descriptors, synchronization primitives), ensuring deterministic reclamation on all error and exit paths.
3. **Execute Evidence-Driven Debugging:** Apply the canonical 8-step diagnostic chain:
   $$\text{Symptom} \rightarrow \text{Own Description} \rightarrow \text{Hypotheses} \rightarrow \text{Experiment} \rightarrow \text{Evidence} \rightarrow \text{Root Cause} \rightarrow \text{Fix} \rightarrow \text{Regression}$$
4. **Reason About the Linux OS Runtime Model:** Accurately reason about process address spaces, file descriptor tables, open file descriptions, copy-on-write across `fork()`, signal masks, and blocking system calls.
5. **Analyze Binary & Toolchain Mechanics:** Inspect and explain ELF object layouts, symbol visibility, relocation bindings, and compilation-vs-linking stages using standard binary utilities (`readelf`, `nm`, `objdump`).
6. **Diagnose Concurrency Invariants & Lifecycle Ordering:** Identify data races, multi-field invariant violations, condition-variable predicate loops, and shutdown synchronization sequences.

### 1.2 Explicit Non-Goals (What the Gate Does NOT Test)

* **No API Recall / Trivia:** Function signatures, `fcntl` command flags, or POSIX error numbers are not tested from memory. Consulting official documentation is expected.
* **No LeetCode / Synthetic Puzzles:** No abstract dynamic programming, balancing binary trees, or artificial puzzles. All tasks reflect real Linux systems failure modes.
* **No Boilerplate Volume:** The assessment evaluates architectural precision and diagnostic depth, not raw typing speed or lines of code.
* **No AI Prompting:** The gate evaluates human mental models and engineering reflexes under an **AI-Free** protocol.

### 1.3 Core Evaluation Hierarchy

Evaluator assessments adhere strictly to the repository evaluation hierarchy:

$$\mathbf{Technical\ Correctness} > \mathbf{Observable\ Evidence} > \mathbf{Mental\ Model} > \mathbf{Debugging\ Transfer} > \mathbf{Source\ Quality}$$

---

## 2. Canonical Time Budget

The Final Gate enforces a total scored time budget of **5–6 hours (300–360 minutes)**.

```
+----------------------------------------------------------------------------------------------------+
|                                    TIME ALLOCATION & PACING                                        |
+---------+------------------------------------+----------------+-------------------+----------------+
| Part    | Description                        | Weight         | Target Duration   | Time Limit     |
+---------+------------------------------------+----------------+-------------------+----------------+
| Part A  | Blank-Directory Build              | 30% (30 pts)   | 90 min            | 105 min max    |
| Part B  | Unknown Bug Investigation          | 25% (25 pts)   | 75 min            | 90 min max     |
| Part C  | ELF / Link / Binary Evidence       | 20% (20 pts)   | 60 min            | 75 min max     |
| Part D  | Process / FD / Concurrency Debug   | 25% (25 pts)   | 75 min            | 90 min max     |
+---------+------------------------------------+----------------+-------------------+----------------+
| Total   | Complete Final Gate Assessment     | 100% (100 pts) | 300 min (5.0 h)   | 360 min (6.0 h)|
+---------+------------------------------------+----------------+-------------------+----------------+
```

### Recommended Pacing Options
* **Single Intensive Day:** Session 1 (Parts A & C, ~2.5 h) $\rightarrow$ 1-hour break $\rightarrow$ Session 2 (Parts B & D, ~2.5–3 h).
* **Two-Day Split:**
  * *Day 1 (Constructive & Binary Foundations):* Part A (Blank-Directory Build) + Part C (ELF / Link Evidence).
  * *Day 2 (Diagnostic & Concurrency Verification):* Part B (Unknown Bug) + Part D (Process/FD/Concurrency Interacting Faults).

### Timing Rules
* The timer stops for meals, rest, and external physical interruptions.
* The timer **does not stop** for reading manual pages, searching official documentation, compiling code, or analyzing debugger traces.
* Actual elapsed times per Part must be recorded in the submission sheet. Unfinished work within the time limit is evaluated as diagnostic evidence.

---

## 3. Four-Part Overview & Weight Distribution

The assessment is divided into four distinct, non-overlapping Parts weighted **30 / 25 / 20 / 25**:

```
+----------------------------------------------------------------------------------------------------+
|                                     FOUR-PART GATE OVERVIEW                                        |
+--------------------------+--------+----------------------------------------------------------------+
| Part                     | Weight | Primary Assessment Focus                                       |
+--------------------------+--------+----------------------------------------------------------------+
| Part A: Blank-Directory  | 30%    | Synthesizing C17 systems software from scratch:                |
| Build                    |        | • Zero starter code; clean multi-file architecture (>= 4 files)|
|                          |        | • Explicit dynamic/static memory ownership, no leaks           |
|                          |        | • POSIX stream/FD error boundaries (EINTR, partial I/O)        |
|                          |        | • Clean Makefile with strict warnings & sanitizer targets      |
+--------------------------+--------+----------------------------------------------------------------+
| Part B: Unknown Bug      | 25%    | Diagnosing an unfamiliar, un-rehearsed defect:                 |
| Investigation            |        | • One random fault drawn from a rotational variant pool        |
|                          |        | • Bounded reproduction harness with safety watchdog timeout    |
|                          |        | • Complete 8-step diagnostic report; no patch guessing         |
|                          |        | • High passing bar (>= 70%) for diagnostic rigor               |
+--------------------------+--------+----------------------------------------------------------------+
| Part C: ELF / Link /     | 20%    | Canonical five evidence tasks on host relocatable objects:     |
| Binary Evidence          |        | • Symbol linkage & binding (GLOBAL / LOCAL / WEAK)             |
|                          |        | • Relocation entry inspection before final link                |
|                          |        | • Section placement (.text / .rodata / .data / .bss)           |
|                          |        | • Compiler diagnostic vs linker diagnostic distinction         |
|                          |        | • Short disassembly-to-C lowering observation                  |
+--------------------------+--------+----------------------------------------------------------------+
| Part D: Process / FD /   | 25%    | Two genuinely interacting failure modes across OS & threads:   |
| Concurrency Debugging    |        | • Hidden pair bridging process/FD and concurrency boundaries   |
|                          |        | • Partial fix leaves residual symptom; regression fails        |
|                          |        | • Requires two independent evidence channels (strace/proc/tsan)|
|                          |        | • Runtime proof of root cause and clean regression             |
+--------------------------+--------+----------------------------------------------------------------+
```

---

## 4. Part A Specification: Blank-Directory Build (30%)

### 4.1 Objective
Verify that the learner can independently architect, implement, and verify a complete, robust Linux userspace systems utility starting in a **completely empty directory with zero starter code or boilerplate**.

### 4.2 Problem Specification: Bounded Record Log Sifter (`sifter`)
The learner must create a standalone command-line data filtration utility (`sifter`) that reads structured text or stream data, validates schema and bounds, enforces error boundaries, and computes deterministic summary statistics.

#### Functional Requirements
1. **Command-Line Interface:**
   * Syntax: `./sifter [--input PATH|-] [--filter THRESHOLD] [--output PATH|-] [--stats]`
   * If `--input` is omitted or `-`, read from `STDIN_FILENO`. If a path is provided, open with `O_RDONLY | O_CLOEXEC`.
   * If `--output` is omitted or `-`, write to `STDOUT_FILENO`. If a path is provided, open with `O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC`, mode `0644`.
2. **Stream & Record Processing:**
   * Reads records formatted as: `<timestamp_ns:uint64> <sensor_id:uint8> <metric_val:int32>\n`.
   * Rejects lines exceeding 128 bytes with a discrete error count without buffer overflow.
   * Parses records safely: validates numeric ranges without undefined signed overflow.
   * Filters records whose `metric_val >= THRESHOLD` and emits accepted records to output.
3. **Resource Ownership & Lifecycle:**
   * **Borrowed vs Owned FDs:** `main` borrows `STDIN_FILENO` / `STDOUT_FILENO` and must never close them; path-opened FDs are owned by `main` and must be closed on **every** exit/error path.
   * **Buffer Ownership:** Dynamic buffers (if used) must have explicit ownership semantics. No memory leaks are permitted.
4. **Error Boundaries:**
   * Handles `EINTR` on slow read/write calls without aborting prematurely.
   * Handles partial writes by looping until all bytes are written.
5. **Build System & Toolchain Discipline:**
   * Strict flags: `-std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror`.
   * Standard targets in `Makefile`: `all`, `test`, `san`, `clean`.
   * `san` target builds with `-fsanitize=address,undefined -fno-omit-frame-pointer`.

### 4.3 Evaluation Deliverables
1. At least four source/header files with a coherent module split (for example, `main.c`, `sifter.c`, `sifter.h`, plus a parser/record module).
2. Self-contained `Makefile`.
3. Automated test script demonstrating normal input, empty input, invalid records, and `stdin` pipeline.
4. Documented **Resource Ownership Table** in submission markdown.

### 4.4 Hard Pass Criteria for Part A
* Score $\ge 18 / 30$ (60%).
* **Zero unexplained resource leaks:** ASan/LSan execution on valid, invalid, and empty inputs must report zero memory errors/leaks, and a separate `/proc/<pid>/fd` or equivalent FD audit must show no leaked owned descriptors. Any unclosed owned descriptor is a failure.

---

## 5. Part B Specification: Unknown Bug Investigation & Variant Pool (25%)

### 5.1 Objective
Verify that the learner can diagnose an unfamiliar defect using disciplined hypothesis testing and evidence selection, rather than guessing patches or applying pre-rehearsed fixes.

### 5.2 Anti-Leak & Non-Reuse Rules
> [!IMPORTANT]
> **No Rehearsed Faults:** Part B must **never** reuse exact faults already studied in P1-M01 through P1-M10, nor Phase 0 baseline faults:
> * Prohibited: M10 pre-read `stop_requested` check bug.
> * Prohibited: M10 signed codec `memcpy` vs cast bug.
> * Prohibited: M10 missing-broadcast shutdown hang.
> * Prohibited: M09 shared counter lost update race.
> * Prohibited: Phase 0 dangling stack pointer or duplicate symbol tasks.
>
> Furthermore, this public design document specifies only the **variant families and assessment contracts**. Exact mechanical seeds, buggy line locations, and hidden solutions are strictly quarantined to reviewer implementation files to prevent answer leaks.

### 5.3 Rotational Variant Pool Families
The implementation issue will construct concrete hidden fixtures across three distinct failure families. When a learner takes or retries Part B, one variant is assigned from the pool:

```
+----------------------------------------------------------------------------------------------------+
|                                  PART B VARIANT FAMILY CONTRACTS                                    |
+---------+-----------------------+-----------------------------+------------------------------------+
| Family  | Domain Assessed       | Evaluation Contract         | Evidence & Bounded Harness Rules   |
+---------+-----------------------+-----------------------------+------------------------------------+
| B-MEM   | Memory Lifetime,      | Tests object lifetime,      | • Bounded execution via watchdog   |
|         | Extent, & Ownership   | allocation extent, pointer  |   timer (alarm <= 3s) on crash/hang|
|         |                       | borrowing across contexts,  | • Reproduces with deterministic input|
|         |                       | and use-after-free/escape.  | • Requires sanitizer trace, GDB    |
|         |                       |                             |   inspection, or memory dump evidence|
+---------+-----------------------+-----------------------------+------------------------------------+
| B-FD    | File Descriptor &     | Tests descriptor lifecycle, | • Bounded execution ensuring child |
|         | Process Boundaries    | owned vs borrowed FDs,      |   reaping within <= 3s             |
|         |                       | child process inheritance,  | • Reproduces via pipeline harness  |
|         |                       | and error-path cleanup.     | • Requires /proc/<pid>/fd audit,   |
|         |                       |                             |   strace, or errno observations    |
+---------+-----------------------+-----------------------------+------------------------------------+
| B-CONC  | Concurrency Invariant,| Tests synchronization locks,| • Bounded execution terminating    |
|         | Race, & Lifecycle     | multi-field invariants under|   within <= 3s on deadlock/stall   |
|         |                       | contention, predicate waits,| • Reproduces under bounded stress  |
|         |                       | or shutdown coordination.   | • Requires TSan log, GDB thread bt,|
|         |                       |                             |   or invariant check output        |
+---------+-----------------------+-----------------------------+------------------------------------+
```

#### Family Governance Rules
1. **Family Isolation:** Each family tests an independent failure domain. A re-attempt or retry of Part B must draw from a **different family** (or an orthogonal, previously unrevealed seed within the family).
2. **Deterministic Reproducibility:** Every variant fixture must include a reproduction driver that deterministically manifests the failure without requiring unconstrained overnight runs.
3. **Bounded Harness:** The reproduction binary `./repro` must include an integrated safety watchdog timer (e.g., `alarm(3)`) ensuring it exits with an error code if stalled, preventing CI or terminal lockup.

### 5.4 Learner Experience & Submission
* The learner is provided with:
  1. A neutral symptom description (e.g., *"The data processing utility occasionally halts with an unexpected error code or stalls during specific batch runs"*).
  2. The source tree.
  3. The bounded reproduction script `./repro`.
* The learner is **not** provided with clues in comments, filenames, or function names (e.g., no `broken_*` tokens).
* **Required Submission Format (8-Step Diagnostic Chain):**
  ```text
  1. Symptom:          Exact observed failure behavior from ./repro.
  2. Own Description:  Explanation in the learner's own technical words.
  3. 3-5 Hypotheses:   Plausible mechanical explanations formulated BEFORE tool use.
  4. Experiment:       Targeted test designed to falsify competing hypotheses.
  5. Evidence:         Concrete terminal logs (GDB backtrace, sanitizer output, strace line).
  6. Root Cause:       The exact broken invariant or violated specification.
  7. Fix:              Minimal, principled code modification.
  8. Regression:       Automated proof demonstrating repeated clean executions.
  ```

### 5.5 Hard Pass Criteria for Part B
* Score $\ge 17.5 / 25$ (**70% threshold**).
* **Evidence-first requirement:** A correct patch submitted without a valid diagnostic evidence chain receives **zero points** for the diagnosis and root-cause scoring dimensions.

---

## 6. Part C Specification: ELF / Link / Binary Evidence (20%)

### 6.1 Objective
Verify solid, evidence-backed comprehension of translation units, ELF relocatable object files, symbol resolution, and compile-vs-link diagnostic boundaries using standard binary utilities (`readelf`, `nm`, `objdump`).

### 6.2 The Five Canonical Evidence Tasks
Part C presents the learner with a host-compiled multi-module object package and asks for five specific, evidence-backed demonstrations:

```
+----------------------------------------------------------------------------------------------------+
|                                    PART C FIVE CANONICAL TASKS                                     |
+---+----------------------------+-----------------------+-------------------------------------------+
| # | Canonical Task             | Inspection Tool       | Evidentiary Artifact Required             |
+---+----------------------------+-----------------------+-------------------------------------------+
| 1 | Symbol Linkage & Binding   | readelf -s / nm       | Inspect a relocatable object (.o); state  |
|   |                            |                       | whether a target symbol is GLOBAL, LOCAL  |
|   |                            |                       | (static), or WEAK, defined or UND, and    |
|   |                            |                       | which C source construct caused it.       |
+---+----------------------------+-----------------------+-------------------------------------------+
| 2 | Relocation Entry           | readelf -r            | Inspect an unlinked object file (.o);     |
|   | Inspection                 |                       | identify a relocation entry for a function|
|   |                            |                       | call or global reference; explain what the|
|   |                            |                       | static linker must patch at link time.    |
+---+----------------------------+-----------------------+-------------------------------------------+
| 3 | Section Placement          | readelf -S / size /   | Determine which ELF section (.text,       |
|   | (.text/.rodata/.data/.bss) | objdump -h            | .rodata, .data, .bss) holds named items;  |
|   |                            |                       | explain the C storage class and           |
|   |                            |                       | initialization rule determining placement.|
+---+----------------------------+-----------------------+-------------------------------------------+
| 4 | Compiler vs Linker         | gcc / make diagnostics| Distinguish whether an observed diagnostic|
|   | Diagnostic Distinction     |                       | occurred during compilation (syntax, type,|
|   |                            |                       | decl) or linking (undefined reference,    |
|   |                            |                       | duplicate symbol, link order).            |
+---+----------------------------+-----------------------+-------------------------------------------+
| 5 | Short Disassembly-to-C     | objdump -d / GDB      | Inspect disassembly of a short function;  |
|   | Lowering Observation       |                       | map instructions back to the corresponding|
|   |                            |                       | C statements (calls, branches, accesses). |
+---+----------------------------+-----------------------+-------------------------------------------+
```

### 6.3 Scope Guardrails (What Part C Does NOT Require)
To preserve the canonical Phase 1 focus and avoid architecture-specific or advanced dynamic-loader trivia:
* **No AMD64 Calling Convention Trivia:** Golden answers must not depend on memorizing register names (`rdi, rsi, rdx, rcx`) or System V ABI parameter passing rules.
* **No Dynamic Linking / PIE Scope:** No position-independent executable runtime loader mechanics, `.so` shared library search paths (`LD_LIBRARY_PATH`), or dynamic symbol tables.
* **No Program Header / MMU Permission Analysis:** No segment-to-page alignment or hardware memory protection attributes.
* **No Architecture Relocation Trivia:** Understanding the *purpose* of relocation patching is required; memorizing specific relocation codes (such as `R_X86_64_PLT32`) is not required.

### 6.4 Evaluation Scenario & Deliverables
The learner is provided with a modular three-file utility (e.g., driver, math/filter helper, and state accumulator) exhibiting an intentional link failure or symbol misconfiguration. The learner must:
1. Provide terminal command excerpts and outputs for each of the five canonical tasks.
2. Formulate the technical explanation connecting tool output to the underlying C and ELF mechanics.
3. Submit the repaired `Makefile` or source header ensuring clean compilation and linkage.

### 6.5 Hard Pass Criteria for Part C
* Score $\ge 12 / 20$ (60%).
* All five tasks must be supported by actual terminal command excerpts and clear technical reasoning.

---

## 7. Part D Specification: Process / FD / Concurrency Interacting Faults (25%)

### 7.1 Objective
Evaluate the learner's ability to debug a realistic, non-isolated Linux systems failure where an operating system process/descriptor lifecycle defect **interacts** with a multithreaded synchronization defect.

### 7.2 Interacting Systems Architecture
The target fixture models a concurrent stream-processing supervisor:
* A **Supervisor Process** manages streaming input and coordinates with a **Child Worker Process**.
* The Child Process executes an internal multithreaded pipeline (e.g., ingestion reader thread communicating with a processing worker thread via a bounded ring buffer).
* The service must cleanly process stream data, respond to termination signals, flush pending state, join threads, close file descriptors, and exit without stalls or resource leaks.

```
+----------------------------------------------------------------------------------------------------+
|                                    PART D INTERACTING ARCHITECTURE                                 |
|                                                                                                    |
|  Supervisor Process                                                                                |
|    |                                                                                               |
|    +-- Process/Stream Coordination (fork / pipe / signal / descriptor inheritance)                 |
|          |                                                                                         |
|          v                                                                                         |
|  Child Processing Daemon                                                                           |
|    |                                                                                               |
|    +-- [Thread 1: Reader] === push ===> [Bounded Ring Queue] === pop ===> [Thread 2: Worker]       |
|    |                                                                                               |
|    +-- [Concurrency Lifecycle: Mutex Invariants, Predicate Waits, Shutdown Join]                  |
+----------------------------------------------------------------------------------------------------+
```

### 7.3 Interacting Fault Contract & Family Pairings
The implementation task must seed **two genuinely interdependent defects** selected from two orthogonal families:

```
+----------------------------------------------------------------------------------------------------+
|                                    INTERACTING FAULT FAMILY MATRIX                                 |
+------------------------------------+---------------------------------------------------------------+
| Family 1: Process / FD Lifecycle   | Family 2: Concurrency & Synchronization                       |
+------------------------------------+---------------------------------------------------------------+
| • Pipe EOF / stream closure hang   | • Data race on shared pipeline state under contention         |
| • Zombie accumulation / waitpid    | • Named multi-field invariant violation during state transition|
| • Leaked inherited descriptor      | • Condition-variable predicate misuse (while vs if / TOCTOU)  |
| • Signal mask inheritance error    | • Lock misuse, ordering deadlock, or shutdown join sequencing |
+------------------------------------+---------------------------------------------------------------+
```

#### Genuine Interaction Requirements
1. **Interdependent Failure:** Resolving only the process/FD lifecycle fault must leave the service stalling, deadlocking, or failing under concurrency. Conversely, resolving only the concurrency fault must leave the service hanging on OS/stream boundaries.
2. **Residual Failure:** A partial fix submitted by the learner will fail the automated regression suite. Both contracts must be understood and repaired to achieve clean execution.
3. **Secrecy Guardrail:** The specific pair selected by the author of the implementation issue must remain quarantined in `reviewer/` materials. The learner is presented only with the observable system symptom (e.g., *"The service stalls indefinitely during shutdown under streaming workloads"*).

### 7.4 Two Required Evidence Channels
Learners must employ and submit concrete evidence from **at least two independent diagnostic channels**:
* **Channel 1 (System / OS / Descriptor Boundary):** `/proc/<pid>/fd` runtime audit, `strace` syscall trace, or explicit return/errno observations from the tested harness.
* **Channel 2 (Thread / Concurrency State):** ThreadSanitizer runtime report, GDB thread state analysis (`thread apply all bt`), or deterministic coordination/invariant logging.

### 7.5 Hard Pass Criteria for Part D
* Score $\ge 15 / 25$ (60%).
* **Runtime Root-Cause Proof:** The learner must provide runtime trace evidence proving that:
  1. The OS/process stream lifecycle boundary terminates and cleans up cleanly.
  2. The multithreaded pipeline drains, worker threads join promptly, and synchronization primitives are destroyed without error.
  3. The regression test passes across repeated iterations (e.g., 50+ runs) with zero deadlocks and zero descriptor leaks.

---

## 8. AI Policy & Learner Attestation

### 8.1 Strict AI-Free Execution Boundary
The Final Gate measures the learner's unassisted mental models and diagnostic reflexes. Generative AI tools (including ChatGPT, Claude, Gemini, GitHub Copilot, Cursor, and local LLMs) are **strictly prohibited** during core gate execution for:
* Formulating diagnostic hypotheses.
* Analyzing error messages or compiler outputs.
* Generating or repairing source code.
* Designing regression tests.
* Writing diagnostic postmortem sections.

### 8.2 Permitted Authoritative Documentation
$$\mathbf{AI\text{-}Free} \neq \mathbf{Documentation\text{-}Free}$$
Learners are encouraged to consult primary engineering sources:
* Linux man-pages (`man 2`, `man 3`, `man 7`).
* GNU GCC, GDB, GNU Make, and Binutils manuals.
* POSIX.1-2017 / IEEE Std 1003.1 specifications.
* ISO C17 Standard (ISO/IEC 9899:2018).
* Canonical module notes and source ledgers from P1-M01 through P1-M10.

### 8.3 Mandatory Learner AI-Free Attestation Template
Every gate submission must include the following signed declaration in its root `README.md`:

```markdown
### Learner AI-Free Attestation

I hereby attest that:
1. All diagnostic hypotheses, root-cause analyses, code fixes, and regression tests submitted in this Final Gate were conceived, written, and verified independently by me without the use of generative AI tools (such as ChatGPT, Claude, Gemini, Copilot, or Cursor).
2. All documentation consulted during this assessment consisted exclusively of official manual pages, tool manuals, language standards, and canonical repository notes.
3. No diagnostic logs, debugger traces, or test outputs were fabricated or altered.

- Learner Name / GitHub Handle: _______________________________
- Date of Completion:           _______________________________
- Total Elapsed Scored Time:    _____ hours _____ minutes
```

---

## 9. Evidence, Interpretation & Non-Proof Policy

To prevent "log dumping" and unverified claims, every evidentiary submission across all parts must explicitly distinguish three components:

```
+----------------------------------------------------------------------------------------------------+
|                                  THE THREE-PART EVIDENCE DISCIPLINE                                 |
+---------------------+------------------------------------------------------------------------------+
| Component           | Definition & Requirement                                                     |
+---------------------+------------------------------------------------------------------------------+
| 1. Evidence         | The verbatim, unedited observation captured from a tool:                     |
|                     | • Exact compiler error or sanitizer output line                              |
|                     | • Specific GDB frame or variable inspection value                            |
|                     | • Exact syscall and return value from strace                                 |
|                     | • /proc/<pid>/fd directory listing                                           |
+---------------------+------------------------------------------------------------------------------+
| 2. Interpretation   | The logical explanation connecting the evidence to the hypothesis:           |
|                     | • What this observation proves or disproves regarding the failure            |
|                     | • Why this narrows the search space to a specific contract                   |
+---------------------+------------------------------------------------------------------------------+
| 3. Non-Proof Limits | Explicit acknowledgment of what the evidence does NOT prove:                 |
|                     | • "One clean TSan run does not prove all possible thread schedules race-free"|
|                     | • "ASan clean exit does not prove byte-order or logic correctness"           |
|                     | • "strace proves syscall parameters, not internal application memory state"  |
+---------------------+------------------------------------------------------------------------------+
```

---

## 10. Scoring and Hard Pass Conditions

### 10.1 Score Weighting Summary (100 Points Total)

```
+----------------------------------------------------------------------------------------------------+
|                                    SCORING BREAKDOWN MATRIX                                        |
+---------+------------------------------------+--------+--------------------------------------------+
| Section | Part Name                          | Points | Evaluation Sub-Dimensions                  |
+---------+------------------------------------+--------+--------------------------------------------+
| Part A  | Blank-Directory Build              | 30     | Architecture (6), Memory Ownership (8),   |
|         |                                    |        | I/O & Error Boundaries (8), Build/Test (8) |
+---------+------------------------------------+--------+--------------------------------------------+
| Part B  | Unknown Bug Investigation          | 25     | Description & Hypotheses (6), Evidence (7),|
|         |                                    |        | Root Cause (4), Fix (4), Regression (4)    |
+---------+------------------------------------+--------+--------------------------------------------+
| Part C  | ELF / Link / Binary Evidence       | 20     | Symbol Binding (4), Relocation Entry (4),  |
|         |                                    |        | Section Placement (4), Compiler vs Link (4)|
|         |                                    |        | Disassembly to C Lowering (4)              |
+---------+------------------------------------+--------+--------------------------------------------+
| Part D  | Process / FD / Concurrency Debug   | 25     | Interaction Analysis (6), 2 Channels (8),  |
|         |                                    |        | Root-Cause Proof (6), Regression (5)       |
+---------+------------------------------------+--------+--------------------------------------------+
| Total   |                                    | 100    |                                            |
+---------+------------------------------------+--------+--------------------------------------------+
```

### 10.2 Mandatory Hard Pass Conditions

To earn a passing grade on the Phase 1 Final Gate, a submission must satisfy **all six** of the following conditions:

1. **Composite Score:** Total score $\ge \mathbf{75 / 100}$.
2. **Per-Part Competency Floor:** Every individual Part must achieve at least **60%**:
   * Part A $\ge 18 / 30$
   * Part B $\ge 15 / 25$
   * Part C $\ge 12 / 20$
   * Part D $\ge 15 / 25$
3. **Diagnostic Mastery Bar:** Part B must achieve at least **70%** ($\ge 17.5 / 25$).
4. **Runtime Concurrency Proof:** Part D must include concrete runtime evidence proving resolution of both interacting defects.
5. **Zero Resource Leaks in Construction:** Part A must be clean under ASan/LSan for memory errors/leaks and must independently demonstrate zero leaked owned file descriptors with `/proc` or equivalent runtime evidence.
6. **Integrity Attestation:** A signed AI-Free Attestation must accompany the submission.

> [!NOTE]
> These thresholds represent the canonical baseline. No arbitrary mandatory-pass station rules may be added without formal Leader review.

---

## 11. Environment & Tool-Availability Policy

The Final Gate is designed to be executable across standard Linux development environments, including native Linux installations, containers, and WSL2.

### 11.1 Environment Recording Requirement
The learner must record their actual host environment in the submission header:
```bash
uname -a
gcc --version | head -n1
make --version | head -n1
gdb --version | head -n1 2>/dev/null || echo "GDB: UNAVAILABLE"
strace --version | head -n1 2>/dev/null || echo "strace: UNAVAILABLE"
```

### 11.2 Tool Availability & Equivalent Evidence Channels
If a specific diagnostic tool is unsupported or unavailable in the host environment, the learner must record its status honestly (`VERIFIED`, `PARTIALLY VERIFIED`, or `UNVERIFIED`) and utilize an equivalent evidence channel:

```
+----------------------------------------------------------------------------------------------------+
|                                EQUIVALENT EVIDENCE CHANNEL MATRIX                                  |
+-------------------+----------------------------+---------------------------------------------------+
| Unavailable Tool  | Impacted Area              | Approved Equivalent Evidence Channel              |
+-------------------+----------------------------+---------------------------------------------------+
| GDB               | Thread inspection /        | • Sanitizer stack traces when relevant             |
|                   | backtrace analysis         | • `/proc` / process-state evidence plus a          |
|                   |                            |   deterministic reproduction harness               |
+-------------------+----------------------------+---------------------------------------------------+
| strace            | Syscall / descriptor leak  | • `/proc/<pid>/fd` runtime audit                   |
|                   | tracing                    | • Explicit return/errno observations from the     |
|                   |                            |   tested program or bounded harness                |
+-------------------+----------------------------+---------------------------------------------------+
| ThreadSanitizer   | Data race detection        | • GDB thread-state evidence when available         |
| (host limitations)|                            | • Deterministic coordination / stress reproduction |
|                   |                            |   plus explicit invariant reasoning                |
+-------------------+----------------------------+---------------------------------------------------+
```

---

## 12. Reviewer Isolation & Answer-Leak Prevention Policy

To protect assessment validity, the repository maintains an absolute barrier between learner-facing materials and reviewer answer references:

```
+----------------------------------------------------------------------------------------------------+
|                                REVIEWER ISOLATION FILE STRUCTURE                                   |
+------------------------------------+---------------------------------------------------------------+
| Path Location                      | Access Policy & Permitted Contents                            |
+------------------------------------+---------------------------------------------------------------+
| `gates/phase-1-final/`             | **Learner-Facing (Public to Learner):**                       |
|                                    | • Specification READMEs and time budgets                      |
|                                    | • Bounded reproduction harnesses (`repro.c`, `repro.sh`)      |
|                                    | • Symptom descriptions and build instructions                 |
|                                    | • Submission template and attestation form                    |
|                                    | • ZERO root causes, defect clues, or patch hints               |
+------------------------------------+---------------------------------------------------------------+
| `gates/phase-1-final/reviewer/`    | **Reviewer-Only (Isolated from Learner):**                    |
|                                    | • Hidden defect seeds and exact mechanical root causes        |
|                                    | • Reference repaired code and patches                         |
|                                    | • Automated evaluation and scoring test suites                |
|                                    | • Rubric benchmark answers for Parts B, C, and D              |
+------------------------------------+---------------------------------------------------------------+
```

* **Naming Discipline:** No learner-facing file, variable, or comment may contain giveaway tokens (e.g., `broken_mutex`, `leak_fd`, `missing_broadcast`).
* **Source Integrity:** Reviewer directories must be excluded from learner starter packages and reviewed only during grading.

---

## 13. Technical Ring-Buffer Queue Invariants

To ensure technical correctness across concurrency evaluations, any queue or buffer specification included in the Gate must adhere to the **canonical M10 ring-buffer definition**:

### 13.1 Pointer & Count Semantics
* `head`: Index of the next element to pop (read cursor).
* `tail`: Index of the next available slot to push (write cursor).
* `count`: Number of valid records currently stored in the ring.
* `capacity`: Fixed maximum buffer capacity.

### 13.2 Canonical Invariant Formulation
Under mutex protection, the structural invariant is defined as:

$$\mathbf{tail == (head + count) \pmod{capacity}}$$

### 13.3 Accompanying State Invariants
1. **Bounds Invariant:**
   $$0 \le \text{count} \le \text{capacity} \quad \wedge \quad \text{head} < \text{capacity} \quad \wedge \quad \text{tail} < \text{capacity}$$
2. **Push Condition:**
   $$\text{A push is accepted if and only if} \quad \text{count} < \text{capacity} \quad \wedge \quad \neg \text{closed}$$
3. **Pop Condition:**
   $$\text{A record is popped if and only if} \quad \text{count} > 0$$
4. **Shutdown Termination Invariant:**
   $$\text{closed} \implies \text{no further pushes accepted}$$
   $$\text{closed} \wedge \text{count} == 0 \implies \text{all waiting consumers awaken and terminate}$$

---

## 14. Retry & Remediation Mapping

Failure on one or more parts of the Final Gate does not require an automatic restart of the entire phase. Instead, deficiencies map directly back to specific Phase 1 curriculum milestones for targeted remediation:

```
+----------------------------------------------------------------------------------------------------+
|                                  REMEDIATION MAPPING TABLE                                         |
+-----------------------+-----------------------------+----------------------------------------------+
| Deficient Area        | Primary Milestone to Review | Remediation Focus Exercises                  |
+-----------------------+-----------------------------+----------------------------------------------+
| Memory & Lifetime     | P1-M01 Objects / Lifetime   | Stack frame escaping, dynamic buffer extent  |
|                       | P1-M05 Ownership / Callbacks| Ownership transfer tables, opaque contexts   |
+-----------------------+-----------------------------+----------------------------------------------+
| File Descriptors &    | P1-M02 Files / Error Bounds | Owned vs borrowed FDs, CLOEXEC audit         |
| Process Lifecycle     | P1-M04 Process / fork / exec| Zombie reaping loops, copy-on-write offsets  |
+-----------------------+-----------------------------+----------------------------------------------+
| Build & Toolchain     | P1-M03 ELF / Build / Link   | Symbol visibility, relocation inspection     |
+-----------------------+-----------------------------+----------------------------------------------+
| Signals & IPC         | P1-M06 Signals / IPC        | Async-signal safety, EINTR handling in pipes |
+-----------------------+-----------------------------+----------------------------------------------+
| Serialization & Wire  | P1-M07 Layout / Codecs      | Bit-preserving decode, explicit endianness   |
+-----------------------+-----------------------------+----------------------------------------------+
| Evidence & Triage     | P1-M08 Debugging / Evidence | Tool triage matrix, hypothesis falsification |
+-----------------------+-----------------------------+----------------------------------------------+
| Concurrency & Locking | P1-M09 pthread Concurrency  | Mutex invariants, while predicate loops      |
+-----------------------+-----------------------------+----------------------------------------------+
| Service Integration   | P1-M10 Telemetry Service    | Graceful shutdown under active input stream  |
+-----------------------+-----------------------------+----------------------------------------------+
```

### Re-Examination Policy
1. If a learner scores $< 60\%$ on 1 or 2 parts, they remediate the mapped milestones and retake **only the deficient parts**.
2. For Part B retries, the learner is assigned a **different variant** from the variant pool (drawing from a different family, e.g., switching from B-MEM to B-FD or B-CONC).
3. If a learner scores $< 60\%$ on 3 or more parts, a comprehensive review of Phase 1 is required before re-attempting the complete Final Gate.

---

## 15. Calibration Plan

Before thresholds are treated as calibrated, the Final Gate will undergo a documented **First-Learner Calibration Run**:

1. **Initial Pilot Run:** The first real learner attempt executes the assessment under timed conditions with full environmental logging.
2. **Calibration Dimensions Measured:**
   * Actual time required per Part vs budgeted duration (identifying unintended time sinks).
   * Ambiguity in problem specifications or harness instructions.
   * Tool portability across standard Linux distributions (Ubuntu, Debian, Fedora, WSL2).
3. **Threshold Adjustments:** Any adjustments to time limits, variant harness timeouts, or scoring weightings must be submitted as a documented pull request linked to the calibration issue, **never altered silently**.
4. **Current Status:**
   * Timing and score thresholds are currently: **UNVERIFIED — pending first learner calibration run**.

---

## 16. Portfolio & Career Mapping

The deliverables generated by the Final Gate are structured to serve as high-signal professional engineering portfolio artifacts:

```
+----------------------------------------------------------------------------------------------------+
|                                    CAREER PORTFOLIO VALUE                                          |
+-----------------------+---------------------------------------+------------------------------------+
| Professional Venue    | Recommended Artifact Showcase         | Engineering Evidence Demonstrated  |
+-----------------------+---------------------------------------+------------------------------------+
| GitHub Portfolio      | Part A standalone systems utility     | Clean C17 architecture, rigorous   |
| Repository            | and Part D supervisor implementation. | Makefiles, zero sanitizer leaks.   |
+-----------------------+---------------------------------------+------------------------------------+
| Technical Interviews  | Part B and Part D 8-step diagnostic   | Concrete stories of hypothesis-led |
| (Embedded / Systems)  | postmortem write-ups.                 | debugging, GDB/strace triage, and  |
|                       |                                       | resolving interacting races.       |
+-----------------------+---------------------------------------+------------------------------------+
| Code Review Samples   | Part C ELF symbol and relocation      | Demonstrates deep toolchain and    |
|                       | analysis worksheets.                  | binary literacy beyond syntax.     |
+-----------------------+---------------------------------------+------------------------------------+
```

### Realistic Competency Claim
> [!IMPORTANT]
> Passing the Phase 1 Final Gate certifies that the candidate has attained **L3/L4-local competency in foundational Linux systems programming, C object lifetime tracking, and multithreaded synchronization**.
>
> It demonstrates strong foundational preparation for junior embedded/Linux systems work and for later BSP/driver training. It does **not** by itself demonstrate BSP, kernel, or driver mastery.

---

## 17. Explicit Exclusions

To prevent curriculum scope creep, the following domains are strictly **excluded** from the Phase 1 Final Gate:

* **No Kernel-Space Programming:** No Linux kernel modules, character drivers, network device drivers, or kernel debugging (`kgdb`, `kprobes`). *(Reserved for Phase 2: Linux Drivers).*
* **No Bootloader / Board Bring-up:** No U-Boot scripting, SPL bring-up, or barebox configuration. *(Reserved for Phase 3: BSP & Hardware).*
* **No Embedded Build Systems:** No Buildroot or Yocto Project / OpenEmbedded recipes. *(Reserved for Phase 3: BSP & Hardware).*
* **No Hardware Register Programming:** No Device Tree source authoring (`.dts`/`.dtsi`), direct MMIO register mapping, DMA controller engines, or MMU page table configuration. *(Reserved for Phase 3 & 4).*
* **No Bare-Metal Microcontrollers / RTOS:** No FreeRTOS tasks, CMSIS, Cortex-M NVIC register manipulation, or STM32 bare-metal code. These belong outside the Phase 1 Final Gate.
* **No Advanced Concurrency Architectures:** No lock-free queues, atomic memory orders (`memory_order_seq_cst`), POSIX semaphores, read-write locks, or multi-consumer worker pools.
* **No External Dependencies:** No CMake, Autotools, JSON parsers, databases, or third-party unit test frameworks.

---

## 18. Implementation Handoff Checklist for Next Issue

When this specification is approved and merged, the subsequent implementation issue will create the following concrete repository artifacts:

```text
[ ] Create directory structure: gates/phase-1-final/ and gates/phase-1-final/reviewer/
[ ] Author learner instructions: gates/phase-1-final/README.md
[ ] Author Part A specification and automated validation harness
[ ] Author Part B hidden variant pool fixtures across families (B-MEM, B-FD, B-CONC) with bounded ./repro harnesses
[ ] Author Part C host-generated relocatable object package covering the five canonical evidence tasks
[ ] Author Part D interacting process/FD and concurrency fixture with hidden seed pair and multi-channel harness
[ ] Author hidden reviewer reference solutions in gates/phase-1-final/reviewer/:
    [ ] Part A golden reference implementation
    [ ] Part B golden postmortems and patches for all seeded variants
    [ ] Part C golden symbol/relocation/disassembly answer key
    [ ] Part D golden interacting-fault postmortem and multi-iteration regression suite
[ ] Provide learner submission template and AI-Free attestation form
[ ] Verify that no reviewer answers leak into learner-facing files
[ ] Test all harnesses under GCC 13/14 and Make 4.x on Linux/WSL2
[ ] Submit implementation PR and initiate First-Learner Calibration Run
```
