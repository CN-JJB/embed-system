# Phase 1 Final Gate Specification: Linux Systems & Concurrency Foundations

> **Document Type:** Specification / Design Document  
> **Status:** Candidate Draft — Ready for Leader Review  
> **Target Audience:** Curriculum authors, evaluators, and Phase 1 learners completing P1-M01 through P1-M10  
> **Evaluation Mode:** Multi-stage (AI-Free core stations + AI-Assisted documentation/review)  
> **Estimated Execution Time:** 6.75 hours (405 minutes, modular across 2–3 days)  
> **Passing Threshold:** 75 / 100 points, with mandatory passing on Station E (Concurrency) and Station F (Integration)

---

## 1. Purpose

The Phase 1 Final Gate is the summative capstone assessment for Phase 1 of `embed-system` (covering **P1-M01 Objects/Lifetime** through **P1-M10 Linux Systems Telemetry Service**). Its primary objective is to verify that the learner has transitioned from following tutorial steps to independently exercising evidence-driven systems engineering.

### What the Final Gate Verifies

1. **System-Level Reasoning:** Ability to reason about code execution in the context of the Linux kernel, process address space, file descriptor tables, virtual memory layouts, and CPU hardware threading.
2. **Deterministic Ownership & Lifetime Tracking:** Precise bookkeeping of dynamically allocated buffers, open file descriptors, synchronization primitives, and execution context lifetimes.
3. **Evidence-Driven Engineering & Debugging:** Disciplined execution of the canonical 8-step diagnostic loop:
   $$\text{Symptom} \rightarrow \text{Own Description} \rightarrow \text{Hypotheses} \rightarrow \text{Experiment} \rightarrow \text{Evidence} \rightarrow \text{Root Cause} \rightarrow \text{Fix} \rightarrow \text{Regression}$$
4. **Linux Mental Model:** Concrete comprehension of process isolation, POSIX signal semantics, blocking system call interruption (`EINTR`), copy-on-write semantics, and thread synchronization.
5. **Tool Selection Disambiguation:** Selecting diagnostic tools based on falsifiable hypotheses rather than brute-force guessing or log dumping.

### What the Final Gate Does NOT Verify

* **API Memorization:** Learners are never tested on verbatim recall of function signatures, `fcntl` flags, or POSIX error codes. Authoritative documentation lookup is expected.
* **Code Volume / Boilerplate Speed:** The gate tests diagnostic depth and architectural clarity, not the ability to generate hundreds of lines of boilerplate code.
* **LeetCode / Synthetic Algorithms:** No abstract dynamic programming, graph traversal puzzles, or artificial mathematical challenges. All challenges originate from real systems failure domains.
* **AI Prompting Capabilities:** The gate is designed to be assessable in an **AI-Free** environment to ensure that the mental models and diagnostic reflexes belong to the engineer, not an external LLM.

### Core Evaluation Hierarchy

All evaluator judgments and scoring decisions adhere to the repository evaluation hierarchy:

$$\mathbf{Technical\ Correctness} > \mathbf{Observable\ Evidence} > \mathbf{Mental\ Model} > \mathbf{Debugging\ Transfer} > \mathbf{Source\ Quality}$$

---

## 2. Competency Map

The Final Gate synthesizes competencies acquired across the 10 Phase 1 milestones into six integrated domains:

```
+----------------------------------------------------------------------------------------------------+
|                                    PHASE 1 COMPETENCY MAP                                          |
+--------------------------+-----------------------------+-------------------------------------------+
| Domain                   | Milestones Covered          | Core Architectural Concepts               |
+--------------------------+-----------------------------+-------------------------------------------+
| 1. System C              | P1-M01, P1-M05, P1-M07      | Lifetime, ownership, UB, memory layout    |
| 2. Linux Fundamentals    | P1-M02, P1-M04, P1-M06      | Processes, FD lifecycle, signals, IPC     |
| 3. Build & Toolchain     | P1-M03                      | Compilation, ELF sections, link symbols   |
| 4. Debugging & Evidence  | P1-M08                      | Tool selection, GDB, sanitizers, strace   |
| 5. Concurrency           | P1-M09                      | Mutex invariants, condvar predicates      |
| 6. Telemetry Integration | P1-M10                      | Bounded queue, ring buffer, worker join   |
+--------------------------+-----------------------------+-------------------------------------------+
```

