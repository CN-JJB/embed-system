# Phase 0 Baseline Assessment

> Status: assessment implementation candidate — Leader review required  
> Target: junior systems / embedded engineer diagnostic exercise  
> Scored mode: **AI-Free, documentation allowed**  
> Estimated scored time: **7 h 45 min** (may be split across 2–4 days)

## Purpose

This Gate measures what the learner can independently **build, inspect, reason about, and debug** before the main curriculum starts. It is not a memory quiz and it does not test FreeRTOS knowledge.

The diagnostic asks for observable engineering evidence: compiler diagnostics, object/symbol inspection, debugger observations, `/proc`/`strace` evidence, benchmark results, and manual-backed STM32 reasoning.

## Modules

| Module | Time | Score | Main evidence |
|---|---:|---:|---|
| A — System C | 90 min | 15 | bug repair + regression evidence; callback component |
| B — Compile / Link / ELF | 60 min | 10 | failing multi-file build repaired and explained with `nm/readelf/objdump` |
| C — Linux userspace | 80 min | 20 | working pipeline + process/FD investigation evidence |
| D — Debugging | 105 min | 25 | four structured fault reports; at least three true root causes |
| E — Computer Systems | 65 min | 15 | disassembly/GDB reasoning + privilege/control-flow + locality experiment |
| F — STM32 bare-metal | 65 min | 15 | startup/linker trace + timer/MMIO/DMA reasoning from official manuals |
| **Total** | **465 min** | **100** | |

The score split preserves the approved Phase 0 v1.2 balance: System C + toolchain remain 25 points in aggregate, Linux 20, Debugging 25, Computer Systems 15, STM32 15. Compile/Link/ELF is only separated structurally so its evidence is easier to review.

## Recommended order

```text
Day 1: A System C + B Compile/Link/ELF
Day 2: C Linux
Day 3: D Debugging
Day 4: E Computer Systems + F STM32
```

A learner may use a different 2–4 day split, but should record start/end times for each module and avoid consulting answers between scored sessions.

## Submission

Create a separate learner work directory outside `reviewer/` and submit:

1. modified source files or patches;
2. terminal commands used;
3. concise evidence excerpts (do not dump entire logs without explanation);
4. answers requested by each module README;
5. for every Debugging fault, the required diagnostic record;
6. a self-recorded timing sheet and AI-use attestation (you may copy `SUBMISSION_TEMPLATE.md`).

Do **not** read `reviewer/` before the assessment is scored.

## Verification status

Host C/Linux starter programs were executed during assessment authoring; exact environment and results are recorded in `research/phase-0/2026-08-30-baseline-design-notes.md`.

STM32 tasks are documentation-reviewed only and are explicitly:

**UNVERIFIED — hardware execution required**

No board output, waveform, SWD trace, or timing measurement is claimed.

## Source ledger

| ID | Source | Organization | Version / revision | Used for | Checked |
|---|---|---|---|---|---|
| S01 | GCC online manuals | GNU | GCC 16.2 current release docs | warnings, UB-related tooling, sanitizers | 2026-08-30 |
| S02 | GNU binutils manuals | GNU | current online docs | `nm`, `readelf`, `objdump`, ELF inspection | 2026-08-30 |
| S03 | Debugging with GDB | GNU | current online manual; released GDB 17.2 noted separately | debugger workflow | 2026-08-30 |
| S04 | Linux man-pages | Linux man-pages project | current online pages | `fork`, `pipe`, `dup2`, `execve`, `waitpid`, `/proc` | 2026-08-30 |
| S05 | CS:APP 3e selected material | Bryant/O'Hallaron | 3e | machine-level programs, linking, exceptional control flow, memory hierarchy | 2026-08-30 |
| S06 | TLPI | Michael Kerrisk | 2010 book + maintained man7 companion | Linux process/FD mental model | 2026-08-30 |
| S07 | OSTEP | Arpaci-Dusseau | v1.10 | process, concurrency, VM/cache/TLB mental models | 2026-08-30 |
| S08 | DS5319 STM32F103x8/xB datasheet | STMicroelectronics | Rev 20, July 2025 | selected MCU capabilities/memory | 2026-08-30 |
| S09 | RM0008 STM32F10x reference manual | STMicroelectronics | Rev 21 | clock tree, timer, ADC, DMA, interrupts | 2026-08-30 |
| S10 | PM0056 Cortex-M3 programming manual | STMicroelectronics | Rev 7, Dec 2024 | exception/NVIC/core model | 2026-08-30 |
| S11 | Phase 0 Curriculum Research & Validation | this repository | v1.2, 2026-08-30 | approved baseline scope and score balance | 2026-08-30 |

Primary URLs are intentionally listed in module/reviewer material where the learner needs to navigate official documentation. No community blog is used as a factual baseline.
