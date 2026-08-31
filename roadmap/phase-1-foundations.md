# Phase 1 — System C + Linux Foundations

> Status: **Execution blueprint — Leader approval required**  
> Recommended duration: **7 weeks** (6-week Fast Track / 8-week remediation variants)  
> Core modules + project: **~62 h MUST**  
> Final Gate: **~5–6 h MUST**  
> Total mandatory planned load: **~67–68 h**  
> Weekly planned load: **~9–10 h average**, preserving meaningful unscheduled buffer  
> Full research/evidence: `research/phase-1/2026-08-31-foundations-curriculum-design.md`

## Exit capability

Phase 1 is complete when the learner can independently:

- reason about pointer/array/extent, storage duration, lifetime, ownership, pointer-to-pointer, callbacks/function pointers/`void *ctx`, `const`, bounded `volatile`, struct layout/alignment, endian/serialization, and integer UB;
- build and inspect the preprocess -> compile -> assemble -> relocatable object -> link -> ELF path;
- explain and use symbols, relocations, `.text/.rodata/.data/.bss`, and static/external linkage;
- maintain a small multi-file GNU Make C project;
- use Linux file/FD, process, `fork/exec/waitpid`, pipe/`dup2`, signal, `/proc`, pthread/mutex, basic IPC/socket concepts;
- select GCC/GDB/binutils/sanitizers/strace as evidence tools rather than command lists;
- debug using `Symptom -> Hypotheses -> Evidence -> Experiment -> Root Cause -> Fix -> Regression`.

Target is L3 on the selected foundations, with L4-local only on explicitly practiced fault classes.

## Course shape

System C and Linux are deliberately interleaved:

```text
objects / lifetime <-> process address space
files / ownership  <-> file descriptors
compile / ELF      <-> executable / exec
callbacks / ctx    <-> signal / event concepts
shared state       <-> pthread / mutex
bytes / layout     <-> serialization / telemetry data path
```

Debugging begins in Week 1. There is no standalone “debugging week.”

## Module sequence

| ID | Module | Target | MUST hours | Principal Gate |
|---|---|---|---:|---|
| P1-M01 | Objects, Storage, Extent, Linux Process Memory | L3 / L4-local faults | 6.5 | dangling/OOB/UB diagnosis with evidence |
| P1-M02 | Files, Permissions, Descriptors, Error Boundaries | L3 | 5.5 | FD-owning helper + zero-leak audit |
| P1-M03 | Translation Pipeline, Linkage, ELF, Make | L3 / L4-local link faults | 7 | repair multi-file build + symbol/relocation evidence |
| P1-M04 | Process, `fork`, `exec`, `waitpid` | L3 | 5.5 | zombie/exec/process-state diagnosis |
| P1-M05 | Ownership, Pointer-to-Pointer, Callback, `void *ctx` | L3 / L4-local ownership faults | 5.5 | callback API + lifetime/ownership proof |
| P1-M06 | Pipe, `dup2`, Signals, Small IPC | L3 | 6 | hanging-pipe root-cause postmortem |
| P1-M07 | Struct Layout, Alignment, Endian, Serialization | L3 | 4.5 | raw-byte record reconstruction |
| P1-M08 | GDB, Sanitizers, `strace`: Evidence Selection | L3 / L4-local practiced bugs | 5 | unknown-bug station |
| P1-M09 | pthread, Mutex, Race, Lock Misuse | L3 | 6 | race diagnosis + mutex/condvar predicate invariant |
| P1-M10 | Linux Systems Telemetry Service Integration | L3 integrated | ~10.5 distributed | project acceptance + fault campaign |

M10 hours are distributed across the phase and are not added as an extra full week after M01–M09.

## Mandatory source policy

Use primary/upstream sources at point of need, then books for mental models:

- C semantics: selected WG14 C draft sections.
- GCC, GNU binutils, GDB, GNU make official manuals.
- System V ABI / ELF and host psABI only for the evidence being observed.
- Linux man-pages for API contracts.
- TLPI selected chapters only; no cover-to-cover reading.
- CS:APP selected Ch. 7 linking material plus small data/machine excerpts only.
- OSTEP selected process/concurrency chapters.
- musl/BusyBox exact-file source-reading assignments.

APUE, Effective C/Modern C, additional CS61C material, static analyzers, deeper sockets and source archaeology are SHOULD/STRETCH.

## Required source-reading objects

### Tier A

1. **musl `src/string/memmove.c`** — pointer ranges, overlap, alignment, compact production C. Approx. 40–60 implementation LOC.
2. **BusyBox `coreutils/cat.c` focused normal `cat_main()` path** — CLI -> FD/data path -> error/exit boundary; ignore unrelated feature macros. Approx. 30–60 focused lines.
Before tutorial publication, pin exact tags/commits and recount LOC.

### Tier B

- A tiny musl libc/syscall wrapper such as `src/process/waitpid.c` or `src/unistd/dup2.c` remains a comparison reading until its exact pinned revision and teaching question are approved.

## Fault recurrence contract