### 2.1 System C
* **Object Lifetime & Storage Duration:** Automatic (stack), static (program lifetime), dynamic (heap via allocator), and thread-local lifetimes. Escaped pointer analysis and stack-frame invalidation.
* **Pointer Ownership & Cleanups:** Clear delineation between owning pointers (responsible for deallocation) and borrowed references. Safe callback context passing without premature teardown.
* **Undefined Behavior (UB) Reasoning:** Diagnosing signed integer overflow, strict aliasing violations, uninitialized memory reads, out-of-bounds array access, and pointer arithmetic beyond object bounds.
* **Memory Layout & Wire Representation:** Structure padding and field alignment; natural alignment boundaries; explicit serialization vs raw struct casting; endianness transformations (host-to-network / little-endian byte ordering).

### 2.2 Linux Fundamentals
* **Process vs Program:** Executable files on disk vs active running execution contexts with isolated virtual memory (`/proc/<pid>/maps`).
* **Process Lifecycle:** `fork()` address space duplication; `execve()` image replacement; parent-child synchronization via `waitpid()`; exit status extraction (`WIFEXITED`, `WEXITSTATUS`, `WIFSIGNALED`); preventing and reaping zombie processes.
* **File Descriptor (FD) Lifecycle:** System-wide open file description table vs per-process descriptor tables; file offset sharing across `fork`; `O_CLOEXEC` inheritance protection; descriptor duplication (`dup2`); FD leak auditing via `/proc/<pid>/fd`.
* **Signal Handling & Async-Signal Safety:** Reentrant execution contexts; signal masks and inheritance (`pthread_sigmask` vs `sigprocmask`); restricting signal handlers to async-signal-safe functions; self-pipe and flag-based stop patterns.
* **Inter-Process Communication (IPC):** Bounded stream semantics of UNIX pipes and FIFOs; handling `EPIPE` and `SIGPIPE`; coordinating producers and consumers over byte streams.

### 2.3 Build / Toolchain
* **Compilation Pipeline:** Step-by-step translation: Preprocessing (`cpp`), Compilation (`cc1`), Assembly (`as`), and Linking (`ld`).
* **ELF Object Architecture:** Header verification, section headers (`.text`, `.rodata`, `.data`, `.bss`), program headers (`LOAD` segments and MMU permissions `R/W/X`).
* **Symbol Resolution & Binding:** Global vs local (`static`) symbols, weak vs strong symbol overrides, symbol visibility, diagnosing `undefined reference` vs duplicate symbol collisions using `nm`, `readelf`, and `objdump`.
* **Build Dependency Reasoning:** Dependency graphs in GNU Make; prerequisite timestamp comparison; avoiding recursive make pitfalls and phantom targets.

### 2.4 Debugging & Evidence Selection
* **Evidence-First Principle:** Tools are not ends in themselves. Every tool invocation must be guided by a falsifiable hypothesis.
* **Inspection Tool Triage Matrix:**
  * Memory corruption, leaks, buffer bounds: AddressSanitizer (ASan) + LeakSanitizer (LSan).
  * Arithmetic overflow, undefined shifts, null-pointer dereference: UndefinedBehaviorSanitizer (UBSan).
  * Data races, conflicting multi-threaded memory access: ThreadSanitizer (TSan).
  * Call stack, register inspection, execution control, thread deadlocks: GNU Debugger (GDB).
  * System call interactions, process lifecycle, signal delivery, descriptor leaks: `strace` and `/proc/<pid>/`.
  * Parser formatting, protocol framing errors: Binary hexdump (`od -tx1`, `hexdump -C`).

### 2.5 Concurrency
* **Threads vs Processes:** Shared virtual memory space vs distinct per-thread stacks; context pointer lifetime across thread execution.
* **Mutexes as Invariant Protectors:** Mutexes protect named multi-field invariants, not arbitrary lines of code; preventing TOCTOU (Time-of-Check to Time-of-Use) vulnerabilities; atomic state transitions.
* **Condition Variables & Predicates:** Predicate `while` loops vs vulnerable `if` checks; spurious wakeup handling; signaling vs broadcasting; ensuring condition state transition precedes wake notification.
* **Shutdown Ordering:** Clean drain transitions; signaling sleepers on queue close; joining worker threads before releasing shared synchronization primitives.

### 2.6 Integration (Telemetry Service Pipeline)
* **Cohesive Pipeline Architecture:**
  $$\text{Input FD} \xrightarrow{\text{parse}} \text{Telemetry Record} \xrightarrow{\text{push}} \text{Bounded Queue} \xrightarrow{\text{pop}} \text{Worker Thread} \xrightarrow{\text{accumulate}} \text{Statistics}$$
* **Resource Ownership Contracts:** Strict separation between caller-owned resources, borrowed file descriptors (`stdin`), and thread-internal state.
* **Graceful Termination Under Stress:** Processing remaining items upon EOF or termination signals while preventing hangs when input streams remain open.

