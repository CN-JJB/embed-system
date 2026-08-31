# Lab — Multi-process Evidence

## Objective

Diagnose missing EOF by choosing process/FD state evidence before single-stepping.

## Prerequisites

M01–M07 relevant contracts; M03 tools for build/ELF domain; M04/M06 process/FD model where relevant.

## Environment

Linux userspace, GCC 14.2.0 authoring baseline. GDB/strace availability is stated in verification, never assumed.

## Estimated Time

**20–25 min**

## AI Mode

**AI-Free first pass.** Official manuals/man-pages allowed.

## Build / Procedure

    make
    run ./pipe_hang in one terminal
    inspect /proc/<parent>/fd and /proc/<child>/fd
    terminate fixture
    strace -f only where available

## Expected Observation

Seeded parent keeps write endpoint while waiting; /proc snapshot reveals extra writer reference.

## Actual Verification Status

**PARTIALLY VERIFIED** — /proc authoring run showed parent 2 pipe endpoints vs child 1; strace UNVERIFIED.

## Questions

1. What exact question are you asking the tool?
2. What hypothesis did the evidence eliminate?
3. What evidence would force you to switch domains/tools?

## Failure Modes

Opening every tool at once; treating a tool label as root cause; treating absence of a sanitizer report as correctness; assuming syscall spelling equals libc API spelling.

## Debug Strategy

Build an FD ownership matrix. /proc answers current holders; strace would answer event timeline.

## Challenge

Repair close order and verify EOF + reap.

## Cleanup

    make clean

(if no Makefile exists, no cleanup is required.)

## Sources

M08-S06/S08; see ../../SOURCE_LEDGER.md.
