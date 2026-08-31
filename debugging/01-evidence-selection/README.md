# P1-M08 — GDB, Sanitizers, strace: Evidence Selection

> Phase 1 / M08  
> Target: **L3**, with **L4-local** selected fault diagnosis  
> AI mode: first Challenge, Gate, initial unknown-bug investigation, and D+7 are **AI-Free**; official documentation is allowed.  
> Planned learner time: **5 h MUST** (canonical roadmap). REQUIRED external reading target: **~55–65 min**.

## Why

M08 不是 GDB 命令大全，也不是 sanitizer flags cheat sheet。核心问题是：

> **面对 symptom，哪一种 evidence source 对当前 hypothesis 的信息增益最高？**

Canonical loop:

    Symptom
    ↓
    Own Description
    ↓
    3–5 Hypotheses
    ↓
    choose one high-information experiment
    ↓
    Logs / Memory / Syscalls / Bytes / ELF
    ↓
    Narrow Scope
    ↓
    Root Cause
    ↓
    Fix
    ↓
    Regression
    ↓
    AI Review only after first-pass evidence

## Evidence taxonomy

| Question | First evidence | Why |
|---|---|---|
| 哪一行改变了 variable？ | GDB watchpoint | stop on write, not guess from final value |
| pointer 指向哪里 / call path? | GDB; sanitizer if memory-safety symptom | state/control-flow vs invalid access |
| heap buffer 是否越界 / UAF? | ASan | access + allocation/free chain |
| signed overflow / selected UB class? | UBSan where supported | runtime diagnostic for instrumented UB classes |
| process 为什么卡住？ | `ps` / `/proc`; strace timeline | current state + boundary events |
| `open` 为什么失败？ | return value + `errno`, then strace | program contract first; syscall boundary as supplement |
| child 是否到达 exec boundary? | `/proc` / strace `-f` | process lifecycle evidence |
| linker 为什么 unresolved? | linker diagnostic + `nm/readelf` | M03 binary/build domain |
| binary bytes 哪里错？ | golden bytes + `od` + codec reasoning | semantic format fault may be memory-safe |
| source variable vs raw memory? | GDB `print` vs `x` | interpretation vs bytes |

没有一个工具“最好”。工具选择必须回答一个 hypothesis-driven question。

## GDB: high-value subset

Current module uses `-O0 -g3` to reduce early observability noise. It does **not** teach that debugging always requires `-O0`; optimization can change variable availability, stepping, inlining, and control-flow correspondence.

Required commands:

    break
    run
    continue
    next
    step
    print
    ptype
    info locals
    info args
    backtrace
    frame
    x
    watch

`disassemble` is a **SHOULD / M03 bridge**, useful when source-level state must be related to generated instructions. No Python scripting, TUI curriculum, remote GDB, reverse debugging, KGDB, or core-dump deep dive here.

Mental model:

- breakpoint = stop at a control-flow location;
- watchpoint = stop when a watched memory location changes;
- `print` = debugger's typed interpretation of program state;
- `x` = examine raw memory at an address.

Always compare **source variable ↔ address ↔ raw bytes** when the bug crosses representation boundaries.

**Authoring runtime has no GDB installed.** The GDB command paths in this module are therefore explicitly **UNVERIFIED**; no transcript is fabricated.

## ASan: read the report, do not outsource it

For a memory-safety report, extract:

    Symptom
    Faulting access: read/write + size
    Allocation site
    Invalidation/free site (if applicable)
    Relevant call stack
    Root contract that allowed the invalid access

Practice covers heap UAF/OOB. Stack lifetime issues are mentioned only where detectable; sanitizer coverage varies by tool/version/options.

ASan output is evidence about an observed instrumented execution. It is not a proof that unreported paths are memory-safe.

## UBSan: selected language-rule diagnostics

M08 uses one clear signed-overflow case. Other supported classes can include shift/alignment depending on instrumentation and target. UBSan does **not** catch all undefined behavior.

    no sanitizer report
    ≠ no UB
    ≠ contract is correct
    ≠ wire format is portable

Examples from earlier modules that may remain silent:

- callback retains a borrowed pointer but has not accessed it yet;
- raw struct serialization happens to match current host bytes;
- wrong endian decode is perfectly in-bounds.