---

## 3. AI Policy

The Phase 1 Final Gate enforces a strict AI policy grounded in a fundamental tenet:

$$\mathbf{AI\text{-}Free} \neq \mathbf{Documentation\text{-}Free}$$

Consulting authoritative technical documentation, manual pages, language standards, and architecture reference manuals is core engineering work and is explicitly permitted throughout all stages.

```
+---------------------------------------------------------------------------------------------------+
|                                   FINAL GATE AI TIERS                                             |
+---------------+-----------------------------------------------+-----------------------------------+
| Tier          | Permitted Activities                          | Strictly Prohibited               |
+---------------+-----------------------------------------------+-----------------------------------+
| 1. AI-Free    | • Full diagnostic postmortem authoring        | • AI code generation              |
|               | • Hypothesis formation and falsification      | • AI diagnosis / root cause       |
|               | • Root cause deduction and fix coding         | • AI hypothesis synthesis         |
|               | • Allowed: man pages, GCC/GDB/Make manuals,   | • AI prompt debugging             |
|               |   POSIX specs, local notes, upstream sources  |                                   |
+---------------+-----------------------------------------------+-----------------------------------+
| 2. AI-Hint    | • Compiler error explanation                  | • Revealing defect locations      |
| (Optional)    | • Syntax syntax confirmation                  | • Providing repair patches        |
|               | • Tool CLI argument reference assistance      |                                   |
+---------------+-----------------------------------------------+-----------------------------------+
| 3. AI-Assisted| • Postmortem prose clarity review             | • Modifying technical evidence    |
| (Post-Score)  | • Editorial grammar and markdown polishing    | • Fabricating execution traces    |
+---------------+-----------------------------------------------+-----------------------------------+
```

### 3.1 AI-Free Stations (Core Assessment)
Stations A through F must be executed in an **AI-Free** environment. The learner must independently:
1. Observe the failure symptom.
2. Articulate the failure in their own technical words.
3. Propose 3–5 competing hypotheses prior to tool invocation.
4. Select evidence targets to falsify competing hypotheses.
5. Identify the exact broken contract or invariant.
6. Write the minimal correct code fix.
7. Construct an automated regression test.

### 3.2 Authoritative Resources Allowed in AI-Free Mode
Learners have unrestricted access to:
* Linux manual pages (`man 2`, `man 3`, `man 7`).
* GNU GCC, GDB, Make, and Binutils official manuals.
* POSIX.1-2017 / IEEE Std 1003.1 specifications.
* C17 Standard (ISO/IEC 9899:2018).
* Upstream libc headers and source code (e.g., musl libc).
* Previously completed Phase 1 module notes and source ledgers.

---

## 4. Gate Structure

The Final Gate comprises **six independent stations** executed across a modular time budget of 405 minutes (~6.75 hours).

```
+----------------------------------------------------------------------------------------------------+
|                                    STATION OVERVIEW                                                |
+---------+------------------------------------+----------+-------+----------------------------------+
| Station | Topic                              | Time     | Score | Primary Assessment Focus         |
+---------+------------------------------------+----------+-------+----------------------------------+
| A       | Memory & Lifetime (System C)       | 60 min   | 15    | Lifetime escape, heap ownership  |
| B       | FD & Process Lifecycle (Linux)     | 75 min   | 15    | fork/exec, FD table, zombies     |
| C       | Build & ELF Toolchain              | 45 min   | 15    | Link order, symbol resolution    |
| D       | Debugging Evidence Selection       | 60 min   | 15    | Tool triage, falsification       |
| E       | Concurrency & Invariants           | 75 min   | 20    | Mutex invariants, condvar wait   |
| F       | Telemetry Service Integration      | 90 min   | 20    | End-to-end shutdown & lifecycle  |
+---------+------------------------------------+----------+-------+----------------------------------+
| Total   |                                    | 405 min  | 100   | Passing threshold: 75 / 100      |
+---------+------------------------------------+----------+-------+----------------------------------+
```

---

### 4.1 Station A — Memory & Lifetime (System C)