| Fault | Introduce | Reproduce later |
|---|---|---|
| dangling pointer | M01 | M05, M08 |
| OOB / extent | M01 | M07, M10 |
| ownership | M02/M05 | M10 |
| integer UB | M01 | M07 |
| undefined reference / multiple definition / visibility | M03 | M08, Final Gate |
| FD leak | M02 | M06, M10, Final Gate |
| pipe EOF hang | M06 | Final Gate |
| zombie | M04 | M08/Final Gate |
| exec failure | M04 | M06/Final Gate |
| race | M09 | M10/Final Gate |
| deadlock/lock misuse | M09 | M10 |

A fix without an evidence-backed root cause does not pass a debugging Gate.

## Telemetry project milestones

The integration project remains intentionally small:

```text
input FD -> parser -> fixed record -> bounded ring buffer
         -> worker -> simple statistics -> logging/status
```

A ring buffer is used because the threaded milestone needs a bounded FIFO with predictable storage and no per-record allocation; it is not included as a generic embedded-data-structure exercise.

- **M0:** contract/ownership skeleton.
- **M1:** single-thread parser + multi-file Make/ELF build.
- **M2:** FD input + cleanup/leak audit.
- **M3:** callback/context API.
- **M4:** binary/layout boundary upgrade.
- **M5:** one worker + bounded ring + mutex + minimal condition-variable predicate loop.
- **M6:** async-safe stop request, normal-context queue close/wakeup/join, tracing, then one injected resource/concurrency fault with postmortem + regression.
- **Final acceptance:** clean build, tests, sanitizer modes, no unexplained leak, README with short English Build/Run/Debug section.

For M6, the asynchronous signal handler must not call pthread mutex/condition APIs or stdio. The baseline design is: handler sets a `volatile sig_atomic_t` stop request; normal control flow performs synchronization, queue shutdown, wakeup, join, and cleanup.

**Not mandatory:** daemonization, systemd, TCP/TLS, database, JSON dependency, worker pool, lock-free queue, CMake/autotools, production logging framework. Unix-domain socket status is SHOULD.

## Spaced review

- **D+1:** 5–8 min closed-note mental-model recall.
- **D+3:** ~10 min changed-context transfer question.
- **D+7:** 15–25 min AI-Free reconstruction from a blank file.
- **Phase end:** AI-Free mini-project reconstruction + one unknown fault.

Review is lightweight; repeated failure triggers remediation, not automatic content expansion.

## 7-week map

| Week | MUST | SHOULD | Weekly Gate | Planned |
|---|---|---|---|---:|
| 1 | M01 + M02 start + project M0; GDB/ASan/UBSan begin | one modern-C companion excerpt | memory/lifetime + FD ownership | 8.5–9.5 h |
| 2 | M02 finish + M03 + project M1 | CS61C linker material | ELF/link/Make | 9–10 h |
| 3 | M04 + project M2 | APUE process comparison | process/zombie/exec | 8.5–9.5 h |
| 4 | M05 + M06 + project M3 | signal-safety deeper read | callback/ownership + pipe hang | 9–10 h |
| 5 | M07 + M08 + project M4 | core dump; one static-analyzer trial | binary boundary + unknown bug | 9–10 h |
| 6 | M09 + project M5 | Unix socket orientation | race/mutex/condvar predicate | 9–10 h |
| 7 | project M6/final + reconstruction + 5–6 h Final Gate | Tier B source reading only if buffer is healthy | Phase 1 Final Gate | 10–11 h |

If schedule slips, drop SHOULD before compressing MUST or removing Gate retry buffer.

## AI rules

- **AI-Free:** first-principles foundational implementations, module Gates, D+7 reconstruction, initial unknown-bug investigation, Final Gate.
- **AI-Hint:** only after hypotheses exist; diagnostic questions and documentation navigation are allowed.
- **AI-Assisted:** post-pass code review, local refactor, test-idea generation after learner tests exist, README/style/English polish.

Do not use `Error -> paste full code to AI` as a debugging workflow.

## Phase 1 Final Gate design

**AI-Free; official documentation/man pages allowed; target 5–6 h.**

- **Part A — 30%:** from an empty directory, build a 4+ file C/Linux utility/service slice with Make, FD I/O, callback/context API, parser validation, tests and sanitizer evidence.
- **Part B — 25%:** diagnose an unfamiliar memory/FD/process/concurrency bug with the full evidence chain.
- **Part C — 20%:** use `nm/readelf/objdump` to explain a symbol, relocation, ELF section placement, compiler-vs-linker distinction, and one disassembly observation.
- **Part D — 25%:** diagnose two interacting process/FD/concurrency faults using at least two evidence channels among `/proc`, `strace`, GDB and sanitizers/TSan.

Proposed pass: total >=75%; each part >=60%; Part B >=70%; at least one Part D root cause proven at runtime; no unexplained resource leak in Part A. Leader calibrates after first learner run.

## Leader decision points

- Freeze exact learner WSL GCC/binutils/GDB/strace versions only after the first calibration run; Phase 0 authoring versions are evidence, not an automatic Phase 1 environment claim.
- Keep Unix-domain socket status **SHOULD** unless a concrete job/project dependency justifies promotion.
- Minimal condition-variable wait/signal semantics are **MUST only for the selected blocking ring-buffer project scope**; broader condition-variable study remains SHOULD.
- Pin exact musl/BusyBox tags/commits before canonical tutorial production.
- Choose at most one modern C companion (Effective C or Modern C) as SHOULD; do not create a second C syllabus.
