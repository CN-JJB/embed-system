# Lab — ASan Report Reading

## Objective

Read a heap UAF report as an evidence chain, not just a red error label.

## Prerequisites

M01–M07 relevant contracts; M03 tools for build/ELF domain; M04/M06 process/FD model where relevant.

## Environment

Linux userspace, GCC 14.2.0 authoring baseline. GDB/strace availability is stated in verification, never assumed.

## Estimated Time

**20 min**

## AI Mode

**AI-Free first pass.** Official manuals/man-pages allowed.

## Build / Procedure

    make asan
    ./uaf_asan

## Expected Observation

ASan should identify invalid read, allocation, free/invalidation, and stack context. Exact addresses/format are non-golden.

## Actual Verification Status

**VERIFIED** — GCC 14.2.0 ASan executed and reported heap-use-after-free.

## Questions

1. What exact question are you asking the tool?
2. What hypothesis did the evidence eliminate?
3. What evidence would force you to switch domains/tools?

## Failure Modes

Opening every tool at once; treating a tool label as root cause; treating absence of a sanitizer report as correctness; assuming syscall spelling equals libc API spelling.

## Debug Strategy

Fill Symptom / Faulting access / Allocation / Free / Stack / Root contract before editing.

## Challenge

Rewrite API so retained state has coherent ownership/lifetime, then rerun ASan.

## Cleanup

    make clean

(if no Makefile exists, no cleanup is required.)

## Sources

M08-S02; see ../../SOURCE_LEDGER.md.