* **Objective:** Diagnose, document, and repair an object lifetime violation and memory ownership leak in a modular data-processing component.
* **Prerequisites:** P1-M01 (Objects & Lifetime), P1-M05 (Ownership & Callbacks), AddressSanitizer usage.
* **AI Mode:** AI-Free.
* **Environment:** Linux x86_64, GCC (`-std=c17 -O0 -g3 -Wall -Wextra -Wpedantic -Werror`), ASan + LSan.
* **Time Budget:** 60 minutes.
* **Symptom:** A record batch processor runs correctly during initial small tests, but produces corrupted aggregate values and random segmentation faults under high batch counts.
* **Allowed Tools:** GCC, GDB, AddressSanitizer, LeakSanitizer, valgrind (optional), text editor.
* **Expected Evidence:**
  1. AddressSanitizer trace identifying either `stack-use-after-return` or `heap-use-after-free`.
  2. Complete **Object Lifetime Table** mapping each buffer from allocation to destruction, identifying the exact boundary where the pointer outlived its referent.
* **Common Wrong Approaches:**
  * Adding arbitrary `malloc` calls without clarifying who frees the memory.
  * Making stack variables `static` to mask lifetime escape (violating reentrancy and concurrency safety).
  * Disabling compiler warnings or optimization levels to suppress the crash.
* **Scoring (15 Points Total):**
  * Symptom description & 3 plausible hypotheses: 3 pts
  * ASan/GDB evidence selection & reproduction trace: 3 pts
  * Accurate identification of broken lifetime contract: 3 pts
  * Minimal, reentrant, ownership-preserving fix: 3 pts
  * Regression test proving zero ASan/LSan errors across 10,000 iterations: 3 pts
* **Pass Criteria:** Score $\ge 12/15$; ASan clean execution; zero memory leaks.
* **Failure Modes:** Patch guessing without lifetime table; memory leak introduced by fix.

---

### 4.2 Station B — File Descriptors & Process Lifecycle (Linux Fundamentals)

* **Objective:** Isolate and repair descriptor leaks, offset corruption, and zombie accumulation across a multi-process worker pool.
* **Prerequisites:** P1-M02 (Files & Error Boundaries), P1-M04 (Process Lifecycle), `/proc` inspection.
* **AI Mode:** AI-Free.
* **Environment:** Linux x86_64, GCC, GNU Make, `/proc/<pid>/fd`, `/proc/<pid>/status`, `strace`.
* **Time Budget:** 75 minutes.
* **Symptom:** A multi-process file parser executes child worker processes to ingest data files. After processing 100 files, subsequent jobs fail with `EMFILE (Too many open files)`, system process tables show `<defunct>` zombie processes, and shared log output suffers truncated inter-process overwrites.
* **Allowed Tools:** GCC, `strace -f`, `ls -l /proc/<pid>/fd`, `ps`, GDB.
* **Expected Evidence:**
  1. Terminal output showing open file descriptor accumulation in `/proc/<pid>/fd`.
  2. Process table inspection showing defunct child processes awaiting `waitpid()`.
  3. `strace` excerpt proving file table offset sharing and missing `O_CLOEXEC` flags.
  4. Explicit **File Descriptor Ownership Table** detailing owned vs borrowed descriptors.
* **Common Wrong Approaches:**
  * Raising `ulimit -n` rather than closing leaked descriptors.
  * Adding arbitrary `sleep()` calls to allow children to finish before parent exits.
  * Calling `close()` on borrowed standard descriptors (`stdin`/`stdout`).
* **Scoring (15 Points Total):**
  * Symptom description & 3 hypotheses: 3 pts
  * Evidence of FD leak and zombie accumulation via `/proc` or `strace`: 3 pts
  * Complete descriptor ownership table: 3 pts
  * Correct repair (`waitpid` reaping loop, explicit `close()`, `O_CLOEXEC`): 3 pts
  * Regression test verifying constant FD count across 500 child cycles: 3 pts
* **Pass Criteria:** Score $\ge 12/15$; 0 leaked descriptors; 0 zombie processes.
* **Failure Modes:** Calling non-async-signal-safe functions in signal handlers; ignoring `waitpid` status flags.

---

### 4.3 Station C — Build Pipeline & ELF Symbols (Build / Toolchain)

* **Objective:** Analyze a failing multi-module link, resolve symbol collisions and visibility errors, and explain the exact resolution mechanics at the ELF symbol level.
* **Prerequisites:** P1-M03 (ELF, Build & Link).
* **AI Mode:** AI-Free.
* **Environment:** Linux x86_64, GNU Make, `readelf`, `nm`, `objdump`.
* **Time Budget:** 45 minutes.
* **Symptom:** A multi-file telemetry utility fails to build. Linking yields `multiple definition of 'telemetry_state'` and `undefined reference to 'codec_validate'`, while an included static library silently uses an obsolete calculation routine instead of the updated version.
* **Allowed Tools:** `nm`, `readelf -s`, `objdump -d`, `make`, GCC.
* **Expected Evidence:**
  1. `readelf -s` or `nm` output demonstrating duplicate global symbols vs static local symbols.
  2. Linker command analysis demonstrating library order sensitivity (`-l` ordering on the command line).
  3. Disassembly proof showing whether call sites bound to the intended function implementation.