## strace: boundary timeline, not C API oracle

`strace` observes Linux system calls/signals. A libc call need not appear under a literally identical syscall name; wrapper, architecture, ABI, and kernel details matter.

Pinned v7.2 guided forms:

    strace -f ./program
    strace -f -e trace=%process ./program
    strace -e trace=%file ./program
    strace -e trace=%desc ./program

Do not memorize filters. Ask what boundary events would discriminate hypotheses.

**Authoring runtime has no strace installed.** Every strace execution path is **UNVERIFIED** and has no copied internet transcript.

## /proc vs strace

    strace → event timeline
    /proc  → current state snapshot

For an FD hang, `/proc/<pid>/fd` can show who currently holds a pipe endpoint. strace can later explain the event sequence that created/closed descriptors. Neither replaces checking return values and `errno`.

## Labs

| Lab | Question | Primary evidence |
|---|---|---|
| [01 GDB State Inspection](labs/01-gdb-state/) | why boundary state is wrong? | GDB state/control flow |
| [02 Watchpoint](labs/02-watchpoint/) | who overwrites count? | GDB watchpoint |
| [03 ASan Report Reading](labs/03-asan-report/) | where was borrowed heap object invalidated? | ASan chain |
| [04 UBSan](labs/04-ubsan/) | which numeric rule failed? | UBSan |
| [05 strace / errno](labs/05-strace-errno/) | why does open fail? | return + errno, then strace |
| [06 Multi-process Evidence](labs/06-multiprocess-evidence/) | why no EOF? | process/FD matrix + /proc, then strace |
| [07 Tool Selection Drill](labs/07-tool-selection/) | which first tool and what would falsify? | reasoning worksheet |

## Challenge — Evidence Triage: Broken Binary Reader

[challenge/](challenge/) contains four domains in one small program:

- heap lifetime bug;
- wrong-endian semantic bug;
- file/syscall failure path;
- state overwrite.

Before any tool, classify symptom and write 3–5 hypotheses. **Do not open GDB by default.**

## Fault campaign

[faults/](faults/):

- F1 UAF → ASan first;
- F2 state overwritten → GDB watchpoint first;
- F3 open failure → return/`errno` + strace;
- F4 wrong endian → golden bytes / codec reasoning;
- F5 pipe hang → FD/process matrix + `/proc` + strace.

## Gate — Evidence Selection Gate

[gate/](gate/) is **80–110 min AI-Free**. It enforces one-primary-tool evidence budget before expansion. Root cause must name the violated contract, not quote the tool label.

## M07 ↔ M08 Integration

[Corrupted Telemetry Record Investigation](integration/corrupted-telemetry/) keeps one program constant while fault domain changes:

| Mode | Primary evidence |
|---|---|
| good | golden bytes + expected decoded state |
| short | input length/bounds; ASan for the seeded invalid read |
| wrong-endian | golden bytes + decode reasoning |
| memory-fault | ASan |
| state-change | GDB watchpoint |

Transfer target: **same program, different fault domain → different evidence source.**

## Spaced review

**D+1:** 8 symptoms; write first tool + why: GDB / ASan / UBSan / strace / /proc / nm-readelf / byte dump.  
**D+3:** solve one unseen UAF and one FD hang with different evidence channels.  
**D+7:** from empty directory create a small C state/memory bug and a syscall failure; form one GDB-or-sanitizer evidence chain and one strace evidence chain. **AI-Free.** If a required tool is unavailable, that execution remains UNVERIFIED rather than replaced with copied output.

## Career relevance

    GDB        → firmware/userspace state reasoning
    sanitizers → host-side C correctness evidence
    strace     → Embedded Linux bring-up boundary evidence
    /proc      → process/FD state inspection
    selection  → BSP/driver debugging discipline later

## Scope boundary

No Valgrind/rr/perf/ftrace/bpftrace/eBPF curriculum, core-dump deep dive, KGDB/JTAG/remote GDB, kernel debugging, GDB Python, production observability, or logging framework. No M09 pthread or M10 full telemetry service.

Exact source pins and runtime/doc distinction: [SOURCE_LEDGER.md](SOURCE_LEDGER.md).