* **Common Wrong Approaches:**
  * Using `-fcommon` to suppress duplicate global symbol errors.
  * Putting complete function and variable definitions into `.h` header files without `extern` or `static inline`.
  * Randomly reordering files in `Makefile` without understanding archive symbol resolution.
* **Scoring (15 Points Total):**
  * Symptom description & root cause analysis: 3 pts
  * `readelf`/`nm` evidence detailing symbol type (GLOBAL, WEAK, LOCAL) and section: 4 pts
  * Make dependency graph & link order explanation: 4 pts
  * Principled header/C file separation and clean build under `-Werror`: 4 pts
* **Pass Criteria:** Score $\ge 12/15$; clean strict build with zero warnings; correct symbol linkage.
* **Failure Modes:** Masking symbol collisions via compiler flags; recursive include loops.

---

### 4.4 Station D — Debugging Evidence Selection & Triage

* **Objective:** Given three realistic embedded systems failure scenarios, select the single most appropriate diagnostic tool, formulate falsifiable hypotheses, and justify why alternative tools are inferior.
* **Prerequisites:** P1-M08 (Debugging & Evidence Selection).
* **AI Mode:** AI-Free.
* **Environment:** Written reasoning & triage worksheet (no code compilation required).
* **Time Budget:** 60 minutes.
* **Scenarios Provided:**
  * **Scenario 1 (CPU Saturation):** A background communications daemon suddenly spikes CPU utilization to 100% and stops responding to IPC messages.
  * **Scenario 2 (Delayed Corruption):** A telemetry logger runs flawlessly for 3 hours, then crashes with a segmentation fault during a rare error-logging event.
  * **Scenario 3 (Silent Stalling):** A pipe-based ingestion pipeline stops processing records without crashing; CPU utilization is 0%.
* **Allowed Tools:** Official manual pages and debugger documentation.
* **Expected Deliverables for Each Scenario:**
  1. **Primary Tool Choice:** (e.g., GDB thread backtrace vs ASan vs `strace`).
  2. **Hypothesis Under Test:** Exactly what physical or logical condition is being verified or falsified.
  3. **Justification:** Why this tool provides immediate disambiguation.
  4. **Why Other Tools Are Inappropriate:** Why running a profiler, compiler flags, or log printouts would be inefficient, misleading, or destructive.
* **Common Wrong Approaches:**
  * Recommending `printf` logging for race conditions (heisenbug perturbation).
  * Suggesting AddressSanitizer for CPU-spin or pipe deadlock issues.
  * Running `strace` on memory corruption bugs.
* **Scoring (15 Points Total — 5 pts per scenario):**
  * Scenario 1 triage, tool justification, and hypothesis: 5 pts
  * Scenario 2 triage, tool justification, and hypothesis: 5 pts
  * Scenario 3 triage, tool justification, and hypothesis: 5 pts
* **Pass Criteria:** Score $\ge 12/15$; clear mapping between tool capabilities and failure domains.
* **Failure Modes:** Generic answers ("I would use GDB for everything"); confusion between syscall tracing and memory instrumentation.

---

### 4.5 Station E — Concurrency & Invariant Synchronization

* **Objective:** Diagnose, isolate, and repair a multi-threaded synchronization bug involving mutex invariants, condition-variable predicate loops, and shutdown sequencing.
* **Prerequisites:** P1-M09 (pthread Concurrency), ThreadSanitizer.
* **AI Mode:** AI-Free.
* **Environment:** Linux x86_64, GCC (`-pthread -std=c17`), TSan, GDB.
* **Time Budget:** 75 minutes.
* **Symptom:** A multi-producer, single-consumer ring queue intermittently produces out-of-order records or crashes due to buffer underflow under heavy thread contention. When shutdown is requested, worker threads occasionally hang indefinitely.
* **Allowed Tools:** GCC, TSan (`-fsanitize=thread`), GDB (`info threads`, `thread apply all bt`), Make.
* **Expected Evidence:**
  1. TSan report identifying data races, or GDB backtrace demonstrating thread deadlock on shutdown.
  2. Clear articulation of the **Protected Queue Invariant**:
     $$0 \le \text{count} \le \text{CAPACITY} \quad \wedge \quad \text{tail} = (\text{head} + \text{count}) \pmod{\text{CAPACITY}}$$
  3. Proof of condition-variable wait loops using `while` predicates instead of `if`.
  4. Proof that `close` sets the termination flag under mutex protection and broadcasts to all sleeping threads.
  5. Execution log showing worker join strictly preceding mutex and condition variable destruction.
* **Common Wrong Approaches:**
  * Using `volatile` variables as a synchronization mechanism.
  * Inserting `usleep()` or arbitrary delays to resolve thread timing conflicts.
  * Calling `pthread_mutex_destroy()` while threads are still executing or before `pthread_join()`.
* **Scoring (20 Points Total):**
  * Symptom description & 3 concurrency hypotheses: 4 pts
  * TSan or GDB diagnostic evidence with falsification notes: 4 pts
  * Explicit invariant definition and broken contract identification: 4 pts
  * Principled repair (`while` predicate, lock protection, broadcast on close): 4 pts
  * Regression suite executing 100 consecutive clean iterations under TSan: 4 pts
* **Pass Criteria:** Score $\ge 16/20$; zero TSan warnings; clean shutdown across repeated runs. Mandatory pass station.
* **Failure Modes:** Retaining `if` predicate waits; destroying mutex prior to thread join; data races remaining.

---

### 4.6 Station F — Telemetry Service Integration

* **Objective:** Audit, diagnose, and execute end-to-end regression testing on the complete Linux Systems Telemetry Service, validating input parsing, wire codecs, signal handling, and shutdown contracts.
* **Prerequisites:** P1-M10 (Linux Systems Telemetry Service).
* **AI Mode:** AI-Free.
* **Environment:** Linux x86_64, GCC, GNU Make, ASan/UBSan, FIFO test harnesses.
* **Time Budget:** 90 minutes.
* **Symptom:** When the telemetry service is connected to an active named pipe (FIFO) whose writer remains open without transmitting data, receiving `SIGTERM` causes the service to hang indefinitely instead of terminating. Concurrently, ingesting malformed wire frames containing signed values triggers undefined conversion errors.
* **Allowed Tools:** GCC, GNU Make, AddressSanitizer, UndefinedBehaviorSanitizer, shell integration scripts, `/proc/<pid>/fd`.
* **Expected Evidence:**
  1. Integration test demonstrating that sending `SIGTERM` to the service with an open, non-EOF input FIFO terminates execution promptly.
  2. Unit test verification of the 12-octet little-endian codec proving bit-preserving signed representation (e.g., `INT32_MIN` decoded via `memcpy` without implementation-defined casting).
  3. Operational evidence mapping covering the complete lifecycle:
     $$\text{Requirement} \rightarrow \text{Command/Path} \rightarrow \text{Observation} \rightarrow \text{Pass/Fail Condition}$$
  4. Full 8-step postmortem report documenting the pre-read stop check failure and repair.
* **Common Wrong Approaches:**
  * Exiting directly from the signal handler using `exit()` (unsafe in multithreaded environments).
  * Calling `read()` after `stop_requested` has been asserted.
  * Relying on `int32_t` typecasts on deserialized `uint32_t` wire bytes.
* **Scoring (20 Points Total):**
  * Complete 8-step postmortem report: 5 pts
  * Pre-read signal stop verification with open pipe: 5 pts
  * Explicit 12-octet codec validation including `INT32_MIN`: 3 pts
  * Operational evidence mapping table for the service: 4 pts
  * ASan/UBSan clean execution across all integration tests: 3 pts
* **Pass Criteria:** Score $\ge 16/20$; passes all integration tests; zero memory/concurrency leaks. Mandatory pass station.
* **Failure Modes:** Hanging on open input shutdown; unhandled `EINTR`; implementation-defined signed casting.

---

## 5. Scoring Rubric

Evaluation is holistic, emphasizing diagnostic reasoning and observable proof rather than raw output matching.

### 5.1 Rubric Scoring Dimensions (100 Points Total)

```
+----------------------------------------------------------------------------------------------------+
|                                    EVALUATION RUBRIC                                               |
+------------------------------------+--------+------------------------------------------------------+
| Dimension                          | Weight | Evaluation Criteria                                  |
+------------------------------------+--------+------------------------------------------------------+
| 1. Symptom Comprehension           | 15%    | Clear technical articulation of the observable       |
|                                    |        | failure without premature speculation.               |
| 2. Hypothesis Quality & Falsify    | 20%    | 3–5 plausible, competing physical/logical            |
|                                    |        | hypotheses proposed prior to running tools.          |
| 3. Evidence Selection & Rigor      | 25%    | Deliberate choice of diagnostic tool; concrete       |
|                                    |        | observations recorded; zero fabricated traces.       |
| 4. Root Cause Contract Accuracy    | 15%    | Pinpointing the exact broken invariant, lifetime     |
|                                    |        | boundary, or POSIX API specification.                |
| 5. Fix Correctness & Minimality    | 15%    | Minimal, principled repair preserving encapsulation  |
|                                    |        | and reentrancy; no arbitrary delays or workarounds.  |
| 6. Regression Quality              | 10%    | Automated test proving the defect is eliminated      |
|                                    |        | without introducing regressions or performance drops.|
+------------------------------------+--------+------------------------------------------------------+
```

### 5.2 Performance Classifications

* **Pass with Distinction (90–100 Points):**
  * All 6 stations executed cleanly within time budgets.
  * Diagnostic postmortems demonstrate exemplary engineering rigor.
  * Hypotheses are systematically eliminated using precise evidence.
  * Fixes are minimal, robust, and zero-warning compliant under `-Wall -Wextra -Wpedantic -Werror`.
  * Zero sanitizer warnings across Address, Undefined, and Thread sanitizers.
* **Pass (75–89 Points):**
  * Stations E and F passed with full lifecycle integrity.
  * Demonstrated solid mental models across process, memory, and concurrency domains.
  * Diagnostic records contain clear evidence and root-cause identification.
  * No more than one minor procedural flaw (e.g., suboptimal tool choice quickly corrected).
* **Rework Required (60–74 Points):**
  * Core repairs succeed, but postmortem reports exhibit "patch guessing" or lack hypothesis falsification.
  * Regression tests are incomplete or rely on manual inspection.
  * Re-examination required on deficient stations.
* **Fail (< 60 Points, or Failure on Station E or F):**
  * Demonstrates symptom-hiding workarounds (e.g., `sleep()` to mask races, `static` to hide dangling pointers).
  * Inability to formulate coherent hypotheses without AI generation.
  * Fabricated diagnostic logs or unverified claims.

---

## 6. Mastery Mapping

The Final Gate maps learner performance against the repository's 4-tier competency taxonomy:

$$\mathbf{L1\ Know} \quad \longrightarrow \quad \mathbf{L2\ Use} \quad \longrightarrow \quad \mathbf{L3\ Explain} \quad \longrightarrow \quad \mathbf{L4\text{-}local\ Debug/Design}$$

```
+---------------------------------------------------------------------------------------------------+
|                                  COMPETENCY BENCHMARK                                             |
+-------------------+-------------------------------------------------------------------------------+
| Level             | Observable Engineering Capability in Phase 1 Final Gate                       |
+-------------------+-------------------------------------------------------------------------------+
| L1 Know           | Can state POSIX syscall names, C storage classes, and ELF section definitions.|
+-------------------+-------------------------------------------------------------------------------+
| L2 Use            | Can invoke GCC with strict flags, write Makefile rules, and run GDB/ASan.    |
+-------------------+-------------------------------------------------------------------------------+
| L3 Explain        | Can explain WHY condition variables require while loops, WHY FDs share offsets|
|                   | across fork, and WHY raw struct wire casting violates portability.            |
+-------------------+-------------------------------------------------------------------------------+
| L4-local          | Can independently isolate unknown concurrency/memory bugs, design bounded     |
| Debug/Design      | multi-threaded pipelines, and construct robust automated regression suites.  |
+-------------------+-------------------------------------------------------------------------------+
```

### Explicit Non-Exaggeration Disclaimer

> [!IMPORTANT]
> Passing the Phase 1 Final Gate certifies that the learner has attained **L3/L4-local competency in foundational Linux systems programming, C object lifetime management, and multi-threaded concurrency**.
>
> It does **NOT** certify the learner as an "Embedded Linux Expert", "Kernel Hacker", or "BSP Specialist". Hardware bring-up, device drivers, kernel internals, and real-time scheduling belong exclusively to subsequent curriculum phases.

---

## 7. Failure Modes

Evaluators must actively screen for the six canonical failure modes:

1. **Patch Guessing ("Shotgun Debugging"):**
   * Modifying source lines randomly, recompiling, and checking if the crash stops without formulating a prior hypothesis.
   * *Evaluation Action:* Automatic score deduction on Hypothesis and Root Cause dimensions.
2. **AI Dependency & Prompt Outsourcing:**
   * Inability to articulate process or memory state without generative AI prompts; pasting error messages into LLMs rather than reading GDB backtraces or man pages.
   * *Evaluation Action:* Rejection of diagnostic report; re-examination in proctored AI-Free setting.
3. **Tool Misuse & Log Dumping:**
   * Pasting 500 lines of unfiltered `strace` or memory dumps into the report without highlighting the specific line that proves or disproves a hypothesis.
   * *Evaluation Action:* Zero credit for evidence selection dimension.
4. **Symptom Hiding (Workarounds vs Root Cause):**
   * Inserting `sleep()`, `usleep()`, or volatile flags to "fix" a race condition; making automatic variables `static` to "fix" a dangling pointer.
   * *Evaluation Action:* Immediate failure of the corresponding station.
5. **No Regression / Manual-Only Verification:**
   * Claiming a bug is fixed because "it worked when I ran it once manually", with no repeatable automated script or edge-case coverage.
   * *Evaluation Action:* Zero credit for regression dimension.
6. **Unverified / Fabricated Output:**
   * Claiming GDB, strace, or TSan outputs that were not actually executed on the host authoring environment.
   * *Evaluation Action:* Immediate assessment invalidation under `.editorial/REVIEW_POLICY.md`.

---

## 8. Portfolio Mapping

Completing the Phase 1 Final Gate yields concrete, verifiable engineering artifacts that learners can showcase to employers and technical interviewers:

```
+---------------------------------------------------------------------------------------------------+
|                                  PORTFOLIO ARTIFACTS                                              |
+-------------------------+-----------------------------------+-------------------------------------+
| Target Application      | Primary Artifact Produced         | Evidence Demonstrated               |
+-------------------------+-----------------------------------+-------------------------------------+
| 1. GitHub Portfolio     | `projects/linux-systems-telemetry`| Production-grade C17 service with   |
|                         | and complete diagnostic records.  | strict flags, sanitizers, and tests.|
+-------------------------+-----------------------------------+-------------------------------------+
| 2. Technical Interview  | Structured postmortem reports     | Demonstrates disciplined debugging, |
|    Discussions          | from Stations A, B, E, and F.     | hypothesis testing, and root-cause  |
|                         |                                   | reasoning under real failure modes. |
+-------------------------+-----------------------------------+-------------------------------------+
| 3. Internship / Junior  | Evidence mapping table and        | Proves the candidate does not guess |
|    Embedded Roles       | sanitizer verification logs.      | or rely on AI for core systems work.|
+-------------------------+-----------------------------------+-------------------------------------+
```

### Sample Interview Talking Points Derived from Gate Work
* *"In Station E, I investigated a multithreaded shutdown race where worker threads deadlocked. Rather than adding arbitrary sleeps, I used ThreadSanitizer and GDB to identify that condition variable predicates were checked with `if` rather than `while`, and that `queue_close` was omitting broadcast notifications."*
* *"In Station B, I traced an `EMFILE` exhaustion issue across process `fork()` boundaries using `/proc/<pid>/fd` and `strace -f`, identifying where inherited file table entries were left open across child exec boundaries."*

---

## 9. Explicit Exclusions

To maintain pedagogical focus and prevent scope creep, the Phase 1 Final Gate explicitly **excludes** all topics assigned to subsequent curriculum phases:

* **Kernel Space Development:** No Linux kernel modules, character drivers, platform drivers, device trees (`.dts`/`.dtsi`), or kernel debugging (`kgdb`, `ftrace`). (Assigned to **Phase 2: Linux Drivers**).
* **Board Bring-up & Bootloaders:** No U-Boot, SPL, barebox, or ROM bootloader analysis. (Assigned to **Phase 3: BSP & Hardware**).
* **Build Systems & Distributions:** No Buildroot, Yocto Project / OpenEmbedded recipe authoring, or rootfs generation. (Assigned to **Phase 3: BSP & Hardware**).
* **Low-Level Hardware & Architecture:** No direct MMU page table manipulation, DMA controller programming, cache coherency registers, or interrupt controller (GIC/NVIC) bare-metal driver code. (Assigned to **Phase 3 & Phase 4**).
* **SoC & Heterogeneous Systems:** No Zynq-7000 / ZynqMP FPGA fabric integration, Vivado block design, or AXI bus protocol debugging. (Assigned to **Phase 4: SoC & Architecture**).
* **Real-Time Extensions:** No PREEMPT_RT kernel patch tuning, real-time priority inheritance mutexes, or Xenomai co-kernel configurations. (Assigned to **Phase 4: Advanced Systems**).

---

## 10. Document Provenance & Verification

* **Authored by:** Antigravity AI Engineering Pair  
* **Approved by:** Pending Leader Review  
* **Canonical Branch:** `gate/phase-1-final-design`  
* **Target Merge Base:** `main`  
* **Implementation Precedent:** P1-M01 through P1-M10 canonical implementation (`2fd8adb`).
